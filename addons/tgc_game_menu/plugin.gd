@tool
extends EditorPlugin

## TGC Game Menu — the add-on's entry point, in the editor only.
##
## The node and the resources are global classes ([code]class_name[/code]): Godot registers
## them itself, so [TgcMenuSession] shows up in "Create New Node" and every class can be
## typed in code. This plugin does only what a [code]class_name[/code] cannot: when it is
## enabled, it declares in the project settings what the menu needs, so that the project
## shows it, lets it be edited, and exports it.
##
## - The add-on's compiled catalogues, in [code]internationalization/locale/translations[/code].
## - The pause action [code]game_pause[/code] (Esc, Start), if the project has none, so that
##   it appears in Project Settings > Input Map, where its defaults can be changed.
##
## Disabling removes the catalogues and leaves the action: it is the project's now, and may
## have been edited. The session does both at run time when they are missing, so a project
## that never enabled the plugin still gets a working menu.

const TRANSLATIONS := "internationalization/locale/translations"
const PAUSE_ACTION := "input/game_pause"


func _enable_plugin() -> void:
	var listed: PackedStringArray = ProjectSettings.get_setting(TRANSLATIONS, PackedStringArray())
	for path in TgcI18n.catalog_paths():
		if not listed.has(path):
			listed.append(path)
	ProjectSettings.set_setting(TRANSLATIONS, listed)
	if not ProjectSettings.has_setting(PAUSE_ACTION):
		var escape := InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		start.device = -1
		ProjectSettings.set_setting(PAUSE_ACTION, {"deadzone": 0.5, "events": [escape, start]})
	ProjectSettings.save()


func _disable_plugin() -> void:
	var listed: PackedStringArray = ProjectSettings.get_setting(TRANSLATIONS, PackedStringArray())
	var kept := PackedStringArray()
	for path in listed:
		if not TgcI18n.catalog_paths().has(path):
			kept.append(path)
	ProjectSettings.set_setting(TRANSLATIONS, kept)
	ProjectSettings.save()
