extends Node
## ENet networking. Clients send input and fire intent; the server owns movement, hits and score.

signal connected_to_server
signal connection_failed_signal
signal server_disconnected_signal
signal player_list_changed
signal match_state_received
signal hit_confirmed
signal respawn_received(id, pos)
signal pings_updated

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 8
const SNAPSHOT_RATE: float = 60.0
const MAX_INPUT_BATCH: int = 24
const MAX_INPUT_BUFFER: int = 96
const SERVER_FIRE_INTERVAL: float = 0.12
const PING_INTERVAL: float = 1.0
const TRACER_MIN_DISTANCE_SQ: float = 0.25

var tracer_script: GDScript = preload("res://scripts/fx/tracer.gd")
const BASE_DAMAGE: float = 25.0
const MAX_RANGE: float = 200.0
const MAX_BACKTRACK_MS: float = 200.0
const MAX_QUEUED_SHOTS: int = 128

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var local_player_name: String = "Player"

## peer id -> {name, kills, deaths, alive, hp}
var players: Dictionary = {}
## peer id -> отображаемый пинг в мс. У хоста — средний пинг всех игроков.
var pings: Dictionary = {}
var _ping_accumulator: float = 0.0
var snapshots = preload("res://scripts/net/snapshot_buffer.gd").new()
var latest_snapshot: Dictionary = {}
var last_snapshot_time: float = 0.0
var server_players: Dictionary = {}
var _input_buffer: Array = []
var _last_server_shot: Dictionary = {}
var _fire_queue: Array[Dictionary] = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		if not _fire_queue.is_empty():
			var pending: Array[Dictionary] = _fire_queue.duplicate()
			_fire_queue.clear()
			for shot in pending:
				_server_fire(int(shot["shooter_id"]), float(shot["yaw"]), float(shot["pitch"]), float(shot["rewind_ms"]))
		_ping_accumulator += delta
		if _ping_accumulator >= PING_INTERVAL:
			_ping_accumulator = 0.0
			_broadcast_pings()
	else:
		_ping_accumulator += delta

## ENet меряет RTT сам: у клиентов — до сервера, у сервера — до каждого клиента.
func _get_peer_rtt(peer_id: int) -> int:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not multiplayer.get_peers().has(peer_id):
		return 0
	return int(enet.get_peer(peer_id).get_round_trip_time())

## Пинг хоста — средний среди всех подключённых игроков, чтобы не было «нечестного» 0.
func _build_ping_table() -> Dictionary:
	var table: Dictionary = {}
	var total: float = 0.0
	var count: int = 0
	for pid in multiplayer.get_peers():
		var rtt: int = _get_peer_rtt(pid)
		table[int(pid)] = rtt
		total += float(rtt)
		count += 1
	var average: int = int(round(total / float(count))) if count > 0 else 0
	var display: Dictionary = {}
	for id in players:
		var player_id := int(id)
		if player_id == 1:
			display[player_id] = average
		else:
			display[player_id] = int(table.get(player_id, 0))
	return display

func _broadcast_pings() -> void:
	pings = _build_ping_table()
	pings_updated.emit()
	rpc("receive_pings", pings.duplicate(true))

@rpc("authority", "call_remote", "unreliable")
func receive_pings(data: Dictionary) -> void:
	pings = data
	pings_updated.emit()

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	close_connection()
	if port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		push_error("Не удалось запустить сервер: %s" % error_string(err))
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_player_name = _sanitize_name(player_name)
	GameState.reset_match()
	players.clear()
	_register_player(1, local_player_name)
	return OK

func join_game(player_name: String, ip: String, port: int = DEFAULT_PORT) -> Error:
	close_connection()
	if port < 1 or port > 65535 or ip.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip.strip_edges(), port)
	if err != OK:
		push_error("Не удалось подключиться: %s" % error_string(err))
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_player_name = _sanitize_name(player_name)
	return OK

func close_connection() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	players.clear()
	pings.clear()
	server_players.clear()
	_input_buffer.clear()
	_fire_queue.clear()
	_last_server_shot.clear()
	latest_snapshot.clear()
	last_snapshot_time = 0.0
	snapshots.clear()

func _sanitize_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		cleaned = "Player"
	return cleaned.substr(0, 16)

func _register_player(id: int, pname: String) -> void:
	var safe_name := _sanitize_name(pname)
	if players.has(id):
		players[id]["name"] = safe_name
	else:
		players[id] = {"name": safe_name, "kills": 0, "deaths": 0, "alive": true, "hp": 100.0}
	GameState.ensure_player(id, safe_name)
	player_list_changed.emit()

