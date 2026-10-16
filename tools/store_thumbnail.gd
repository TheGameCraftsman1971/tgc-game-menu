extends Node

## The Asset Store's thumbnail, 16:9 as the store requires: the add-on's icon, its name, what
## it does, and the real menu beside them, drawn by a [TgcMenuPreview] on the demo's config.
## With `-- title`, the store's second picture instead: the icon and the name alone, centred.
##
##   godot --path . res://tools/store_thumbnail.tscn
##   godot --path . res://tools/store_thumbnail.tscn -- title
##
## It opens a window (drawing needs the graphics card) and writes
## `captures/store_thumbnail.png` (or `captures/store_title.png`), 1920 × 1080 whatever the
## screen's density: the picture is drawn in a viewport of that size. Copy it into `screenshots/`.

const SIZE := Vector2i(1920, 1080)
const ICON := "res://screenshots/store_icon.svg"
const THEME := preload("res://addons/tgc_game_menu/default_theme.tres")
const DEMO_CONFIG := preload("res://demo/demo_menu_config.tres")
const BACKGROUND := Color(0.06, 0.08, 0.13)
const TEXT := Color(0.86, 0.9, 1.0)
const MUTED := Color(0.62, 0.69, 0.84)
const ACCENT := Color(0.36, 0.45, 0.68)


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root := Control.new()
	root.theme = THEME
	root.size = SIZE
	viewport.add_child(root)

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.size = SIZE
	root.add_child(background)

	var file := "store_thumbnail"
	if "title" in OS.get_cmdline_user_args():
		file = "store_title"
		_draw_title(root)
	else:
		_draw_thumbnail(root)

	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures")
	viewport.get_texture().get_image().save_png("res://captures/%s.png" % file)
	print("saved res://captures/%s.png" % file)
	get_tree().quit()


func _draw_thumbnail(root: Control) -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(100, 0)
	column.size = Vector2(740, SIZE.y)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	root.add_child(column)
	var icon := TextureRect.new()
	icon.texture = _svg(ICON, 1.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(icon)
	column.add_child(_label("TGC Game Menu", 80, TEXT))
	column.add_child(_label("The main menu, pause menu and settings\nyour Godot 4.7 game needs.", 32, MUTED))
	var features := _label("Display · Sound · Remappable controls\nSaves and quick saves · Live editor preview", 28, TEXT)
	features.add_theme_constant_override("line_spacing", 10)
	column.add_child(features)
	column.add_child(_label("English · Français · Deutsch · Español", 26, MUTED))

	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT
	style.set_corner_radius_all(22)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(900, 270)
	frame.size = Vector2(920, 540)
	root.add_child(frame)
	var preview := TgcMenuPreview.new()
	preview.config = DEMO_CONFIG
	preview.locale = "en"
	preview.screen = TgcMenuPreview.Screen.SETTINGS
	preview.background_color = Color(0.11, 0.14, 0.2)
	preview.position = Vector2(10, 10)
	preview.size = Vector2(900, 520)
	frame.add_child(preview)


func _draw_title(root: Control) -> void:
	var column := VBoxContainer.new()
	column.size = SIZE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 56)
	root.add_child(column)
	var icon := TextureRect.new()
	icon.texture = _svg(ICON, 2.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var name_label := _label("TGC Game Menu", 120, TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## An SVG read as an image: `screenshots/` is not imported (`.gdignore`).
static func _svg(path: String, scale: float) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string(path), scale)
	return ImageTexture.create_from_image(image)
