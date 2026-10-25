extends CanvasLayer
## Settings menu for the game's abilities and visual options. Opens with INSERT.

const CATEGORIES: Array[String] = ["Ragebot", "Anti-Aim", "Visuals", "Misc", "Config"]
const ACCENT: Color = Color(0.16, 0.79, 1.0, 1.0)
const MUTED: Color = Color(0.55, 0.66, 0.78, 1.0)

var _backdrop: ColorRect
var _root: PanelContainer
var _tabs: TabContainer
var _config_name: LineEdit
var _status: Label
var _open: bool = false

func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    _set_open(false)

func _input(event: InputEvent) -> void:
    # Use _input rather than _unhandled_input so gameplay/UI controls cannot
    # consume INSERT before this menu sees it.
    var toggle_pressed := false
    if event is InputEventKey and event.pressed and not event.echo:
        toggle_pressed = event.physical_keycode == KEY_INSERT or event.keycode == KEY_INSERT
    if event.is_action_pressed("toggle_cheat_menu") or toggle_pressed:
        _set_open(not _open)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("escape_menu") and _open:
        _set_open(false)
        get_viewport().set_input_as_handled()

func _set_open(value: bool) -> void:
    _open = value
    if _backdrop:
        _backdrop.visible = value
    if _root:
        _root.visible = value
    if value:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif NetManager.peer != null:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build() -> void:
    _backdrop = ColorRect.new()
    _backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _backdrop.color = Color(0.005, 0.015, 0.03, 0.78)
    _backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _backdrop.gui_input.connect(_on_backdrop_input)
    add_child(_backdrop)

    _root = PanelContainer.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _root.offset_left = -460.0
    _root.offset_top = -310.0
    _root.offset_right = 460.0
    _root.offset_bottom = 310.0
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.045, 0.06, 0.09, 0.99)
    panel_style.border_color = Color(0.16, 0.79, 1.0, 0.65)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(8)
    _root.add_theme_stylebox_override("panel", panel_style)
    add_child(_root)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 18)
    margins.add_theme_constant_override("margin_right", 18)
    margins.add_theme_constant_override("margin_top", 16)
    margins.add_theme_constant_override("margin_bottom", 16)
    _root.add_child(margins)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 9)
    margins.add_child(layout)

    var heading := HBoxContainer.new()
    layout.add_child(heading)
    var title := Label.new()
    title.text = "HVH  /  CONTROL CENTER"
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    var key_hint := Label.new()
    key_hint.text = "INSERT TO CLOSE"
    key_hint.add_theme_font_size_override("font_size", 10)
    key_hint.add_theme_color_override("font_color", MUTED)
    heading.add_child(key_hint)

    var separator := HSeparator.new()
    layout.add_child(separator)
    _tabs = TabContainer.new()
    _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(_tabs)

    for category in CATEGORIES:
        var scroll := ScrollContainer.new()
        scroll.name = category
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _tabs.add_child(scroll)
        var contents := VBoxContainer.new()
        contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        contents.add_theme_constant_override("separation", 10)
        scroll.add_child(contents)
        if category == "Config":
            _build_config_tab(contents)
        else:
            _build_cheat_tab(contents, category)

func _on_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and _open:
        _set_open(false)

const MOVEMENT_CONTROLS: Array = [
    {"name": "autobhop", "type": "bool"},
    {"name": "enable_bhop", "type": "bool"},
    {"name": "gravity", "type": "float", "min": 100.0, "max": 1600.0},
    {"name": "accelerate", "type": "float", "min": 1.0, "max": 20.0},
    {"name": "air_accelerate", "type": "float", "min": 1.0, "max": 200.0},
    {"name": "air_wishspeed_cap", "type": "float", "min": 1.0, "max": 500.0},
    {"name": "friction", "type": "float", "min": 0.0, "max": 15.0},
    {"name": "weapon_max_speed", "type": "float", "min": 100.0, "max": 1000.0},
    {"name": "jump_height", "type": "float", "min": 10.0, "max": 300.0},
]

