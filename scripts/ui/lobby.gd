extends Control
## Full-screen lobby and connection form.

signal host_requested(pname: String, port: int)
signal join_requested(pname: String, ip: String, port: int)

const ACCENT: Color = Color(0.16, 0.79, 1.0, 1.0)
const MUTED: Color = Color(0.57, 0.67, 0.79, 1.0)

var name_input: LineEdit
var ip_input: LineEdit
var port_input: LineEdit
var error_label: Label
var host_btn: Button
var join_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.04, 0.07, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var decoration := ColorRect.new()
	decoration.position = Vector2(0.0, 0.0)
	decoration.size = Vector2(6.0, 720.0)
	decoration.color = ACCENT
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decoration)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -238.0
	panel.offset_right = 280.0
	panel.offset_bottom = 238.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
	panel_style.border_color = Color(0.16, 0.79, 1.0, 0.5)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 13)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var eyebrow := Label.new()
	eyebrow.text = "ARENA PROTOCOL   /   BUILD 0.2"
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", MUTED)
	vbox.add_child(eyebrow)

	var title := Label.new()
	title.text = "HVH  /  ARENA"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A compact arena shooter. Out-aim, out-move, outplay."
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", MUTED)
	vbox.add_child(subtitle)
	var line := HSeparator.new()
	vbox.add_child(line)

	var name_label := _field_label("PLAYER NAME")
	vbox.add_child(name_label)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your nickname"
	name_input.text = "Player"
	name_input.max_length = 16
	name_input.custom_minimum_size = Vector2(0.0, 42.0)
	_style_input(name_input)
	vbox.add_child(name_input)

	var server_row := HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 12)
	vbox.add_child(server_row)
	var ip_column := VBoxContainer.new()
	ip_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_column.add_child(_field_label("SERVER IP"))
	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(0.0, 42.0)
	_style_input(ip_input)
	ip_column.add_child(ip_input)
	server_row.add_child(ip_column)
	var port_column := VBoxContainer.new()
	port_column.custom_minimum_size.x = 112.0
	port_column.add_child(_field_label("PORT"))
	port_input = LineEdit.new()
	port_input.text = "27015"
	port_input.placeholder_text = "27015"
	port_input.max_length = 5
	port_input.custom_minimum_size = Vector2(0.0, 42.0)
	_style_input(port_input)
	port_column.add_child(port_input)
	server_row.add_child(port_column)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)
	host_btn = Button.new()
	host_btn.text = "CREATE SERVER"
	host_btn.custom_minimum_size = Vector2(0.0, 46.0)
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(host_btn, true)
	host_btn.pressed.connect(_on_host)
	buttons.add_child(host_btn)
	join_btn = Button.new()
	join_btn.text = "JOIN SERVER"
	join_btn.custom_minimum_size = Vector2(0.0, 46.0)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(join_btn, false)
	join_btn.pressed.connect(_on_join)
	buttons.add_child(join_btn)

	error_label = Label.new()
	error_label.text = ""
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_font_size_override("font_size", 12)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.36, 1.0))
	vbox.add_child(error_label)
	var footer := Label.new()
	footer.text = "WASD MOVE  ·  SPACE JUMP  ·  LMB FIRE  ·  INS SETTINGS"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.4, 0.5, 0.62, 1.0))
	vbox.add_child(footer)

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.84, 1.0))
	return label

func _style_input(input: LineEdit) -> void:
	input.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0, 1.0))
	input.add_theme_color_override("font_placeholder_color", Color(0.38, 0.47, 0.6, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.04, 0.065, 1.0)
	normal.border_color = Color(0.16, 0.23, 0.32, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	input.add_theme_stylebox_override("normal", normal)

func _style_button(button: Button, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT if primary else Color(0.1, 0.15, 0.22, 1.0)
	normal.border_color = ACCENT if primary else Color(0.22, 0.33, 0.46, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.86, 1.0, 1.0) if primary else Color(0.15, 0.23, 0.33, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color(0.025, 0.045, 0.07, 1.0) if primary else Color(0.88, 0.94, 1.0, 1.0))

func _read_port() -> int:
	var value := port_input.text.strip_edges()
	if not value.is_valid_int():
		return -1
	return int(value)

func _on_host() -> void:
	show_error("")
	var port := _read_port()
	if port < 1 or port > 65535:
		show_error("Port must be between 1 and 65535.")
		return
	host_requested.emit(name_input.text.strip_edges(), port)

func _on_join() -> void:
	show_error("")
	var port := _read_port()
	if ip_input.text.strip_edges().is_empty():
		show_error("Enter the server IP address.")
		return
	if port < 1 or port > 65535:
		show_error("Port must be between 1 and 65535.")
		return
	join_requested.emit(name_input.text.strip_edges(), ip_input.text.strip_edges(), port)

func show_error(message: String) -> void:
	if error_label:
		error_label.text = message
