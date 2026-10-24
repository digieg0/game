extends Node
## Сетевой менеджер (автолоад).
## Хост поднимает ENet-сервер, клиенты подключаются по IP.
## Сервер хранит авторитетные позиции и HP, клиенты шлют ввод.

signal connected_to_server
signal connection_failed_signal
signal server_disconnected_signal
signal player_list_changed
signal match_state_received
signal hit_confirmed

const DEFAULT_PORT: int = 27015
const MAX_PLAYERS: int = 8
const TICK_RATE: float = 60.0

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var local_player_name: String = "Player"

## id -> {name, score, kills, deaths, alive, hp}
var players: Dictionary = {}

## История снапшотов для интерполяции/backtrack
var snapshots := preload("res://scripts/net/snapshot_buffer.gd").new()

## Последний полученный/отправленный снапшот: id -> {pos, yaw, pitch, hp, alive}
var latest_snapshot: Dictionary = {}
## Время последнего снапшота
var last_snapshot_time: float = 0.0

## Сервер: id -> Player-узел
var server_players: Dictionary = {}

## Fake lag буфер: массив накопленных инпутов
var _input_buffer: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Не удалось запустить сервер: %s" % err)
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	players.clear()
	_register_player(1, player_name)
	return OK

func join_game(player_name: String, ip: String, port: int = DEFAULT_PORT) -> Error:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Не удалось подключиться: %s" % err)
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_player_name = player_name
	return OK

func close_connection() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	players.clear()
	latest_snapshot.clear()
	snapshots.clear()

func _register_player(id: int, pname: String) -> void:
	players[id] = {"name": pname, "score": 0, "kills": 0, "deaths": 0, "alive": true, "hp": 100.0}
	player_list_changed.emit()

func get_local_id() -> int:
	return multiplayer.get_unique_id()

# --- Сетевые колбэки ---

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		# Сервер сообщает новому клиенту актуальный список
		rpc_id(id, "sync_players", players)
		if not players.has(id):
			_register_player(id, "Player%d" % id)
			rpc("sync_players", players)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		players.erase(id)
		player_list_changed.emit()
		rpc("sync_players", players)

func _on_connected_to_server() -> void:
	rpc_id(1, "register_player", local_player_name)
	connected_to_server.emit()

func _on_connection_failed() -> void:
	close_connection()
	connection_failed_signal.emit()

func _on_server_disconnected() -> void:
	close_connection()
	server_disconnected_signal.emit()

# --- Регистрация ---

@rpc("any_peer", "call_remote", "reliable")
func register_player(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_register_player(sender, pname)
	rpc("sync_players", players)

@rpc("authority", "call_remote", "reliable")
func sync_players(data: Dictionary) -> void:
	players = data
	player_list_changed.emit()

# --- Ввод и снапшоты (сервер авторитетен по позиции) ---

## Клиент отправляет ввод серверу (позиция считается на сервере)
func send_input(input: Dictionary) -> void:
	if multiplayer.is_server():
		return
	_input_buffer.append(input)

## Вызывать каждый физический тик на клиенте: с учётом fake lag отправляет пачку
func flush_inputs() -> void:
	if multiplayer.is_server() or _input_buffer.is_empty():
		return
	var interval := 1
	var fl = CheatRegistry.get_cheat("fake_lag")
	if fl != null and fl.enabled:
		interval = int(fl.get_setting("limit", 5)) + 1
	if Engine.get_physics_frames() % interval == 0:
		rpc_id(1, "submit_inputs", _input_buffer)
		_input_buffer.clear()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_inputs(inputs: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var p: Node = server_players.get(sender)
	if p == null:
		return
	for inp in inputs:
		p.apply_server_input(inp)

## Сервер рассылает снапшоты всем клиентам
func broadcast_snapshot() -> void:
	if not multiplayer.is_server():
		return
	var snap: Dictionary = {}
	for id in server_players:
		var p: Node = server_players[id]
		snap[id] = {
			"pos": p.global_position,
			"yaw": p.get_visible_yaw(),
			"pitch": p.get_visible_pitch(),
			"hp": p.hp,
			"alive": p.alive,
		}
	rpc("receive_snapshot", snap, Time.get_ticks_msec() / 1000.0)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(snap: Dictionary, t: float) -> void:
	last_snapshot_time = t
	latest_snapshot = snap
	for id in snap:
		var s: Dictionary = snap[id]
		snapshots.push(id, t, s["pos"], s["yaw"], s["pitch"], s["alive"])

# --- Попадания (клиентский hit-рейкаст) ---

## Клиент сообщает серверу о попадании
func report_hit(shooter_id: int, victim_id: int, zone: String, dmg: float) -> void:
	if multiplayer.is_server():
		_apply_hit(shooter_id, victim_id, zone, dmg)
	else:
		rpc_id(1, "submit_hit", shooter_id, victim_id, zone, dmg)

@rpc("any_peer", "call_remote", "reliable")
func submit_hit(shooter_id: int, victim_id: int, zone: String, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_hit(sender, victim_id, zone, dmg)

func _apply_hit(shooter_id: int, victim_id: int, zone: String, dmg: float) -> void:
	var victim: Node = server_players.get(victim_id)
	if victim == null or not victim.alive:
		return
	victim.take_damage(dmg)
	var killed: bool = not victim.alive
	if killed:
		GameState.add_kill(shooter_id, victim_id)
		_start_respawn_timer(victim_id)
	rpc("receive_hit", shooter_id, victim_id, zone, dmg, killed)

@rpc("authority", "call_remote", "reliable")
func receive_hit(shooter_id: int, victim_id: int, zone: String, dmg: float, killed: bool) -> void:
	hit_confirmed.emit(shooter_id, victim_id, zone, dmg, killed)

# --- Респавн ---

func _start_respawn_timer(id: int) -> void:
	await get_tree().create_timer(GameState.RESPAWN_TIME).timeout
	var p: Node = server_players.get(id)
	if p == null:
		return
	var arena := get_tree().get_first_node_in_group("arena")
	var pos := Vector3(0, 1, 0)
	if arena and arena.has_method("get_spawn_position"):
		pos = arena.get_spawn_position()
	p.respawn(pos)
	rpc("receive_respawn", id, pos)

@rpc("authority", "call_remote", "reliable")
func receive_respawn(id: int, pos: Vector3) -> void:
	respawn_received.emit(id, pos)

signal respawn_received(id, pos)
