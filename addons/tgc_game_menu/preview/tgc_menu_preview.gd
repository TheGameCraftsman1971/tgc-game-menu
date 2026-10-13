@tool
@icon("res://addons/tgc_game_menu/icon.svg")
class_name TgcMenuPreview
extends SubViewportContainer

## The menu, drawn in the editor as the game will draw it: with a [TgcMenuConfig], a theme,
## a screen and a language chosen in the Inspector. What it is for: editing a theme, or a
## config, and seeing the result at once.
##
## Add one to a scene of your own (or open `tgc_menu_preview.tscn`), give it your config, and
## pick the screen: the main menu, the pause menu, Settings, one page, Save, Load, a
## confirmation, a notification. A change of the config or of the screen redraws it; a change
## of the theme shows at once, the menu using the very resource you edit.
##
## **It touches nothing.** The menu is driven by a preview session
## ([method TgcMenuSession.setup_preview]): settings at their defaults and no file read nor
## written, controls read from the project settings and no action created, saves that do not
## exist ([TgcPreviewSaves]), and a language of its own — a translation domain its nodes
## inherit — that changes neither the editor's nor the game's.
##
## The menu is drawn at the project's resolution inside a viewport of its own, and fitted to
## the node's size: give the node another size to see the menu at another resolution.
##
## The page and the language are picked from lists: the pages of the config drawn, the
## languages the add-on or the game speaks. The page shows only for [constant Screen.PAGE].

enum Screen {
	MAIN_MENU,
	PAUSE_MENU,
	SETTINGS,
	PAGE,
	SAVE,
	LOAD,
	CONFIRMATION,
	NOTIFICATION,
}

## The translation domain of the preview's nodes.
const DOMAIN := &"tgc_menu_preview"
## How often the config is compared with the one drawn, in the editor, in seconds.
const POLL_SECONDS := 0.5

## The config to preview. Empty: the add-on's `default_menu_config.tres`.
@export var config: TgcMenuConfig:
	set(value):
		config = value
		_queue_rebuild()
## A theme to try in place of the config's.
@export var theme_override: Theme:
	set(value):
		theme_override = value
		_queue_rebuild()
@export var screen: Screen = Screen.MAIN_MENU:
	set(value):
		if value != screen:
			screen = value
			notify_property_list_changed()
			_queue_rebuild()
## The page shown by [constant Screen.PAGE]: `general`, `display`, `sound`, `controls`, or the
## id of one of the game's pages.
@export var page: StringName = &"display":
	set(value):
		if value != page:
			page = value
			_queue_rebuild()
## The language of the preview: a locale code the add-on or the game speaks.
@export var locale := "en":
	set(value):
		if value != locale:
			locale = value
			_queue_rebuild()
## How many regular saves seem to exist, on the Save and Load pages.
@export_range(0, 99) var filled_slots := 2:
	set(value):
		filled_slots = value
		_queue_rebuild()
## What lies behind the menu: a colour, or a picture of the game.
@export var background_color := Color(0.11, 0.14, 0.2):
	set(value):
		background_color = value
		_show_background()
@export var background: Texture2D:
	set(value):
		background = value
		_show_background()
## Redraws everything: what a change inside a sub-resource the preview did not see needs.
@export_tool_button("Redraw", "Reload") var redraw_action := rebuild

var _viewport: SubViewport
var _colour: ColorRect
var _picture: TextureRect
var _session: TgcMenuSession
var _signature := 0
var _since_poll := 0.0
var _queued := false
## What the Inspector's lists offer, as drawn last.
var _pages := PackedStringArray()
var _locales := PackedStringArray()


func _ready() -> void:
	stretch = true
	if size == Vector2.ZERO:
		size = _project_size()
	_viewport = SubViewport.new()
	_viewport.set_translation_domain(DOMAIN)
	add_child(_viewport, false, Node.INTERNAL_MODE_BACK)
	_colour = ColorRect.new()
	_colour.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_colour)
	_picture = TextureRect.new()
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_viewport.add_child(_picture)
	_show_background()
	rebuild()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_since_poll += delta
	if _since_poll < POLL_SECONDS:
		return
	_since_poll = 0.0
	# A config's fields do not announce their changes: they are compared with the drawing's.
	if signature_of(_effective_config()) != _signature:
		rebuild()


## The session behind the preview's menu. For benches.
func session() -> TgcMenuSession:
	return _session


