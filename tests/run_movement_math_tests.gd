extends SceneTree
## Автономный раннер мувмент-тестов (везти GUT в билд не хочется):
##   godot --headless --script res://tests/run_movement_math_tests.gd
## Покрывает те же случаи, что и test_movement_math.gd (GUT).

var _failures := 0
var _checks := 0

func _initialize() -> void:
	_run_all()
	if _failures == 0:
		print("ALL MOVEMENT TESTS PASSED (%d checks)" % _checks)
		quit(0)
	else:
		print("MOVEMENT TESTS FAILED: %d of %d checks" % [_failures, _checks])
		quit(1)

func _ok(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

func _between(value: int, low: int, high: int, label: String) -> void:
	_ok(value >= low and value <= high, "%s (%d in [%d..%d])" % [label, value, low, high])

func _almost(actual: float, expected: float, eps: float, label: String) -> void:
	_ok(absf(actual - expected) <= eps, "%s (%.4f ≈ %.4f)" % [label, actual, expected])

func _run_all() -> void:
	var p := MovementParams.new()
	const DT := 1.0 / 64.0

	# --- friction ---
	var v := Vector3(250, 0, 0)
	var ticks := 0
	while MovementMath.horizontal(v).length() > 0.01 and ticks < 200:
		v = MovementMath.apply_friction(v, p, DT)
		ticks += 1
	_between(ticks, 22, 32, "friction stops player in ~0.4s")

	# --- air strafe перпендикулярно ---
	var s := Vector3(250, 0, 0)
	var wishdir := Vector3(0, 0, 1)
	var s2 := MovementMath.air_accelerate(s, wishdir, 250.0, p, DT)
	_almost(s2.dot(wishdir), 30.0, 0.01, "air strafe gain 30")
	_ok(MovementMath.horizontal(s2).length() > 250.0, "air strafe speeds up total")

	# --- air strafe вдоль скорости ---
	var v3 := Vector3(250, 0, 0)
	var v3_after := MovementMath.air_accelerate(v3, Vector3(1, 0, 0), 250.0, p, DT)
	_ok(v3_after == v3, "no air gain along velocity")

	# --- bhop cap ---
	var cap_v := Vector3(400, 0, 0)
	p.enable_bhop = false
	_almost(MovementMath.apply_bhop_cap(cap_v, p).x, 275.0, 0.01, "speed capped to 275")
	p.enable_bhop = true
	_ok(Vector3(400, 0, 0) == cap_v and MovementMath.apply_bhop_cap(Vector3(400, 0, 0), p).x == 400.0, "bhop enabled: no cap")

	# --- jump velocity ---
	_almost(p.jump_velocity(), 302.0, 0.5, "jump_velocity ≈ 302")

	# --- симуляция bhop цепочки: прыжки + воздушный strafe, старт со скоростью 400 ---
	var sim_free := _simulate_chain(p, true)
	var sim_capped := _simulate_chain(p, false)
	_ok(sim_free > sim_capped, "bhop chain: free bhop faster (%.1f > %.1f)" % [sim_free, sim_capped])
	_ok(sim_capped <= 275.0 + 35.0, "capped bhop near cap (%.1f)" % sim_capped)

func _simulate_chain(prototype: MovementParams, free_bhop: bool) -> float:
	var p := prototype.duplicate() as MovementParams
	p.enable_bhop = free_bhop
	var vel := Vector3(400.0, 0.0, 0.0)   # уже разогнались — кап должен проявиться
	var yaw := 0.0
	const DT := 1.0 / 64.0
	var airborne := false
	var air_ticks := 0
	for i in range(50):
		if not airborne:
			# идеальная цепочка: прыжок в первом тике контакта, ДО трения
			vel = MovementMath.apply_bhop_cap(vel, p)
			vel.y = p.jump_velocity()
			airborne = true
			air_ticks = 0
		yaw += deg_to_rad(3.0)
		var wishdir := Vector3(-sin(yaw), 0.0, -cos(yaw))
		vel = MovementMath.air_accelerate(vel, wishdir, p.weapon_max_speed, p, DT)
		vel.y -= p.gravity * DT
		air_ticks += 1
		# укороченный «отрезок» полёта, чтобы уложиться в 50 тиков
		if air_ticks >= 4:
			vel.y = 0.0
			airborne = false
	return MovementMath.horizontal(vel).length()
