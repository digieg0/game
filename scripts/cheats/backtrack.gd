extends Cheat
## Backtrack: стрельба по прошлой позиции цели из snapshot_buffer.
## Клиентский: рейкаст по позе из буфера N мс назад. Серверной истории нет.

func setup_settings() -> void:
	name = "Backtrack"
	id = "backtrack"
	category = "Ragebot"
	settings = {
		"window_ms": 200.0,
	}

## Вернуть точку цели из прошлого, если включён. Иначе текущую.
func get_aim_point(target: Node, hitbox: Area3D) -> Vector3:
	var window: float = float(get_setting("window_ms", 200.0)) / 1000.0
	var now: float = Time.get_ticks_msec() / 1000.0
	var snap: Variant = NetManager.snapshots.sample(target.player_id, now - window)
	if snap == null:
		return hitbox.global_position
	var pose: Dictionary = snap
	if not pose.get("alive", true):
		return hitbox.global_position
	# Смещение хитбокса относительно игрока в прошлом
	var center: Vector3 = target.global_position
	var rel: Vector3 = hitbox.global_position - center
	return pose["pos"] + rel
