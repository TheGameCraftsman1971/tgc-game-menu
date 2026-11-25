extends Node

## Capture tool: mounts the demonstration and saves what one sees, menu and game, in each
## language asked for.
##
##   godot --path . res://tools/capture.tscn --resolution 1600x900 [-- en fr de es]
##
## It opens a window — headless rendering has no graphics card. The images go to
## `captures/`, ignored by git and carrying a `.gdignore` without which Godot would import
## every PNG as a texture. `CAPTURE_DIR` writes elsewhere. The gestures are played through
## the session's public methods, as in the bench: it is the menu itself being photographed,
## not a staging of it.
##
## After the menu as the demonstration sets it, two other presentations, each on a demonstration
## of its own (a config is read when its session starts): the pause menu standing on the left
## over a light veil (`_12_placed_left`), and an application's drop-down menu hanging under a
## button of its own, then its Settings (`_13_drop_down`, `_14_drop_down_settings`).

const DEMO_SCENE := preload("res://demo/demo.tscn")
const DEMO_CONFIG := preload("res://demo/demo_menu_config.tres")
const PREFIX := "capture_"
const SAVE_DIRECTORY := "user://capture_saves"

var _directory := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_directory = OS.get_environment("CAPTURE_DIR")
	if _directory == "":
		_directory = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(_directory)
	var locales := OS.get_cmdline_user_args()
	if locales.is_empty():
		locales = PackedStringArray(["en", "fr"])

	var config := DEMO_CONFIG.redirected(PREFIX)
	# Every language the add-on speaks, for the pictures: the demonstration only has two.
	config.languages = PackedStringArray(TgcI18n.LOCALES)
	var demo: Demo = DEMO_SCENE.instantiate()
	(demo.get_node("MenuSession") as TgcMenuSession).config = config
	demo.save_directory = SAVE_DIRECTORY
	add_child(demo)
	var session := demo.session()
	var menu := session.menu()
	for locale in locales:
		session.general.locale = locale
		await _wait(0.3)
		await _shot("%s_01_main_menu" % locale)
		(menu.get_node("%Quit") as Button).pressed.emit()
		await _wait(0.2)
		await _shot("%s_01b_quit" % locale)
		(menu.get_node("%Cancel") as Button).pressed.emit()
		menu.show_page(TgcGameMenu.SETTINGS)
		await _wait(0.2)
		await _shot("%s_02_settings" % locale)
		var index := 3
		for page in menu.page_ids():
			menu.show_page(page)
			await _wait(0.2)
			await _shot("%s_%02d_%s" % [locale, index, page])
			index += 1
		session.play()
		demo.world().place_player(Vector2(640, 380))
		session.quick_save()
		await _wait(0.4)
		await _shot("%s_%02d_game" % [locale, index])
		session.progress_at_risk = true
		session.quick_load()
		await _wait(0.2)
		await _shot("%s_%02db_quick_load" % [locale, index])
		menu.back()
		session.pause()
		await _wait(0.3)
		await _shot("%s_%02d_pause" % [locale, index + 1])
		session.save_to(session.save_slots()[0])
		demo.world().place_player(Vector2(1200, 700))
		session.save_to(session.save_slots()[2])
		menu.show_page(&"save")
		await _wait(0.2)
		await _shot("%s_%02d_save" % [locale, index + 1])
		menu.show_page(&"load")
		await _wait(0.2)
		await _shot("%s_%02d_load" % [locale, index + 1])
		menu.show_page(TgcGameMenu.ROOT)
		(menu.get_node("%MainMenu") as Button).pressed.emit()
		await _wait(0.2)
		await _shot("%s_%02d_confirm" % [locale, index + 2])
		session.to_main_menu()

	session.bindings.restore_defaults()
	demo.queue_free()
	await _wait(0.2)
	for locale in locales:
		await _placed(config, locale)
		await _drop_down(config, locale)
	for path in config.player_files():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for name in DirAccess.get_files_at(SAVE_DIRECTORY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY.path_join(name)))
	await _wait(0.2)
	get_tree().quit()


## The pause menu on the left, 80 px from the edge, over a light veil: the game stays in sight.
func _placed(base: TgcMenuConfig, locale: String) -> void:
	var config := base.duplicate() as TgcMenuConfig
	config.horizontal_placement = TgcMenuConfig.HorizontalPlacement.LEFT
	config.screen_margin = 80.0
	config.veil_opacity = 0.25
	var demo := _mount(config, locale)
	await _wait(0.2)
	demo.session().play()
	demo.world().place_player(Vector2(980, 420))
	await _wait(0.4)
	demo.session().pause()
	await _wait(0.3)
	await _shot("%s_12_placed_left" % locale)
	await _unmount(demo)


## An application's menu: no "New game" nor "Main menu", "Quit" rather than "Quit game", dropped
## down from a button of its own (here the add-on's icon), then its Settings.
func _drop_down(base: TgcMenuConfig, locale: String) -> void:
	var config := base.duplicate() as TgcMenuConfig
	config.presentation = TgcMenuConfig.Presentation.DROP_DOWN
	config.wording = TgcMenuConfig.Wording.APPLICATION
	config.start_on_main_menu = false
	config.show_new_game = false
	config.show_main_menu_button = false
	config.pause_title = "TGC Game Menu"
	var demo := _mount(config, locale)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var button := Button.new()
	# The icon drawn at its size from its SVG: the imported one is 16 px, blurred once enlarged.
	var image := Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string("res://addons/tgc_game_menu/icon.svg"), 3.0)
	button.icon = ImageTexture.create_from_image(image)
	button.position = Vector2(24.0, 24.0)
	button.size = Vector2(64.0, 64.0)
	layer.add_child(button)
	demo.add_child(layer)
	await _wait(0.4)
	demo.world().place_player(Vector2(900, 460))
	var menu := demo.session().menu()
	menu.drop_from(button.get_global_rect())
	demo.session().toggle_menu()
	await _wait(0.6)
	await _shot("%s_13_drop_down" % locale)
	menu.show_page(TgcGameMenu.SETTINGS)
	await _wait(0.6)
	await _shot("%s_14_drop_down_settings" % locale)
	await _unmount(demo)


func _mount(config: TgcMenuConfig, locale: String) -> Demo:
	var demo: Demo = DEMO_SCENE.instantiate()
	(demo.get_node("MenuSession") as TgcMenuSession).config = config
	demo.save_directory = SAVE_DIRECTORY
	add_child(demo)
	demo.session().general.locale = locale
	return demo


func _unmount(demo: Demo) -> void:
	demo.session().bindings.restore_defaults()
	get_tree().paused = false
	demo.queue_free()
	await _wait(0.2)


func _wait(seconds: float) -> void:
	# The delay also runs during the pause: it is the pause being photographed.
	await get_tree().create_timer(seconds, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _directory.path_join(name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("%s %s" % ["saved" if error == OK else "FAILED", path])
