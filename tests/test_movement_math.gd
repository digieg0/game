extends GutTest

var p := MovementParams.new()
const DT := 1.0 / 64.0

func test_friction_stops_player():
	var v := Vector3(250, 0, 0)
	var ticks := 0
	while MovementMath.horizontal(v).length() > 0.01 and ticks < 200:
		v = MovementMath.apply_friction(v, p, DT)
		ticks += 1
	# ожидаем примерно 26 тиков (~0.4 с) при friction 5.2, stop_speed 80
	assert_between(ticks, 22, 32)

func test_air_strafe_gain_is_30():
	var v := Vector3(250, 0, 0)
	var wishdir := Vector3(0, 0, 1)             # перпендикулярно скорости
	var v2 := MovementMath.air_accelerate(v, wishdir, 250.0, p, DT)
	assert_almost_eq(v2.dot(wishdir), 30.0, 0.01)
	assert_gt(MovementMath.horizontal(v2).length(), 250.0)

func test_air_strafe_no_gain_along_velocity():
	var v := Vector3(250, 0, 0)
	var v2 := MovementMath.air_accelerate(v, Vector3(1, 0, 0), 250.0, p, DT)
	assert_eq(v2, v)   # проекция уже > 30, прироста нет

func test_bhop_cap_vs_free():
	var v := Vector3(400, 0, 0)
	p.enable_bhop = false
	var capped := MovementMath.apply_bhop_cap(v, p)
	assert_almost_eq(capped.x, 275.0, 0.01)     # 250 * 1.1
	p.enable_bhop = true
	var free := MovementMath.apply_bhop_cap(v, p)
	assert_eq(free.x, 400.0)

func test_jump_velocity_default():
	assert_almost_eq(p.jump_velocity(), 302.0, 0.5)
