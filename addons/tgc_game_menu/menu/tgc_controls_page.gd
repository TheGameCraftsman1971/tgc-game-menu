@tool
class_name TgcControlsPage
extends TgcMenuPage

## The Controls page: it shows the controls, and **it changes them**.
##
## **It copies nothing.** It reads the [InputMap] through [TgcControlBindings] and shows what
## it finds there. A list written by hand would drift at the first remapping: the page would
## announce the old key without anything telling.
##
## ## Waiting for an input
##
## One clicks a slot, then presses what one wants instead: a key, a mouse button or a wheel
## for the keyboard-and-mouse column, a button or a stick for the gamepad column. The wait is
## read in `_input`, **before** the interface: otherwise a click on the grid itself would be
## taken by the button under the pointer, and the left click could never be bound. The click
## that opens the wait does not count: a button fires on release, and the wait only keeps
## presses.
##
## Esc gives up, Delete (or Backspace) clears the slot, and the wait ends by itself after
## [member TgcMenuConfig.capture_timeout] seconds: a player holding only a gamepad must be
## able to get out of it.
##
## The page does not save: the bindings notify, and the session saves.
##
## ## The language
##
## The actions' captions are keys ([member TgcMenuConfig.remappable_actions]), which the
## Labels translate themselves. The names of keys and the messages carry values: they are
## translated here, and redone when the language changes.

const _EMPTY_SLOT := "—"
const _SLOT_WIDTH := 190.0
const _GAP := 12.0
## The width of the actions' column.
const _CAPTION_WIDTH := 312.0

var bindings: TgcControlBindings
var _timeout := 6.0
var _families: Array[TgcControlBindings.Family] = []
## The slot buttons, by action, then by family: {action: {family: [Button, …]}}.
var _slots: Dictionary = {}
var _awaited := &""
var _awaited_family := TgcControlBindings.Family.KEYBOARD
var _awaited_slot := 0
var _capture_serial := 0

@onready var _grid: GridContainer = %Grid
@onready var _hint: Label = %Hint


func setup(with_session: TgcMenuSession) -> void:
	super(with_session)
	bindings = session.bindings
	_timeout = session.config.capture_timeout
	_families = [TgcControlBindings.Family.KEYBOARD]
	if session.config.show_gamepad_column:
		_families.append(TgcControlBindings.Family.PAD)


func is_relevant() -> bool:
	return not bindings.actions().is_empty()


func _ready() -> void:
	# Opened alone in the editor, the page has no session: it stays as it is drawn.
	if session == null:
		return
	var column_width := bindings.slots * _SLOT_WIDTH + (bindings.slots - 1) * _GAP
	(%KeyboardHeader as Control).custom_minimum_size.x = column_width
	(%PadHeader as Control).custom_minimum_size.x = column_width
	(%PadHeader as Control).visible = _families.has(TgcControlBindings.Family.PAD)
	_grid.columns = 1 + bindings.slots * _families.size()
	(%Scroll as Control).custom_minimum_size.x = _CAPTION_WIDTH + _families.size() * (column_width + _GAP)
	(%Restore as Button).pressed.connect(_restore)
	(%Back as Button).pressed.connect(func() -> void:
		cancel_capture()
		closed.emit())
	_fill()
	_hint.text = tr("TGC_CONTROLS_HINT_IDLE")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and bindings != null:
		cancel_capture()


func focus_first() -> void:
	refresh()
	var actions := bindings.actions()
	if not actions.is_empty() and _slots.has(actions[0]):
		(_slots[actions[0]][_families[0]][0] as Button).grab_focus()


func leave() -> void:
	cancel_capture()


func is_capturing() -> bool:
	return _awaited != &""


## The text of a slot, as the page shows it. For benches.
func slot_text(action: StringName, family: TgcControlBindings.Family, slot: int) -> String:
	return (_slots[action][family][slot] as Button).text


func hint_text() -> String:
	return _hint.text


## Opens the wait for an input, for a slot.
func begin_capture(action: StringName, family: TgcControlBindings.Family, slot: int) -> void:
	_awaited = action
	_awaited_family = family
	_awaited_slot = slot
	_capture_serial += 1
	var serial := _capture_serial
	_hint.text = tr("TGC_CONTROLS_HINT_WAITING")
	(_slots[action][family][slot] as Button).text = tr("TGC_CONTROLS_PRESS")
	var give_up := func() -> void:
		if serial == _capture_serial and is_capturing():
			cancel_capture(tr("TGC_CONTROLS_TIMEOUT"))
	get_tree().create_timer(_timeout, true).timeout.connect(give_up)


