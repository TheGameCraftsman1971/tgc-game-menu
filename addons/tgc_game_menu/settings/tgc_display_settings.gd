@tool
class_name TgcDisplaySettings
extends Resource

## The player's display settings, and what they mean for a window.
##
## An **observable** Resource: every change emits `changed`. [TgcMenuSession] applies to the
## window what concerns it and saves; the Display page only changes a field.
##
## **The defaults are what the project declares**: its window mode and size, its vsync mode,
## its frame rate limit, its 3D render scale and its 3D MSAA. "Reset" brings them back, and
## a project that changes one of them in its settings changes the default with it. The
## values offered (frame rates, interface sizes) come from [TgcMenuConfig].
##
## The file lives in `user://`, so it is read back in Zero-Trust: each value is first
## checked for its type, then brought back among the allowed values. A damaged value falls
## back on the default, and never crashes the game.
##
## ## Three modes, and window sizes that keep the screen's shape
##
## Windowed, maximized, fullscreen. In windowed mode, the sizes offered have **the same
## aspect ratio as the screen** the window is on, and fit in it, title bar included
## ([method window_sizes]). A size saved on another screen is brought back to the nearest
## size of the current one. Everything is counted in pixels: Godot's unit for the screen as
## for the window, Retina included.

const _SECTION := "display"

enum WindowMode {
	WINDOWED,
	MAXIMIZED,
	FULLSCREEN,
}

## The name of a mode in the file: a readable word rather than an integer that would change
## meaning the day a mode is added.
const _MODE_NAMES := {
	WindowMode.WINDOWED: "windowed",
	WindowMode.MAXIMIZED: "maximized",
	WindowMode.FULLSCREEN: "fullscreen",
}

const MAX_RENDER_SCALE := 1.0
## The widths the window sizes are built from; the height follows the screen.
const WINDOW_WIDTHS: Array[int] = [
	960, 1024, 1152, 1280, 1366, 1440, 1600, 1680, 1920, 2048, 2304, 2560, 2880, 3200,
	3456, 3840, 4096, 5120,
]
const MIN_WINDOW_SIZE := Vector2i(640, 360)
const MAX_WINDOW_SIZE := Vector2i(7680, 4320)
## The share of a screen's usable height a window may take: its title bar must fit.
const USABLE_HEIGHT_SHARE := 0.92
## The screen assumed when the display server knows none (headless).
const FALLBACK_SCREEN := Vector2i(1920, 1080)

var window_mode := declared_mode():
	set(value):
		value = clampi(value, 0, WindowMode.size() - 1)
		if value != window_mode:
			window_mode = value
			_notify()
## The window's size in windowed mode, in pixels.
var window_size := declared_size():
	set(value):
		value = value.clamp(MIN_WINDOW_SIZE, MAX_WINDOW_SIZE)
		if value != window_size:
			window_size = value
			_notify()
var vsync := declared_vsync():
	set(value):
		if value != vsync:
			vsync = value
			_notify()
## Frames per second at most; 0: unlimited. Only the values of
## [member TgcMenuConfig.fps_limits] are accepted.
var max_fps := 0:
	set(value):
		value = value if fps_limits.has(value) else _fallback_fps()
		if value != max_fps:
			max_fps = value
			_notify()
## The 3D render scale: under 1, the scene is computed smaller and then enlarged.
var render_scale := 1.0:
	set(value):
		value = snappedf(clampf(value, min_render_scale, MAX_RENDER_SCALE), 0.05)
		if not is_equal_approx(value, render_scale):
			render_scale = value
			_notify()
## 3D multisample anti-aliasing: 0 none, 1 2×, 2 4×, 3 8× ([enum Viewport.MSAA]).
var msaa := Viewport.MSAA_DISABLED as int:
	set(value):
		value = clampi(value, Viewport.MSAA_DISABLED, Viewport.MSAA_8X)
		if value != msaa:
			msaa = value
			_notify()
## The interface's size, as a multiple of its designed size. Only the values of
## [member TgcMenuConfig.ui_scales] are accepted.
var ui_scale := 1.0:
	set(value):
		value = value if ui_scales.has(value) else _fallback_ui_scale()
		if not is_equal_approx(value, ui_scale):
			ui_scale = value
			_notify()

