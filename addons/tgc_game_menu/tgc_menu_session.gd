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
##
## ## Saves
##
## With [member TgcMenuConfig.enable_saves] on and a [TgcSaveProvider] in [member saves], the
## menu gets "Save" and "Load", and the quick save and quick load get their shortcuts (F5,
## F9, remappable). The session decides when and where — which slot, whether the game can be
## left — and the provider does the saving. [method save_to], [method load_from],
## [method delete_save], [method quick_save] and [method quick_load] are what the menu and the
## shortcuts call, and what a game calls itself (an autosave is a [method save_to]).

## A game starts: "Play" on the main menu, or "New game" in the pause menu. Start it.
signal game_started
## The game in progress is abandoned: "Main menu", "New game", or "Quit". Stop it.
signal game_stopped
## The tree was paused, or resumed.
signal paused_changed(paused: bool)
## The player remapped a control. The InputMap already has it: this is for the game's
## on-screen help.
signal controls_changed(bindings: TgcControlBindings)
## The game was saved into `slot` (from the menu, a shortcut, or the game itself).
signal saved(slot: TgcSaveSlot)
## The game in `slot` was loaded, and is running.
signal loaded(slot: TgcSaveSlot)
## What `slot` held was deleted.
signal save_deleted(slot: TgcSaveSlot)

const DEFAULT_CONFIG := "res://addons/tgc_game_menu/default_menu_config.tres"
const DEFAULT_MENU := "res://addons/tgc_game_menu/menu/tgc_game_menu.tscn"
const TOAST := "res://addons/tgc_game_menu/menu/tgc_toast.tscn"

## What the game decided about its menu. Empty: the add-on's `default_menu_config.tres`.
## To be set **before** the session enters the tree: that is when the settings are read.
@export var config: TgcMenuConfig

var general: TgcGeneralSettings
var display: TgcDisplaySettings
var audio: TgcAudioSettings
var bindings: TgcControlBindings
## The game in progress has run since it was last saved or loaded: leaving it would lose
## something. The session keeps it — false after a save or a load, true again as soon as the
## game runs, and when a game starts —, and "New game", "Main menu", "Quit" and loading ask
## for a confirmation while it is true ([member TgcMenuConfig.confirm_progress_loss]).
var progress_at_risk := true
## The game's saving, when it has one: see [TgcSaveProvider]. Set it once the session is
## ready; the menu's "Save" and "Load" appear when it is there and the config allows them,
## the main menu already shown included.
var saves: TgcSaveProvider:
	set(value):
		saves = value
		if _menu != null and _menu.is_node_ready():
			_menu.refresh_root()

var _menu: TgcGameMenu
var _toast: TgcToast
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
	_toast = (load(TOAST) as PackedScene).instantiate() as TgcToast
	add_child(_toast)
	if config.theme != null:
		_toast.set_theme(config.theme)
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
	elif config.quick_saves_enabled() and not _menu.is_confirming():
		if event.is_action_pressed(config.quick_save_action):
			quick_save()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(config.quick_load_action):
			quick_load()
			get_viewport().set_input_as_handled()


## Progress is at risk as soon as the game runs: a frame played since the last save is a
## frame a "Main menu" would lose.
func _process(_delta: float) -> void:
	if _in_game and not get_tree().paused:
		progress_at_risk = true


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


## The on-screen messages. For benches.
func toast() -> TgcToast:
	return _toast


## True if leaving the game now would lose something: what the menu asks before "New game",
## "Main menu" and "Quit".
func needs_confirmation() -> bool:
	return config.confirm_progress_loss and _in_game and progress_at_risk


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
	progress_at_risk = true
	game_started.emit()
	resume()


## Abandons the game and reopens the start menu. What a game calls at its own end, too.
func to_main_menu() -> void:
	_stop_game()
	pause()


func quit() -> void:
	_stop_game()
	get_tree().quit()


## True if the menu offers saving and loading: the config allows it, and the game handed its
## [TgcSaveProvider] over.
func saves_enabled() -> bool:
	return config.enable_saves and saves != null


## The slots of the Save page, numbered from 1.
func save_slots() -> Array[TgcSaveSlot]:
	return _slots(TgcSaveSlot.Kind.REGULAR, config.save_slots if saves_enabled() else 0)


## The slots the quick save writes in turn.
func quick_slots() -> Array[TgcSaveSlot]:
	return _slots(TgcSaveSlot.Kind.QUICK, config.quick_save_slots if saves_enabled() else 0)


## What `slot` holds, or null if it is empty. Whatever the provider returns that is not a
## [TgcSaveInfo] counts as empty.
func describe(slot: TgcSaveSlot) -> TgcSaveInfo:
	if not saves_enabled():
		return null
	var info: Variant = saves.describe(slot)
	return info as TgcSaveInfo if info is TgcSaveInfo else null


