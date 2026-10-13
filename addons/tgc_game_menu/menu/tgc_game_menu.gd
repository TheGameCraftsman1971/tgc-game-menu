class_name TgcGameMenu
extends CanvasLayer

## The game's menu: the **main** menu at start, the **pause** menu during a game. One menu,
## two faces.
##
## At start, before any game, it is titled with the game's name and offers "Play"; "Resume"
## and "Main menu" are absent, for want of a game. In pause, it is titled "Paused" and
## offers "Resume", "New game" and "Main menu". "Settings" opens the same sub-menu on both
## sides. "Quit" disappears in a browser, where it would close nothing.
##
## It lies over the frozen game: the tree is paused, the scene stays visible under a veil,
## and this layer alone goes on living ([code]process_mode = ALWAYS[/code], in the scene). It
## knows nothing of the game. It **asks** (play, resume, quit) and [TgcMenuSession] decides.
##
## ## Three levels
##
## The root, the **Settings** sub-menu ([constant SETTINGS]), and the pages below it. Its
## pages come from [method TgcMenuConfig.page_scenes]: each one is a scene whose root is a
## [TgcMenuPage], and each gets a button in the sub-menu, in the same order. Without a single
## page to show, "Settings" is hidden. `back()` goes up one level — from a page to the
## sub-menu, from the sub-menu to the root — and only returns false at the root, where going
## up means resuming the game. Going up gives the focus back to the button one came from, so
## that a gamepad never loses its place.
##
## ## Confirmations
##
## "New game", "Main menu" and "Quit" abandon the game in progress. When there is one, and
## [method TgcMenuSession.needs_confirmation] says its progress is at risk, they first open a
## **modal** in place of the root — hidden meanwhile, since a theme's panels may let it show
## through —: the question, what will be lost, "Cancel" and the action itself.
## The focus starts on "Cancel" — a press too many on a gamepad must not cost a game — and
## cannot leave the modal; the pointer cannot reach what lies under it. "Cancel", Esc, B or
## the pause gesture close it ([method back]) and give the focus back to the button that
## opened it. Without a game, the three buttons act at once: there is nothing to lose.
##
## A game that wants another look duplicates `tgc_game_menu.tscn`, keeps its unique names
## (`%Title`, `%Resume`, `%Play`, `%OpenSettings`, `%MainMenu`, `%Quit`, `%Settings`,
## `%PageButtons`, `%SettingsBack`, `%Pages`, `%Confirm`, `%Question`, `%Cancel`,
## `%ConfirmAction`…) and names the copy in
## [member TgcMenuConfig.menu_scene].

signal resume_requested
signal play_requested
signal main_menu_requested
signal quit_requested

## The menu's root, as [method current_page] and [method show_page] name it.
const ROOT := &""
## The Settings sub-menu, which lists the pages. A page cannot take this id.
const SETTINGS := &"settings"

@onready var _frame: Control = %Frame
@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _play: Button = %Play
@onready var _open_settings: Button = %OpenSettings
@onready var _settings: Control = %Settings
@onready var _page_buttons: Container = %PageButtons
@onready var _main_menu: Button = %MainMenu
@onready var _quit: Button = %Quit
@onready var _pages_holder: Control = %Pages
@onready var _confirm_layer: Control = %Confirm
@onready var _question: Label = %Question
@onready var _cancel: Button = %Cancel
@onready var _confirm_action: Button = %ConfirmAction

var _session: TgcMenuSession
var _home_title := ""
var _pages: Dictionary[StringName, TgcMenuPage] = {}
var _page_openers: Dictionary[StringName, Button] = {}
var _page := ROOT
## What the open confirmation will do, and the button that asked for it.
var _pending := Signal()
var _asker: Button


## Called by the session **before** the menu enters the tree.
func setup(session: TgcMenuSession) -> void:
	_session = session


func _ready() -> void:
	visible = false
	_resume.pressed.connect(resume_requested.emit)
	_play.pressed.connect(_ask.bind(play_requested, "TGC_CONFIRM_NEW_GAME", "TGC_NEW_GAME", _play))
	_main_menu.pressed.connect(_ask.bind(main_menu_requested, "TGC_CONFIRM_MAIN_MENU", "TGC_MAIN_MENU", _main_menu))
	_quit.pressed.connect(_ask.bind(quit_requested, "TGC_CONFIRM_QUIT", "TGC_QUIT", _quit))
	_cancel.pressed.connect(_dismiss)
	_confirm_action.pressed.connect(_accept)
	_trap_focus()
	_open_settings.pressed.connect(show_page.bind(SETTINGS))
	(%SettingsBack as Button).pressed.connect(show_page.bind(ROOT))
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
	_open_settings.visible = not _pages.is_empty()


