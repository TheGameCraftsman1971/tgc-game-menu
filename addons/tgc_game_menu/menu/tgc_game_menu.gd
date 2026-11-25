@tool
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
## ## Save and Load
##
## With saves on ([method TgcMenuSession.saves_enabled]), the root also offers "Save" (during
## a game, disabled while the game cannot be saved) and "Load" (disabled while there is no
## save). They open two pages of the root, not of Settings: `tgc_save_page.tscn` and
## `tgc_load_page.tscn` ([TgcSavesPage]). Their buttons are refreshed each time the root is
## shown.
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
## opened it. [method confirm] opens the same modal for a page (overwrite a save, delete
## one). Without a game, "Play" acts at once: there is nothing to lose. "Quit" still
## asks ([member TgcMenuConfig.confirm_quit]), without the line about what would be lost.
##
## ## Dropping down
##
## With [member TgcMenuConfig.presentation] set to `DROP_DOWN`, the menu hangs under the
## button the game names ([method drop_from]): it unrolls from it when it opens and rolls
## back into it when it closes, over a lighter veil; a click on the veil asks to resume.
## Each level takes the place of the one before, under the button — the root, the Settings
## sub-menu, a page (its first container) —, and **morphs** from its shape: going down or
## up, the new panel is born at the size of the old one and grows or shrinks to its own.
##
## A game that wants another look duplicates `tgc_game_menu.tscn`, keeps its unique names
## (`%Title`, `%Resume`, `%Play`, `%OpenSettings`, `%MainMenu`, `%Quit`, `%Settings`,
## `%PageButtons`, `%SettingsBack`, `%Pages`, `%Confirm`, `%Question`, `%Detail`, `%Cancel`,
## `%ConfirmAction`, `%OpenSave`, `%OpenLoad`…) and names the copy in
## [member TgcMenuConfig.menu_scene].

signal resume_requested
signal play_requested
signal main_menu_requested
signal quit_requested

## The gap between a drop-down menu and the button it hangs from.
const DROP_GAP := 10.0
## The share of the config's veil a drop-down menu lays ([member TgcMenuConfig.veil_opacity]).
const DROP_VEIL_SHARE := 0.5

## The menu's root, as [method current_page] and [method show_page] name it.
const ROOT := &""
## The Settings sub-menu, which lists the pages. A page cannot take this id.
const SETTINGS := &"settings"
## The pages of the root, built when the config enables saves. Reserved ids too.
const SAVE := &"save"
const LOAD := &"load"
const _SAVE_PAGE := "res://addons/tgc_game_menu/menu/tgc_save_page.tscn"
const _LOAD_PAGE := "res://addons/tgc_game_menu/menu/tgc_load_page.tscn"

@onready var _frame: Control = %Frame
@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _play: Button = %Play
@onready var _open_save: Button = %OpenSave
@onready var _open_load: Button = %OpenLoad
@onready var _open_settings: Button = %OpenSettings
@onready var _settings: Control = %Settings
@onready var _page_buttons: Container = %PageButtons
@onready var _main_menu: Button = %MainMenu
@onready var _quit: Button = %Quit
@onready var _pages_holder: Control = %Pages
@onready var _confirm_layer: Control = %Confirm
@onready var _question: Label = %Question
@onready var _detail: Label = %Detail
@onready var _cancel: Button = %Cancel
@onready var _confirm_action: Button = %ConfirmAction

var _session: TgcMenuSession
var _home_title := ""
var _pages: Dictionary[StringName, TgcMenuPage] = {}
var _page_openers: Dictionary[StringName, Button] = {}
## Pages whose script does not run in the editor (not `@tool`): in a preview they are shown
## as their scene draws them, and none of their code is called.
var _inert_pages: Array[StringName] = []
## The pages opened from the root rather than from Settings.
var _root_pages: Array[StringName] = []
var _page := ROOT
## What the open confirmation will do, and the button that asked for it.
var _pending := Callable()
var _on_cancel := Callable()
## The screen rectangle of the button a drop-down menu hangs from.
var _origin := Rect2()
var _tween: Tween
## True while a drop-down menu rolls back into its button: closed, but still drawn.
var _closing := false
var _asker: Control


