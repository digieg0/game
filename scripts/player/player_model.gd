extends Node3D
## Lightweight articulated fighter model with basic locomotion animation.

var server_yaw: float = 0.0
var server_pitch: float = 0.0
var _walk_phase: float = 0.0
var _last_root_position: Vector3 = Vector3.ZERO

@onready var head_pivot: Node3D = $HeadPivot
@onready var body_pivot: Node3D = $BodyPivot
@onready var left_leg: Node3D = $LeftLegPivot
@onready var right_leg: Node3D = $RightLegPivot
@onready var left_arm: Node3D = $BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $BodyPivot/RightArmPivot

func _ready() -> void:
    _last_root_position = global_position

func _process(delta: float) -> void:
    if delta <= 0.0:
        return
    var root: CharacterBody3D = get_parent() as CharacterBody3D
    var horizontal_speed: float = 0.0
    if root != null:
        var planar_velocity: Vector3 = Vector3(root.velocity.x, 0.0, root.velocity.z)
        horizontal_speed = planar_velocity.length()
        # Remote players are interpolated from snapshots; infer movement from displacement.
        var displacement: Vector3 = root.global_position - _last_root_position
        displacement.y = 0.0
        if displacement.length() / delta > horizontal_speed:
            horizontal_speed = displacement.length() / delta
        horizontal_speed = minf(horizontal_speed, 7.0)
        _last_root_position = root.global_position

    var blend: float = clampf(horizontal_speed / 4.0, 0.0, 1.0)
    if blend > 0.03:
        _walk_phase += delta * (5.0 + horizontal_speed * 0.8)
        var swing: float = sin(_walk_phase) * 0.58 * blend
        left_leg.rotation.x = swing
        right_leg.rotation.x = -swing
        left_arm.rotation.x = -swing * 0.52
        right_arm.rotation.x = swing * 0.52
    else:
        left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, minf(delta * 8.0, 1.0))
        right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, minf(delta * 8.0, 1.0))
        left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, minf(delta * 8.0, 1.0))
        right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, minf(delta * 8.0, 1.0))

func set_server_pose(yaw: float, pitch: float) -> void:
    server_yaw = yaw
    server_pitch = pitch
    transform.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0))
    if head_pivot:
        head_pivot.rotation.x = pitch
    if body_pivot:
        body_pivot.rotation.x = pitch * 0.3

func set_local_look(yaw: float, pitch: float) -> void:
    set_server_pose(yaw, pitch)