## `in_game`: a game waits behind the menu (pause menu). Otherwise, it is the main menu.
func open(in_game: bool) -> void:
	_resume.visible = in_game
	_main_menu.visible = in_game
	_title.text = "TGC_PAUSE" if in_game else _home_title
	_play.text = "TGC_NEW_GAME" if in_game else "TGC_PLAY"
	visible = true
	_hide_confirmation()
	show_page(ROOT)


func close() -> void:
	if _pages.has(_page):
		_pages[_page].leave()
	# The menu always reopens at its root, with the focus on its first button.
	_page = ROOT
	_hide_confirmation()
	visible = false


func is_open() -> bool:
	return visible


## True while a confirmation waits for an answer.
func is_confirming() -> bool:
	return _confirm_layer.visible


## The page shown, or [constant ROOT], or [constant SETTINGS].
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


## Goes up one level: from a page to the Settings sub-menu, from the sub-menu to the root.
## False at the root: there is nothing left to go up to, and it is up to the session to
## resume the game.
func back() -> bool:
	if is_confirming():
		_dismiss()
		return true
	if _page == ROOT:
		return false
	show_page(SETTINGS if _pages.has(_page) else ROOT)
	return true


func show_page(target: StringName) -> void:
	if target != ROOT and target != SETTINGS and not _pages.has(target):
		push_warning("TGC Game Menu: no page \"%s\"." % target)
		return
	var previous := _page
	if previous != target and _pages.has(previous):
		_pages[previous].leave()
	_page = target
	_root.visible = target == ROOT
	_settings.visible = target == SETTINGS
	for id: StringName in _pages:
		_pages[id].visible = id == target
	match target:
		ROOT:
			if previous == SETTINGS:
				_open_settings.grab_focus()
			else:
				(_resume if _resume.visible else _play).grab_focus()
		SETTINGS:
			if _page_openers.has(previous):
				_page_openers[previous].grab_focus()
			elif _page_buttons.get_child_count() > 0:
				(_page_buttons.get_child(0) as Button).grab_focus()
		_:
			_pages[target].focus_first()


## Does what a button asks, or first asks the player when it would lose the game in
## progress.
func _ask(action: Signal, question: String, label: String, asker: Button) -> void:
	if _session == null or not _session.needs_confirmation():
		action.emit()
		return
	_pending = action
	_asker = asker
	_question.text = question
	_confirm_action.text = label
	_root.visible = false
	_confirm_layer.visible = true
	_cancel.grab_focus()


func _accept() -> void:
	var action := _pending
	_hide_confirmation()
	action.emit()


## Gives up, and gives the focus back to the button that asked.
func _dismiss() -> void:
	var asker := _asker
	_hide_confirmation()
	if asker != null and asker.is_visible_in_tree():
		asker.grab_focus()


func _hide_confirmation() -> void:
	if _confirm_layer.visible:
		_root.visible = _page == ROOT
	_confirm_layer.visible = false
	_pending = Signal()
	_asker = null


## The two buttons of the modal lead only to each other, whatever the direction: the
## keyboard and the gamepad cannot wander to the menu underneath.
func _trap_focus() -> void:
	for pair: Array in [[_cancel, _confirm_action], [_confirm_action, _cancel]]:
		var button: Button = pair[0]
		var other := button.get_path_to(pair[1] as Button)
		var itself := button.get_path_to(button)
		button.focus_neighbor_left = other
		button.focus_neighbor_right = other
		button.focus_neighbor_top = itself
		button.focus_neighbor_bottom = itself
		button.focus_next = other
		button.focus_previous = other


func _add_page(scene: PackedScene) -> void:
	var node := scene.instantiate()
	var added := node as TgcMenuPage
	if added == null:
		push_warning("TGC Game Menu: %s is not a TgcMenuPage, and is left out." % scene.resource_path)
		node.free()
		return
	if added.page_id == ROOT or added.page_id == SETTINGS or _pages.has(added.page_id):
		push_warning("TGC Game Menu: the page id \"%s\" of %s is empty, reserved or taken." % [added.page_id, scene.resource_path])
		added.free()
		return
	added.setup(_session)
	if not added.is_relevant():
		added.free()
		return
	added.visible = false
	_pages_holder.add_child(added)
	_pages[added.page_id] = added
	added.closed.connect(show_page.bind(SETTINGS))
	var button := Button.new()
	button.name = "Open" + String(added.page_id).to_pascal_case()
	# A key: the button translates it, and follows the language.
	button.text = added.title
	button.pressed.connect(show_page.bind(added.page_id))
	_page_buttons.add_child(button)
	_page_openers[added.page_id] = button