func _build_cheat_tab(parent: VBoxContainer, category: String) -> void:
    if category == "Misc":
        _build_movement_section(parent)
    var category_cheats: Array = CheatRegistry.get_by_category(category)
    if category_cheats.is_empty():
        var empty_label := Label.new()
        empty_label.text = "No options in this category yet."
        empty_label.add_theme_color_override("font_color", MUTED)
        parent.add_child(empty_label)
        return
    for cheat in category_cheats:
        var card := PanelContainer.new()
        var card_style := StyleBoxFlat.new()
        card_style.bg_color = Color(0.065, 0.09, 0.13, 1.0)
        card_style.border_color = Color(0.14, 0.22, 0.31, 1.0)
        card_style.set_border_width_all(1)
        card_style.set_corner_radius_all(6)
        card.add_theme_stylebox_override("panel", card_style)
        parent.add_child(card)
        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 12)
        margin.add_theme_constant_override("margin_right", 12)
        margin.add_theme_constant_override("margin_top", 10)
        margin.add_theme_constant_override("margin_bottom", 10)
        card.add_child(margin)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 7)
        margin.add_child(box)

        var title_row := HBoxContainer.new()
        box.add_child(title_row)
        var name_label := Label.new()
        name_label.text = str(cheat.name)
        name_label.add_theme_font_size_override("font_size", 15)
        name_label.add_theme_color_override("font_color", Color(0.91, 0.96, 1.0, 1.0))
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        title_row.add_child(name_label)
        var enabled := CheckBox.new()
        enabled.text = "ENABLED"
        enabled.button_pressed = cheat.enabled
        enabled.add_theme_color_override("font_color", ACCENT)
        enabled.toggled.connect(func(value: bool): cheat.set_enabled(_local_player(), value))
        title_row.add_child(enabled)

        var description := Label.new()
        description.text = _description_for(str(cheat.id))
        description.add_theme_font_size_override("font_size", 11)
        description.add_theme_color_override("font_color", MUTED)
        box.add_child(description)
        for key in cheat.settings.keys():
            if str(key) == "enabled":
                continue
            _add_setting_row(box, cheat, str(key))

func _build_movement_section(parent: VBoxContainer) -> void:
    var card := PanelContainer.new()
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.065, 0.09, 0.13, 1.0)
    card_style.border_color = Color(0.24, 0.7, 0.42, 0.8)
    card_style.set_border_width_all(1)
    card_style.set_corner_radius_all(6)
    card.add_theme_stylebox_override("panel", card_style)
    parent.add_child(card)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    card.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    margin.add_child(box)
    var title_row := HBoxContainer.new()
    box.add_child(title_row)
    var name_label := Label.new()
    name_label.text = "Movement  /  CS2"
    name_label.add_theme_font_size_override("font_size", 15)
    name_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.7, 1.0))
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(name_label)
    var description := Label.new()
    description.text = "Меняет MovementParams в рантайме. Физика только читает."
    description.add_theme_font_size_override("font_size", 11)
    description.add_theme_color_override("font_color", MUTED)
    box.add_child(description)
    var params: MovementParams = MovementSettings.params
    for mc in MOVEMENT_CONTROLS:
        var key: String = str(mc["name"])
        if mc["type"] == "bool":
            var check := CheckBox.new()
            check.text = key.replace("_", " ").capitalize()
            check.button_pressed = bool(params.get(key))
            check.toggled.connect(func(value: bool): params.set(key, value))
            box.add_child(check)
        else:
            _add_movement_slider(box, params, key, float(mc["min"]), float(mc["max"]))
    var reset := Button.new()
    reset.text = "RESET DEFAULTS"
    reset.pressed.connect(_on_reset_movement)
    box.add_child(reset)

func _add_movement_slider(parent: VBoxContainer, params: MovementParams, key: String,
        min_value: float, max_value: float) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var label := Label.new()
    label.text = key.replace("_", " ").capitalize()
    label.custom_minimum_size.x = 160.0
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(0.67, 0.77, 0.88, 1.0))
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = 0.1 if max_value - min_value <= 40.0 else 1.0
    var value := float(params.get(key, min_value))
    slider.value = clampf(value, min_value, max_value)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var readout := Label.new()
    readout.text = "%.1f" % value
    readout.custom_minimum_size.x = 52.0
    readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    slider.value_changed.connect(func(next_value: float):
        params.set(key, next_value)
        readout.text = "%.1f" % next_value
    )
    row.add_child(slider)
    row.add_child(readout)

