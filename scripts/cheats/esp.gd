extends Cheat
## ESP: подсветка врагов — боксы, HP, ники, линии.

func setup_settings() -> void:
	name = "ESP"
	id = "esp"
	category = "Visuals"
	settings = {
		"box": true,
		"hp": true,
		"name": true,
		"line": true,
		"color": Color(1, 0, 0, 1),
	}

func _on_enable(_player: Node) -> void:
	pass

func apply(player: Node, delta: float) -> void:
	pass

func get_color() -> Color:
	return Color(get_setting("color", Color(1, 0, 0, 1)))

func show_box() -> bool:
	return bool(get_setting("box", true))

func show_hp() -> bool:
	return bool(get_setting("hp", true))

func show_name() -> bool:
	return bool(get_setting("name", true))

func show_line() -> bool:
	return bool(get_setting("line", true))

func _on_disable(player: Node) -> void:
	pass