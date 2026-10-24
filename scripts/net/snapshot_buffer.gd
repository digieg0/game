extends RefCounted
## Кольцевой буфер снапшотов позиций игроков.
## Используется для интерполяции видимой позы и backtrack'а
## (рейкаст по позе N мс назад).

## Максимальный возраст истории в секундах (2 секунды хватает с запасом)
const MAX_AGE: float = 2.0

## player_id -> Array[{t: float, pos: Vector3, yaw: float, pitch: float, alive: bool}]
var entries: Dictionary = {}

func push(player_id: int, t: float, pos: Vector3, yaw: float, pitch: float, alive: bool) -> void:
	if not entries.has(player_id):
		entries[player_id] = []
	var arr: Array = entries[player_id]
	arr.append({"t": t, "pos": pos, "yaw": yaw, "pitch": pitch, "alive": alive})
	# Выкидываем слишком старые кадры
	var cutoff: float = t - MAX_AGE
	while arr.size() > 0 and arr[0]["t"] < cutoff:
		arr.pop_front()

## Возвращает интерполированное состояние на момент времени t.
## Если истории нет — null.
func sample(player_id: int, t: float) -> Variant:
	if not entries.has(player_id):
		return null
	var arr: Array = entries[player_id]
	if arr.is_empty():
		return null
	if arr.size() == 1:
		return arr[0]
	# Ищем два кадра вокруг t
	for i in range(arr.size() - 1, -1, -1):
		if arr[i]["t"] <= t:
			if i == arr.size() - 1:
				return arr[i]
			var a: Dictionary = arr[i]
			var b: Dictionary = arr[i + 1]
			var span: float = b["t"] - a["t"]
			var w: float = 0.0 if span <= 0.0 else clampf((t - a["t"]) / span, 0.0, 1.0)
			return {
				"t": t,
				"pos": a["pos"].lerp(b["pos"], w),
				"yaw": lerp_angle(a["yaw"], b["yaw"], w),
				"pitch": lerpf(a["pitch"], b["pitch"], w),
				"alive": a["alive"],
			}
	# Всё ещё раньше самого старого кадра
	return arr[0]

func clear() -> void:
	entries.clear()
