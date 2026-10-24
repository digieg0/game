extends Node
## Корень игры: лобби -> матч. Спавнит HUD/меню/ESP/scoreboard, мир арены.

@onready var ui_root: Control = $UIRoot
@onready var world_root: Node3D = $WorldRoot

const LOBBY := preload("res://scenes/ui/lobby.tscn")
const ARENA := preload("res://scenes/world/arena.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const SCOREBOARD := preload("res://scenes/ui/scoreboard.tscn")
const CHEAT_MENU := preload("res://scenes/ui/cheat_menu.tscn")
const ESP_OVERLAY := preload("res://scripts/ui/esp_overlay.gd")

var lobby: Control = null
var arena: Node3D = null
var hud: CanvasLayer = null
var scoreboard: CanvasLayer = null
var cheat_menu: CanvasLayer = null
var esp_overlay: Control = null

func _ready() -> void:
	NetManager.connected_to_server.connect(_on_connected)
	NetManager.connection_failed_signal.connect(_on_connection_failed)
	NetManager.server_disconnected_signal.connect(_on_disconnected)
	_show_lobby()

func _show_lobby() -> void:
	_clear_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lobby = LOBBY.instantiate()
	lobby.host_requested.connect(_on_host_requested)
	lobby.join_requested.connect(_on_join_requested)
	ui_root.add_child(lobby)

func _clear_match() -> void:
	if arena: arena.queue_free(); arena = null
	if hud: hud.queue_free(); hud = null
	if scoreboard: scoreboard.queue_free(); scoreboard = null
	if cheat_menu: cheat_menu.queue_free(); cheat_menu = null
	if esp_overlay: esp_overlay.queue_free(); esp_overlay = null

func _on_host_requested(pname: String, port: int) -> void:
	if NetManager.host_game(pname, port) == OK:
		_start_match()

func _on_join_requested(pname: String, ip: String, port: int) -> void:
	NetManager.join_game(pname, ip, port)

func _on_connected() -> void:
	_start_match()

func _on_connection_failed() -> void:
	if lobby: lobby.show_error("Не удалось подключиться")

func _on_disconnected() -> void:
	_show_lobby()

func _start_match() -> void:
	if lobby:
		lobby.queue_free()
		lobby = null
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
	hud.add_child(esp_overlay)