func get_local_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_register_player(id, "Player%d" % id)
	rpc("sync_players", players)
	_broadcast_pings()

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	# server_players aliases the arena's local_players dictionary; the arena owns node cleanup.
	_last_server_shot.erase(id)
	GameState.remove_player(id)
	player_list_changed.emit()
	rpc("sync_players", players)
	_broadcast_pings()

func _on_connected_to_server() -> void:
	rpc_id(1, "register_player", local_player_name)
	connected_to_server.emit()

func _on_connection_failed() -> void:
	close_connection()
	connection_failed_signal.emit()

func _on_server_disconnected() -> void:
	close_connection()
	server_disconnected_signal.emit()

@rpc("any_peer", "call_remote", "reliable")
func register_player(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not players.has(sender):
		return
	_register_player(sender, pname)
	rpc("sync_players", players)

@rpc("authority", "call_remote", "reliable")
func sync_players(data: Dictionary) -> void:
	players = data.duplicate(true)
	GameState.replace_scores(players)
	player_list_changed.emit()

## Input is intentionally limited to movement/angles; the server never accepts client positions.
func send_input(input: Dictionary) -> void:
	if multiplayer.is_server() or peer == null:
		return
	_input_buffer.append(input.duplicate(true))
	while _input_buffer.size() > MAX_INPUT_BUFFER:
		_input_buffer.pop_front()

func flush_inputs() -> void:
	if multiplayer.is_server() or peer == null or _input_buffer.is_empty():
		return
	var fake_lag = CheatRegistry.get_cheat("fake_lag")
	if fake_lag != null and fake_lag.enabled and _input_buffer.size() < MAX_INPUT_BATCH:
		if not fake_lag.should_send_input():
			return
	var count: int = mini(_input_buffer.size(), MAX_INPUT_BATCH)
	var batch: Array = _input_buffer.slice(0, count)
	_input_buffer = _input_buffer.slice(count)
	rpc_id(1, "submit_inputs", batch)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_inputs(inputs: Array) -> void:
	if not multiplayer.is_server() or inputs.size() > MAX_INPUT_BATCH:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player: Node = server_players.get(sender)
	if player == null or not player.has_method("apply_server_input"):
		return
	for item in inputs:
		if item is Dictionary:
			player.apply_server_input(item)

func broadcast_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var snap: Dictionary = {}
	var server_time: float = Time.get_ticks_msec() / 1000.0
	for id in server_players:
		var p: Node = server_players[id]
		if not is_instance_valid(p):
			continue
		var state := {
			"pos": p.global_position,
			"yaw": p.get_visible_yaw(),
			"pitch": p.get_visible_pitch(),
			"hp": p.hp,
			"alive": p.alive,
			"crouch": p.crouch_amount,
		}
		snap[id] = state
		snapshots.push(int(id), server_time, state["pos"], state["yaw"], state["pitch"], state["alive"], state["hp"], float(state["crouch"]))
	rpc("receive_snapshot", snap, server_time)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(snap: Dictionary, _server_time: float) -> void:
	var local_time: float = Time.get_ticks_msec() / 1000.0
	last_snapshot_time = local_time
	latest_snapshot = snap
	for id in snap:
		var state: Dictionary = snap[id]
		snapshots.push(int(id), local_time, state.get("pos", Vector3.ZERO), float(state.get("yaw", 0.0)), float(state.get("pitch", 0.0)), bool(state.get("alive", true)), float(state.get("hp", 100.0)), float(state.get("crouch", 1.0)))
	match_state_received.emit()

## A fire request contains view angles and an optional, bounded rewind window.
## The server still performs the raycast and computes all damage.
func request_fire(yaw: float, pitch: float) -> void:
	if peer == null:
		return
	var rewind_ms: float = 0.0
	var backtrack = CheatRegistry.get_cheat("backtrack")
	if backtrack != null and backtrack.enabled:
		rewind_ms = clampf(float(backtrack.get_setting("window_ms", 200.0)), 0.0, MAX_BACKTRACK_MS)
	if multiplayer.is_server():
		_queue_fire(1, yaw, pitch, rewind_ms)
	else:
		rpc_id(1, "submit_fire", yaw, pitch, rewind_ms)

@rpc("any_peer", "call_remote", "unreliable")
func submit_fire(yaw: float, pitch: float, rewind_ms: float) -> void:
	if not multiplayer.is_server():
		return
	_queue_fire(multiplayer.get_remote_sender_id(), yaw, pitch, clampf(rewind_ms, 0.0, MAX_BACKTRACK_MS))

func _queue_fire(shooter_id: int, yaw: float, pitch: float, rewind_ms: float) -> void:
	if _fire_queue.size() >= MAX_QUEUED_SHOTS:
		return
	_fire_queue.append({
		"shooter_id": shooter_id,
		"yaw": clampf(yaw, -1000.0, 1000.0),
		"pitch": clampf(pitch, -1.5, 1.5),
		"rewind_ms": clampf(rewind_ms, 0.0, MAX_BACKTRACK_MS),
	})

func _server_fire(shooter_id: int, yaw: float, pitch: float, rewind_ms: float = 0.0) -> void:
	var shooter = server_players.get(shooter_id)
	if shooter == null or not shooter.alive:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_server_shot.get(shooter_id, -100.0)) < SERVER_FIRE_INTERVAL * 0.92:
		return
	_last_server_shot[shooter_id] = now

	yaw = wrapf(yaw, -PI, PI)
	pitch = clampf(pitch, -1.5, 1.5)
	var origin: Vector3 = shooter.global_position + Vector3(0.0, 1.6, 0.0)
	var cos_pitch := cos(pitch)
	var direction := Vector3(-sin(yaw) * cos_pitch, sin(pitch), -cos(yaw) * cos_pitch).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * MAX_RANGE)
	query.collision_mask = 5
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	var model: Node = shooter.get_node_or_null("Model")
	if model:
		for hitbox in model.find_children("*", "Area3D", true, false):
			excluded.append(hitbox.get_rid())
	query.exclude = excluded
	var current_hit: Dictionary = shooter.get_world_3d().direct_space_state.intersect_ray(query)
	var blocker_distance: float = MAX_RANGE
	var current_victim = null
	var current_zone: String = ""
	var current_multiplier: float = 1.0
	if not current_hit.is_empty():
		blocker_distance = origin.distance_to(current_hit["position"])
		var current_hitbox = current_hit.get("collider")
		if current_hitbox != null and current_hitbox.has_method("get_damage_multiplier"):
			current_victim = current_hitbox.get("owner_player")
			if current_victim != null and current_victim != shooter and current_victim.alive:
				current_zone = current_hitbox.get_zone_name()
				current_multiplier = float(current_hitbox.get_damage_multiplier())
			else:
				current_victim = null

	var victim = null
	var zone: String = ""
	var damage_multiplier: float = 1.0
	var historical_hit: Dictionary = {}
	if rewind_ms > 0.0:
		historical_hit = _find_historical_hit(origin, direction, shooter_id, rewind_ms, blocker_distance)
		if not historical_hit.is_empty():
			victim = server_players.get(int(historical_hit["player_id"]))
			zone = str(historical_hit["zone"])
			damage_multiplier = float(historical_hit["multiplier"])
	if victim == null:
		victim = current_victim
		zone = current_zone
		damage_multiplier = current_multiplier

	# Трассер уходит всем (и хосту) при ЛЮБОМ выстреле: промах или попадание.
	# Стартует из ДУЛА винтовки стрелявшего, а не из головы.
	var end_point: Vector3 = origin + direction * MAX_RANGE
	if not historical_hit.is_empty():
		end_point = origin + direction * minf(float(historical_hit["distance"]), blocker_distance)
	elif not current_hit.is_empty():
		end_point = current_hit["position"]
	var tracer_from: Vector3 = origin
	if shooter.has_method("get_muzzle_global"):
		tracer_from = shooter.get_muzzle_global()
	_emit_tracer(tracer_from, end_point)

	if victim == null or victim == shooter or not victim.alive or zone.is_empty():
		return

	var damage: float = BASE_DAMAGE * damage_multiplier
	victim.take_damage(damage)
	var killed: bool = not victim.alive
	if players.has(victim.player_id):
		players[victim.player_id]["hp"] = victim.hp
		players[victim.player_id]["alive"] = victim.alive
	if killed:
		if players.has(shooter_id):
			players[shooter_id]["kills"] = int(players[shooter_id].get("kills", 0)) + 1
		if players.has(victim.player_id):
			players[victim.player_id]["deaths"] = int(players[victim.player_id].get("deaths", 0)) + 1
		GameState.add_kill(shooter_id, victim.player_id)
		_start_respawn_timer(victim.player_id)
		rpc("sync_players", players)
	hit_confirmed.emit(shooter_id, victim.player_id, zone, damage, killed)
	rpc("receive_hit", shooter_id, victim.player_id, zone, damage, killed)

