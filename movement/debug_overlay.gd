extends CanvasLayer
## Отладочный мувмент-оверлей: горизонтальная/вертикальная скорость (units/s),
## состояние земли и текущие bhop-настройки. Обновляется каждый кадр.

var label: Label

func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.position = Vector2(26.0, 84.0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.42, 0.95, 0.75, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

func _process(_delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("local_player")
	if player == null or params_of(player) == null:
		label.text = ""
		return
	var p: MovementParams = params_of(player)
	var vel: Vector3 = MovementMath.horizontal(player.vel)
	var jump_info := "-" if bool(player.on_ground) else str(int(player.jump_takeoff_ticks))
	label.text = "\n".join([
		"SPEED %.1f" % vel.length(),
		"SPEED_Z %.1f" % player.vel.y,
		"ON_GROUND %s" % ("TRUE" if bool(player.on_ground) else "FALSE"),
		"GROUND_TICKS %d" % int(player.ground_ticks),
		"TICKS_BEFORE_JUMP %s" % jump_info,
		"ENABLE_BHOP %s  AUTOBHOP %s" % ("ON" if bool(p.enable_bhop) else "OFF", "ON" if bool(p.autobhop) else "OFF"),
	])

func params_of(player: Node) -> MovementParams:
	var p: Variant = player.get("params")
	return p as MovementParams
