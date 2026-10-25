extends CanvasLayer
## Hold TAB to show the sorted match scoreboard.

var _backdrop: ColorRect
var _panel: PanelContainer
var _rows: VBoxContainer
var _shown: bool = false

func _ready() -> void:
    layer = 7
    process_mode = Node.PROCESS_MODE_ALWAYS
    _backdrop = ColorRect.new()
    _backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _backdrop.color = Color(0.01, 0.025, 0.05, 0.72)
    _backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_backdrop)

    _panel = PanelContainer.new()
    _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _panel.offset_left = -300.0
    _panel.offset_top = -240.0
    _panel.offset_right = 300.0
    _panel.offset_bottom = 240.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.075, 0.11, 0.98)
    style.border_color = Color(0.14, 0.72, 0.95, 0.8)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    _panel.add_theme_stylebox_override("panel", style)
    add_child(_panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 24)
    margins.add_theme_constant_override("margin_right", 24)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 20)
    _panel.add_child(margins)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    margins.add_child(root)
    var title := Label.new()
    title.text = "MATCH SCOREBOARD"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(0.2, 0.82, 1.0, 1.0))
    root.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "LIVE MATCH  ·  TAB TO CLOSE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color(0.55, 0.66, 0.78, 1.0))
    root.add_child(subtitle)
    var separator := HSeparator.new()
    root.add_child(separator)
    var header := HBoxContainer.new()
    _add_header(header, "PLAYER", true)
    _add_header(header, "K", false, 44)
    _add_header(header, "D", false, 44)
    _add_header(header, "K/D", false, 64)
    root.add_child(header)
    _rows = VBoxContainer.new()
    _rows.add_theme_constant_override("separation", 5)
    root.add_child(_rows)
    var hint := Label.new()
    hint.text = "Keep moving. Keep your aim sharp."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.44, 0.55, 0.68, 1.0))
    root.add_child(hint)
    _backdrop.visible = false
    _panel.visible = false
    var gs = get_node_or_null("/root/GameState")
    if gs:
        gs.score_changed.connect(_refresh)
    _refresh()

func _process(_delta: float) -> void:
    var requested := Input.is_action_pressed("scoreboard")
    if requested != _shown:
        _shown = requested
        _backdrop.visible = _shown
        _panel.visible = _shown
        if _shown:
            _refresh()

func _add_header(parent: HBoxContainer, text: String, expand: bool, width: float = 0.0) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.84, 1.0))
    if expand:
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    else:
        label.custom_minimum_size.x = width
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    parent.add_child(label)

func _refresh() -> void:
    if _rows == null:
        return
    for child in _rows.get_children():
        _rows.remove_child(child)
        child.queue_free()
    for index in range(GameState.get_sorted_scores().size()):
        var record: Dictionary = GameState.get_sorted_scores()[index]
        var row := HBoxContainer.new()
        var player_label := Label.new()
        player_label.text = "%02d  %s" % [index + 1, str(record["name"])]
        player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        player_label.add_theme_font_size_override("font_size", 14)
        player_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
        row.add_child(player_label)
        _add_score_cell(row, int(record["kills"]), Color(0.25, 0.94, 0.68, 1.0))
        _add_score_cell(row, int(record["deaths"]), Color(1.0, 0.52, 0.48, 1.0))
        var deaths: int = maxi(1, int(record["deaths"]))
        _add_score_cell(row, snappedf(float(record["kills"]) / float(deaths), 0.01), Color(0.64, 0.8, 1.0, 1.0), 64)
        _rows.add_child(row)

func _add_score_cell(parent: HBoxContainer, value: Variant, color: Color, width: float = 44.0) -> void:
    var label := Label.new()
    label.text = str(value)
    label.custom_minimum_size.x = width
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
