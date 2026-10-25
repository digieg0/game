extends CanvasLayer
## Minimal competitive HUD: crosshair, health, alive count and hitmarker.

const OVERLAY_SCRIPT := preload("res://scripts/ui/hud_overlay.gd")
const HITMARKER_DURATION: float = 0.45

var hitmarker_time: float = 0.0
var last_hit_killed: bool = false

func _ready() -> void:
    layer = 5
    add_to_group("hud")
    var overlay := Control.new()
    overlay.set_script(OVERLAY_SCRIPT)
    overlay.name = "HUDOverlay"
    overlay.hud = self
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)

func _process(delta: float) -> void:
    if hitmarker_time > 0.0:
        hitmarker_time = maxf(0.0, hitmarker_time - delta)

func add_hitmarker(killed: bool) -> void:
    hitmarker_time = HITMARKER_DURATION
    last_hit_killed = killed
