extends Resource
## Базовый класс чита.
## Читы — часть геймплея, регистрируются автоматически из scripts/cheats/.

class_name Cheat

@export var name: String = "Cheat"
@export var id: String = "cheat"
@export var category: String = "Misc"
@export var enabled: bool = false
@export var settings: Dictionary = {}

var bind_key: int = KEY_NONE
var bind_hold: bool = false

func _init() -> void:
	setup_settings()

## Переопределяется наследниками: задать name/id/category и settings по умолчанию
func setup_settings() -> void:
	pass

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value

func get_setting(key: String, default_value: Variant = null) -> Variant:
	return settings.get(key, default_value)

func set_enabled(player: Node, value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled:
		_on_enable(player)
	else:
		_on_disable(player)

func _on_enable(_player: Node) -> void:
	pass

func _on_disable(_player: Node) -> void:
	pass

func apply(_player: Node, _delta: float) -> void:
	pass

func on_shoot(_player: Node, _ctx: Dictionary) -> void:
	pass

func to_dict() -> Dictionary:
	var s: Dictionary = {}
	for k in settings:
		var v = settings[k]
		if v is Color:
			s[k] = v.to_html()
		else:
			s[k] = v
	return {
		"id": id,
		"enabled": enabled,
		"settings": s,
		"bind_key": bind_key,
		"bind_hold": bind_hold,
	}

func from_dict(d: Dictionary, player: Node = null) -> void:
	var desired_enabled: bool = bool(d.get("enabled", false))
	set_enabled(player, desired_enabled)
	bind_key = int(d.get("bind_key", KEY_NONE))
	bind_hold = bool(d.get("bind_hold", false))
	var s: Dictionary = d.get("settings", {})
	for k in s:
		if settings.has(k) and settings[k] is Color and s[k] is String:
			settings[k] = Color(s[k])
		else:
			settings[k] = s[k]
