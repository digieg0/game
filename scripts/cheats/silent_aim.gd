extends Cheat
## Silent Aim: прицел и камера НЕ наводятся на врага.
## Пуля сама летит в цель: углы выстрела подменяются только в request_fire,
## а видимая модель/камера остаются на свободном взгляде игрока.

var _angles: Dictionary = {}      # {yaw, pitch, player_id} — свежие за последний тик
var _next_attempt_time: float = 0.0

func setup_settings() -> void:
	name = "Silent Aim"
	id = "silent_aim"
	category = "Ragebot"
	settings = {
		"fov": 120.0,          # сектор выбора цели (180 = всё вокруг)
		"chance": 90.0,        # шанс автопрострела, %
		"auto_fire": true,     # стрелять в цель автоматически (палец на триггере тоже работает)
		"bone": "head",
		"retry_delay": 0.12,   # пауза между ролями шанса, сек
		"key": 0,
	}

func _on_enable(_player: Node) -> void:
	_angles.clear()
	_next_attempt_time = 0.0

func apply(player: Node, _delta: float) -> void:
	_angles.clear()
	if player == null or not player.is_local or not player.alive or player.camera == null:
		return
	var key_code := int(get_setting("key", 0))
	if key_code > 0 and not Input.is_key_pressed(key_code):
		return
	var found := _find_target(player)
	if found.is_empty():
		return
	_angles = {
		"yaw": float(found["yaw"]),
		"pitch": float(found["pitch"]),
		"player_id": int(found["player_id"]),
	}
	if not bool(get_setting("auto_fire", true)):
		return
	# Сервер не примет выстрел чаще SERVER_FIRE_INTERVAL — respect кулдауна.
	if player._fire_cooldown > 0.0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _next_attempt_time:
		return
	_next_attempt_time = now + maxf(float(get_setting("retry_delay", 0.12)), 0.01)
	var chance: float = clampf(float(get_setting("chance", 90.0)), 0.0, 100.0)
	if randf() * 100.0 < chance:
		player.force_shoot = true

## Хук из Player._fire_once: подменяем углы выстрела (камеру не трогаем).
func get_shot_angles(_player: Node) -> Dictionary:
	return _angles

func _on_disable(_player: Node) -> void:
	_angles.clear()
	_next_attempt_time = 0.0

func _find_target(player: Node) -> Dictionary:
	var camera: Camera3D = player.camera
	var origin: Vector3 = camera.global_position
	var cos_pitch: float = cos(player.aim_pitch)
	var forward := Vector3(
		-sin(player.aim_yaw) * cos_pitch,
		sin(player.aim_pitch),
		-cos(player.aim_yaw) * cos_pitch
	).normalized()
	var max_angle: float = deg_to_rad(clampf(float(get_setting("fov", 120.0)), 1.0, 180.0) * 0.5)
	var bone: String = str(get_setting("bone", "head"))
	var best_score: float = INF
	var best := {}
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state

	for target in player.get_tree().get_nodes_in_group("players"):
		if target == player or not target.alive:
			continue
		var hitbox_path: String = "Model/HitboxLegs"
		if bone == "head":
			hitbox_path = "Model/HeadPivot/HitboxHead"
		elif bone == "body":
			hitbox_path = "Model/BodyPivot/HitboxBody"
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

		# Чистая линия до хитбокса: стены и чужие хитбоксы мешают выбору цели.
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
			var point: Vector3 = aim_point
			var backtrack = CheatRegistry.get_cheat("backtrack")
			if backtrack != null and backtrack.enabled:
				point = backtrack.get_aim_point(target, hitbox)
			var to_point: Vector3 = (point - origin).normalized()
			best = {
				"yaw": atan2(-to_point.x, -to_point.z),
				"pitch": asin(clampf(to_point.y, -1.0, 1.0)),
				"player_id": int(target.player_id),
			}
	return best
