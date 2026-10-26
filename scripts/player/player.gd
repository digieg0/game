extends CharacterBody3D
## Player controller. CS2/Source-мувмент: скорость в units/s (в метры переводим
## только на границе move_and_slide), трение/ускорение/air strafe/bhop.
## The local player is predicted locally; remote players are server-simulated
## той же математикой (см. movement/movement_math.gd).

const UNIT := 0.0254
const FIRE_RATE: float = 0.12
const MAX_HP: float = 100.0
const MOUSE_SENS: float = 0.0025
const STAND_CAPSULE_HEIGHT: float = 1.8
const CROUCH_SCALE: float = 0.72      # во сколько раз приседает модель/хитбоксы
const CROUCH_TIME: float = 0.18       # время приседания/вставания, сек
const EYE_HEIGHT_STAND: float = 1.58

var player_id: int = 0
var player_name: String = "Player"
var hp: float = MAX_HP
var alive: bool = true
var is_local: bool = false
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var visible_yaw: float = 0.0
var visible_pitch: float = 0.0
var spin_extra_yaw: float = 0.0
var aa_yaw_offset: float = 0.0
var aa_pitch: float = 0.0
var force_shoot: bool = false
var aim_target: Dictionary = {}
var is_third_person: bool = false

# --- мувмент (units/s — источник истины) ---
var params: MovementParams
var vel := Vector3.ZERO          # скорость в units/s
var on_ground := false
var ground_ticks := 0            # сколько тиков подряд на земле
var jump_takeoff_ticks := 0      # state ground_ticks на взлёте (для отладки bhop)
var jump_buffer := 0
var last_want_jump := false      # что отправляется на сервер в этот тик
var crouch_amount: float = 1.0   # 1.0 = стоит, CROUCH_SCALE = присед

var _fire_cooldown: float = 0.0
var _tick_counter: int = 0
var _server_input_queue: Array[Dictionary] = []
var _server_input: Dictionary = {}
var _server_input_idle: float = 999.0
var _last_server_tick: int = -1

@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var model: Node3D = $Model
@onready var viewmodel: Node3D = $CameraPivot/SpringArm3D/Camera3D/VMRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var vm_muzzle: Node3D = $CameraPivot/SpringArm3D/Camera3D/VMRoot/VMMuzzle
@onready var model_muzzle: Node3D = $Model/BodyPivot/WeaponPivot/ModelMuzzle
var _capsule: CapsuleShape3D

func _ready() -> void:
	params = MovementSettings.params
	_apply_floor_params()
	# Shape в .tscn — общий ресурс; каждый игрок получает свою копию капсулы,
	# иначе присед одного игрока менял бы коллизию всем.
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		_capsule = collision_shape.shape.duplicate()
		collision_shape.shape = _capsule
	if is_local:
		camera.current = true
		_apply_view_mode()
	else:
		# Remote players do not need their own Camera3D or SpringArm3D.
		camera_pivot.queue_free()
		model.visible = true
	if multiplayer.is_server() and not is_local:
		_server_input = {"move_x": 0.0, "move_y": 0.0, "jump": false, "yaw": 0.0, "pitch": 0.0}

func _apply_floor_params() -> void:
	if params == null:
		return
	floor_max_angle = deg_to_rad(params.max_slope_deg)
	floor_snap_length = params.step_height * UNIT
	floor_stop_on_slope = false
	floor_constant_speed = false
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

func _apply_view_mode() -> void:
	if not is_local or not is_instance_valid(spring_arm):
		return
	# The SpringArm keeps the third-person camera behind the player and shortens near walls.
	spring_arm.spring_length = 4.2 if is_third_person else 0.0
	camera_pivot.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
	if is_instance_valid(model):
		# Avoid seeing inside the head/torso from the first-person camera.
		model.visible = is_third_person
	if is_instance_valid(viewmodel):
		# Viewmodel-винтовка только в 1-м лице; в 3-м лице видна винтовка у модели.
		viewmodel.visible = alive and not is_third_person

func _toggle_view_mode() -> void:
	is_third_person = not is_third_person
	_apply_view_mode()

