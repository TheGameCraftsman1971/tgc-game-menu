class_name TgcToast
extends CanvasLayer

## A short message at the top of the screen, which fades away by itself: "Quick save done",
## "No quick save". The session shows it after a shortcut, when no menu is there to answer.
##
## It lives above the menu and the game, always runs (a quick save happens during the game,
## a message must still fade in pause), and never takes the focus nor the mouse.

const SHOWN_SECONDS := 1.8
const FADE_SECONDS := 0.4

var _fade: Tween

@onready var _frame: Control = %Frame
@onready var _panel: Control = %Panel
@onready var _label: Label = %Message


func _ready() -> void:
	_panel.visible = false


## The theme of the menu, for the panel and its text.
func set_theme(theme: Theme) -> void:
	_frame.theme = theme


## Shows `text`, already translated, in place of whatever was shown.
func show_message(text: String) -> void:
	if _fade != null:
		_fade.kill()
	_label.text = text
	_panel.modulate.a = 1.0
	_panel.visible = true
	_fade = create_tween()
	_fade.tween_interval(SHOWN_SECONDS)
	_fade.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
	_fade.tween_callback(func() -> void: _panel.visible = false)


## The message shown, or an empty string once it has faded. For benches.
func message() -> String:
	return _label.text if _panel.visible else ""
