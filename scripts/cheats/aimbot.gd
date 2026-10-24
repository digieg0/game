extends Cheat
## Aimbot: подбирает цель и корректирует прицел к выбранной зоне хитбокса.

var _target: Dictionary = {}

func setup_settings() -> void:
	name = "Aimbot"
	id = "aimbot"
	category = "Ragebot"
	settings = {
		"enabled": true,
		"fov": 180.0,
		"smooth": 5.0,
		"bone": "head",
		"key": 0,
	}

func _on_enable(_player: Node) -> void:
	_target = {}

func apply(player: Node, delta: float) -> void:
	pass

func get_target(player: Node) -> Dictionary:
	return _target

func _on_disable(player: Node) -> void:
	_target = {}