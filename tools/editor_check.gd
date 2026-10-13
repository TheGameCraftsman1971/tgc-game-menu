@tool
extends Node

## The editor's bench: what only the editor can show. An autoload of the development
## project, idle unless `TGC_EDITOR_CHECK=1` is set:
##
##   TGC_EDITOR_CHECK=1 godot --path . --editor
##
## It opens a window (the preview draws on the graphics card), checks, and quits with a
## non-zero code on failure. It checks that a session in a scene opened in the editor stays
## inert (no menu, no action, no language, no file), that the menu's scene does not hide
## itself, and that the preview draws every screen in every language without a script error;
## then it photographs the preview into `captures/editor_*.png`.
##
## ⚠ Do not run it right after a headless import: the first window the editor opens then
## draws its viewports black, and so do the photographs. The checks still hold.

const LOCALES: Array[String] = ["en", "fr", "de", "es"]

var _passed := 0
var _failed := 0


func _ready() -> void:
	if not Engine.is_editor_hint() or OS.get_environment("TGC_EDITOR_CHECK") != "1":
		return
	await _frames(30)
	print("\n=== TGC Game Menu — editor bench ===\n")
	var bench_log := BenchLog.new()
	var actions := InputMap.get_actions().size()
	var locale := TranslationServer.get_locale()
	var files := _player_files()

	EditorInterface.open_scene_from_path("res://demo/demo.tscn")
	await _frames(20)
	var session := EditorInterface.get_edited_scene_root().get_node("MenuSession") as TgcMenuSession
	_expect(session.menu() == null and session.get_child_count() == 0, "a session in an opened scene builds no menu")

	EditorInterface.open_scene_from_path("res://addons/tgc_game_menu/menu/tgc_game_menu.tscn")
	await _frames(10)
	_expect((EditorInterface.get_edited_scene_root() as CanvasLayer).visible, "the menu's scene does not hide itself")

	EditorInterface.open_scene_from_path("res://demo/menu_preview.tscn")
	await _frames(20)
	var preview := EditorInterface.get_edited_scene_root() as TgcMenuPreview
	var viewport := preview.get_child(0, true) as SubViewport
	for code in LOCALES:
		for shown: TgcMenuPreview.Screen in TgcMenuPreview.Screen.values():
			preview.locale = code
			preview.screen = shown
			preview.page = &"gameplay"
			await _frames(4)
		_expect(preview.session() != null and preview.session().is_preview(), "every screen drawn in \"%s\"" % code)
	for shot: Array in [[TgcMenuPreview.Screen.MAIN_MENU, "fr"], [TgcMenuPreview.Screen.SETTINGS, "en"],
			[TgcMenuPreview.Screen.LOAD, "de"], [TgcMenuPreview.Screen.CONFIRMATION, "es"]]:
		preview.screen = shot[0]
		preview.locale = shot[1]
		await _frames(10)
		await RenderingServer.frame_post_draw
		var name := "editor_%s_%s" % [shot[1], String(TgcMenuPreview.Screen.keys()[shot[0]]).to_lower()]
		viewport.get_texture().get_image().save_png("res://captures/%s.png" % name)

	_expect(InputMap.get_actions().size() == actions and TranslationServer.get_locale() == locale,
			"no action created, the editor's language unchanged")
	_expect(_player_files() == files, "no file of the player's written")
	_expect(bench_log.script_errors() == 0, "no script error", "%d error(s)" % bench_log.script_errors())
	print("\n--- %d check(s) passed, %d failure(s) ---\n" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _expect(condition: bool, label: String, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _player_files() -> PackedStringArray:
	return DirAccess.get_files_at("user://") if DirAccess.dir_exists_absolute("user://") else PackedStringArray()
