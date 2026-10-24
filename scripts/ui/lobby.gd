extends Control
## Лобби: хост / подключение по IP, ввод ника. HvH-стиль.

signal host_requested(pname: String, port: int)
signal join_requested(pname: String, ip: String, port: int)

var name_input: LineEdit
var ip_input: LineEdit
var port_input: LineEdit
var host_btn: Button
var join_btn: Button
var error_label: Label

const ACCENT_COLOR: Color = Color(0.2, 0.6, 1.0, 1)
const BG_COLOR: Color = Color(0.1, 0.1, 0.12, 1)
const PANEL_COLOR: Color = Color(0.15, 0.15, 0.18, 1)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.95, 1)

func _ready() -> void:
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -260
	offset_top = -210
	offset_right = 260
	offset_bottom = 210
	size = Vector2(520, 420)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "HVH // LOBBY"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Мультиплеерный шутер, где читы — легальная механика"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Никнейм"
	name_input.text = "Player"
	name_input.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(name_input)

	ip_input = LineEdit.new()
	ip_input.placeholder_text = "IP сервера"
	ip_input.text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(ip_input)

	port_input = LineEdit.new()
	port_input.placeholder_text = "Порт"
	port_input.text = "27015"
	port_input.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(port_input)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btns)

	host_btn = Button.new()
	host_btn.text = "Host"
	host_btn.custom_minimum_size = Vector2(160, 44)
	host_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	host_btn.pressed.connect(_on_host)
	btns.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "Join"
	join_btn.custom_minimum_size = Vector2(160, 44)
	join_btn.pressed.connect(_on_join)
	btns.add_child(join_btn)

	error_label = Label.new()
	error_label.text = ""
	error_label.add_theme_font_size_override("font_size", 14)
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	vbox.add_child(error_label)

func _on_host() -> void:
	error_label.text = ""
	host_requested.emit(name_input.text.strip_edges(), int(port_input.text.strip_edges()))

func _on_join() -> void:
	error_label.text = ""
	join_requested.emit(name_input.text.strip_edges(), ip_input.text.strip_edges(), int(port_input.text.strip_edges()))

func show_error(msg: String) -> void:
	error_label.text = msg