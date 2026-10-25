class_name MovementParams
extends Resource
## Все параметры CS2/Source-мувмента. Физика только читает их,
## чит-меню меняет в рантайме на объекте MovementSettings.params.

# --- физика ---
@export var gravity: float = 800.0              # units/s²
@export var accelerate: float = 5.5
@export var air_accelerate: float = 12.0
@export var friction: float = 5.2
@export var stop_speed: float = 80.0
@export var air_wishspeed_cap: float = 30.0     # ключ к air strafe

# --- скорости ---
@export var weapon_max_speed: float = 250.0     # нож 250, винтовки ~215-230
@export var walk_mult: float = 0.52
@export var crouch_mult: float = 0.34

# --- прыжок ---
@export var jump_height: float = 57.0
@export var enable_bhop: bool = false           # false = есть потолок скорости
@export var bhop_speed_cap_mult: float = 1.1
@export var autobhop: bool = false
@export var jump_buffer_ticks: int = 2          # сколько тиков помним нажатие пробела

# --- геометрия ---
@export var step_height: float = 18.0
@export var max_slope_deg: float = 45.57

func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)    # ≈ 302 при дефолтах
