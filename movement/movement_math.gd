class_name MovementMath
extends RefCounted
## Чистая математика Source-мувмента. Только static, скорости в units/s,
## к узлам не обращается — тестируется без сцены.

static func horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func apply_friction(vel: Vector3, p: MovementParams, dt: float) -> Vector3:
	var h := horizontal(vel)
	var speed := h.length()
	if speed < 0.1:
		return Vector3(0.0, vel.y, 0.0)
	var control := maxf(speed, p.stop_speed)
	var drop := control * p.friction * dt
	var new_speed := maxf(speed - drop, 0.0)
	var h2 := h * (new_speed / speed)
	return Vector3(h2.x, vel.y, h2.z)

static func accelerate(vel: Vector3, wishdir: Vector3, wishspeed: float,
		accel: float, dt: float) -> Vector3:
	var current := horizontal(vel).dot(wishdir)
	var add := wishspeed - current
	if add <= 0.0:
		return vel
	var accel_speed := minf(accel * dt * wishspeed, add)
	return vel + wishdir * accel_speed

static func air_accelerate(vel: Vector3, wishdir: Vector3, wishspeed: float,
		p: MovementParams, dt: float) -> Vector3:
	var capped := minf(wishspeed, p.air_wishspeed_cap)   # 30
	var current := horizontal(vel).dot(wishdir)
	var add := capped - current
	if add <= 0.0:
		return vel
	# сила ускорения считается от НЕурезанного wishspeed
	var accel_speed := minf(p.air_accelerate * wishspeed * dt, add)
	return vel + wishdir * accel_speed

static func apply_bhop_cap(vel: Vector3, p: MovementParams) -> Vector3:
	if p.enable_bhop:
		return vel
	var cap := p.weapon_max_speed * p.bhop_speed_cap_mult
	var h := horizontal(vel)
	var speed := h.length()
	if speed > cap:
		var h2 := h * (cap / speed)
		return Vector3(h2.x, vel.y, h2.z)
	return vel