## Gives up the wait, and shows `message` (translated), or the ordinary hint.
func cancel_capture(message := "") -> void:
	_awaited = &""
	_capture_serial += 1
	_hint.text = message if message != "" else tr("TGC_CONTROLS_HINT_IDLE")
	refresh()


## Gives an input to the slot awaited, or to the one named. True if it was taken. It is also
## what a bench calls: headless, a fabricated key does not reach the input callbacks.
func assign(action: StringName, family: TgcControlBindings.Family, slot: int, event: InputEvent) -> bool:
	var label := TgcInputLabels.of(event)
	var holder := bindings.holder_of(event)
	if not bindings.can_bind(action, family, event):
		var refusal := tr("TGC_CONTROLS_CANNOT") % label
		if holder != &"" and holder != action:
			refusal = tr("TGC_CONTROLS_LAST_KEY") % [label, tr(bindings.label_of(holder))]
		cancel_capture(refusal)
		return false
	bindings.bind(action, family, slot, event)
	var message := ""
	if holder != &"" and holder != action:
		message = tr("TGC_CONTROLS_TAKEN") % [label, tr(bindings.label_of(holder))]
	cancel_capture(message)
	return true


## Reads **all** the slots again, not only the one just changed: an input given to an action
## is taken from the one that had it, and that other slot would go on lying.
func refresh() -> void:
	for action: StringName in _slots:
		for family in _families:
			var events := bindings.events(action, family)
			var buttons: Array = _slots[action][family]
			for slot in buttons.size():
				var text := TgcInputLabels.of(events[slot]) if slot < events.size() else ""
				(buttons[slot] as Button).text = text if text != "" else _EMPTY_SLOT


func _input(event: InputEvent) -> void:
	if not is_capturing() or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key != null:
		get_viewport().set_input_as_handled()
		if not key.pressed or key.echo:
			return
		match key.physical_keycode:
			KEY_ESCAPE:
				cancel_capture()
			KEY_DELETE, KEY_BACKSPACE:
				_clear_awaited()
			_:
				if _awaited_family == TgcControlBindings.Family.KEYBOARD:
					assign(_awaited, _awaited_family, _awaited_slot, key)
		return
	var click := event as InputEventMouseButton
	if click != null:
		get_viewport().set_input_as_handled()
		if click.pressed and _awaited_family == TgcControlBindings.Family.KEYBOARD:
			assign(_awaited, _awaited_family, _awaited_slot, click)
		return
	var button := event as InputEventJoypadButton
	if button != null:
		get_viewport().set_input_as_handled()
		if button.pressed and _awaited_family == TgcControlBindings.Family.PAD:
			assign(_awaited, _awaited_family, _awaited_slot, button)
		return
	var motion := event as InputEventJoypadMotion
	if motion != null:
		get_viewport().set_input_as_handled()
		# A stick at rest sends events all the time: only a clear push counts, and the
		# direction is kept, not how hard the thumb pressed at that moment.
		if absf(motion.axis_value) >= 0.6 and _awaited_family == TgcControlBindings.Family.PAD:
			assign(_awaited, _awaited_family, _awaited_slot, motion)
		return
	if event is InputEventMouseMotion or event is InputEventPanGesture:
		get_viewport().set_input_as_handled()


## Fills the grid from the list of actions.
##
## It is the only part of the page left in code, and that is as it should be: the number of
## rows depends on the actions declared, which no scene can know in advance. The frame and
## the header are in `tgc_controls_page.tscn`.
func _fill() -> void:
	for action in bindings.actions():
		var caption := Label.new()
		# A key: the Label translates it, and follows the language.
		caption.text = bindings.label_of(action)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(caption)
		var by_family := {}
		for family in _families:
			var row: Array[Button] = []
			for slot in bindings.slots:
				var button := Button.new()
				button.theme_type_variation = &"SlotButton"
				button.custom_minimum_size = Vector2(_SLOT_WIDTH, 0.0)
				button.clip_text = true
				# A key's name is not a translation key: "A" must not turn into anything.
				button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				button.pressed.connect(begin_capture.bind(action, family, slot))
				_grid.add_child(button)
				row.append(button)
			by_family[family] = row
		_slots[action] = by_family
	refresh()


func _clear_awaited() -> void:
	var action := _awaited
	if bindings.clear(action, _awaited_family, _awaited_slot):
		cancel_capture()
	elif bindings.is_essential(action):
		cancel_capture(tr("TGC_CONTROLS_KEEPS_ONE") % tr(bindings.label_of(action)))
	else:
		cancel_capture()


func _restore() -> void:
	cancel_capture()
	bindings.restore_defaults()
	refresh()
