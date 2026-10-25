extends RefCounted
## Small time-based snapshot history used for smooth remote-player rendering.

const MAX_AGE: float = 2.0
var entries: Dictionary = {}

func push(player_id: int, t: float, pos: Vector3, yaw: float, pitch: float, alive: bool, hp: float = 100.0, crouch: float = 1.0) -> void:
	if not entries.has(player_id):
		entries[player_id] = []
	var frames: Array = entries[player_id]
	frames.append({"t": t, "pos": pos, "yaw": yaw, "pitch": pitch, "alive": alive, "hp": hp, "crouch": crouch})
	var cutoff: float = t - MAX_AGE
	while frames.size() > 0 and float(frames[0]["t"]) < cutoff:
		frames.pop_front()

func sample(player_id: int, t: float) -> Variant:
	if not entries.has(player_id):
		return null
	var frames: Array = entries[player_id]
	if frames.is_empty():
		return null
	if frames.size() == 1 or t <= float(frames[0]["t"]):
		return frames[0]
	for i in range(frames.size() - 1):
		var a: Dictionary = frames[i]
		var b: Dictionary = frames[i + 1]
		if t <= float(b["t"]):
			var span: float = float(b["t"]) - float(a["t"])
			var weight: float = 0.0 if span <= 0.00001 else clampf((t - float(a["t"])) / span, 0.0, 1.0)
			return {
				"t": t,
				"pos": a["pos"].lerp(b["pos"], weight),
				"yaw": lerp_angle(float(a["yaw"]), float(b["yaw"]), weight),
				"pitch": lerpf(float(a["pitch"]), float(b["pitch"]), weight),
				"alive": bool(a["alive"]) if weight < 0.5 else bool(b["alive"]),
				"hp": lerpf(float(a.get("hp", 100.0)), float(b.get("hp", 100.0)), weight),
				"crouch": lerpf(float(a.get("crouch", 1.0)), float(b.get("crouch", 1.0)), weight),
			}
	return frames[frames.size() - 1]

func clear() -> void:
	entries.clear()
