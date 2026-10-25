extends Cheat
## Fake lag: приостанавливает отправку ввода каждые N тиков.

var _ticks: int = 0

func setup_settings() -> void:
	name = "Fake Lag"
	id = "fake_lag"
	category = "Misc"
	settings = {
		"limit": 5,
	}

func _on_enable(_player: Node) -> void:
	_ticks = 0

func apply(player: Node, delta: float) -> void:
	pass

func should_send_input() -> bool:
	var limit: int = int(get_setting("limit", 5))
	var enabled: bool = self.enabled
	if not enabled:
		return true
	_ticks += 1
	return _ticks % (limit + 1) == 0

func _on_disable(player: Node) -> void:
	_ticks = 0