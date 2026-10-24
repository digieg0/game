extends Node3D
## Арена: спавн игроков, применение снапшотов, респавн.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var local_players: Dictionary = {}
var local_id: int = 0

func _ready() -> void:
	add_to_group("arena")
	NetManager.player_list_changed.connect(_rebuild_players)
	NetManager.respawn_received.connect(_on_respawn)
	NetManager.hit_confirmed.connect(_on_hit_confirmed)
	local_id = NetManager.get_local_id()
	if multiplayer.is_server():
		NetManager.server_players = local_players
	_rebuild_players()

func _physics_process(_delta: float) -> void:
	if multiplayer.is_server():
		NetManager.broadcast_snapshot()
	else:
		_apply_snapshots()
	NetManager.flush_inputs()

func _rebuild_players() -> void:
	for id in local_players.keys():
		if not NetManager.players.has(id):
			local_players[id].queue_free()
			local_players.erase(id)
	for id in NetManager.players:
		if local_players.has(id):
			continue
		var p = PLAYER_SCENE.instantiate()
		p.setup(id, NetManager.players[id]["name"], id == local_id)
		p.add_to_group("players")
		if id == local_id:
			p.add_to_group("local_player")
		p.global_position = get_spawn_position()
		add_child(p)
		local_players[id] = p
		for hb in p.get_node("Model").find_children("*", "Area3D", true, false):
			hb.owner_player = p
	if multiplayer.is_server():
		NetManager.server_players = local_players

func _apply_snapshots() -> void:
	var t := NetManager.last_snapshot_time
	if t <= 0.0:
		return
	var render_t := t - 0.05
	for id in local_players:
		if id == local_id:
			continue
		var snap: Variant = NetManager.snapshots.sample(id, render_t)
		if snap == null:
			continue
		var p = local_players[id]
		var s: Dictionary = snap
		p.global_position = p.global_position.lerp(s["pos"], 0.5)
		p.visible_yaw = s["yaw"]
		p.visible_pitch = s["pitch"]
		p.hp = s["hp"]
		p.alive = s["alive"]
		p.model.set_server_pose(s["yaw"], s["pitch"])
		p.visible = s["alive"]

func _on_respawn(id: int, pos: Vector3) -> void:
	var p = local_players.get(id)
	if p:
		p.respawn(pos)

func _on_hit_confirmed(shooter_id: int, _victim_id: int, _zone: String, _dmg: float, killed: bool) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_hitmarker") and shooter_id == local_id:
		hud.add_hitmarker(killed)

func get_spawn_position() -> Vector3:
	var spawns := $Spawns.get_children()
	if spawns.is_empty():
		return Vector3(0, 1, 0)
	var m: Node3D = spawns[randi() % spawns.size()]
	return m.global_position + Vector3(0, 1.0, 0)
