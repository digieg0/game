extends Node
## Main flow: lobby -> multiplayer match -> return to lobby after disconnect.

@onready var ui_root: Control = $UIRoot
@onready var world_root: Node3D = $WorldRoot

const LOBBY := preload("res://scenes/ui/lobby.tscn")
const ARENA := preload("res://scenes/world/arena.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const SCOREBOARD := preload("res://scenes/ui/scoreboard.tscn")
const CHEAT_MENU := preload("res://scenes/ui/cheat_menu.tscn")
const ESP_OVERLAY := preload("res://scripts/ui/esp_overlay.gd")
const MOVEMENT_DEBUG := preload("res://movement/debug_overlay.gd")

var lobby: Control
var arena: Node3D
var hud: CanvasLayer
var scoreboard: CanvasLayer
var cheat_menu: CanvasLayer
var esp_overlay: Control
var movement_debug: CanvasLayer

func _ready() -> void:
	NetManager.connected_to_server.connect(_on_connected)
	NetManager.connection_failed_signal.connect(_on_connection_failed)
	NetManager.server_disconnected_signal.connect(_on_disconnected)
	_show_lobby()

func _unhandled_input(event: InputEvent) -> void:
	if arena != null and event.is_action_pressed("escape_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _show_lobby() -> void:
	_clear_match()
	if lobby != null and is_instance_valid(lobby):
		lobby.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby = LOBBY.instantiate()
	lobby.host_requested.connect(_on_host_requested)
	lobby.join_requested.connect(_on_join_requested)
	ui_root.add_child(lobby)

func _clear_match() -> void:
	for node in [arena, hud, scoreboard, cheat_menu, esp_overlay, movement_debug]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	arena = null
	hud = null
	scoreboard = null
	cheat_menu = null
	esp_overlay = null
	movement_debug = null

func _on_host_requested(pname: String, port: int) -> void:
	var err: Error = NetManager.host_game(pname, port)
	if err == OK:
		_start_match()
	elif lobby:
		lobby.show_error("Не удалось создать сервер на этом порту (%s)." % error_string(err))

func _on_join_requested(pname: String, ip: String, port: int) -> void:
	var err: Error = NetManager.join_game(pname, ip, port)
	if err != OK and lobby:
		lobby.show_error("Не удалось начать подключение (%s)." % error_string(err))
	elif lobby:
		lobby.show_error("Подключение к %s:%d…" % [ip, port])

func _on_connected() -> void:
	_start_match()

func _on_connection_failed() -> void:
	if lobby:
		lobby.show_error("Не удалось подключиться. Проверьте IP, порт и доступность сервера.")

func _on_disconnected() -> void:
	_show_lobby()

func _start_match() -> void:
	if lobby != null:
		lobby.queue_free()
		lobby = null
	_clear_match()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	arena = ARENA.instantiate()
	world_root.add_child(arena)
	hud = HUD.instantiate()
	add_child(hud)
	scoreboard = SCOREBOARD.instantiate()
	add_child(scoreboard)
	cheat_menu = CHEAT_MENU.instantiate()
	add_child(cheat_menu)
	esp_overlay = Control.new()
	esp_overlay.set_script(ESP_OVERLAY)
	esp_overlay.name = "ESPOverlay"
	hud.add_child(esp_overlay)
	movement_debug = MOVEMENT_DEBUG.new()
	add_child(movement_debug)