## Called by the session **before** the menu enters the tree.
func setup(session: TgcMenuSession) -> void:
	_session = session


func _ready() -> void:
	# Opened as a scene in the editor, the menu stays as it is drawn: hiding it here would end
	# up saved in the scene. Only a session — a preview's, in the editor — brings it to life.
	if Engine.is_editor_hint() and _session == null:
		return
	visible = false
	_resume.pressed.connect(resume_requested.emit)
	_play.pressed.connect(_ask.bind(play_requested, "TGC_CONFIRM_NEW_GAME", "TGC_NEW_GAME", _play))
	_main_menu.pressed.connect(_ask.bind(main_menu_requested, "TGC_CONFIRM_MAIN_MENU", "TGC_MAIN_MENU", _main_menu))
	_quit.pressed.connect(_ask_quit)
	_cancel.pressed.connect(_dismiss)
	_confirm_action.pressed.connect(_accept)
	_trap_focus()
	_open_settings.pressed.connect(show_page.bind(SETTINGS))
	_open_save.pressed.connect(show_page.bind(SAVE))
	_open_load.pressed.connect(show_page.bind(LOAD))
	_open_save.visible = false
	_open_load.visible = false
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
	_quit.text = "TGC_QUIT_APP" if config.wording == TgcMenuConfig.Wording.APPLICATION else "TGC_QUIT"
	for scene in config.page_scenes():
		_add_page(scene)
	_open_settings.visible = not _pages.is_empty()
	var veil := get_node_or_null("Frame/Backdrop") as ColorRect
	if veil != null:
		veil.color.a = config.veil_opacity * (DROP_VEIL_SHARE if _drops() else 1.0)
		if _drops():
			veil.gui_input.connect(_on_veil_input)
	if config.enable_saves:
		_add_page(load(_SAVE_PAGE) as PackedScene, _open_save)
		_add_page(load(_LOAD_PAGE) as PackedScene, _open_load)
	if not _drops() and (config.horizontal_placement != TgcMenuConfig.HorizontalPlacement.CENTRE
			or config.vertical_placement != TgcMenuConfig.VerticalPlacement.CENTRE):
		for holder in _hangers():
			_place(holder, config.horizontal_placement, config.vertical_placement, config.screen_margin)


## `in_game`: a game waits behind the menu (pause menu). Otherwise, it is the main menu.
func open(in_game: bool) -> void:
	var config := _session.config if _session != null else null
	_resume.visible = in_game
	_main_menu.visible = in_game and (config == null or config.show_main_menu_button)
	_play.visible = not in_game or config == null or config.show_new_game
	var pause_title := config.pause_title if config != null and config.pause_title != "" else "TGC_PAUSE"
	_title.text = pause_title if in_game else _home_title
	_play.text = "TGC_NEW_GAME" if in_game else "TGC_PLAY"
	_stop_rolling()
	visible = true
	_hide_confirmation()
	show_page(ROOT)
	if _drops():
		_roll(true)


func close() -> void:
	if _pages.has(_page) and not _inert_pages.has(_page):
		_pages[_page].leave()
	# The menu always reopens at its root, with the focus on its first button; and nothing of
	# the page left must show if the menu is shown again for a lone question.
	_page = ROOT
	_hide_confirmation()
	_root.visible = true
	_settings.visible = false
	for id: StringName in _pages:
		_pages[id].visible = false
	if _drops() and visible and _rolls():
		_closing = true
		_roll(false)
	else:
		visible = false


## True while the menu shows — not while a drop-down menu rolls back into its button.
func is_open() -> bool:
	return visible and not _closing


## Names the button a drop-down menu hangs from, by its rectangle on screen (in the
## coordinates of the game's canvas, as [method Control.get_global_rect] gives them). Called
## before each opening if the button can move.
func drop_from(rect: Rect2) -> void:
	_origin = rect


