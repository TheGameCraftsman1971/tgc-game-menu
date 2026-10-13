class_name TgcSavesPage
extends TgcMenuPage

## The Save page and the Load page: one script, two scenes (`tgc_save_page.tscn`,
## `tgc_load_page.tscn`). They are opened from the menu's root, not from Settings.
##
## **Save** lists the regular slots, empty or not; choosing an empty one saves at once,
## choosing a full one asks first (it would be overwritten). **Load** lists the saves that
## exist, regular and quick, the most recent first; choosing one loads it, after asking if the
## game in progress would be lost. With [member TgcMenuConfig.allow_delete_saves], each save
## also gets a "Delete" button, which always asks.
##
## The page knows nothing of how a game is saved: it asks the session, which asks the game's
## [TgcSaveProvider]. Each row is one button, on two lines — the slot's name, then the date
## and the game's summary — so that a gamepad goes from save to save with the D-pad. The rows are rebuilt each time
## the page is shown, after each save and each deletion: the provider is the only truth.

enum Mode {
	SAVE,
	LOAD,
}

@export var mode := Mode.SAVE

var _rows: Array[Button] = []
## The slot of each row, in the same order.
var _shown: Array[TgcSaveSlot] = []

@onready var _list: VBoxContainer = %List
@onready var _hint: Label = %Hint
@onready var _back: Button = %Back


func is_relevant() -> bool:
	var config := session.config
	if not config.enable_saves:
		return false
	return config.save_slots > 0 if mode == Mode.SAVE else config.save_slots + config.quick_save_slots > 0


func _ready() -> void:
	_back.pressed.connect(closed.emit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_visible_in_tree():
		refresh()


func focus_first() -> void:
	_hint.text = ""
	refresh()
	(_rows[0] if not _rows.is_empty() else _back).grab_focus()


## The rows, in order. For benches.
func rows() -> Array[Button]:
	return _rows


## The delete button of a row, or null. For benches.
func delete_button(row: int) -> Button:
	var holder := _rows[row].get_parent()
	return holder.get_child(1) as Button if holder.get_child_count() > 1 else null


func hint_text() -> String:
	return _hint.text


## Rebuilds the list from what the provider says now.
func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_shown.clear()
	var slots := session.save_slots() if mode == Mode.SAVE else session.existing_saves()
	if slots.is_empty():
		var nothing := Label.new()
		nothing.text = "TGC_NO_SAVES"
		nothing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(nothing)
		return
	for slot in slots:
		_add_row(slot, session.describe(slot))


func _add_row(slot: TgcSaveSlot, info: TgcSaveInfo) -> void:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override(&"separation", 12)
	var row := Button.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A name and a date, not a key.
	row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# Two lines: the slot, then what it holds. On one, the game's summary would be cut.
	var detail := tr("TGC_SLOT_EMPTY") if info == null else info.line()
	row.text = "%s\n%s" % [slot.caption(session.config.quick_save_slots), detail]
	row.pressed.connect(_choose.bind(slot, info != null, row))
	holder.add_child(row)
	if session.config.allow_delete_saves and info != null:
		var delete := Button.new()
		delete.text = "TGC_DELETE"
		delete.pressed.connect(_ask_delete.bind(slot, delete))
		holder.add_child(delete)
	_list.add_child(holder)
	_rows.append(row)
	_shown.append(slot)


func _choose(slot: TgcSaveSlot, full: bool, row: Button) -> void:
	var menu := session.menu()
	if mode == Mode.SAVE:
		if full:
			menu.confirm("TGC_CONFIRM_OVERWRITE", "TGC_SAVE", "TGC_CONFIRM_OVERWRITE_DETAIL",
					_save.bind(slot), row)
		else:
			_save(slot)
	elif session.needs_confirmation():
		menu.confirm("TGC_CONFIRM_LOAD", "TGC_LOAD", "TGC_CONFIRM_LOSS", _load.bind(slot), row)
	else:
		_load(slot)


func _save(slot: TgcSaveSlot) -> void:
	var at := _index_of(slot)
	var error := session.save_to(slot)
	refresh()
	_hint.text = tr("TGC_SAVED") if error == OK else tr("TGC_SAVE_FAILED")
	_focus_row(at)


func _load(slot: TgcSaveSlot) -> void:
	# A success closes the menu and resumes; a failure goes back to the main menu, where this
	# page is no longer shown: the message goes on screen instead.
	if session.load_from(slot) != OK:
		session.notify("TGC_LOAD_FAILED")


func _ask_delete(slot: TgcSaveSlot, button: Button) -> void:
	session.menu().confirm("TGC_CONFIRM_DELETE", "TGC_DELETE", "TGC_CONFIRM_DELETE_DETAIL",
			_delete.bind(slot), button)


func _delete(slot: TgcSaveSlot) -> void:
	var at := _index_of(slot)
	var error := session.delete_save(slot)
	refresh()
	_hint.text = tr("TGC_DELETED") if error == OK else tr("TGC_DELETE_FAILED")
	_focus_row(at)


func _index_of(slot: TgcSaveSlot) -> int:
	for index in _shown.size():
		if _shown[index].id == slot.id:
			return index
	return 0


## Gives the focus back to the row at `index`, or the nearest one, or "Back".
func _focus_row(index: int) -> void:
	if _rows.is_empty():
		_back.grab_focus()
	else:
		_rows[clampi(index, 0, _rows.size() - 1)].grab_focus()
