extends CharacterBody3D
## Player controller. The local player is predicted locally; remote players are server-simulated.

const SPEED: float = 7.0
const ACCEL: float = 10.0
const AIR_ACCEL: float = 2.5
const JUMP_VELOCITY: float = 5.5
const GRAVITY: float = 15.0
const MOUSE_SENS: float = 0.0025
const GROUND_FRICTION: float = 6.0
const FIRE_RATE: float = 0.12
const MAX_HP: float = 100.0

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

func _ready() -> void:
    if is_local:
        camera.current = true
        _apply_view_mode()
    else:
        # Remote players do not need their own Camera3D or SpringArm3D.
        camera_pivot.queue_free()
        model.visible = true
    if multiplayer.is_server() and not is_local:
        _server_input = {"move_x": 0.0, "move_y": 0.0, "jump": false, "yaw": 0.0, "pitch": 0.0}

func _apply_view_mode() -> void:
    if not is_local or not is_instance_valid(spring_arm):
        return
    # The SpringArm keeps the third-person camera behind the player and shortens near walls.
    spring_arm.spring_length = 4.2 if is_third_person else 0.0
    camera_pivot.rotation = Vector3(aim_pitch, aim_yaw, 0.0)
    if is_instance_valid(model):
        # Avoid seeing inside the head/torso from the first-person camera.
        model.visible = is_third_person

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
    var input_dir := Vector2.ZERO
    if Input.is_action_pressed("move_forward"):
        input_dir.y -= 1.0
    if Input.is_action_pressed("move_back"):
        input_dir.y += 1.0
    if Input.is_action_pressed("move_left"):
        input_dir.x -= 1.0
    if Input.is_action_pressed("move_right"):
        input_dir.x += 1.0
    return input_dir.normalized()

func _local_move(delta: float, accept_input: bool = true) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    elif not accept_input or not Input.is_action_pressed("jump"):
        var horizontal := Vector3(velocity.x, 0.0, velocity.z)
        horizontal = horizontal.move_toward(Vector3.ZERO, GROUND_FRICTION * delta * maxf(horizontal.length(), 1.0))
        velocity.x = horizontal.x
        velocity.z = horizontal.z

    var input_dir := _get_move_input(accept_input)
    var basis := Basis.from_euler(Vector3(0.0, aim_yaw, 0.0))
    var wish_dir := (basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
    var acceleration: float = ACCEL if is_on_floor() else AIR_ACCEL
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var target := wish_dir * SPEED
    if not is_on_floor():
        horizontal_velocity = horizontal_velocity.move_toward(target, acceleration * delta)
    else:
        horizontal_velocity = horizontal_velocity.move_toward(target, acceleration * delta * SPEED)
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z

    if accept_input and is_on_floor() and Input.is_action_pressed("jump"):
        velocity.y = JUMP_VELOCITY
    move_and_slide()

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
        "jump": Input.is_action_pressed("jump") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
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
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        var horizontal := Vector3(velocity.x, 0.0, velocity.z)
        horizontal = horizontal.move_toward(Vector3.ZERO, GROUND_FRICTION * delta * maxf(horizontal.length(), 1.0))
        velocity.x = horizontal.x
        velocity.z = horizontal.z
    var direction_basis := Basis.from_euler(Vector3(0.0, move_yaw, 0.0))
    var wish_dir := (direction_basis * Vector3(movement.x, 0.0, movement.y)).normalized()
    var acceleration: float = ACCEL if is_on_floor() else AIR_ACCEL
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    horizontal_velocity = horizontal_velocity.move_toward(wish_dir * SPEED, acceleration * delta * (SPEED if is_on_floor() else 1.0))
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z
    if _server_input_idle <= 0.15 and bool(_server_input.get("jump", false)) and is_on_floor():
        velocity.y = JUMP_VELOCITY
    move_and_slide()
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
    NetManager.request_fire(aim_yaw, aim_pitch)

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
        set_hitboxes_enabled(false)

func respawn(spawn_pos: Vector3) -> void:
    hp = MAX_HP
    alive = true
    global_position = spawn_pos
    velocity = Vector3.ZERO
    visible = true
    _server_input_queue.clear()
    _server_input_idle = 999.0
    set_hitboxes_enabled(true)

func set_hitboxes_enabled(value: bool) -> void:
    if model == null:
        return
    for hitbox in model.find_children("*", "Area3D", true, false):
        hitbox.set_collision_layer_value(3, value)
        hitbox.monitorable = value