## True while a confirmation waits for an answer.
func is_confirming() -> bool:
	return _confirm_layer.visible


## The page shown, or [constant ROOT], or [constant SETTINGS].
func current_page() -> StringName:
	return _page


## The page named `id`, or null.
func page(id: StringName) -> TgcMenuPage:
	return _pages[id] if _pages.has(id) else null


## The pages of the Settings sub-menu, in the order of their buttons.
func page_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _pages:
		if not _root_pages.has(id):
			ids.append(id)
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
	show_page(SETTINGS if _pages.has(_page) and not _root_pages.has(_page) else ROOT)
	return true


func show_page(target: StringName) -> void:
	if target != ROOT and target != SETTINGS and not _pages.has(target):
		push_warning("TGC Game Menu: no page \"%s\"." % target)
		return
	var previous := _page
	if previous != target and _pages.has(previous):
		if not _inert_pages.has(previous):
			_pages[previous].leave()
	_page = target
	_root.visible = target == ROOT
	_settings.visible = target == SETTINGS
	for id: StringName in _pages:
		_pages[id].visible = id == target
	if _drops():
		var arriving := _hanger(target)
		_hang(arriving)
		if previous != target and visible and not _closing and _rolls():
			_morph(_hanger(previous), arriving)
	match target:
		ROOT:
			refresh_root()
			if _root_pages.has(previous) and _page_openers[previous].visible:
				_focus(_page_openers[previous])
			elif previous == SETTINGS:
				_focus(_open_settings)
			else:
				_focus(_resume if _resume.visible else _play)
		SETTINGS:
			if _page_openers.has(previous):
				_focus(_page_openers[previous])
			elif _page_buttons.get_child_count() > 0:
				_focus(_page_buttons.get_child(0) as Button)
		_:
			if not _inert_pages.has(target):
				_pages[target].focus_first()


## Opens the modal: `question` and `detail` (keys; an empty detail hides its line), "Cancel"
## and a button saying `label`, which calls `on_accept`. "Cancel", Esc or B give the focus
## back to `asker` (by default, whatever had it) and call `on_cancel`. What a page calls before
## an action that cannot be undone, and the session before a quick load: the menu shows
## itself for it if it was closed, with nothing but the modal.
func confirm(question: String, label: String, detail: String, on_accept: Callable,
		asker: Control = null, on_cancel := Callable()) -> void:
	_pending = on_accept
	_on_cancel = on_cancel
	_asker = asker if asker != null else get_viewport().gui_get_focus_owner()
	_stop_rolling()
	visible = true
	_question.text = question
	_detail.text = detail
	_detail.visible = detail != ""
	_confirm_action.text = label
	_root.visible = false
	for id: StringName in _pages:
		_pages[id].visible = false
	_settings.visible = false
	_confirm_layer.visible = true
	_focus(_cancel)


## Gives `control` the focus — except in a preview: a control taking the focus in a viewport
## takes it from the whole window, and the editor's field being typed in would lose it. (A
## page still gives the focus to its first control: the preview gives it back.)
func _focus(control: Control) -> void:
	if not _previewed():
		control.grab_focus()


func _previewed() -> bool:
	return _session != null and _session.is_preview()


## Does what a button asks, or first asks the player when it would lose the game in
## progress.
## `always`: ask even when no progress is at risk.
func _ask(action: Signal, question: String, label: String, asker: Button, always := false) -> void:
	var at_risk := _session != null and _session.needs_confirmation()
	if not at_risk and not always:
		action.emit()
		return
	confirm(question, label, "TGC_CONFIRM_LOSS" if at_risk else "", action.emit, asker)


func _ask_quit() -> void:
	var always := _session != null and _session.config.confirm_quit
	var application := _session != null and _session.config.wording == TgcMenuConfig.Wording.APPLICATION
	_ask(quit_requested, "TGC_CONFIRM_QUIT_APP" if application else "TGC_CONFIRM_QUIT",
			"TGC_QUIT_APP" if application else "TGC_QUIT", _quit, always)


