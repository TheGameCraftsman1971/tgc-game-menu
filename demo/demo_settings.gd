@tool
class_name DemoSettings
extends Resource

## The demonstration's own setting, shown on its own page ([DemoGameplayPage]): whether the
## help line is on screen.
##
## It is here to show how a game adds a page of its own to the menu. An observable Resource,
## like the add-on's settings: the page changes a field, the game applies. A real game would
## also save it in `user://`, the way [TgcGeneralSettings] does; the demonstration keeps it
## in memory.

var show_help := true:
	set(value):
		if value != show_help:
			show_help = value
			emit_changed()