func _find_historical_hit(origin: Vector3, direction: Vector3, shooter_id: int, rewind_ms: float, blocker_distance: float) -> Dictionary:
	var sample_time: float = Time.get_ticks_msec() / 1000.0 - rewind_ms / 1000.0
	var best: Dictionary = {}
	var best_distance: float = MAX_RANGE + 1.0
	var zones: Array[Dictionary] = [
		{"zone": "head", "offset": Vector3(0.0, 1.68, 0.0), "radius": 0.29, "multiplier": 4.0},
		{"zone": "body", "offset": Vector3(0.0, 1.0, 0.0), "radius": 0.48, "multiplier": 1.0},
		{"zone": "legs", "offset": Vector3(0.0, 0.45, 0.0), "radius": 0.34, "multiplier": 0.6},
	]
	for id in server_players:
		if int(id) == shooter_id:
			continue
		var sampled: Variant = snapshots.sample(int(id), sample_time)
		if sampled == null:
			continue
		var state: Dictionary = sampled
		if not bool(state.get("alive", true)):
			continue
		var player_position: Vector3 = state["pos"]
		# присед сжимает модель/хитзоны — этим же множителем проверяем исторические точки
		var squat: float = clampf(float(state.get("crouch", 1.0)), 0.5, 1.5)
		for zone_data in zones:
			var center: Vector3 = player_position + (zone_data["offset"] as Vector3) * squat
			var distance: float = _ray_sphere_distance(origin, direction, center, float(zone_data["radius"]))
			if distance < 0.0 or distance >= best_distance or distance >= blocker_distance or distance > MAX_RANGE:
				continue
			best_distance = distance
			best = {
				"player_id": int(id),
				"zone": str(zone_data["zone"]),
				"multiplier": float(zone_data["multiplier"]),
				"distance": distance,
			}
	return best

