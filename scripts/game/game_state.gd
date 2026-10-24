extends Node
## Глобальное состояние матча (автолоад).
## Счёт, лимит убийств, сигналы для UI.

signal score_changed

const KILL_LIMIT: int = 20
const RESPAWN_TIME: float = 3.0

## id -> {name, kills, deaths}
var scores: Dictionary = {}

func reset_match() -> void:
	scores.clear()
	score_changed.emit()

func ensure_player(id: int, pname: String) -> void:
	if not scores.has(id):
		scores[id] = {"name": pname, "kills": 0, "deaths": 0}
		score_changed.emit()

func add_kill(killer_id: int, victim_id: int) -> void:
	if scores.has(killer_id):
		scores[killer_id]["kills"] += 1
	if scores.has(victim_id):
		scores[victim_id]["deaths"] += 1
	score_changed.emit()

func get_sorted_scores() -> Array:
	var arr: Array = []
	for id in scores:
		arr.append({"id": id, "name": scores[id]["name"], "kills": scores[id]["kills"], "deaths": scores[id]["deaths"]})
	arr.sort_custom(func(a, b): return a["kills"] > b["kills"])
	return arr
