extends Node3D
## Arena lifecycle, player spawning and interpolated remote rendering.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
var local_players: Dictionary = {}
var local_id: int = 0
var _snapshot_accumulator: float = 0.0

func _ready() -> void:
    add_to_group("arena")
    NetManager.player_list_changed.connect(_rebuild_players)
    NetManager.respawn_received.connect(_on_respawn)
    NetManager.hit_confirmed.connect(_on_hit_confirmed)
    local_id = NetManager.get_local_id()
    _rebuild_players()
    if multiplayer.is_server():
        NetManager.server_players = local_players

func _exit_tree() -> void:
    if NetManager.player_list_changed.is_connected(_rebuild_players):
        NetManager.player_list_changed.disconnect(_rebuild_players)
    if NetManager.respawn_received.is_connected(_on_respawn):
        NetManager.respawn_received.disconnect(_on_respawn)
    if NetManager.hit_confirmed.is_connected(_on_hit_confirmed):
        NetManager.hit_confirmed.disconnect(_on_hit_confirmed)
    if multiplayer.is_server():
        NetManager.server_players.clear()

func _physics_process(delta: float) -> void:
    if multiplayer.is_server():
        _snapshot_accumulator += delta
        var interval: float = 1.0 / NetManager.SNAPSHOT_RATE
        if _snapshot_accumulator >= interval:
            _snapshot_accumulator = fmod(_snapshot_accumulator, interval)
            NetManager.broadcast_snapshot()
    else:
        _apply_snapshots()

func _rebuild_players() -> void:
    for id in local_players.keys():
        if not NetManager.players.has(id):
            if is_instance_valid(local_players[id]):
                local_players[id].queue_free()
            local_players.erase(id)
    for id in NetManager.players:
        if local_players.has(id):
            local_players[id].player_name = str(NetManager.players[id].get("name", "Player"))
            continue
        var player = PLAYER_SCENE.instantiate()
        player.setup(int(id), str(NetManager.players[id].get("name", "Player")), int(id) == local_id)
        player.add_to_group("players")
        if int(id) == local_id:
            player.add_to_group("local_player")
        # Node3D.global_position requires the node to be inside the scene tree.
        # Add first, then apply the world-space spawn transform.
        add_child(player)
        player.global_position = get_spawn_position()
        local_players[id] = player
        var model: Node = player.get_node("Model")
        for hitbox in model.find_children("*", "Area3D", true, false):
            hitbox.owner_player = player
    if multiplayer.is_server():
        NetManager.server_players = local_players

func _apply_snapshots() -> void:
    if NetManager.last_snapshot_time <= 0.0:
        return
    var render_time: float = NetManager.last_snapshot_time - 0.05
    for id in local_players:
        if int(id) == local_id:
            continue
        var snap: Variant = NetManager.snapshots.sample(int(id), render_time)
        if snap == null:
            continue
        var player: Node = local_players[id]
        var state: Dictionary = snap
        player.global_position = player.global_position.lerp(state["pos"], 0.5)
        player.visible_yaw = float(state["yaw"])
        player.visible_pitch = float(state["pitch"])
        player.hp = float(state.get("hp", 100.0))
        var was_alive: bool = player.alive
        player.alive = bool(state["alive"])
        player.visible = player.alive
        if was_alive != player.alive:
            player.set_hitboxes_enabled(player.alive)
        player.crouch_amount = clampf(float(state.get("crouch", 1.0)), float(player.CROUCH_SCALE), 1.0)
        if player.model and player.model.has_method("set_server_pose"):
            player.model.set_server_pose(player.visible_yaw, player.visible_pitch)
        player._apply_pose(player.crouch_amount)

func _on_respawn(id: int, pos: Vector3) -> void:
    var player: Node = local_players.get(id)
    if player:
        player.respawn(pos)

func _on_hit_confirmed(shooter_id: int, victim_id: int, _zone: String, damage: float, killed: bool) -> void:
    if not multiplayer.is_server() and victim_id == local_id:
        var local_player = local_players.get(local_id)
        if local_player != null:
            local_player.hp = maxf(0.0, float(local_player.hp) - damage)
            if killed:
                local_player.alive = false
                local_player.visible = false
                local_player.set_hitboxes_enabled(false)
    var hud: Node = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("add_hitmarker") and shooter_id == local_id:
        hud.add_hitmarker(killed)

func get_spawn_position() -> Vector3:
    var spawns := $Spawns.get_children()
    if spawns.is_empty():
        return Vector3(0.0, 0.1, 0.0)
    var marker: Node3D = spawns[randi() % spawns.size()]
    return marker.global_position + Vector3(0.0, 0.1, 0.0)