var path := "user://settings_display.cfg"
## The values offered, from the config.
var fps_limits: Array[int] = []
var ui_scales: Array[float] = []
var min_render_scale := 0.5

var _quiet := false


func _init(menu_config: TgcMenuConfig = null) -> void:
	var config := menu_config if menu_config != null else TgcMenuConfig.new()
	fps_limits = config.fps_limits.duplicate()
	if fps_limits.is_empty():
		fps_limits = [0]
	ui_scales = config.ui_scales.duplicate()
	if ui_scales.is_empty():
		ui_scales = [1.0]
	min_render_scale = clampf(config.min_render_scale, 0.25, MAX_RENDER_SCALE)
	path = config.display_file
	_quiet = true
	restore_defaults()
	_quiet = false


## Applies to a window what concerns it. The window mode, its size and vsync are not asked
## of the headless server, which does not know them and complains.
func apply_to_window(window: Window) -> void:
	if DisplayServer.get_name() != "headless":
		var target := window_mode_for(DisplayServer.window_get_mode(), window_mode)
		if target >= 0:
			DisplayServer.window_set_mode(target)
		if window_mode == WindowMode.WINDOWED:
			_size_window(window, target >= 0)
		DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = max_fps
	window.msaa_3d = msaa as Viewport.MSAA
	window.scaling_3d_scale = render_scale
	window.content_scale_factor = ui_scale


## The sizes offered for a screen: the screen's aspect ratio, and no larger than its usable
## area (minus the title bar). Sorted from smallest to largest; never empty, since a tiny
## screen still keeps its own shape.
static func window_sizes(screen: Vector2i, usable: Vector2i) -> Array[Vector2i]:
	var shape := screen if screen.x > 0 and screen.y > 0 else FALLBACK_SCREEN
	var room := usable if usable.x > 0 and usable.y > 0 else shape
	var aspect := float(shape.x) / float(shape.y)
	var max_height := floori(room.y * USABLE_HEIGHT_SHARE)
	var sizes: Array[Vector2i] = []
	for width in WINDOW_WIDTHS:
		# An even height: half a pixel cannot be centred.
		var height := roundi(width / aspect / 2.0) * 2
		if width <= room.x and height <= max_height and height >= MIN_WINDOW_SIZE.y:
			sizes.append(Vector2i(width, height))
	if sizes.is_empty():
		var height := maxi(max_height - max_height % 2, MIN_WINDOW_SIZE.y)
		sizes.append(Vector2i(roundi(height * aspect), height))
	return sizes


## The size offered that is nearest to the one wanted, by width.
static func nearest_size(sizes: Array[Vector2i], wanted: Vector2i) -> Vector2i:
	var best := sizes[0]
	for size in sizes:
		if absi(size.x - wanted.x) < absi(best.x - wanted.x):
			best = size
	return best


## The window's screen: its size and its usable area, in pixels. The fallback screen when
## the server knows none.
static func screen_metrics() -> Array[Vector2i]:
	var screen := DisplayServer.window_get_current_screen()
	if screen < 0:
		return [FALLBACK_SCREEN, FALLBACK_SCREEN]
	return [DisplayServer.screen_get_size(screen), DisplayServer.screen_get_usable_rect(screen).size]


## The mode to give the window, or -1 if it is already in it.
static func window_mode_for(current: int, wanted: WindowMode) -> int:
	match wanted:
		WindowMode.FULLSCREEN:
			if current == DisplayServer.WINDOW_MODE_FULLSCREEN \
					or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				return -1
			return DisplayServer.WINDOW_MODE_FULLSCREEN
		WindowMode.MAXIMIZED:
			return -1 if current == DisplayServer.WINDOW_MODE_MAXIMIZED else DisplayServer.WINDOW_MODE_MAXIMIZED
	return -1 if current == DisplayServer.WINDOW_MODE_WINDOWED else DisplayServer.WINDOW_MODE_WINDOWED


## The mode the project declares, brought back to the three the page offers.
static func declared_mode() -> WindowMode:
	match int(ProjectSettings.get_setting("display/window/size/mode", DisplayServer.WINDOW_MODE_WINDOWED)):
		DisplayServer.WINDOW_MODE_MAXIMIZED:
			return WindowMode.MAXIMIZED
		DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return WindowMode.FULLSCREEN
	return WindowMode.WINDOWED


