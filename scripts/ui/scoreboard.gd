extends CanvasLayer
## Табло счёта: id -> имя, киллы, смерти.

var _rows: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.score_changed.connect(_refresh)

func _refresh() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var scores: Array = gs.get_sorted_scores()
	var y: int = 40
	for s in scores:
		var row: Label = Label.new()
		row.position = Vector2(20, y)
		row.text = str(s["name"]) + "  K:" + str(s["kills"]) + "  D:" + str(s["deaths"])
		add_child(row)
		_rows.append(row)
		y += 24