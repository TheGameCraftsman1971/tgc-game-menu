@tool
class_name TgcControlBindings
extends RefCounted

## The player's controls, as they wanted them.
##
## The actions it handles are those of [member TgcMenuConfig.remappable_actions], in that
## order: the Controls page and a game's on-screen help read them here, and nowhere else is
## there a list of keys to keep in step.
##
## It is not a screen: it draws nothing, reads no key and has no node. [TgcMenuSession] holds
## it and gives it to the Controls page, which is also what lets a bench remap, save and read
## back without a window ever opening. Every change emits `changed`; the session saves.
##
## ## Two families, slots in each
##
## Keyboard and mouse on one side, gamepad on the other. Remapping one **never touches** the
## other: it is the first thing a player notices when it does, and they conclude their
## gamepad no longer works. Each family has [member slots] slots, two by default, because
## actions usually carry two already (the mouse and a key, WASD and the arrows, the stick and
## the D-pad).
##
## An input given to an action is **taken from whoever had it**: a key that would trigger two
## actions at once makes no sense while playing, whereas an action left without a key shows
## on the Controls page.
##
## ## Zero-Trust, because the file comes from outside
##
## It lives in `user://`, so anyone can write anything in it. **No object is serialised**:
## each input is written in plain text — `t:83`, `s:1`, `b:0`, `a:1:+` —, read back field by
## field and bounded before it enters the [InputMap]. A damaged line is ignored, and the
## action falls back on its default inputs.
##
## ## Defaults come from the project settings, not from the InputMap
##
## The InputMap is rewritten as soon as the player's file is loaded. The default inputs are
## therefore read from [ProjectSettings], which keeps what the project declares: a second
## instance, a bench's for instance, never takes inputs already remapped for the defaults. An
## action the project does not declare (the pause action created by the session) has its
## inputs taken when this object is built, before any file is read.

signal changed

enum Family {
	KEYBOARD, ## keyboard keys and mouse buttons
	PAD, ## gamepad buttons and axes
}

const _SECTION := "controls"

## Where it reads and writes. A field, so that a bench can test saving for real without
## overwriting the file of the player who runs it.
var path := "user://settings_controls.cfg"
## Inputs per action and per family.
var slots := 2

var _labels: Dictionary[StringName, String] = {}
var _essential: Array[StringName] = []
var _undeclared_defaults: Dictionary[StringName, PackedStringArray] = {}
## A preview's inputs ([method preview]): read from the project settings, never from the
## InputMap, which in the editor is the editor's.
var _preview := false
var _preview_events: Dictionary[StringName, Array] = {}


func _init(menu_config: TgcMenuConfig = null) -> void:
	var config := menu_config if menu_config != null else TgcMenuConfig.new()
	for entry in config.remappable():
		if entry == null or entry.action == &"" or _labels.has(entry.action):
			continue
		_labels[entry.action] = entry.label
		if entry.essential:
			_essential.append(entry.action)
	slots = clampi(config.slots_per_family, 1, 4)
	path = config.controls_file
	for action: StringName in _labels:
		if InputMap.has_action(action) and not ProjectSettings.has_setting("input/" + String(action)):
			_undeclared_defaults[action] = _encode_all(action)


## Bindings for [TgcMenuPreview]: the inputs the project declares, or those the session would
## create, read without touching the InputMap. Nothing is loaded nor saved.
static func preview(menu_config: TgcMenuConfig) -> TgcControlBindings:
	var bindings := TgcControlBindings.new(menu_config)
	bindings._preview = true
	var built_in := menu_config.built_in_inputs()
	for action: StringName in bindings._labels:
		var declared := ProjectSettings.has_setting("input/" + String(action))
		if not declared and not built_in.has(action):
			continue
		var codes := bindings.defaults_of(action) if declared else built_in[action]
		var found: Array[InputEvent] = []
		for code in codes:
			var event := decode(code)
			if event != null:
				found.append(event)
		bindings._preview_events[action] = found
	return bindings


## The remappable actions the project declares, in the order of the Controls page.
func actions() -> Array[StringName]:
	var found: Array[StringName] = []
	for action: StringName in _labels:
		if (_preview_events.has(action) if _preview else InputMap.has_action(action)):
			found.append(action)
	return found


