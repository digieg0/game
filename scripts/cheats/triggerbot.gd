extends Cheat
## Triggerbot: автоматический выстрел, если прицел наведён на врага.

var _last_shot: float = 0.0

func setup_settings() -> void:
	name = "Triggerbot"
	id = "triggerbot"
	category = "Ragebot"
	settings = {
		"delay": 0.05,
		"bone": "head",
	}

func _on_enable(_player: Node) -> void:
	_last_shot = 0.0

func apply(player: Node, delta: float) -> void:
	pass

func on_shoot(player: Node, ctx: Dictionary) -> void:
	var delay: float = float(get_setting("delay", 0.05))
	var t: float = Time.get_ticks_msec() / 1000.0
	if t - _last_shot < delay:
		ctx["block"] = true
		return
	_last_shot = t

func _on_disable(player: Node) -> void:
	pass