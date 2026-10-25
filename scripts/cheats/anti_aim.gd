extends Cheat
## Anti-aim: подменяет видимый угол поворота модели, не влияя на направление выстрела.

var _angle: float = 0.0

func setup_settings() -> void:
	name = "Anti-Aim"
	id = "anti_aim"
	category = "Anti-Aim"
	settings = {
		"yaw_offset": 0.0,
		"pitch_offset": 0.0,
		"mode": "static",
		"jitter_speed": 10.0,
	}

func _on_enable(_player: Node) -> void:
	_angle = 0.0

func apply(player: Node, delta: float) -> void:
	var mode: String = String(get_setting("mode", "static"))
	var yaw_off: float = float(get_setting("yaw_offset", 0.0))
	var pitch_off: float = float(get_setting("pitch_offset", 0.0))
	match mode:
		"static":
			_angle = deg_to_rad(yaw_off)
		"jitter":
			var js: float = float(get_setting("jitter_speed", 10.0))
			_angle = deg_to_rad(yaw_off + sin(Time.get_ticks_msec() / 100.0 * js) * 30.0)
		"down":
			_angle = deg_to_rad(yaw_off + 90.0)
		"up":
			_angle = deg_to_rad(yaw_off - 90.0)
	if player != null:
		player.aa_yaw_offset = _angle
		player.aa_pitch = deg_to_rad(pitch_off)

func _on_disable(player: Node) -> void:
	if player != null:
		player.aa_yaw_offset = 0.0
		player.aa_pitch = 0.0