static func declared_size() -> Vector2i:
	return Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", FALLBACK_SCREEN.x)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", FALLBACK_SCREEN.y)))


static func declared_vsync() -> bool:
	return int(ProjectSettings.get_setting("display/window/vsync/vsync_mode",
			DisplayServer.VSYNC_ENABLED)) != DisplayServer.VSYNC_DISABLED


static func declared_max_fps() -> int:
	return int(ProjectSettings.get_setting("application/run/max_fps", 0))


static func declared_render_scale() -> float:
	return float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))


static func declared_msaa() -> int:
	return int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_DISABLED))


## Puts the window at the chosen size, centred in the usable area of its screen.
##
## Leaving fullscreen is **animated** on macOS, and the window takes back on the way the
## **position** it had before entering it: placed at once, it ends up off-centre. It is
## therefore placed again once the animation is over.
func _size_window(window: Window, leaving_another_mode: bool) -> void:
	var metrics := screen_metrics()
	var size := nearest_size(window_sizes(metrics[0], metrics[1]), window_size)
	_place(size)
	if leaving_another_mode and window.is_inside_tree():
		var again := func() -> void:
			if window_mode == WindowMode.WINDOWED:
				_place(size)
		window.get_tree().create_timer(0.8, true).timeout.connect(again)


static func _place(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	if screen >= 0:
		var usable := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func load_from_disk() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	_quiet = true
	var mode: Variant = file.get_value(_SECTION, "mode", "")
	if mode is String and _MODE_NAMES.values().has(mode):
		window_mode = _MODE_NAMES.find_key(mode)
	var width: Variant = file.get_value(_SECTION, "width", window_size.x)
	var height: Variant = file.get_value(_SECTION, "height", window_size.y)
	if width is int and height is int:
		window_size = Vector2i(width, height)
	vsync = _read_bool(file, "vsync", vsync)
	var fps: Variant = file.get_value(_SECTION, "max_fps", max_fps)
	if fps is int:
		max_fps = fps
	var scale: Variant = file.get_value(_SECTION, "render_scale", render_scale)
	if scale is float or scale is int:
		render_scale = float(scale)
	var samples: Variant = file.get_value(_SECTION, "msaa", msaa)
	if samples is int:
		msaa = samples
	var interface: Variant = file.get_value(_SECTION, "ui_scale", ui_scale)
	if interface is float or interface is int:
		ui_scale = float(interface)
	_quiet = false
	emit_changed()
	return true


func save() -> bool:
	var file := ConfigFile.new()
	file.set_value(_SECTION, "mode", _MODE_NAMES[window_mode])
	file.set_value(_SECTION, "width", window_size.x)
	file.set_value(_SECTION, "height", window_size.y)
	file.set_value(_SECTION, "vsync", vsync)
	file.set_value(_SECTION, "max_fps", max_fps)
	file.set_value(_SECTION, "render_scale", render_scale)
	file.set_value(_SECTION, "msaa", msaa)
	file.set_value(_SECTION, "ui_scale", ui_scale)
	var error := file.save(path)
	if error != OK:
		push_warning("TGC Game Menu: display settings not saved (%d): %s" % [error, path])
	return error == OK


func restore_defaults() -> void:
	var was_quiet := _quiet
	_quiet = true
	window_mode = declared_mode()
	window_size = declared_size()
	vsync = declared_vsync()
	max_fps = declared_max_fps()
	render_scale = declared_render_scale()
	msaa = declared_msaa()
	ui_scale = 1.0
	_quiet = was_quiet
	_notify()


## The frame rate a refused value falls back on: unlimited if it is offered, else the
## first value offered.
func _fallback_fps() -> int:
	return 0 if fps_limits.has(0) else fps_limits[0]


func _fallback_ui_scale() -> float:
	return 1.0 if ui_scales.has(1.0) else ui_scales[0]


## Notifies, except while reading the file back: a file of eight settings must not have the
## window re-applied eight times.
func _notify() -> void:
	if not _quiet:
		emit_changed()


func _read_bool(file: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = file.get_value(_SECTION, key, fallback)
	return value if value is bool else fallback
