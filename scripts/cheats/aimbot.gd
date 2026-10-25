extends Cheat
## Aim assist: chooses a visible hitbox inside the configured field of view.

var _target: Dictionary = {}

func setup_settings() -> void:
    name = "Aimbot"
    id = "aimbot"
    category = "Ragebot"
    settings = {
        "fov": 35.0,
        "smooth": 8.0,
        "bone": "head",
        "key": 0,
    }

func _on_enable(_player: Node) -> void:
    _target.clear()

func apply(player: Node, delta: float) -> void:
    _target.clear()
    if player == null:
        return
    if not player.is_local or player.camera == null or not player.alive:
        player.aim_target.clear()
        return
    var key_code := int(get_setting("key", 0))
    if key_code > 0 and not Input.is_key_pressed(key_code):
        player.aim_target.clear()
        return

    var camera: Camera3D = player.camera
    var origin: Vector3 = camera.global_position
    var cos_pitch: float = cos(player.aim_pitch)
    var forward := Vector3(
        -sin(player.aim_yaw) * cos_pitch,
        sin(player.aim_pitch),
        -cos(player.aim_yaw) * cos_pitch
    ).normalized()
    var max_angle: float = deg_to_rad(clampf(float(get_setting("fov", 35.0)), 1.0, 180.0) * 0.5)
    var bone: String = str(get_setting("bone", "head"))
    var best_score: float = INF
    var best_point := Vector3.ZERO
    var best_id := -1
    var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

    for target in player.get_tree().get_nodes_in_group("players"):
        if target == player or not target.alive:
            continue
        var hitbox_path := "Model/HeadPivot/HitboxHead"
        if bone == "body":
            hitbox_path = "Model/BodyPivot/HitboxBody"
        elif bone == "legs":
            hitbox_path = "Model/HitboxLegs"
        var hitbox: Node = target.get_node_or_null(hitbox_path)
        if hitbox == null:
            continue
        var visible_point: Vector3 = hitbox.global_position
        var aim_point: Vector3 = visible_point
        var resolver = CheatRegistry.get_cheat("resolver")
        if resolver != null and resolver.enabled:
            aim_point = resolver.resolve_point(target, hitbox, player)
        var direction: Vector3 = (aim_point - origin).normalized()
        var angle: float = acos(clampf(forward.dot(direction), -1.0, 1.0))
        if angle > max_angle:
            continue

        # Require a clear ray to the target's current hitbox. World cover and
        # another player's hitbox both block target acquisition.
        var query := PhysicsRayQueryParameters3D.create(origin, visible_point)
        query.collision_mask = 5
        query.collide_with_areas = true
        query.collide_with_bodies = true
        var excluded: Array[RID] = []
        for own_hitbox in player.model.find_children("*", "Area3D", true, false):
            excluded.append(own_hitbox.get_rid())
        query.exclude = excluded
        var hit: Dictionary = space.intersect_ray(query)
        if hit.is_empty():
            continue
        var collider = hit.get("collider")
        if collider == null or not collider.has_method("get_zone_name") or collider.get("owner_player") != target:
            continue
        var score: float = angle + aim_point.distance_to(origin) * 0.0005
        if score < best_score:
            best_score = score
            best_point = aim_point
            var backtrack = CheatRegistry.get_cheat("backtrack")
            if backtrack != null and backtrack.enabled:
                best_point = backtrack.get_aim_point(target, hitbox)
            best_id = int(target.player_id)

    if best_id < 0:
        player.aim_target.clear()
        return
    var to_target: Vector3 = (best_point - origin).normalized()
    var desired_yaw: float = atan2(-to_target.x, -to_target.z)
    var desired_pitch: float = asin(clampf(to_target.y, -1.0, 1.0))
    var smoothing: float = maxf(float(get_setting("smooth", 8.0)), 0.1)
    var weight: float = 1.0 - exp(-smoothing * maxf(delta, 0.0))
    player.aim_yaw = lerp_angle(player.aim_yaw, desired_yaw, weight)
    player.aim_pitch = lerpf(player.aim_pitch, desired_pitch, weight)
    _target = {"point": best_point, "player_id": best_id}
    player.aim_target = _target.duplicate(true)

func get_target(_player: Node) -> Dictionary:
    return _target

func _on_disable(player: Node) -> void:
    _target.clear()
    if player != null:
        player.aim_target.clear()
