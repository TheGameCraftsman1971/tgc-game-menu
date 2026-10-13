class_name DemoWorld
extends Node2D

## The demonstration's game: a square moved by the `move_*` actions, which jumps on
## `action_primary`, and a help line that **reads the InputMap** ([TgcInputLabels]) instead
## of naming the keys.
##
## What a game owes the session is small: `start()`, `stop()`, and nothing that starts a
## game by itself. It never asks whether it is paused: it is pausable (`process_mode`, in the
## scene), and the tree stops calling it.

const SPEED := 520.0
const JUMP_SECONDS := 0.3

var settings := DemoSettings.new()

var _running := false
var _jump: Tween

@onready var _player: ColorRect = %Player
@onready var _hud: CanvasLayer = %Hud
@onready var _help: Label = %Help


func _ready() -> void:
	_hud.visible = false
	settings.changed.connect(show_help)
	show_help()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		show_help()


func start() -> void:
	_player.position = _centre()
	_player.scale = Vector2.ONE
	_hud.visible = true
	_running = true


func stop() -> void:
	_running = false
	_hud.visible = false


func is_running() -> bool:
	return _running


func player_position() -> Vector2:
	return _player.position


## The jump. A function rather than a block of `_unhandled_input`: a bench plays it
## directly, since a fabricated key does not reach the input callbacks when headless.
func jump() -> void:
	if not _running or (_jump != null and _jump.is_running()):
		return
	_player.pivot_offset = _player.size / 2.0
	_jump = create_tween()
	_jump.tween_property(_player, "scale", Vector2(1.4, 1.4), JUMP_SECONDS / 2.0)
	_jump.tween_property(_player, "scale", Vector2.ONE, JUMP_SECONDS / 2.0)


## The help, **read from the InputMap**: written by hand, it would lie at the first
## remapping.
func show_help() -> void:
	_help.visible = settings.show_help
	var move := " ".join([
		TgcInputLabels.first_of(&"move_forward", false), TgcInputLabels.first_of(&"move_left", false),
		TgcInputLabels.first_of(&"move_back", false), TgcInputLabels.first_of(&"move_right", false)])
	_help.text = tr("DEMO_HELP") % [move, TgcInputLabels.first_of(&"action_primary", false),
			TgcInputLabels.first_of(&"game_pause", false)]


func _physics_process(delta: float) -> void:
	if not _running:
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var bounds := get_viewport_rect().size - _player.size
	_player.position = (_player.position + direction * SPEED * delta).clamp(Vector2.ZERO, bounds)


func _unhandled_input(event: InputEvent) -> void:
	if _running and event.is_action_pressed(&"action_primary"):
		jump()
		get_viewport().set_input_as_handled()


func _centre() -> Vector2:
	return (get_viewport_rect().size - _player.size) / 2.0
