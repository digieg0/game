extends Node3D
## Трассер пули: тонкий светящийся цилиндр от стрелявшего к точке попадания.
## Спавнится сервером при любом выстреле (попадание или промах).

const LIFETIME: float = 0.09
const WIDTH: float = 0.012

var from: Vector3
var to: Vector3

func _ready() -> void:
	var span: Vector3 = to - from
	var length: float = span.length()
	if length < 0.5:
		queue_free()
		return
	var mesh_instance := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = WIDTH
	beam.bottom_radius = WIDTH
	beam.height = length
	beam.radial_segments = 6
	beam.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.45, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.3, 1.0)
	material.emission_energy_multiplier = 1.6
	mesh_instance.mesh = beam
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	# Локальная ось Y цилиндра — вдоль направления полёта (looking_at даёт -Z = dir).
	var span_dir: Vector3 = span.normalized()
	var reference_up := Vector3.UP
	if span_dir.dot(Vector3.UP) < -0.99 or span_dir.dot(Vector3.UP) > 0.99:
		reference_up = Vector3.RIGHT
	var look_basis: Basis = Basis.looking_at(span_dir, reference_up)
	mesh_instance.transform = Transform3D(look_basis * Basis(Vector3(1, 0, 0), -PI / 2.0), Vector3.ZERO)
	global_position = (from + to) * 0.5
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()
