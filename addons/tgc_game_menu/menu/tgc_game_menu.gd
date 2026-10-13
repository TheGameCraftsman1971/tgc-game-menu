class_name TgcGameMenu
extends CanvasLayer

## The game's menu: the **main** menu at start, the **pause** menu during a game. One menu,
## two faces.
##
## At start, before any game, it is titled with the game's name and offers "Play"; "Resume"
## and "Main menu" are absent, for want of a game. In pause, it is titled "Paused" and
## offers "Resume", "New game" and "Main menu". The settings pages are the same on both
## sides. "Quit" disappears in a browser, where it would close nothing.
##
## It lies over the frozen game: the tree is paused, the scene stays visible under a veil,
## and this layer alone goes on living ([code]process_mode = ALWAYS[/code], in the scene). It
## knows nothing of the game. It **asks** (play, resume, quit) and [TgcMenuSession] decides.
##
## Its pages come from [method TgcMenuConfig.page_scenes]: each one is a scene whose root is
## a [TgcMenuPage], and each gets a button at the root, in the same order. `back()` goes up
## one page, and only returns false at the root, where going up means resuming the game.
##
## A game that wants another look duplicates `tgc_game_menu.tscn`, keeps its unique names
## (`%Title`, `%Resume`, `%Play`, `%PageButtons`, `%MainMenu`, `%Quit`, `%Pages`…) and
## names the copy in [member TgcMenuConfig.menu_scene].

signal resume_requested
signal play_requested
signal main_menu_requested
signal quit_requested

## The menu's root, as [method page] and [method show_page] name it.
const ROOT := &""

@onready var _frame: Control = %Frame
@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _play: Button = %Play
@onready var _page_buttons: Container = %PageButtons
@onready var _main_menu: Button = %MainMenu
@onready var _quit: Button = %Quit
@onready var _pages_holder: Control = %Pages

var _session: TgcMenuSession
var _home_title := ""
var _pages: Dictionary[StringName, TgcMenuPage] = {}
var _page := ROOT


## Called by the session **before** the menu enters the tree.
func setup(session: TgcMenuSession) -> void:
	_session = session


func _ready() -> void:
	visible = false
	_resume.pressed.connect(resume_requested.emit)
	_play.pressed.connect(play_requested.emit)
	_main_menu.pressed.connect(main_menu_requested.emit)
	_quit.pressed.connect(quit_requested.emit)
	if _session == null:
		push_warning("TGC Game Menu: the menu has no session. Let a TgcMenuSession create it.")
		return
	var config := _session.config
	if config.theme != null:
		_frame.theme = config.theme
	# A key of the game's catalogue, or the game's name: the Label translates the first, and
	# shows the second as it is.
	_home_title = config.title if config.title != "" \
			else String(ProjectSettings.get_setting("application/config/name", ""))
	_quit.visible = not (config.hide_quit_on_web and OS.has_feature("web"))
	for scene in config.page_scenes():
		_add_page(scene)


## `in_game`: a game waits behind the menu (pause menu). Otherwise, it is the main menu.
func open(in_game: bool) -> void:
	_resume.visible = in_game
	_main_menu.visible = in_game
	_title.text = "TGC_PAUSE" if in_game else _home_title
	_play.text = "TGC_NEW_GAME" if in_game else "TGC_PLAY"
	visible = true
	show_page(ROOT)


func close() -> void:
	if _pages.has(_page):
		_pages[_page].leave()
	visible = false


func is_open() -> bool:
	return visible


## The page shown, or [constant ROOT].
func current_page() -> StringName:
	return _page


## The page named `id`, or null.
func page(id: StringName) -> TgcMenuPage:
	return _pages[id] if _pages.has(id) else null


## The pages, in the order of their buttons.
func page_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_pages.keys())
	return ids


## Goes up one page. False at the root: there is nothing left to go up to, and it is up to
## the session to resume the game.
func back() -> bool:
	if _page == ROOT:
		return false
	show_page(ROOT)
	return true


func show_page(target: StringName) -> void:
	if target != ROOT and not _pages.has(target):
		push_warning("TGC Game Menu: no page \"%s\"." % target)
		return
	if _page != target and _pages.has(_page):
		_pages[_page].leave()
	_page = target
	_root.visible = target == ROOT
	for id: StringName in _pages:
		_pages[id].visible = id == target
	if target == ROOT:
		(_resume if _resume.visible else _play).grab_focus()
	else:
		_pages[target].focus_first()


func _add_page(scene: PackedScene) -> void:
	var node := scene.instantiate()
	var added := node as TgcMenuPage
	if added == null:
		push_warning("TGC Game Menu: %s is not a TgcMenuPage, and is left out." % scene.resource_path)
		node.free()
		return
	if added.page_id == ROOT or _pages.has(added.page_id):
		push_warning("TGC Game Menu: the page id \"%s\" of %s is empty or taken." % [added.page_id, scene.resource_path])
		added.free()
		return
	added.setup(_session)
	if not added.is_relevant():
		added.free()
		return
	added.visible = false
	_pages_holder.add_child(added)
	_pages[added.page_id] = added
	added.closed.connect(show_page.bind(ROOT))
	var button := Button.new()
	button.name = "Open" + String(added.page_id).to_pascal_case()
	# A key: the button translates it, and follows the language.
	button.text = added.title
	button.pressed.connect(show_page.bind(added.page_id))
	_page_buttons.add_child(button)