## The translation key of an action's caption.
func label_of(action: StringName) -> String:
	return _labels[action] if _labels.has(action) else String(action)


## True if the action always keeps at least one keyboard key.
func is_essential(action: StringName) -> bool:
	return _essential.has(action)


## Reads the player's file back and applies it. False if there is none, which is the
## ordinary case of the first game, and not an error.
func load_from_disk() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	for action in actions():
		if not file.has_section_key(_SECTION, action):
			continue
		# The type itself is suspect, not only the value: a damaged file can return anything
		# here, and a forced conversion would crash the game.
		var stored: Variant = file.get_value(_SECTION, action, PackedStringArray())
		if stored is PackedStringArray:
			_apply(action, stored)
	changed.emit()
	return true


## Writes what **differs** from the defaults, and nothing else. An exhaustive save would
## freeze the defaults in the player's file: the day the game changed one, only that player
## would keep the old one without having asked for it.
func save() -> bool:
	var file := ConfigFile.new()
	for action in actions():
		var current := _encode_all(action)
		if current != defaults_of(action):
			file.set_value(_SECTION, action, current)
	var error := file.save(path)
	if error != OK:
		push_warning("TGC Game Menu: controls not saved (%d): %s" % [error, path])
	return error == OK


## An action's inputs in a family, in the order of their slots.
func events(action: StringName, family: Family) -> Array[InputEvent]:
	var found: Array[InputEvent] = []
	var all: Array = _preview_events.get(action, []) if _preview \
			else (InputMap.action_get_events(action) if InputMap.has_action(action) else [])
	for event: InputEvent in all:
		if family_of(event) == family and encode(event) != "":
			found.append(event)
	return found


## The remappable action that already holds this input, or `&""`.
func holder_of(event: InputEvent) -> StringName:
	var code := encode(event)
	for action in actions():
		for existing in InputMap.action_get_events(action):
			if encode(existing) == code:
				return action
	return &""


## True if this input can be given to this action: the right family, an input that can be
## written, and one that does not leave an essential action without its last key.
func can_bind(action: StringName, family: Family, event: InputEvent) -> bool:
	if not _labels.has(action) or not InputMap.has_action(action):
		return false
	if encode(event) == "" or family_of(event) != family:
		return false
	var holder := holder_of(event)
	return holder == &"" or holder == action or not _would_strand(holder, event)


## Gives an input to a slot. It is **taken from whoever had it** at the same time.
func bind(action: StringName, family: Family, slot: int, event: InputEvent) -> bool:
	if not can_bind(action, family, event):
		return false
	var taken := _normalized(event)
	var code := encode(taken)
	for other in actions():
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if encode(existing) == code:
				InputMap.action_erase_event(other, existing)
	var list: Array[InputEvent] = []
	for existing in events(action, family):
		if encode(existing) != code:
			list.append(existing)
	var index := clampi(slot, 0, slots - 1)
	if index < list.size():
		list[index] = taken
	else:
		list.append(taken)
	_set_family(action, family, list)
	changed.emit()
	return true


## Empties a slot. False if it was the last key of an essential action.
func clear(action: StringName, family: Family, slot: int) -> bool:
	var list := events(action, family)
	if slot < 0 or slot >= list.size():
		return false
	if is_essential(action) and family == Family.KEYBOARD and list.size() == 1:
		return false
	list.remove_at(slot)
	_set_family(action, family, list)
	changed.emit()
	return true


## Brings back the default inputs.
func restore_defaults() -> void:
	for action in actions():
		_apply(action, defaults_of(action))
	changed.emit()


## The inputs the project declares for an action, in plain text.
func defaults_of(action: StringName) -> PackedStringArray:
	if _undeclared_defaults.has(action):
		return _undeclared_defaults[action]
	var declared: Variant = ProjectSettings.get_setting("input/" + String(action), {})
	var out := PackedStringArray()
	if declared is Dictionary:
		var listed: Variant = (declared as Dictionary).get("events", [])
		if listed is Array:
			for event: Variant in listed:
				if event is InputEvent:
					var text := encode(event)
					if text != "":
						out.append(text)
	return out


