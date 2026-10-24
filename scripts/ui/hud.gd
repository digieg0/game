extends CanvasLayer
## HUD в игре: хитмаркер, счёт, HP.

var hitmarker_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gs = get_node_or_null("/root/GameState")
	if gs:
		gs.score_changed.connect(_on_score_changed)

func _process(delta: float) -> void:
	if hitmarker_time > 0:
		hitmarker_time -= delta

func add_hitmarker(killed: bool) -> void:
	hitmarker_time = 0.8

func _on_score_changed() -> void:
	pass