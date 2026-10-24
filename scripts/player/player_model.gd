extends Node3D
## Визуальная модель игрока (торс, голова, ноги) + хитбоксы.
## Модель вращается по server_yaw/server_pitch — то, что видят другие.
## Камера/прицел локального игрока живут отдельно в player.gd и не зависят от модели.
## Это и есть база spinbot / anti-aim.

## Текущий видимый угол (yaw модели). Меняется сервером (spinbot/anti-aim).
var server_yaw: float = 0.0
## Видимый pitch (наклон модели), тоже серверный.
var server_pitch: float = 0.0

@onready var head_pivot: Node3D = $HeadPivot
@onready var body_pivot: Node3D = $BodyPivot
@onready var hitboxes: Array[Area3D] = []

func _ready() -> void:
	for child in find_children("*", "Area3D", true, false):
		hitboxes.append(child)

## Применить видимую позу (приходит из снапшотов).
func set_server_pose(yaw: float, pitch: float) -> void:
	server_yaw = yaw
	server_pitch = pitch
	transform.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0))
	if head_pivot:
		head_pivot.rotation.x = pitch
	if body_pivot:
		body_pivot.rotation.x = pitch * 0.3

## Локальный поворот модели для предсказания/отладки
func set_local_look(yaw: float, pitch: float) -> void:
	set_server_pose(yaw, pitch)