func _ray_sphere_distance(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> float:
	var offset: Vector3 = origin - center
	var b: float = offset.dot(direction)
	var c: float = offset.length_squared() - radius * radius
	var discriminant: float = b * b - c
	if discriminant < 0.0:
		return -1.0
	var distance: float = -b - sqrt(discriminant)
	if distance < 0.0:
		distance = -b + sqrt(discriminant)
	return distance if distance >= 0.0 else -1.0

@rpc("authority", "call_remote", "reliable")
func receive_hit(shooter_id: int, victim_id: int, zone: String, damage: float, killed: bool) -> void:
	hit_confirmed.emit(shooter_id, victim_id, zone, damage, killed)

## Трассер рисуется у всех, включая хоста (call_local).
@rpc("authority", "call_local", "unreliable")
func receive_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	_spawn_tracer_node(from_pos, to_pos)

## Трассер, который клиент рисует СРАЗУ при своем выстреле (локальный предикт —
## без сетевой задержки и без зависимости от серверного RPC).
func spawn_local_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	_spawn_tracer_node(from_pos, to_pos)

func _spawn_tracer_node(from_pos: Vector3, to_pos: Vector3) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		push_warning("[Tracer] нет SceneTree — трассер не создан")
		return
	var scene: Node = tree.current_scene
	if scene == null:
		push_warning("[Tracer] current_scene == null — трассер не создан")
		return
	if tracer_script == null:
		push_error("[Tracer] tracer_script не загрузился (preload) — трассер не создан")
		return
	var tracer: Node3D = tracer_script.new()
	tracer.from = from_pos
	tracer.to = to_pos
	tracer.name = "Tracer"
	scene.add_child(tracer)

func _emit_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if from_pos.distance_squared_to(to_pos) < TRACER_MIN_DISTANCE_SQ:
		return
	rpc("receive_tracer", from_pos, to_pos)

func _start_respawn_timer(id: int) -> void:
	await get_tree().create_timer(GameState.RESPAWN_TIME).timeout
	var player: Node = server_players.get(id)
	if player == null:
		return
	var arena: Node = get_tree().get_first_node_in_group("arena")
	var pos := Vector3(0.0, 1.0, 0.0)
	if arena and arena.has_method("get_spawn_position"):
		pos = arena.get_spawn_position()
	player.respawn(pos)
	if players.has(id):
		players[id]["hp"] = player.hp
		players[id]["alive"] = true
	rpc("receive_respawn", id, pos)
	rpc("sync_players", players)

@rpc("authority", "call_remote", "reliable")
func receive_respawn(id: int, pos: Vector3) -> void:
	respawn_received.emit(id, pos)
