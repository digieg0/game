extends Cheat
## Automatically requests a shot when the crosshair is directly over an enemy hitbox.

var _last_shot: float = 0.0

func setup_settings() -> void:
    name = "Triggerbot"
    id = "triggerbot"
    category = "Ragebot"
    settings = {"delay": 0.05, "bone": "head"}

func _on_enable(_player: Node) -> void:
    _last_shot = 0.0

func apply(player: Node, _delta: float) -> void:
    if player == null or not player.is_local or not player.alive or player.camera == null:
        return
    var origin: Vector3 = player.camera.global_position
    var cos_pitch: float = cos(player.aim_pitch)
    var direction := Vector3(
        -sin(player.aim_yaw) * cos_pitch,
        sin(player.aim_pitch),
        -cos(player.aim_yaw) * cos_pitch
    ).normalized()
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0)
    query.collision_mask = 5
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var exclude: Array[RID] = []
    for hitbox in player.model.find_children("*", "Area3D", true, false):
        exclude.append(hitbox.get_rid())
    query.exclude = exclude
    var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var hitbox: Node = hit.get("collider")
    if hitbox == null or not hitbox.has_method("get_zone_name"):
        return
    var victim: Node = hitbox.get("owner_player")
    if victim == null or victim == player or not victim.alive:
        return
    var expected_bone: String = str(get_setting("bone", "head"))
    if expected_bone != "" and hitbox.get_zone_name() != expected_bone:
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    if now - _last_shot >= maxf(float(get_setting("delay", 0.05)), 0.0):
        player.force_shoot = true
        _last_shot = now

func on_shoot(_player: Node, _ctx: Dictionary) -> void:
    pass

func _on_disable(_player: Node) -> void:
    pass