## The slots that hold a save, regular and quick, the most recent first.
func existing_saves() -> Array[TgcSaveSlot]:
	var found: Array[TgcSaveSlot] = []
	var times := {}
	for slot in save_slots() + quick_slots():
		var info := describe(slot)
		if info != null:
			found.append(slot)
			times[slot] = info.saved_at
	found.sort_custom(func(a: TgcSaveSlot, b: TgcSaveSlot) -> bool: return times[a] > times[b])
	return found


## True if the game in progress can be saved now.
func can_save() -> bool:
	return saves_enabled() and _in_game and saves.can_save()


## Saves the game in progress into `slot`.
func save_to(slot: TgcSaveSlot) -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	var error := saves.save_game(slot)
	if error == OK:
		progress_at_risk = false
		saved.emit(slot)
	return error


## Loads `slot`: stops the game in progress, starts a fresh one, and has the provider restore
## the saved state over it. On failure, back to the main menu.
func load_from(slot: TgcSaveSlot) -> Error:
	if not saves_enabled() or describe(slot) == null:
		return ERR_DOES_NOT_EXIST
	_stop_game()
	_in_game = true
	game_started.emit()
	var error := saves.load_game(slot)
	if error != OK:
		to_main_menu()
		return error
	resume()
	progress_at_risk = false
	loaded.emit(slot)
	return OK


func delete_save(slot: TgcSaveSlot) -> Error:
	if not saves_enabled():
		return ERR_UNAVAILABLE
	var error := saves.delete_save(slot)
	if error == OK:
		save_deleted.emit(slot)
	return error


## Saves into the quick slots in turn: the first empty one, else the oldest.
func quick_save() -> Error:
	var slots := quick_slots()
	if slots.is_empty() or not _in_game:
		return ERR_UNAVAILABLE
	if not saves.can_save():
		notify("TGC_CANNOT_SAVE")
		return ERR_BUSY
	var target := slots[0]
	var oldest := INF
	for slot in slots:
		var info := describe(slot)
		if info == null:
			target = slot
			break
		if info.saved_at < oldest:
			oldest = info.saved_at
			target = slot
	var error := save_to(target)
	notify("TGC_QUICK_SAVED" if error == OK else "TGC_SAVE_FAILED")
	return error


## Loads the most recent quick save. Without a question: that is what a quick load is for.
func quick_load() -> Error:
	var latest: TgcSaveSlot = null
	for slot in existing_saves():
		if slot.is_quick():
			latest = slot
			break
	if latest == null:
		if not quick_slots().is_empty():
			notify("TGC_NO_QUICK_SAVE")
		return ERR_DOES_NOT_EXIST
	var error := load_from(latest)
	notify("TGC_QUICK_LOADED" if error == OK else "TGC_LOAD_FAILED")
	return error


## Shows a short message on screen, a key of the catalogue, if the config wants them.
func notify(message: String) -> void:
	if config.show_save_notifications and _toast != null:
		_toast.show_message(tr(message))


func _slots(kind: TgcSaveSlot.Kind, count: int) -> Array[TgcSaveSlot]:
	var slots: Array[TgcSaveSlot] = []
	for index in range(1, count + 1):
		slots.append(TgcSaveSlot.new(kind, index))
	return slots


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
## action exists (Esc, Start), so do the quick save's shortcuts when they are on (F5, F9),
## and with [member TgcMenuConfig.gamepad_ui_buttons],
## `ui_accept` and `ui_cancel` answer to A and B. A remappable action the project does not
## declare is reported, once: it would silently be missing from the Controls page.
func _ensure_actions() -> void:
	_declare(config.pause_action, [KEY_ESCAPE], [JOY_BUTTON_START])
	if config.quick_saves_enabled():
		_declare(config.quick_save_action, [KEY_F5], [])
		_declare(config.quick_load_action, [KEY_F9], [])
	if config.gamepad_ui_buttons:
		_give_pad_button(&"ui_accept", JOY_BUTTON_A)
		_give_pad_button(&"ui_cancel", JOY_BUTTON_B)
	for entry in config.remappable():
		if entry != null and not InputMap.has_action(entry.action):
			push_warning("TGC Game Menu: the remappable action \"%s\" is not declared in the project's Input Map." % entry.action)


## Creates an action the project does not declare, with these keys and gamepad buttons.
static func _declare(action: StringName, keys: Array[Key], buttons: Array[JoyButton]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var press := InputEventKey.new()
		press.physical_keycode = key
		InputMap.action_add_event(action, press)
	for button in buttons:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		pad.device = -1
		InputMap.action_add_event(action, pad)


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
