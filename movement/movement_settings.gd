extends Node
## Автолоад: единый объект MovementParams на процесс.
## Физика игрока только читает его, чит-меню пишет в него в рантайме.

var params := MovementParams.new()

## Сброс к дефолтам в ТЕМ ЖЕ объекте (игроки держат ссылку на params).
func reset_params() -> void:
	var defaults := MovementParams.new()
	for prop in defaults.get_property_list():
		var usage: int = int(prop.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var pname := String(prop["name"])
		if pname == "script" or pname == "resource_name":
			continue
		params.set(pname, defaults.get(pname))