func setup(id: int, pname: String, local: bool) -> void:
	player_id = id
	player_name = pname
	is_local = local

func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	# V toggles first-/third-person independently of mouse capture state.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V or event.physical_keycode == KEY_V:
			_toggle_view_mode()
			return
	if not alive or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		aim_yaw = wrapf(aim_yaw - event.relative.x * MOUSE_SENS, -PI, PI)
		aim_pitch = clampf(aim_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		camera_pivot.rotation = Vector3(aim_pitch, aim_yaw, 0.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_local:
		if multiplayer.is_server():
			_server_move(delta)
		return

	_local_move(delta, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		CheatRegistry.apply_all(self, delta)
		_handle_shoot(delta)
	camera_pivot.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
	if model and model.has_method("set_local_look"):
		model.set_local_look(aim_yaw + spin_extra_yaw + aa_yaw_offset, aim_pitch + aa_pitch)
	_flush_input_to_server()

func _get_move_input(accept_input: bool = true) -> Vector2:
	if not accept_input:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _local_move(delta: float, accept_input: bool = true) -> void:
	var input := _get_move_input(accept_input)
	var walking := accept_input and Input.is_action_pressed("walk")
	var crouching := accept_input and Input.is_action_pressed("crouch")
	if accept_input:
		var jump_held := Input.is_action_pressed("jump")
		var jump_pressed := Input.is_action_just_pressed("jump")
		last_want_jump = _update_jump_buffer(jump_held, jump_pressed)
	else:
		jump_buffer = 0
		last_want_jump = false
	_movement_step(delta, input, walking, crouching, aim_yaw, last_want_jump)

## Буфер прыжка: EdgePress помним jump_buffer_ticks тиков; autobhop — по удержанию.
func _update_jump_buffer(jump_held: bool, jump_pressed: bool) -> bool:
	if jump_pressed:
		jump_buffer = int(params.jump_buffer_ticks)
	elif jump_buffer > 0:
		jump_buffer -= 1
	var want_jump := jump_buffer > 0
	if params.autobhop and jump_held:
		want_jump = true
	return want_jump

## Один тик мувмента в стиле CS2/Source.
## Entry order обязателен: гравитация (1/2) -> прыжок ДО трения -> 
## трение + accelerate (земля) / air_accelerate (воздух) -> коллизия -> гравитация (1/2).
func _movement_step(delta: float, input: Vector2, walking: bool, crouching: bool,
		move_yaw: float, want_jump: bool) -> void:
	var wishdir: Vector3 = Basis.from_euler(Vector3(0.0, move_yaw, 0.0)) * Vector3(input.x, 0.0, input.y)
	wishdir.y = 0.0
	wishdir = wishdir.normalized()

	var max_speed: float = params.weapon_max_speed
	if walking:
		max_speed *= params.walk_mult
	if crouching:
		max_speed *= params.crouch_mult
	var wishspeed: float = minf(input.length(), 1.0) * max_speed

	# --- первая половина гравитации (в воздухе) ---
	if not on_ground:
		vel.y -= params.gravity * delta * 0.5

	# --- прыжок: делается ДО трения, поэтому bhop не теряет скорость ---
	if want_jump and on_ground:
		jump_takeoff_ticks = ground_ticks
		vel = MovementMath.apply_bhop_cap(vel, params)
		vel.y = params.jump_velocity()
		on_ground = false
		jump_buffer = 0

	# --- выбор режима ---
	if on_ground:
		vel.y = 0.0
		vel = MovementMath.apply_friction(vel, params, delta)
		vel = MovementMath.accelerate(vel, wishdir, wishspeed, params.accelerate, delta)
		# не превышать max_speed на земле
		var h := MovementMath.horizontal(vel)
		if h.length() > max_speed and max_speed > 0.0:
			h = h.normalized() * max_speed
			vel = Vector3(h.x, vel.y, h.z)
	else:
		vel = MovementMath.air_accelerate(vel, wishdir, wishspeed, params, delta)

	# --- коллизии: переводим в метры только здесь ---
	velocity = vel * UNIT
	move_and_slide()
	vel = velocity / UNIT

	# --- состояние земли ---
	on_ground = is_on_floor()
	ground_ticks = (ground_ticks + 1) if on_ground else 0

	# --- вторая половина гравитации ---
	if not on_ground:
		vel.y -= params.gravity * delta * 0.5

	_update_crouch_pose(delta, crouching)

## Присед: капсула/камера/модель плавно сжимаются, хитбоксы сжимаются вместе с моделью.
func _update_crouch_pose(delta: float, crouching: bool) -> void:
	var target: float = CROUCH_SCALE if crouching else 1.0
	var rate: float = (1.0 - CROUCH_SCALE) / CROUCH_TIME
	crouch_amount = move_toward(crouch_amount, target, rate * delta)
	_apply_pose(crouch_amount)

func _apply_pose(amount: float) -> void:
	amount = clampf(amount, minf(CROUCH_SCALE, 1.0), maxf(CROUCH_SCALE, 1.0))
	if _capsule != null:
		_capsule.height = STAND_CAPSULE_HEIGHT * amount
		collision_shape.position = Vector3(0.0, 0.9 * amount, 0.0)
	if model != null:
		model.scale = Vector3(1.0, amount, 1.0)
	if is_local and camera_pivot != null:
		camera_pivot.position.y = EYE_HEIGHT_STAND * amount

func _flush_input_to_server() -> void:
	_tick_counter += 1
	var movement := _get_move_input(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	NetManager.send_input({
		"tick": _tick_counter,
		"yaw": aim_yaw,
		"pitch": aim_pitch,
		"visible_yaw": aim_yaw + spin_extra_yaw + aa_yaw_offset,
		"visible_pitch": aim_pitch + aa_pitch,
		"move_x": movement.x,
		"move_y": movement.y,
		"jump": last_want_jump,
		"walk": Input.is_action_pressed("walk") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"crouch": Input.is_action_pressed("crouch") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
	})
	NetManager.flush_inputs()

func _server_move(delta: float) -> void:
	_server_input_idle += delta
	if not _server_input_queue.is_empty():
		_server_input = _server_input_queue.pop_front()
		_server_input_idle = 0.0
	var movement := Vector2(float(_server_input.get("move_x", 0.0)), float(_server_input.get("move_y", 0.0)))
	if _server_input_idle > 0.15:
		movement = Vector2.ZERO
	movement = movement.limit_length(1.0)
	var move_yaw := float(_server_input.get("yaw", visible_yaw))
	var active: bool = _server_input_idle <= 0.15
	var walking := active and bool(_server_input.get("walk", false))
	var crouching := active and bool(_server_input.get("crouch", false))
	# Клиент отправляет уже обработанный want_jump (буфер + autobhop accounted).
	var want_jump := active and bool(_server_input.get("jump", false))
	last_want_jump = want_jump
	_movement_step(delta, movement, walking, crouching, move_yaw, want_jump)
	if model and model.has_method("set_server_pose"):
		model.set_server_pose(visible_yaw, visible_pitch)

## Queue sanitized client inputs; positions and velocities are never accepted from the network.
func apply_server_input(input: Dictionary) -> void:
	var tick := int(input.get("tick", -1))
	if tick <= _last_server_tick:
		return
	_last_server_tick = tick
	visible_yaw = wrapf(float(input.get("visible_yaw", input.get("yaw", 0.0))), -PI, PI)
	visible_pitch = clampf(float(input.get("visible_pitch", input.get("pitch", 0.0))), -1.5, 1.5)
	var clean := {
		"tick": tick,
		"yaw": wrapf(float(input.get("yaw", 0.0)), -PI, PI),
		"pitch": clampf(float(input.get("pitch", 0.0)), -1.5, 1.5),
		"move_x": clampf(float(input.get("move_x", 0.0)), -1.0, 1.0),
		"move_y": clampf(float(input.get("move_y", 0.0)), -1.0, 1.0),
		"jump": bool(input.get("jump", false)),
		"walk": bool(input.get("walk", false)),
		"crouch": bool(input.get("crouch", false)),
	}
	_server_input_queue.append(clean)
	while _server_input_queue.size() > 32:
		_server_input_queue.pop_front()

func _handle_shoot(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var want_to_shoot := Input.is_action_pressed("shoot") or force_shoot
	force_shoot = false
	if want_to_shoot and _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_RATE
		_fire_once()

func _fire_once() -> void:
	var yaw: float = aim_yaw
	var pitch: float = aim_pitch
	# Silent Aim: углы выстрела подменяются в сторону цели; камера/прицел не крутится,
	# сервер считает попадание по отправленным углам (как и в обычной стрельбе).
	var silent = CheatRegistry.get_cheat("silent_aim")
	if silent != null and silent.enabled:
		var shot_angles: Dictionary = silent.get_shot_angles(self)
		if not shot_angles.is_empty():
			yaw = float(shot_angles.get("yaw", aim_yaw))
			pitch = float(shot_angles.get("pitch", aim_pitch))
	NetManager.request_fire(yaw, pitch)
	_local_tracer(yaw, pitch)

## Мгновенный ЛОКАЛЬНЫЙ трассер: рисуем его сами на клиенте, не дожидаясь RPC
## от сервера. Серверный трассер рисуется только для ДРУГИХ игроков.
func _local_tracer(yaw: float, pitch: float) -> void:
	var origin: Vector3 = global_position + Vector3(0.0, 1.6, 0.0)
	var cos_pitch := cos(pitch)
	var direction := Vector3(-sin(yaw) * cos_pitch, sin(pitch), -cos(yaw) * cos_pitch).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * NetManager.MAX_RANGE)
	query.collision_mask = 5
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var excluded: Array[RID] = []
	var model: Node = get_node_or_null("Model")
	if model:
		for hitbox in model.find_children("*", "Area3D", true, false):
			excluded.append(hitbox.get_rid())
	query.exclude = excluded
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end_point: Vector3 = origin + direction * NetManager.MAX_RANGE
	if not hit.is_empty():
		end_point = hit["position"]
	# Луч света идёт ИЗ ДУЛА винтовки до точки попадания (рейкаст — от глаз,
	# иначе прицел и трассер разойдутся).
	NetManager.spawn_local_tracer(get_muzzle_global(), end_point)

## Позиция дула в мировых координатах: у локального игрока — кончик вьюмодели,
## у остальных — кончик винтовки модели. Fallback — голова (+1.6м).
func get_muzzle_global() -> Vector3:
	if is_local and is_third_person:
		return model_muzzle.global_position if model_muzzle != null else global_position + Vector3(0.0, 1.6, 0.0)
	if is_local and vm_muzzle != null:
		return vm_muzzle.global_position
	if model_muzzle != null:
		return model_muzzle.global_position
	return global_position + Vector3(0.0, 1.6, 0.0)

func get_visible_yaw() -> float:
	if is_local:
		return aim_yaw + spin_extra_yaw + aa_yaw_offset
	return visible_yaw

func get_visible_pitch() -> float:
	if is_local:
		return aim_pitch + aa_pitch
	return visible_pitch

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0))
	if hp <= 0.0:
		alive = false
		visible = false
		if is_instance_valid(viewmodel):
			viewmodel.visible = false
		set_hitboxes_enabled(false)

func respawn(spawn_pos: Vector3) -> void:
	hp = MAX_HP
	alive = true
	global_position = spawn_pos
	velocity = Vector3.ZERO
	vel = Vector3.ZERO
	on_ground = false
	ground_ticks = 0
	jump_buffer = 0
	crouch_amount = 1.0
	_apply_pose(1.0)
	visible = true
	_server_input_queue.clear()
	_server_input_idle = 999.0
	_apply_view_mode()
	set_hitboxes_enabled(true)

func set_hitboxes_enabled(value: bool) -> void:
	if model == null:
		return
	for hitbox in model.find_children("*", "Area3D", true, false):
		hitbox.set_collision_layer_value(3, value)
		hitbox.monitorable = value
