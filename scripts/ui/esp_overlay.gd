extends Control
## ESP overlay: рамки, HP, ник, линии до врагов. Работает при включённом чите esp.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var esp = CheatRegistry.get_cheat("esp")
	if esp == null or not esp.enabled:
		return
	var local = get_tree().get_first_node_in_group("local_player")
	if local == null or local.camera == null:
		return
	var cam: Camera3D = local.camera
	var col: Color = esp.get_color()
	var screen_size := get_viewport_rect().size
	for p in get_tree().get_nodes_in_group("players"):
		if p == local or not p.alive:
			continue
		var head: Vector3 = p.global_position + Vector3(0, 1.9, 0)
		var feet: Vector3 = p.global_position
		if cam.is_position_behind(head):
			continue
		var hp := cam.unproject_position(head)
		var fp := cam.unproject_position(feet)
		var h := absf(fp.y - hp.y)
		var w := h * 0.5
		var rect := Rect2(Vector2(hp.x - w * 0.5, hp.y), Vector2(w, h))
		if esp.show_box():
			draw_rect(rect, col, false, 2.0)
		if esp.show_hp():
			var hp_frac: float = clampf(p.hp / 100.0, 0.0, 1.0)
			var bar := Rect2(Vector2(rect.position.x - 6, rect.position.y + (1.0 - hp_frac) * rect.size.y), Vector2(4, rect.size.y * hp_frac))
			draw_rect(bar, Color(0.2, 1, 0.2, 1), true)
		if esp.show_name():
			draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y - 6), p.player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		if esp.show_line():
			draw_line(Vector2(screen_size.x * 0.5, screen_size.y), hp, col, 1.0)
