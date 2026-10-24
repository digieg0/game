extends Node
## Автолоад: реестр читов. Сканирует scripts/cheats/ и создаёт экземпляр каждого чита.

var cheats: Array = []
var by_id: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	cheats.clear()
	by_id.clear()
	var dir := DirAccess.open("res://scripts/cheats/")
	if dir == null:
		push_error("Не удалось открыть папку читов")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".gd") and fname != "cheat_base.gd" and fname != "cheat_registry.gd":
			_register_from_file("res://scripts/cheats/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()

func _register_from_file(path: String) -> void:
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		return
	var inst: Variant = script.new()
	if inst == null or not (inst is Cheat):
		return
	var cheat: Cheat = inst
	if cheat.id == "" or cheat.id == "cheat":
		cheat.id = path.get_file().get_basename()
	cheats.append(cheat)
	by_id[cheat.id] = cheat

func get_cheat(cheat_id: String) -> Cheat:
	return by_id.get(cheat_id, null)

func get_by_category(category: String) -> Array:
	var out: Array = []
	for c in cheats:
		if c.category == category:
			out.append(c)
	return out

func apply_all(player: Node, delta: float) -> void:
	for c in cheats:
		if c.enabled:
			c.apply(player, delta)

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for c in cheats:
		out[c.id] = c.to_dict()
	return out

func from_dict(d: Dictionary) -> void:
	for cheat_id in d:
		var c: Cheat = by_id.get(cheat_id, null)
		if c:
			c.from_dict(d[cheat_id])
