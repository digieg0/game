extends Node
## Authoritative match scoreboard mirrored to each client.

signal score_changed

const KILL_LIMIT: int = 20
const RESPAWN_TIME: float = 3.0

## peer id -> {name, kills, deaths}
var scores: Dictionary = {}

func reset_match() -> void:
	scores.clear()
	score_changed.emit()

func ensure_player(id: int, pname: String) -> void:
	if not scores.has(id):
		scores[id] = {"name": pname, "kills": 0, "deaths": 0}
		score_changed.emit()
	elif str(scores[id].get("name", "")) != pname:
		scores[id]["name"] = pname
		score_changed.emit()

func replace_scores(data: Dictionary) -> void:
	var next_scores: Dictionary = {}
	for id in data:
		var entry: Dictionary = data[id]
		next_scores[int(id)] = {
			"name": str(entry.get("name", "Player")),
			"kills": int(entry.get("kills", 0)),
			"deaths": int(entry.get("deaths", 0)),
		}
	scores = next_scores
	score_changed.emit()

func remove_player(id: int) -> void:
	if scores.erase(id):
		score_changed.emit()

func add_kill(killer_id: int, victim_id: int) -> void:
	if scores.has(killer_id):
		scores[killer_id]["kills"] = int(scores[killer_id].get("kills", 0)) + 1
	if scores.has(victim_id):
		scores[victim_id]["deaths"] = int(scores[victim_id].get("deaths", 0)) + 1
	score_changed.emit()

func get_sorted_scores() -> Array:
	var result: Array = []
	for id in scores:
		result.append({
			"id": int(id),
			"name": str(scores[id].get("name", "Player")),
			"kills": int(scores[id].get("kills", 0)),
			"deaths": int(scores[id].get("deaths", 0)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kills"] == b["kills"]:
			return a["deaths"] < b["deaths"]
		return a["kills"] > b["kills"]
	)
	return result
