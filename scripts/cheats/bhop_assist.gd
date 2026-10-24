extends Cheat
## Bhop assist: автоматически прыгает при касании земли.

var _was_on_floor: bool = false

func setup_settings() -> void:
	name = "Bhop Assist"
	id = "bhop_assist"
	category = "Misc"
	settings = {
		"enabled": false,
	}

func _on_enable(_player: Node) -> void:
	_was_on_floor = false

func apply(player: Node, delta: float) -> void:
	var enabled: bool = bool(get_setting("enabled", false))
	if not enabled or player == null:
		return
	var cb: CharacterBody3D = player
	if cb.is_on_floor() and not _was_on_floor:
		cb.velocity = cb.velocity.move_toward(cb.velocity + Vector3.UP * 5.5, 5.5)
		_was_on_floor = true
	elif not cb.is_on_floor():
		_was_on_floor = false

func _on_disable(player: Node) -> void:
	_was_on_floor = false