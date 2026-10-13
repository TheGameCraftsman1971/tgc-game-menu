class_name TgcMenuConfig
extends Resource

## Everything a game decides about its menu, in one Resource edited in the Inspector.
##
## Save one as a `.tres`, fill it in, and give it to [member TgcMenuSession.config]. Every
## field has a working default, so an empty config already gives a main menu and a pause
## menu with the display page, the master volume and a remappable pause action.
##
## It is data and nothing else: no setting is read from it after the session has started,
## and nothing in the add-on writes to it. A bench or a capture tool that must not touch the
## player's files works on a copy ([method redirected]).

const _GENERAL_PAGE := "res://addons/tgc_game_menu/menu/tgc_general_page.tscn"
const _DISPLAY_PAGE := "res://addons/tgc_game_menu/menu/tgc_display_page.tscn"
const _SOUND_PAGE := "res://addons/tgc_game_menu/menu/tgc_sound_page.tscn"
const _CONTROLS_PAGE := "res://addons/tgc_game_menu/menu/tgc_controls_page.tscn"

@export_group("Menu")
## The title of the main menu: a translation key, or plain text. Empty: the project's name
## ([code]application/config/name[/code]).
@export var title := ""
## The program opens on the main menu, paused, and waits for "Play". Off: a game starts at
## once, and the menu is only ever a pause menu.
@export var start_on_main_menu := true
## A game in progress pauses itself when the window loses the focus.
@export var pause_on_focus_loss := true
## "Quit" is hidden in a web build, where it would close nothing.
@export var hide_quit_on_web := true
## "New game", "Main menu" and "Quit" ask for a confirmation when they would abandon a game
## in progress ([member TgcMenuSession.progress_at_risk]). Off for a game that saves all the
## time, where leaving loses nothing.
@export var confirm_progress_loss := true
## The action that opens the pause menu and closes it again. If the project does not
## declare it, the session creates it at run time with Esc and Start.
@export var pause_action: StringName = &"game_pause"
## The menu's theme. Empty: the project's own theme ([code]gui/theme/custom[/code]), or
## Godot's default one.
@export var theme: Theme
## A scene to use instead of the built-in menu. Its root must extend [TgcGameMenu]: start
## from a copy of [code]menu/tgc_game_menu.tscn[/code].
@export var menu_scene: PackedScene

@export_group("Pages")
@export var show_general_page := true
@export var show_display_page := true
@export var show_sound_page := true
@export var show_controls_page := true
## The game's own pages, after the built-in ones. Each scene's root must extend
## [TgcMenuPage].
@export var extra_pages: Array[PackedScene] = []

@export_group("Languages")
## The languages the General page offers, as locale codes. Empty: those of the project's own
## translations. The add-on's catalogue is never counted: the menu speaking German does not
## mean the game does.
@export var languages := PackedStringArray()

@export_group("Display")
@export var show_window_mode := true
@export var show_window_size := true
@export var show_vsync := true
@export var show_max_fps := true
## Off for a 2D game: the 3D render scale changes nothing there.
@export var show_render_scale := true
## Off for a 2D game: this is the 3D multisample anti-aliasing.
@export var show_msaa := true
@export var show_ui_scale := true
## The frame rate limits offered, in frames per second. 0 means unlimited.
@export var fps_limits: Array[int] = [30, 60, 120, 144, 0]
## The interface sizes offered, as multiples of the designed size.
@export var ui_scales: Array[float] = [0.75, 1.0, 1.25, 1.5, 2.0]
@export_range(0.25, 1.0, 0.05) var min_render_scale := 0.5

@export_group("Sound")
## One slider per channel, in this order. A channel whose bus the project does not have is
## not shown. Empty: the master volume alone.
@export var audio_channels: Array[TgcAudioChannel] = []

@export_group("Controls")
## The actions the player can remap, **in the order the Controls page shows them**. An
## action the project does not declare is skipped, with a warning. Empty: the pause action
## alone.
@export var remappable_actions: Array[TgcRemappableAction] = []
## Inputs per action and per family (keyboard and mouse; gamepad).
@export_range(1, 4) var slots_per_family := 2
## Off for a game that is not played with a gamepad.
@export var show_gamepad_column := true
## Seconds the Controls page waits for an input before giving up on its own.
@export_range(2.0, 30.0, 0.5) var capture_timeout := 6.0
## Gives [code]ui_accept[/code] the A button and [code]ui_cancel[/code] the B button at run
## time when they have no gamepad button: Godot's defaults have none, and a gamepad could
## move through the menu without ever confirming anything.
@export var gamepad_ui_buttons := true

@export_group("Files")
@export var general_file := "user://settings_general.cfg"
@export var display_file := "user://settings_display.cfg"
@export var audio_file := "user://settings_audio.cfg"
@export var controls_file := "user://settings_controls.cfg"


## The files the session reads and writes on the player's machine.
func player_files() -> PackedStringArray:
	return PackedStringArray([general_file, display_file, audio_file, controls_file])


## A copy whose files are renamed with `prefix` (`user://settings_audio.cfg` →
## `user://bench_settings_audio.cfg`). For benches and capture tools, which must never read
## nor write the player's own settings.
func redirected(prefix: String) -> TgcMenuConfig:
	var copy := duplicate() as TgcMenuConfig
	copy.general_file = _prefixed(general_file, prefix)
	copy.display_file = _prefixed(display_file, prefix)
	copy.audio_file = _prefixed(audio_file, prefix)
	copy.controls_file = _prefixed(controls_file, prefix)
	return copy


## The pages of the menu, built-in ones first, in the order of their buttons.
func page_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	var built_in := {
		_GENERAL_PAGE: show_general_page,
		_DISPLAY_PAGE: show_display_page,
		_SOUND_PAGE: show_sound_page,
		_CONTROLS_PAGE: show_controls_page,
	}
	for path: String in built_in:
		if built_in[path]:
			scenes.append(load(path) as PackedScene)
	for scene in extra_pages:
		if scene != null:
			scenes.append(scene)
	return scenes


## The volume sliders: those declared, or the master volume alone.
func volume_channels() -> Array[TgcAudioChannel]:
	if not audio_channels.is_empty():
		return audio_channels
	var master: Array[TgcAudioChannel] = [TgcAudioChannel.new()]
	return master


## The rows of the Controls page: those declared, or the pause action alone.
func remappable() -> Array[TgcRemappableAction]:
	if not remappable_actions.is_empty():
		return remappable_actions
	var pause: Array[TgcRemappableAction] = [TgcRemappableAction.make(pause_action, "TGC_ACTION_PAUSE", true)]
	return pause


static func _prefixed(path: String, prefix: String) -> String:
	return path.get_base_dir().path_join(prefix + path.get_file())
