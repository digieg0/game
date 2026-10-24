extends CanvasLayer
## Чит-меню в стиле HvH: вкладки Ragebot / Anti-Aim / Visuals / Misc / Config.
## Открывается Insert. Управляет CheatRegistry.

const CATEGORIES := ["Ragebot", "Anti-Aim", "Visuals", "Misc", "Config"]

const ACCENT_COLOR: Color = Color(0.2, 0.6, 1.0, 1)
const BG_COLOR: Color = Color(0.1, 0.1, 0.12, 0.95)
const PANEL_COLOR: Color = Color(0.15, 0.15, 0.18, 1)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.95, 1)

var _root: Panel
var _tabs: TabContainer
var _config_name: LineEdit
var _status: Label
var _open: bool = false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_cheat_menu"):
		if _open:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_menu() -> void:
	_open = false
	_root.visible = false
	if NetManager.peer != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build() -> void:
	_root = Panel.new()
	_root.position = Vector2(40, 40)
	_root.size = Vector2(900, 620)
	_root.modulate = PANEL_COLOR
	add_child(_root)

	var bg := ColorRect.new()
	bg.size = Vector2(900, 620)
	bg.color = Color(0, 0, 0, 0.4)
	add_child(bg)
	bg.move_child(_root, -1)

	var title := Label.new()
	title.text = "HVH // CHEAT MENU"
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	_root.add_child(title)

	var sub := Label.new()
	sub.text = "Insert — открыть/закрыть"
	sub.position = Vector2(16, 36)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	_root.add_child(sub)

	_tabs = TabContainer.new()
	_tabs.position = Vector2(8, 64)
	_tabs.size = Vector2(884, 548)
	_root.add_child(_tabs)

	for cat in CATEGORIES:
		var scroll := ScrollContainer.new()
		scroll.name = cat
		_tabs.add_child(scroll)
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 8)
		scroll.add_child(panel)
		if cat == "Config":
			_build_config_tab(panel)
		else:
			_build_cheat_tab(panel, cat)

func _build_cheat_tab(parent: VBoxContainer, category: String) -> void:
	for cheat in CheatRegistry.get_by_category(category):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var cb := CheckBox.new()
		cb.text = cheat.name
		cb.button_pressed = cheat.enabled
		cb.toggled.connect(func(v): cheat.set_enabled(_local_player(), v))
		hbox.add_child(cb)
		parent.add_child(hbox)
		for key in cheat.settings.keys():
			_add_setting_row(parent, cheat, key)
		var sep := HSeparator.new()
		parent.add_child(sep)

func _add_setting_row(parent: VBoxContainer, cheat: Cheat, key: String) -> void:
	var value: Variant = cheat.settings[key]
	if value is bool:
		var cb := CheckBox.new()
		cb.text = "  " + key
		cb.button_pressed = value
		cb.toggled.connect(func(v): cheat.set_setting(key, v))
		parent.add_child(cb)
	elif value is int or value is float:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "  " + key
		label.custom_minimum_size.x = 170
		h.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = maxf(1000.0, float(value) * 2.0)
		slider.step = 1.0 if value is int else 0.1
		slider.value = float(value)
		slider.custom_minimum_size.x = 340
		slider.value_changed.connect(func(v): cheat.set_setting(key, v))
		h.add_child(slider)
		parent.add_child(h)
	elif value is String:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "  " + key
		label.custom_minimum_size.x = 170
		h.add_child(label)
		var opt := OptionButton.new()
		var options := ["spin", "jitter", "random", "static", "down", "up", "head", "body", "legs", "none", "heuristic"]
		for i in options.size():
			opt.add_item(options[i], i)
			if options[i] == value:
				opt.selected = i
		opt.item_selected.connect(func(idx): cheat.set_setting(key, options[idx]))
		h.add_child(opt)
		parent.add_child(h)
	elif value is Color:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "  " + key
		label.custom_minimum_size.x = 170
		h.add_child(label)
		var picker := ColorPickerButton.new()
		picker.color = value
		picker.color_changed.connect(func(c): cheat.set_setting(key, c))
		h.add_child(picker)
		parent.add_child(h)

func _build_config_tab(parent: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_config_name = LineEdit.new()
	_config_name.text = "default"
	_config_name.custom_minimum_size.x = 220
	h.add_child(_config_name)
	var save_btn := Button.new()
	save_btn.text = "Сохранить"
	save_btn.add_theme_color_override("font_color", ACCENT_COLOR)
	save_btn.pressed.connect(_on_save)
	h.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Загрузить"
	load_btn.pressed.connect(_on_load)
	h.add_child(load_btn)
	parent.add_child(h)
	_status = Label.new()
	_status.text = "Конфиги: user://configs/"
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
	parent.add_child(_status)

func _on_save() -> void:
	ConfigManager.save_config(_config_name.text.strip_edges())
	_status.text = "Сохранено: " + _config_name.text

func _on_load() -> void:
	ConfigManager.load_config(_config_name.text.strip_edges())
	_status.text = "Загружено: " + _config_name.text
	_rebuild_cheat_tabs()

func _rebuild_cheat_tabs() -> void:
	for i in range(4):
		var scroll: ScrollContainer = _tabs.get_child(i)
		var panel: VBoxContainer = scroll.get_child(0)
		for c in panel.get_children():
			c.queue_free()
		await get_tree().process_frame
		_build_cheat_tab(panel, CATEGORIES[i])

func _local_player() -> Node:
	return get_tree().get_first_node_in_group("local_player")