extends Cheat
## Ragebot: мгновенно наводит прицел и СРАЗУ стреляет, как только команда
## «вышла» на противника (цель появился в зоне наводки). Каждый выстрел
## проходит проверку шанса попадания.

var _last_target_id: int = -1
## Время следующей попытки выстрела после неудачного рола шанса
## (чтобы шанс не «перекатывался» каждый физический кадр).
var _next_attempt_time: float = 0.0

func setup_settings() -> void:
	name = "Ragebot"
	id = "ragebot"
	category = "Ragebot"
	settings = {
		"fov": 120.0,          # сектор автонаводки (180 = всё вокруг)
		"chance": 85.0,        # ШАНС ВЫСТРЕЛА, %
		"bone": "head",
		"first_shot_chance": 100.0,  # шанс первого выстрела на цели (выход на противника)
		"retry_delay": 0.15,   # пауза между ролями шанса, сек
		"key": 0,
	}

func _on_enable(_player: Node) -> void:
	_last_target_id = -1
	_next_attempt_time = 0.0

func apply(player: Node, _delta: float) -> void:
	if player == null or not player.is_local or not player.alive:
		_forget(player)
		return
	var key_code := int(get_setting("key", 0))
	if key_code > 0 and not Input.is_key_pressed(key_code):
		_forget(player)
		return

	var aim := _find_target(player)
	if aim.is_empty():
		_forget(player)
		return

	var target_id: int = int(aim["player_id"])
	var newly_acquired: bool = target_id != _last_target_id
	_last_target_id = target_id
	player.aim_target = {
		"point": aim["point"],
		"player_id": target_id,
	}

	# Мгновенный снап прицела — без сглаживания, это rage.
	var to_point: Vector3 = Vector3(aim["point"]) - player.camera.global_position
	var yaw: float = atan2(-to_point.x, -to_point.z)
	var pitch: float = asin(clampf(to_point.normalized().y, -1.0, 1.0))
	player.aim_yaw = yaw
	player.aim_pitch = pitch
	player.camera_pivot.rotation = Vector3(pitch, yaw, 0.0)

	# Сервер не примет выстрел чаще SERVER_FIRE_INTERVAL — не спамим под кулдаун.
	if player._fire_cooldown > 0.0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _next_attempt_time:
		return
	# Выход на противника — стреляем сразу, шанс первого выстрела отдельный.
	var chance: float = float(get_setting("first_shot_chance", 100.0)) \
		if newly_acquired else float(get_setting("chance", 85.0))
	_next_attempt_time = now + maxf(float(get_setting("retry_delay", 0.15)), 0.01)
	if randf() * 100.0 < clampf(chance, 0.0, 100.0):
		player.force_shoot = true

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

		# Требуем чистую линию до хитбокса: стены и чужие хитбоксы мешают наводке.
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
			best = {"point": point, "player_id": int(target.player_id)}
	return best

func _forget(player: Node) -> void:
	_last_target_id = -1
	if player != null and player.get("aim_target") != null:
		player.aim_target.clear()

func _on_disable(player: Node) -> void:
	_forget(player)
	_next_attempt_time = 0.0
