extends CharacterBody3D
## Игрок: движение, bunnyhop, стрельба. Локальный — камера+ввод, удалённый — снапшоты.
## Хитбоксы вращаются вместе с моделью (видимая поза).

const SPEED: float = 7.0
const ACCEL: float = 10.0
const AIR_ACCEL: float = 2.0
const JUMP_VELOCITY: float = 5.5
const GRAVITY: float = 15.0
const MOUSE_SENS: float = 0.0025
const BHOP_GROUND_FRICTION: float = 6.0
const BASE_DAMAGE: float = 25.0
const FIRE_RATE: float = 0.12
const MAX_HP: float = 100.0
const MAX_RANGE: float = 200.0

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

var _fire_cooldown: float = 0.0
var _tick_counter: int = 0

@onready var camera: Camera3D = $Camera3D
@onready var model: Node3D = $Model

func _ready() -> void:
	if is_local:
		camera.current = true
	else:
		camera.queue_free()

func setup(id: int, pname: String, local: bool) -> void:
	player_id = id
	player_name = pname
	is_local = local

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		aim_yaw -= event.relative.x * MOUSE_SENS
		aim_pitch = clampf(aim_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		camera.rotation = Vector3(aim_pitch, aim_yaw, 0.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_local:
		return
	_local_move(delta)
	CheatRegistry.apply_all(self, delta)
	_handle_shoot(delta)
	_flush_aim_to_server()

func _flush_aim_to_server() -> void:
	_tick_counter += 1
	NetManager.send_input({
		"tick": _tick_counter,
		"yaw": aim_yaw,
		"pitch": aim_pitch,
	})

func _local_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if not Input.is_action_pressed("jump"):
			var horiz := Vector3(velocity.x, 0.0, velocity.z)
			horiz = horiz.move_toward(Vector3.ZERO, BHOP_GROUND_FRICTION * delta * horiz.length())
			velocity.x = horiz.x
			velocity.z = horiz.z

	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var basis := Basis.from_euler(Vector3(0.0, aim_yaw, 0.0))
	var wish_dir := (basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var horiz2 := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish_dir * SPEED
	if not is_on_floor():
		horiz2 = horiz2.move_toward(target, accel * delta)
	else:
		horiz2 = horiz2.move_toward(target, accel * delta * SPEED)
	velocity.x = horiz2.x
	velocity.z = horiz2.z

	if is_on_floor() and Input.is_action_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if model and model.has_method("set_local_look"):
		model.set_local_look(aim_yaw + spin_extra_yaw + aa_yaw_offset, aim_pitch + aa_pitch)

func _handle_shoot(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var want := Input.is_action_pressed("shoot") or force_shoot
	force_shoot = false
	if want and _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_RATE
		_fire_once()

func _fire_once() -> void:
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var aimbot = CheatRegistry.get_cheat("aimbot")
	if aimbot and aimbot.enabled and not aim_target.is_empty():
		var point: Vector3 = aim_target["point"]
		dir = (point - origin).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * MAX_RANGE)
	query.collision_mask = 0b100
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var hb: Node = hit.get("collider")
	if hb == null or not hb.has_method("get_damage_multiplier"):
		return
	var victim: Node = hb.owner_player
	if victim == null or victim == self or not victim.alive:
		return
	var dmg: float = BASE_DAMAGE * hb.get_damage_multiplier()
	NetManager.report_hit(player_id, victim.player_id, hb.get_zone_name(), dmg)
	var res = CheatRegistry.get_cheat("resolver")
	if res and res.enabled:
		res.report_result(victim.player_id, true)

## Сервер: применить ввод клиента
func apply_server_input(inp: Dictionary) -> void:
	if not alive:
		return
	visible_yaw = float(inp.get("yaw", 0.0))
	visible_pitch = float(inp.get("pitch", 0.0))

func get_visible_yaw() -> float:
	if is_local:
		return visible_yaw + spin_extra_yaw + aa_yaw_offset
	return visible_yaw

func get_visible_pitch() -> float:
	if is_local:
		return visible_pitch + aa_pitch
	return visible_pitch

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		alive = false

func respawn(spawn_pos: Vector3) -> void:
	hp = MAX_HP
	alive = true
	global_position = spawn_pos
	velocity = Vector3.ZERO
	visible = true
