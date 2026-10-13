@icon("res://addons/tgc_game_menu/icon.svg")
class_name TgcMenuSession
extends Node

## The session: whether the game is paused, the menu over it, and the player's settings.
##
## Add one to the main scene, give it a [TgcMenuConfig], and connect [signal game_started]
## and [signal game_stopped] to the game. That is the whole contract.
##
## It is the **only** place that knows whether the game is paused. The game does not: it
## only knows that the tree stops calling it. The menu does not either: it asks, and the
## session decides. Nor does the session know the game: it says when one starts and when it
## stops, and the game does the rest.
##
## It holds the settings — [TgcGeneralSettings], [TgcDisplaySettings], [TgcAudioSettings] and
## [TgcControlBindings] —, reads them back when it starts, gives them to the menu, applies
## them to the language, the window, the buses and the [InputMap], and saves at each change.
##
## ## What freezes in pause
##
## The session always runs ([code]PROCESS_MODE_ALWAYS[/code]), and so does the menu it
## creates as its child. Everything else follows the project's own process modes: the game
## freezes if it is pausable, which is Godot's default, and the music or interface sounds go
## on if they are marked [code]PROCESS_MODE_ALWAYS[/code].
##
## ## The start
##
## By default, the program opens **on the main menu**, and no game is started: the tree is
## paused, and "Play" waits. With [member TgcMenuConfig.start_on_main_menu] off, a game
## starts at once, and the menu only ever opens as a pause menu.
##
## ## The pause
##
## It is taken on [member TgcMenuConfig.pause_action] (Esc, Start) and left by the same
## gesture. In a settings page, that gesture — and [code]ui_cancel[/code] (Esc, B) — goes up
## one page. A game in progress also pauses itself when the window loses the focus. "Main
## menu" abandons the game and reopens the start menu.

## A game starts: "Play" on the main menu, or "New game" in the pause menu. Start it.
signal game_started
## The game in progress is abandoned: "Main menu", "New game", or "Quit". Stop it.
signal game_stopped
## The tree was paused, or resumed.
signal paused_changed(paused: bool)
## The player remapped a control. The InputMap already has it: this is for the game's
## on-screen help.
signal controls_changed(bindings: TgcControlBindings)

const DEFAULT_CONFIG := "res://addons/tgc_game_menu/default_menu_config.tres"
const DEFAULT_MENU := "res://addons/tgc_game_menu/menu/tgc_game_menu.tscn"

## What the game decided about its menu. Empty: the add-on's `default_menu_config.tres`.
## To be set **before** the session enters the tree: that is when the settings are read.
@export var config: TgcMenuConfig

var general: TgcGeneralSettings
var display: TgcDisplaySettings
var audio: TgcAudioSettings
var bindings: TgcControlBindings

var _menu: TgcGameMenu
var _in_game := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = load(DEFAULT_CONFIG) as TgcMenuConfig
	TgcI18n.ensure_loaded()
	_ensure_actions()
	general = TgcGeneralSettings.new(config)
	general.load_from_disk()
	display = TgcDisplaySettings.new(config)
	display.load_from_disk()
	audio = TgcAudioSettings.new(config)
	audio.load_from_disk()
	bindings = TgcControlBindings.new(config)
	bindings.load_from_disk()
	general.apply()
	display.apply_to_window(get_window())
	audio.apply()
	general.changed.connect(_on_general_changed)
	display.changed.connect(_on_display_changed)
	audio.changed.connect(_on_audio_changed)
	bindings.changed.connect(_on_bindings_changed)

	var scene := config.menu_scene if config.menu_scene != null else load(DEFAULT_MENU) as PackedScene
	_menu = scene.instantiate() as TgcGameMenu
	_menu.setup(self)
	add_child(_menu)
	_menu.resume_requested.connect(resume)
	_menu.play_requested.connect(play)
	_menu.main_menu_requested.connect(to_main_menu)
	_menu.quit_requested.connect(quit)
	if config.start_on_main_menu:
		pause()
	else:
		# Deferred: whoever connects to `game_started` in its own `_ready()` runs after this
		# one, its child's.
		play.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(config.pause_action):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and is_paused():
		toggle_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() \
			and config.pause_on_focus_loss and _in_game and not is_paused():
		pause()


func is_paused() -> bool:
	return get_tree().paused


## True while a game is in progress, paused or not: there is something to resume.
func is_in_game() -> bool:
	return _in_game


func menu() -> TgcGameMenu:
	return _menu


## The pause gesture: pauses, goes up one page, or resumes from the menu's root if there is
## a game to resume.
func toggle_pause() -> void:
	if not is_paused():
		pause()
	elif not _menu.back():
		resume()


func pause() -> void:
	_set_paused(true)
	_menu.open(_in_game)


## Resumes the game. Without a game there is nothing to resume, and the menu stays.
func resume() -> void:
	if not _in_game:
		return
	_menu.close()
	_set_paused(false)


## Starts a game: the main menu's, or a new one from the pause menu.
func play() -> void:
	_stop_game()
	_in_game = true
	game_started.emit()
	resume()


## Abandons the game and reopens the start menu. What a game calls at its own end, too.
func to_main_menu() -> void:
	_stop_game()
	pause()


func quit() -> void:
	_stop_game()
	get_tree().quit()


func _stop_game() -> void:
	if _in_game:
		_in_game = false
		game_stopped.emit()


func _set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	paused_changed.emit(paused)


## Makes sure the menu can be opened and confirmed whatever the project declares: the pause
## action exists (Esc, Start), and with [member TgcMenuConfig.gamepad_ui_buttons],
## `ui_accept` and `ui_cancel` answer to A and B. A remappable action the project does not
## declare is reported, once: it would silently be missing from the Controls page.
func _ensure_actions() -> void:
	if not InputMap.has_action(config.pause_action):
		InputMap.add_action(config.pause_action)
		var escape := InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event(config.pause_action, escape)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		start.device = -1
		InputMap.action_add_event(config.pause_action, start)
	if config.gamepad_ui_buttons:
		_give_pad_button(&"ui_accept", JOY_BUTTON_A)
		_give_pad_button(&"ui_cancel", JOY_BUTTON_B)
	for entry in config.remappable():
		if entry != null and not InputMap.has_action(entry.action):
			push_warning("TGC Game Menu: the remappable action \"%s\" is not declared in the project's Input Map." % entry.action)


static func _give_pad_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return
	var pad := InputEventJoypadButton.new()
	pad.button_index = button
	pad.device = -1
	InputMap.action_add_event(action, pad)


func _on_general_changed() -> void:
	general.apply()
	general.save()


func _on_display_changed() -> void:
	display.apply_to_window(get_window())
	display.save()


func _on_audio_changed() -> void:
	audio.apply()
	audio.save()


func _on_bindings_changed() -> void:
	bindings.save()
	controls_changed.emit(bindings)
