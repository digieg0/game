extends Node
## Конфигуратор читов: сохраняет/загружает состояние CheatRegistry в JSON (user://configs/).

var configs_dir: String = "user://configs/"

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(configs_dir):
		var d: DirAccess = DirAccess.open(configs_dir)
		if d != null:
			d.make_dir_absolute(configs_dir)
			d.close()

func save_config(name: String) -> void:
	if name == "":
		name = "default"
	var path: String = configs_dir + name + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось создать конфиг: " + path)
		return
	file.store_line(JSON.stringify(CheatRegistry.to_dict(), "\t"))
	file.close()

func load_config(name: String) -> void:
	if name == "":
		name = "default"
	var path: String = configs_dir + name + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Конфиг не найден: " + path)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data != null and typeof(data) == TYPE_DICTIONARY:
		CheatRegistry.from_dict(data)

func list_configs() -> Array:
	var out: Array = []
	if DirAccess.dir_exists_absolute(configs_dir):
		var d: DirAccess = DirAccess.open(configs_dir)
		if d != null:
			d.list_dir_begin()
			var f := d.get_next()
			while f != "":
				if f.ends_with(".json"):
					out.append(f.get_basename())
				f = d.get_next()
			d.list_dir_end()
	return out