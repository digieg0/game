extends Cheat
## Spinbot: вращение модели игрока по yaw.
## Направление камеры/выстрела не меняется.

var _angle: float = 0.0

func setup_settings() -> void:
	name = "Spinbot"
	id = "spinbot"
	category = "Anti-Aim"
	settings = {
		"speed": 720.0,
		"mode": "spin",
		"direction": 1,
	}

func _on_enable(_player: Node) -> void:
	_angle = 0.0

func apply(player: Node, delta: float) -> void:
	var speed: float = float(get_setting("speed", 720.0))
	var mode: String = String(get_setting("mode", "spin"))
	var dir: int = int(get_setting("direction", 1))
	match mode:
		"spin":
			_angle = wrapf(_angle + deg_to_rad(speed) * dir * delta, -PI, PI)
		"jitter":
			_angle = deg_to_rad(90.0) * dir * (1.0 if fmod(Time.get_ticks_msec() / 100.0, 2.0) < 1.0 else -1.0)
		"random":
			_angle = randf_range(-PI, PI)
	if player != null:
		player.spin_extra_yaw = _angle

func _on_disable(player: Node) -> void:
	if player != null:
		player.spin_extra_yaw = 0.0
