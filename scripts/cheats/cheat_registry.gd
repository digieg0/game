extends Node
## Автолоад: реестр читов. Регистрирует каждый чит через явный preload,
## чтобы работать и в редакторе, и в экспортированном билде (res:// в PCK
## не поддерживает перечисление файлов через DirAccess).

var cheats: Array = []
var by_id: Dictionary = {}

var CHEAT_PATHS: Array[String] = [
	"res://scripts/cheats/aimbot.gd",
	"res://scripts/cheats/anti_aim.gd",
	"res://scripts/cheats/backtrack.gd",
	"res://scripts/cheats/bhop_assist.gd",
	"res://scripts/cheats/esp.gd",
	"res://scripts/cheats/fake_lag.gd",
	"res://scripts/cheats/ragebot.gd",
	"res://scripts/cheats/resolver.gd",
	"res://scripts/cheats/spinbot.gd",
	"res://scripts/cheats/triggerbot.gd",
]

func _ready() -> void:
	load_all()

func load_all() -> void:
	cheats.clear()
	by_id.clear()
	for path in CHEAT_PATHS:
		_register_from_file(path)

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

func from_dict(d: Dictionary, player: Node = null) -> void:
	for cheat_id in d:
		var c: Cheat = by_id.get(cheat_id, null)
		if c:
			c.from_dict(d[cheat_id], player)