## Draws the menu again, from the config, the screen and the language.
func rebuild() -> void:
	_queued = false
	if not is_node_ready():
		return
	if _session != null:
		_viewport.remove_child(_session)
		_session.queue_free()
	var shown := _effective_config()
	_signature = signature_of(shown)
	if theme_override != null:
		shown = shown.duplicate() as TgcMenuConfig
		shown.theme = theme_override
	# A control taking the focus in a viewport takes it from the whole window: a page giving
	# its first control the focus would take it from the editor's field being typed in.
	var focused := get_window().gui_get_focus_owner()
	TgcI18n.open_preview_domain(DOMAIN, locale)
	TgcI18n.use_domain(DOMAIN)
	_session = TgcMenuSession.new()
	_session.setup_preview(shown, screen != Screen.MAIN_MENU, TgcPreviewSaves.new(filled_slots))
	_viewport.add_child(_session)
	_show_screen(_session.menu())
	TgcI18n.use_domain(&"")
	if focused != null and is_instance_valid(focused) and not focused.has_focus():
		focused.grab_focus()
	_offer(PackedStringArray(_session.menu().page_ids()), locales_of(shown))


## The languages a preview of `menu_config` can speak: the add-on's, and the game's (those the
## config names, else those of its catalogues). Sorted.
static func locales_of(menu_config: TgcMenuConfig) -> PackedStringArray:
	var found := PackedStringArray(TgcI18n.LOCALES)
	var game := menu_config.languages if not menu_config.languages.is_empty() else TgcI18n.game_locales()
	for code in game:
		if not found.has(code):
			found.append(code)
	found.sort()
	return found


## The page's and the language's lists, in the Inspector.
func _validate_property(property: Dictionary) -> void:
	match property.name:
		"page":
			if screen != Screen.PAGE:
				property.usage = PROPERTY_USAGE_NO_EDITOR
			else:
				property.hint = PROPERTY_HINT_ENUM
				property.hint_string = ",".join(_with_current(_pages, page))
		"locale":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(_with_current(_locales, locale))


## Renews the Inspector's lists, only when they change: renewing them redraws the Inspector.
func _offer(pages: PackedStringArray, locales: PackedStringArray) -> void:
	if pages != _pages or locales != _locales:
		_pages = pages
		_locales = locales
		notify_property_list_changed()


## A list, and the value chosen if it is not in it (a page the config no longer has), so the
## Inspector still shows it.
static func _with_current(choices: PackedStringArray, current: String) -> PackedStringArray:
	if current == "" or choices.has(current):
		return choices
	var all := choices.duplicate()
	all.append(current)
	return all


## A number that changes when anything stored in `resource` changes, its sub-resources
## included (themes and scenes by identity: their own changes show by themselves).
static func signature_of(resource: Resource) -> int:
	var values := []
	_collect(resource, values, 0)
	return hash(values)


func _show_screen(menu: TgcGameMenu) -> void:
	menu.open(screen != Screen.MAIN_MENU)
	match screen:
		Screen.SETTINGS:
			menu.show_page(TgcGameMenu.SETTINGS)
		Screen.PAGE:
			if menu.page_ids().has(page):
				menu.show_page(page)
			else:
				push_warning("TGC Game Menu preview: no page \"%s\" in this config." % page)
		Screen.SAVE, Screen.LOAD:
			var id := TgcGameMenu.SAVE if screen == Screen.SAVE else TgcGameMenu.LOAD
			if menu.page(id) != null:
				menu.show_page(id)
			else:
				push_warning("TGC Game Menu preview: this config does not enable saves.")
		Screen.CONFIRMATION:
			menu.confirm("TGC_CONFIRM_MAIN_MENU", "TGC_MAIN_MENU", "TGC_CONFIRM_LOSS", Callable())
		Screen.NOTIFICATION:
			_session.toast().show_message(TgcI18n.translate("TGC_QUICK_SAVED"), true)


func _effective_config() -> TgcMenuConfig:
	return config if config != null else load(TgcMenuSession.DEFAULT_CONFIG) as TgcMenuConfig


func _queue_rebuild() -> void:
	if is_node_ready() and not _queued:
		_queued = true
		rebuild.call_deferred()


func _show_background() -> void:
	if _colour == null:
		return
	_colour.color = background_color
	_picture.texture = background


static func _project_size() -> Vector2:
	return Vector2(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))


static func _collect(value: Variant, into: Array, depth: int) -> void:
	if value is Theme or value is PackedScene or value is Texture2D:
		into.append((value as Object).get_instance_id())
	elif value is Resource and depth < 4:
		for property in (value as Resource).get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and not String(property.name).begins_with("resource_"):
				_collect((value as Resource).get(property.name), into, depth + 1)
	elif value is Array:
		for item: Variant in value:
			_collect(item, into, depth)
	elif value is Object:
		into.append((value as Object).get_instance_id())
	else:
		into.append(value)