func _on_reset_movement() -> void:
    MovementSettings.reset_params()
    _rebuild_cheat_tabs()

func _description_for(cheat_id: String) -> String:
    match cheat_id:
        "aimbot": return "Selects a visible target within the field of view."
        "triggerbot": return "Fires when the crosshair intersects an enemy."
        "ragebot": return "Snaps at the visible target and fires INSTANTLY on target acquisition. Sets shot chance."
        "anti_aim": return "Changes the pose shown to other players."
        "spinbot": return "Rotates your displayed model."
        "esp": return "Shows enemy outlines and status information."
        "bhop_assist": return "Automates jumps when you land."
        "fake_lag": return "Buffers outgoing movement input."
        "backtrack": return "Samples recent positions from the snapshot history."
        "resolver": return "Estimates target pose from recent snapshots."
        _: return "Tune this ability for your preferred play style."

func _add_setting_row(parent: VBoxContainer, cheat: Cheat, key: String) -> void:
    var value: Variant = cheat.settings[key]
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var label := Label.new()
    label.text = key.replace("_", " ").capitalize()
    label.custom_minimum_size.x = 160.0
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(0.67, 0.77, 0.88, 1.0))
    row.add_child(label)

    if value is bool:
        var checkbox := CheckBox.new()
        checkbox.button_pressed = value
        checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        checkbox.toggled.connect(func(next_value: bool): cheat.set_setting(key, next_value))
        row.add_child(checkbox)
    elif value is int and key == "key":
        var picker := OptionButton.new()
        var key_labels: Array[String] = ["Always on", "Shift", "Ctrl", "Alt", "Space", "Q", "E"]
        var key_values: Array[int] = [0, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_SPACE, KEY_Q, KEY_E]
        for index in range(key_labels.size()):
            picker.add_item(key_labels[index], key_values[index])
            if int(value) == key_values[index]:
                picker.select(index)
        picker.item_selected.connect(func(index: int): cheat.set_setting(key, key_values[index]))
        row.add_child(picker)
    elif value is int and key == "direction":
        var picker := OptionButton.new()
        picker.add_item("Clockwise", 1)
        picker.add_item("Counter-clockwise", -1)
        picker.select(0 if int(value) >= 0 else 1)
        picker.item_selected.connect(func(index: int): cheat.set_setting(key, picker.get_item_id(index)))
        row.add_child(picker)
    elif value is int:
        var spin := SpinBox.new()
        var bounds := _numeric_bounds(cheat.id, key, float(value))
        spin.min_value = bounds.x
        spin.max_value = bounds.y
        spin.step = 1.0
        spin.value = float(value)
        spin.custom_minimum_size.x = 130.0
        spin.value_changed.connect(func(next_value: float): cheat.set_setting(key, int(round(next_value))))
        row.add_child(spin)
    elif value is float:
        var bounds := _numeric_bounds(cheat.id, key, value)
        var slider := HSlider.new()
        slider.min_value = bounds.x
        slider.max_value = bounds.y
        slider.step = 0.1 if bounds.y - bounds.x <= 40.0 else 1.0
        slider.value = clampf(value, bounds.x, bounds.y)
        slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var readout := Label.new()
        readout.text = "%.1f" % value
        readout.custom_minimum_size.x = 52.0
        readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        slider.value_changed.connect(func(next_value: float):
            cheat.set_setting(key, next_value)
            readout.text = "%.1f" % next_value
        )
        row.add_child(slider)
        row.add_child(readout)
    elif value is String:
        var options: Array = _enum_options(cheat.id, key)
        if options.is_empty():
            var input := LineEdit.new()
            input.text = value
            input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            input.text_submitted.connect(func(next_value: String): cheat.set_setting(key, next_value))
            row.add_child(input)
        else:
            var picker := OptionButton.new()
            for index in range(options.size()):
                picker.add_item(str(options[index]))
                if str(options[index]) == value:
                    picker.select(index)
            picker.item_selected.connect(func(index: int): cheat.set_setting(key, options[index]))
            row.add_child(picker)
    elif value is Color:
        var picker := ColorPickerButton.new()
        picker.color = value
        picker.color_changed.connect(func(next_color: Color): cheat.set_setting(key, next_color))
        row.add_child(picker)

