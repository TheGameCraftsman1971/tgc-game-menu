@tool
class_name DemoGameplayPage
extends TgcMenuPage

## A page of the game's own, after the add-on's: a scene whose root extends [TgcMenuPage],
## listed in [member TgcMenuConfig.extra_pages]. The game gives it its settings ([method
## bind]) once the session is ready; the page shows them and changes them, nothing more. It
## is a tool script so that [TgcMenuPreview] can draw it live in the editor: without `@tool`,
## the preview would show it as its scene draws it.

var settings: DemoSettings

@onready var _show_help: CheckButton = %ShowHelp


func _ready() -> void:
	_show_help.toggled.connect(func(on: bool) -> void: settings.show_help = on)
	(%Back as Button).pressed.connect(closed.emit)
	if settings == null:
		settings = DemoSettings.new()
	_watch()


func bind(with_settings: DemoSettings) -> void:
	settings = with_settings
	if is_node_ready():
		_watch()


func focus_first() -> void:
	_show_help.grab_focus()


func _watch() -> void:
	if not settings.changed.is_connected(_show):
		settings.changed.connect(_show)
	_show()


func _show() -> void:
	_show_help.set_pressed_no_signal(settings.show_help)
