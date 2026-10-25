extends Cheat
## Bhop assist: автоматически прыгает при касании земли.

var _was_on_floor: bool = false

func setup_settings() -> void:
	name = "Bhop Assist"
	id = "bhop_assist"
	category = "Misc"
	settings = {}

func _on_enable(_player: Node) -> void:
	_was_on_floor = false

func apply(player: Node, _delta: float) -> void:
	if player == null or not player.is_local:
		return
	var cb: CharacterBody3D = player
	if cb.is_on_floor() and not _was_on_floor:
		cb.velocity.y = 5.5
		_was_on_floor = true
	elif not cb.is_on_floor():
		_was_on_floor = false

func _on_disable(player: Node) -> void:
	_was_on_floor = false