func _numeric_bounds(cheat_id: String, key: String, current: float) -> Vector2:
    match key:
        "fov": return Vector2(5.0, 180.0)
        "smooth": return Vector2(1.0, 20.0)
        "delay": return Vector2(0.0, 0.5)
        "chance", "first_shot_chance": return Vector2(0.0, 100.0)
        "retry_delay": return Vector2(0.01, 1.0)
        "speed": return Vector2(30.0, 1800.0)
        "jitter_speed": return Vector2(1.0, 30.0)
        "limit": return Vector2(0.0, 12.0)
        "window_ms": return Vector2(0.0, 500.0)
        "history_ticks": return Vector2(4.0, 64.0)
        "bruteforce_step": return Vector2(5.0, 90.0)
        "misses_before_bruteforce": return Vector2(1.0, 10.0)
        "hits", "misses": return Vector2(0.0, 10000.0)
        "key": return Vector2(0.0, 4194310.0)
        _: return Vector2(0.0, maxf(100.0, current * 2.0))

func _enum_options(cheat_id: String, key: String) -> Array:
    match key:
        "bone": return ["head", "body", "legs"]
        "mode":
            if cheat_id == "anti_aim":
                return ["static", "jitter", "down", "up"]
            return ["spin", "jitter", "random"]
        "enabled_mode": return ["heuristic", "none"]
        _: return []

func _build_config_tab(parent: VBoxContainer) -> void:
    var description := Label.new()
    description.text = "Save your current setup or load a preset from user://configs/."
    description.add_theme_color_override("font_color", MUTED)
    parent.add_child(description)
    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    parent.add_child(controls)
    _config_name = LineEdit.new()
    _config_name.text = "default"
    _config_name.placeholder_text = "Config name"
    _config_name.custom_minimum_size.x = 240.0
    _config_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls.add_child(_config_name)
    var save_button := Button.new()
    save_button.text = "SAVE CONFIG"
    save_button.pressed.connect(_on_save)
    controls.add_child(save_button)
    var load_button := Button.new()
    load_button.text = "LOAD CONFIG"
    load_button.pressed.connect(_on_load)
    controls.add_child(load_button)
    _status = Label.new()
    _status.text = "Configs are stored locally."
    _status.add_theme_font_size_override("font_size", 11)
    _status.add_theme_color_override("font_color", MUTED)
    parent.add_child(_status)
    var refresh_button := Button.new()
    refresh_button.text = "SHOW AVAILABLE CONFIGS"
    refresh_button.pressed.connect(_show_configs)
    parent.add_child(refresh_button)

func _on_save() -> void:
    var label: String = _config_name.text.strip_edges()
    var success: bool = get_node("/root/ConfigManager").save_config(label)
    _status.text = ("Saved: " if success else "Could not save: ") + label

func _on_load() -> void:
    var label: String = _config_name.text.strip_edges()
    var success: bool = get_node("/root/ConfigManager").load_config(label, _local_player())
    _status.text = ("Loaded: " if success else "Could not load: ") + label
    if success:
        _rebuild_cheat_tabs()

func _show_configs() -> void:
    var names: Array[String] = get_node("/root/ConfigManager").list_configs()
    _status.text = "Available: " + (", ".join(names) if not names.is_empty() else "none yet")

func _rebuild_cheat_tabs() -> void:
    for index in range(4):
        var scroll: ScrollContainer = _tabs.get_child(index)
        var contents: VBoxContainer = scroll.get_child(0)
        for child in contents.get_children():
            contents.remove_child(child)
            child.queue_free()
        await get_tree().process_frame
        _build_cheat_tab(contents, CATEGORIES[index])

func _local_player() -> Node:
    return get_tree().get_first_node_in_group("local_player")