func _drops() -> bool:
	return _session != null and _session.config.presentation == TgcMenuConfig.Presentation.DROP_DOWN


func _rolls() -> bool:
	return _session.config.drop_down_seconds > 0.0 and not _previewed()


## Hangs the root and the Settings sub-menu under the button, then unrolls the one shown
## from it (`opening`), or rolls it back and hides the menu.
func _roll(opening: bool) -> void:
	for holder in _hangers():
		_hang(holder)
	if not _rolls():
		return
	var shown := _settings if _settings.visible else _root
	var folded := Vector2(0.35, 0.05)
	if opening:
		shown.scale = folded
		_frame.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	var seconds := _session.config.drop_down_seconds
	_tween.tween_property(shown, "scale", Vector2.ONE if opening else folded, seconds)
	_tween.tween_property(_frame, "modulate:a", 1.0 if opening else 0.0, seconds)
	if not opening:
		_tween.chain().tween_callback(_rolled_back)


## What hangs under the button for `target`: the root's or the sub-menu's holder, or a
## page's first container (the page itself if it has none).
func _hanger(target: StringName) -> Control:
	match target:
		ROOT:
			return _root
		SETTINGS:
			return _settings
	var page: Control = _pages.get(target)
	if page == null:
		return null
	for child in page.get_children():
		if child is Container:
			return child
	return page


func _hangers() -> Array[Control]:
	var out: Array[Control] = [_root, _settings]
	for id: StringName in _pages:
		var holder := _hanger(id)
		if holder != null:
			out.append(holder)
	return out


## Hangs `holder` under the button, at its own size.
func _hang(holder: Control) -> void:
	if holder == null:
		return
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = holder.get_combined_minimum_size()
	holder.position = Vector2(_origin.position.x, _origin.end.y + DROP_GAP)
	holder.pivot_offset = Vector2.ZERO


## Places `holder` (the root's, the sub-menu's or a page's container, one that centres what
## it holds) on the screen. On an axis where it stands against an edge, it shrinks to its own
## size there, `margin` from that edge; on a centred axis, it spans the screen, and centres.
static func _place(holder: Control, across: TgcMenuConfig.HorizontalPlacement,
		upright: TgcMenuConfig.VerticalPlacement, margin: float) -> void:
	if holder == null:
		return
	var x := _edge(int(across), margin)
	var y := _edge(int(upright), margin)
	holder.anchor_left = x[0]
	holder.anchor_right = x[1]
	holder.offset_left = x[2]
	holder.offset_right = x[3]
	holder.grow_horizontal = x[4]
	holder.anchor_top = y[0]
	holder.anchor_bottom = y[1]
	holder.offset_top = y[2]
	holder.offset_bottom = y[3]
	holder.grow_vertical = y[4]


## The anchors, offsets and growth on one axis, for a placement at its start (0), middle (1)
## or end (2).
static func _edge(placement: int, margin: float) -> Array:
	match placement:
		0:
			return [0.0, 0.0, margin, margin, Control.GROW_DIRECTION_END]
		2:
			return [1.0, 1.0, -margin, -margin, Control.GROW_DIRECTION_BEGIN]
	return [0.0, 1.0, 0.0, 0.0, Control.GROW_DIRECTION_BOTH]


## The level `arriving` takes the place of `leaving`: born at its size, it grows or shrinks
## to its own while it shows.
func _morph(leaving: Control, arriving: Control) -> void:
	if leaving == null or arriving == null or arriving.size.x <= 0.0 or arriving.size.y <= 0.0:
		return
	if _tween != null:
		_tween.kill()
	_unfold()
	arriving.scale = Vector2(leaving.size.x / arriving.size.x, leaving.size.y / arriving.size.y)
	arriving.modulate.a = 0.0
	_tween = create_tween().set_parallel().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var seconds := _session.config.drop_down_seconds
	_tween.tween_property(arriving, "scale", Vector2.ONE, seconds)
	_tween.tween_property(arriving, "modulate:a", 1.0, seconds * 0.7)


