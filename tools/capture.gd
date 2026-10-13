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

const DEMO_SCENE := preload("res://demo/demo.tscn")
const DEMO_CONFIG := preload("res://demo/demo_menu_config.tres")
const PREFIX := "capture_"

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
	add_child(demo)
	var session := demo.session()
	var menu := session.menu()
	for locale in locales:
		session.general.locale = locale
		await _wait(0.3)
		await _shot("%s_01_main_menu" % locale)
		var index := 2
		for page in menu.page_ids():
			menu.show_page(page)
			await _wait(0.2)
			await _shot("%s_%02d_%s" % [locale, index, page])
			index += 1
		session.play()
		await _wait(0.4)
		await _shot("%s_%02d_game" % [locale, index])
		session.pause()
		await _wait(0.3)
		await _shot("%s_%02d_pause" % [locale, index + 1])
		session.to_main_menu()

	session.bindings.restore_defaults()
	demo.queue_free()
	for path in config.player_files():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await _wait(0.2)
	get_tree().quit()


func _wait(seconds: float) -> void:
	# The delay also runs during the pause: it is the pause being photographed.
	await get_tree().create_timer(seconds, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _directory.path_join(name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("%s %s" % ["saved" if error == OK else "FAILED", path])
