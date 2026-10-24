extends Cheat
## Resolver: попытка угадать реальный угол цели с anti-aim/spin.
## Эвристика: хранит историю видимых yaw жертв, предсказывает
## «истинный» угол и брутфорсит по миссам.

## victim_id -> Array[float] история видимых yaw
var _history: Dictionary = {}
## victim_id -> Array[float] накопленные смещения (брутфорс)
var _bruteforce: Dictionary = {}

func setup_settings() -> void:
	name = "Resolver"
	id = "resolver"
	category = "Ragebot"
	settings = {
		"enabled_mode": "heuristic",
		"history_ticks": 16,
		"bruteforce_step": 30.0,
		"misses_before_bruteforce": 2,
		"stats_enabled": true,
		"hits": 0,
		"misses": 0,
	}

func apply(player: Node, delta: float) -> void:
	for p in player.get_tree().get_nodes_in_group("players"):
		if p == player:
			continue
		if not _history.has(p.player_id):
			_history[p.player_id] = []
		var arr: Array = _history[p.player_id]
		arr.append(p.visible_yaw)
		var max_ticks: int = int(get_setting("history_ticks", 16))
		while arr.size() > max_ticks:
			arr.pop_front()

## Резолвнуть позицию хитбокса цели: возвращает точку с учётом предсказанного yaw
func resolve_point(target: Node, hitbox: Area3D, player: Node) -> Vector3:
	var mode: String = String(get_setting("enabled_mode", "heuristic"))
	var base: Vector3 = hitbox.global_position
	if mode == "none":
		return base
	# Предсказанный yaw
	var pred_yaw: float = target.visible_yaw
	if _history.has(target.player_id):
		var arr: Array = _history[target.player_id]
		if arr.size() >= 2:
			# Экстраполяция по средней угловой скорости
			var sum := 0.0
			for i in range(1, arr.size()):
				sum += angle_difference(arr[i - 1], arr[i])
			var avg := sum / float(arr.size() - 1)
			pred_yaw = arr[arr.size() - 1] + avg
	var offset: float = pred_yaw - target.visible_yaw
	# Смещаем точку вращением вокруг центра игрока
	var center: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	var rel := base - center
	var rot := Basis(Vector3.UP, offset)
	return center + rot * rel

## Учесть попадание/мисс для брутфорса
func report_result(target_id: int, hit: bool) -> void:
	if bool(get_setting("stats_enabled", true)):
		if hit:
			set_setting("hits", int(get_setting("hits", 0)) + 1)
		else:
			set_setting("misses", int(get_setting("misses", 0)) + 1)
	if hit:
		return
	if not _bruteforce.has(target_id):
		_bruteforce[target_id] = 0.0
	var step := deg_to_rad(float(get_setting("bruteforce_step", 30.0)))
	_bruteforce[target_id] = wrapf(float(_bruteforce[target_id]) + step, -PI, PI)

func get_bruteforce_offset(target_id: int) -> float:
	return float(_bruteforce.get(target_id, 0.0))

func _on_disable(_player: Node) -> void:
	_history.clear()
	_bruteforce.clear()