## The family of an event. Everything that is not a gamepad is the keyboard's: it is the
## same hand, and the player remaps them with the same gesture.
static func family_of(event: InputEvent) -> Family:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Family.PAD
	return Family.KEYBOARD


## An input, in plain text and on one line: the **only** format written to disk, and it can
## be read with the naked eye, so a player can repair their file in a text editor.
static func encode(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null and key.physical_keycode != KEY_NONE:
		return "t:%d" % key.physical_keycode
	var click := event as InputEventMouseButton
	if click != null and click.button_index >= 1 and click.button_index <= 9:
		return "s:%d" % click.button_index
	var button := event as InputEventJoypadButton
	if button != null and button.button_index >= 0 and button.button_index < JOY_BUTTON_SDL_MAX:
		return "b:%d" % button.button_index
	var motion := event as InputEventJoypadMotion
	if motion != null and motion.axis >= 0 and motion.axis < JOY_AXIS_SDL_MAX:
		return "a:%d:%s" % [motion.axis, "+" if motion.axis_value > 0.0 else "-"]
	return ""


## The reverse, and **it trusts nothing**: each field is bounded, and whatever is not
## recognised returns `null`. Events apply to **every** device: an input read back must not
## answer to gamepad number 0 only.
static func decode(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var value := parts[1].to_int()
	var event: InputEvent = null
	match parts[0]:
		"t":
			if value > 0 and value <= 0x7FFFFF:
				var key := InputEventKey.new()
				key.physical_keycode = value as Key
				event = key
		"s":
			if value >= 1 and value <= 9:
				var click := InputEventMouseButton.new()
				click.button_index = value as MouseButton
				event = click
		"b":
			if value >= 0 and value < JOY_BUTTON_SDL_MAX:
				var button := InputEventJoypadButton.new()
				button.button_index = value as JoyButton
				event = button
		"a":
			if value >= 0 and value < JOY_AXIS_SDL_MAX and parts.size() == 3 and parts[2] in ["+", "-"]:
				var motion := InputEventJoypadMotion.new()
				motion.axis = value as JoyAxis
				motion.axis_value = 1.0 if parts[2] == "+" else -1.0
				event = motion
	if event != null:
		event.device = -1
	return event


## A stripped copy of the event received: the one the engine passes carries the mouse
## position, the modifiers and the device, none of which means anything in a binding.
static func _normalized(event: InputEvent) -> InputEvent:
	return decode(encode(event))


func _encode_all(action: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for event in InputMap.action_get_events(action):
		var text := encode(event)
		if text != "":
			out.append(text)
	return out


## True if taking `event` from `action` would leave it without its last key while it is
## essential.
func _would_strand(action: StringName, event: InputEvent) -> bool:
	if not is_essential(action) or family_of(event) != Family.KEYBOARD:
		return false
	return events(action, Family.KEYBOARD).size() <= 1


## Replaces a family's inputs, without touching the other's.
func _set_family(action: StringName, family: Family, list: Array[InputEvent]) -> void:
	var kept: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if family_of(existing) != family:
			kept.append(existing)
	InputMap.action_erase_events(action)
	var ordered: Array[InputEvent] = list if family == Family.KEYBOARD else kept
	var others: Array[InputEvent] = kept if family == Family.KEYBOARD else list
	for event in ordered + others:
		InputMap.action_add_event(action, event)


## Replaces an action's inputs with a list written in plain text.
##
## A list of which **nothing** is readable leaves the action as it is: better the defaults
## than a dead action. Each family is bounded to [member slots], and an essential action
## without a keyboard key falls back on the defaults.
func _apply(action: StringName, stored: PackedStringArray) -> void:
	var keyboard: Array[InputEvent] = []
	var pad: Array[InputEvent] = []
	var seen := {}
	for text in stored:
		var event := decode(text)
		if event == null or seen.has(encode(event)):
			continue
		seen[encode(event)] = true
		var list := keyboard if family_of(event) == Family.KEYBOARD else pad
		if list.size() < slots:
			list.append(event)
	if keyboard.is_empty() and pad.is_empty():
		return
	if is_essential(action) and keyboard.is_empty():
		return
	InputMap.action_erase_events(action)
	for event in keyboard + pad:
		InputMap.action_add_event(action, event)