func _rolled_back() -> void:
	_closing = false
	visible = false
	_unfold()


## Stops a drop-down menu rolling, and unfolds it at once.
func _stop_rolling() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_closing = false
	_unfold()


func _unfold() -> void:
	for holder in _hangers():
		holder.scale = Vector2.ONE
		holder.modulate.a = 1.0
	_frame.modulate.a = 1.0


## A click on the veil, beside a drop-down menu: the player wants the game back.
func _on_veil_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var pressed := (mouse != null and mouse.pressed) or (touch != null and touch.pressed)
	if pressed and not is_confirming() and _session != null and _session.is_in_game():
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _accept() -> void:
	var action := _pending
	_hide_confirmation()
	if action.is_valid():
		action.call()


## Gives up, and gives the focus back to the button that asked.
func _dismiss() -> void:
	var asker := _asker
	var on_cancel := _on_cancel
	_hide_confirmation()
	if asker != null and is_instance_valid(asker) and asker.is_visible_in_tree():
		asker.grab_focus()
	if on_cancel.is_valid():
		on_cancel.call()


func _hide_confirmation() -> void:
	if _confirm_layer.visible:
		_root.visible = _page == ROOT
		_settings.visible = _page == SETTINGS
		if _pages.has(_page):
			_pages[_page].visible = true
	_confirm_layer.visible = false
	_pending = Callable()
	_on_cancel = Callable()
	_asker = null


## "Save" during a game only, and only while the game can be saved; "Load" while a save
## exists. Asked again each time the root is shown — a save or a deletion changes both —, and
## when the game hands its provider over.
func refresh_root() -> void:
	if _session == null or not _session.saves_enabled():
		_open_save.visible = false
		_open_load.visible = false
		return
	_open_save.visible = _pages.has(SAVE) and _session.is_in_game()
	_open_save.disabled = not _session.can_save()
	_open_load.visible = _pages.has(LOAD)
	_open_load.disabled = _session.existing_saves().is_empty()


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


## Adds a page: to the Settings sub-menu, with a button there; or, given its `opener`, to the
## root.
func _add_page(scene: PackedScene, opener: Button = null) -> void:
	var node := scene.instantiate()
	var added := node as TgcMenuPage
	if added == null:
		push_warning("TGC Game Menu: %s is not a TgcMenuPage, and is left out." % scene.resource_path)
		node.free()
		return
	var reserved: Array[StringName] = [ROOT, SETTINGS]
	if opener == null:
		reserved.append_array([SAVE, LOAD])
	if reserved.has(added.page_id) or _pages.has(added.page_id):
		push_warning("TGC Game Menu: the page id \"%s\" of %s is empty, reserved or taken." % [added.page_id, scene.resource_path])
		added.free()
		return
	# In the editor, a game's page whose script is not a tool is a placeholder: none of its
	# code can run, so it is shown as its scene draws it.
	var script := added.get_script() as Script
	var inert := Engine.is_editor_hint() and script != null and not script.is_tool()
	if inert:
		_inert_pages.append(added.page_id)
	else:
		added.setup(_session)
		if not added.is_relevant():
			added.free()
			return
	added.visible = false
	_pages_holder.add_child(added)
	_pages[added.page_id] = added
	if opener != null:
		_root_pages.append(added.page_id)
		_page_openers[added.page_id] = opener
		if not inert:
			added.closed.connect(show_page.bind(ROOT))
		return
	if not inert:
		added.closed.connect(show_page.bind(SETTINGS))
	var button := Button.new()
	button.name = "Open" + String(added.page_id).to_pascal_case()
	# A key: the button translates it, and follows the language.
	button.text = added.title
	button.pressed.connect(show_page.bind(added.page_id))
	_page_buttons.add_child(button)
	_page_openers[added.page_id] = button
