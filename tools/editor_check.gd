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
## itself, that the preview offers its page and language as lists, that a redraw takes the
## focus from no field of the editor, and that every screen is drawn in every language
## without a script error; then it photographs the preview, and the whole editor for the
## store page, into `captures/editor_*.png`.
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
	EditorInterface.inspect_object(preview)
	preview.screen = TgcMenuPreview.Screen.PAGE
	await _frames(10)
	_expect(_editor_class(&"screen") == "EditorPropertyEnum"
			and _editor_class(&"page") == "EditorPropertyTextEnum"
			and _editor_class(&"locale") == "EditorPropertyTextEnum",
			"the screen, the page and the language are picked from lists")
	var pages := _first_of_type(_property_editor(&"page"), "OptionButton") as OptionButton
	var listed := PackedStringArray()
	for index in pages.item_count:
		listed.append(pages.get_item_text(index))
	_expect(listed.has("display") and listed.has("gameplay") and not listed.has("save"),
			"the pages listed are the config's", ", ".join(listed))
	preview.screen = TgcMenuPreview.Screen.MAIN_MENU
	await _frames(10)
	_expect(_property_editor(&"page") == null, "the page shows only for the screen PAGE")

	# A control that takes the focus in a viewport takes it from the whole window: a field of
	# the editor being typed in must keep it when the preview redraws.
	var field := LineEdit.new()
	EditorInterface.get_base_control().add_child(field)
	field.grab_focus()
	for shown: TgcMenuPreview.Screen in TgcMenuPreview.Screen.values():
		preview.screen = shown
		await _frames(4)
	_expect(field.has_focus(), "a redraw leaves the focus where it is")
	field.queue_free()
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
		if not await _drawn():
			continue
		var name := "editor_%s_%s" % [shot[1], String(TgcMenuPreview.Screen.keys()[shot[0]]).to_lower()]
		viewport.get_texture().get_image().save_png("res://captures/%s.png" % name)

	# The whole editor, for the store page: the preview on Display, its Inspector beside it.
	# The bottom panel folded and the view framed on the preview through the editor's own
	# nodes, which are not an API: should they change, the photograph only looks worse.
	preview.screen = TgcMenuPreview.Screen.PAGE
	preview.page = &"display"
	preview.locale = "en"
	EditorInterface.set_main_screen_editor("2D")
	EditorInterface.edit_node(preview)
	await _frames(30)
	var base := EditorInterface.get_base_control()
	for panel in _all_of(base, "EditorBottomPanel"):
		(panel as TabContainer).current_tab = -1
	await _frames(5)
	var canvas_editor := _all_of(base, "CanvasItemEditor")[0]
	for found in _all_of(canvas_editor, "MenuButton"):
		var menu := (found as MenuButton).get_popup()
		for index in menu.item_count:
			if menu.get_item_text(index).begins_with("Frame Selection"):
				menu.id_pressed.emit(menu.get_item_id(index))
	await _frames(20)
	if await _drawn():
		get_tree().root.get_texture().get_image().save_png("res://captures/editor_window.png")

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


## Waits for the editor to draw a frame, and forces one after a few seconds (a window the
## system no longer draws, hidden or minimised); false if even that draws nothing: the
## photograph is then skipped.
func _drawn() -> bool:
	var drawn := [false]
	var mark := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var start := Time.get_ticks_msec()
	while not drawn[0] and Time.get_ticks_msec() - start < 5000:
		await get_tree().process_frame
	if not drawn[0]:
		# The viewports render off screen: a drawing forced here still gives their pictures.
		RenderingServer.force_draw()
		if not drawn[0]:
			RenderingServer.frame_post_draw.disconnect(mark)
			print("  --   no frame drawn: photograph skipped")
	return drawn[0]


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## The Inspector's editor of a property of the object it shows, or null.
func _property_editor(property: StringName) -> EditorProperty:
	for found in EditorInterface.get_inspector().find_children("*", "EditorProperty", true, false):
		if (found as EditorProperty).get_edited_property() == property:
			return found
	return null


func _editor_class(property: StringName) -> String:
	var editor := _property_editor(property)
	return editor.get_class() if editor != null else "none"


func _all_of(root: Node, type: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children(true):
		if child.is_class(type):
			found.append(child)
		found.append_array(_all_of(child, type))
	return found


func _first_of_type(root: Node, type: String) -> Node:
	if root == null:
		return null
	var found := root.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null


func _player_files() -> PackedStringArray:
	return DirAccess.get_files_at("user://") if DirAccess.dir_exists_absolute("user://") else PackedStringArray()
