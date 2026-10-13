class_name TgcDisplayPage
extends TgcMenuPage

## The Display page: it shows [TgcDisplaySettings] and changes it, nothing more. It does not
## apply: the Resource notifies (`changed`), and the session applies to the window and
## saves. The page knows neither the window nor the file.
##
## The structure is declared in `tgc_display_page.tscn`. Only the lists' choices are set in
## code, because they come from the allowed values of the settings: written in the scene
## too, they would drift apart at the first addition. A row the config hides
## ([member TgcMenuConfig.show_msaa]…) is hidden with its caption. The captions are keys of
## the catalogue, which the lists translate themselves; only those carrying a number
## ("60 fps") are translated here, and redone when the language changes.

## The captions of the modes, in the order of [enum TgcDisplaySettings.WindowMode].
const _MODE_LABELS: Array[String] = ["TGC_WINDOWED", "TGC_MAXIMIZED", "TGC_FULLSCREEN"]
## The captions of anti-aliasing, in the order of [enum Viewport.MSAA].
const _MSAA_LABELS: Array[String] = ["TGC_MSAA_OFF", "MSAA 2×", "MSAA 4×", "MSAA 8×"]

var settings: TgcDisplaySettings
## The sizes the list offers, for the screen the window is on.
var _sizes: Array[Vector2i] = []

@onready var _mode: OptionButton = %Mode
@onready var _window_size: OptionButton = %WindowSize
@onready var _vsync: CheckButton = %Vsync
@onready var _fps: OptionButton = %Fps
@onready var _render_scale: HSlider = %RenderScale
@onready var _render_scale_value: Label = %RenderScaleValue
@onready var _msaa: OptionButton = %Msaa
@onready var _ui_scale: OptionButton = %UiScale


func setup(with_session: TgcMenuSession) -> void:
	super(with_session)
	settings = session.display


func is_relevant() -> bool:
	return not _shown_rows().is_empty()


func _ready() -> void:
	var shown := _shown_rows()
	for row: String in _rows():
		var visible_row := shown.has(row)
		(get_node("%" + row) as Control).visible = visible_row
		(get_node("%" + row + "Caption") as Control).visible = visible_row
	for label in _MODE_LABELS:
		_mode.add_item(label)
	for label in _MSAA_LABELS:
		_msaa.add_item(label)
	for scale in settings.ui_scales:
		_ui_scale.add_item("%d %%" % roundi(scale * 100.0))
	_fill_fps()
	_render_scale.min_value = settings.min_render_scale * 100.0
	_render_scale.max_value = TgcDisplaySettings.MAX_RENDER_SCALE * 100.0
	_render_scale.step = 5.0

	_mode.item_selected.connect(func(index: int) -> void: settings.window_mode = index)
	_window_size.item_selected.connect(func(index: int) -> void: settings.window_size = _sizes[index])
	_vsync.toggled.connect(func(on: bool) -> void: settings.vsync = on)
	_fps.item_selected.connect(func(index: int) -> void: settings.max_fps = settings.fps_limits[index])
	_render_scale.value_changed.connect(func(value: float) -> void: settings.render_scale = value / 100.0)
	_msaa.item_selected.connect(func(index: int) -> void: settings.msaa = index)
	_ui_scale.item_selected.connect(func(index: int) -> void: settings.ui_scale = settings.ui_scales[index])
	(%Restore as Button).pressed.connect(func() -> void: settings.restore_defaults())
	(%Back as Button).pressed.connect(closed.emit)
	settings.changed.connect(_show)
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_fps()
		_fps.select(settings.fps_limits.find(settings.max_fps))


func focus_first() -> void:
	for row: String in _shown_rows():
		var control := get_node("%" + row) as Control
		# The render scale's row is a box; its slider takes the focus.
		(_render_scale if control is HBoxContainer else control).grab_focus()
		return


## The sizes the page offers. For benches.
func window_sizes() -> Array[Vector2i]:
	return _sizes


## The rows of the page, by the unique name of their control, and whether the config shows
## them.
func _rows() -> Dictionary[String, bool]:
	var config := session.config
	return {
		"Mode": config.show_window_mode,
		"WindowSize": config.show_window_size,
		"Vsync": config.show_vsync,
		"Fps": config.show_max_fps,
		"RenderScaleRow": config.show_render_scale,
		"Msaa": config.show_msaa,
		"UiScale": config.show_ui_scale,
	}


func _shown_rows() -> Array[String]:
	var shown: Array[String] = []
	var rows := _rows()
	for row: String in rows:
		if rows[row]:
			shown.append(row)
	return shown


## Shows the settings **without** emitting again: a choice made by the code is not a choice
## of the player's, and must not have the window re-applied.
func _show() -> void:
	_mode.select(settings.window_mode)
	_show_sizes()
	_vsync.set_pressed_no_signal(settings.vsync)
	_fps.select(settings.fps_limits.find(settings.max_fps))
	_render_scale.set_value_no_signal(settings.render_scale * 100.0)
	_render_scale_value.text = "%d %%" % roundi(settings.render_scale * 100.0)
	_msaa.select(settings.msaa)
	_ui_scale.select(settings.ui_scales.find(settings.ui_scale))


func _fill_fps() -> void:
	_fps.clear()
	for fps in settings.fps_limits:
		_fps.add_item("TGC_FPS_UNLIMITED" if fps == 0 else tr("TGC_FPS_N") % fps)


## The list of sizes, read again every time: it depends on the screen the window is on, and
## the player may have moved it from one screen to another. It only applies in windowed
## mode, and is disabled otherwise rather than hidden: one sees that it exists.
func _show_sizes() -> void:
	var metrics := TgcDisplaySettings.screen_metrics()
	_sizes = TgcDisplaySettings.window_sizes(metrics[0], metrics[1])
	_window_size.clear()
	for size in _sizes:
		_window_size.add_item("%d × %d" % [size.x, size.y])
	_window_size.select(_sizes.find(TgcDisplaySettings.nearest_size(_sizes, settings.window_size)))
	_window_size.disabled = settings.window_mode != TgcDisplaySettings.WindowMode.WINDOWED
