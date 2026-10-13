class_name TgcInputLabels
extends RefCounted

## The name of an input as a player recognises it, **in their language**. Static functions,
## no state.
##
## The Controls page and a game's on-screen help name the same keys. One function does it,
## or the help and the settings would end up saying different things. The names are keys of
## the add-on's catalogue (`TGC_INPUT_*`), translated when they are asked for: whoever shows
## one asks again when the language changes ([code]NOTIFICATION_TRANSLATION_CHANGED[/code]).

## A gamepad's buttons, named for both families of pads. A player who reads "button 2" does
## not know where to press; "X / Square" they do.
const PAD_BUTTONS := {
	0: "TGC_INPUT_PAD_A", 1: "TGC_INPUT_PAD_B", 2: "TGC_INPUT_PAD_X", 3: "TGC_INPUT_PAD_Y",
	4: "TGC_INPUT_PAD_BACK", 5: "TGC_INPUT_PAD_GUIDE", 6: "TGC_INPUT_PAD_START",
	7: "TGC_INPUT_PAD_LEFT_STICK", 8: "TGC_INPUT_PAD_RIGHT_STICK",
	9: "TGC_INPUT_PAD_LB", 10: "TGC_INPUT_PAD_RB",
	11: "TGC_INPUT_PAD_DPAD_UP", 12: "TGC_INPUT_PAD_DPAD_DOWN",
	13: "TGC_INPUT_PAD_DPAD_LEFT", 14: "TGC_INPUT_PAD_DPAD_RIGHT",
}
## The axes, and what their sign means: [negative, positive].
const PAD_AXES := {
	0: ["TGC_INPUT_AXIS_LEFT_X_NEG", "TGC_INPUT_AXIS_LEFT_X_POS"],
	1: ["TGC_INPUT_AXIS_LEFT_Y_NEG", "TGC_INPUT_AXIS_LEFT_Y_POS"],
	2: ["TGC_INPUT_AXIS_RIGHT_X_NEG", "TGC_INPUT_AXIS_RIGHT_X_POS"],
	3: ["TGC_INPUT_AXIS_RIGHT_Y_NEG", "TGC_INPUT_AXIS_RIGHT_Y_POS"],
	# A trigger only goes one way: 0 at rest, 1 pressed.
	4: ["TGC_INPUT_PAD_LT", "TGC_INPUT_PAD_LT"],
	5: ["TGC_INPUT_PAD_RT", "TGC_INPUT_PAD_RT"],
}
## The keys that `OS.get_keycode_string` names in English ("Escape", "PageUp").
const NAMED_KEYS := {
	KEY_ESCAPE: "TGC_INPUT_KEY_ESCAPE", KEY_SPACE: "TGC_INPUT_KEY_SPACE",
	KEY_ENTER: "TGC_INPUT_KEY_ENTER", KEY_KP_ENTER: "TGC_INPUT_KEY_KP_ENTER",
	KEY_TAB: "TGC_INPUT_KEY_TAB", KEY_BACKSPACE: "TGC_INPUT_KEY_BACKSPACE",
	KEY_DELETE: "TGC_INPUT_KEY_DELETE", KEY_INSERT: "TGC_INPUT_KEY_INSERT",
	KEY_HOME: "TGC_INPUT_KEY_HOME", KEY_END: "TGC_INPUT_KEY_END",
	KEY_PAGEUP: "TGC_INPUT_KEY_PAGEUP", KEY_PAGEDOWN: "TGC_INPUT_KEY_PAGEDOWN",
	KEY_UP: "TGC_INPUT_KEY_UP", KEY_DOWN: "TGC_INPUT_KEY_DOWN",
	KEY_LEFT: "TGC_INPUT_KEY_LEFT", KEY_RIGHT: "TGC_INPUT_KEY_RIGHT",
	KEY_SHIFT: "TGC_INPUT_KEY_SHIFT", KEY_CTRL: "TGC_INPUT_KEY_CTRL",
	KEY_CAPSLOCK: "TGC_INPUT_KEY_CAPSLOCK",
}
const MOUSE_BUTTONS := {
	1: "TGC_INPUT_MOUSE_LEFT", 2: "TGC_INPUT_MOUSE_RIGHT", 3: "TGC_INPUT_MOUSE_MIDDLE",
	4: "TGC_INPUT_WHEEL_UP", 5: "TGC_INPUT_WHEEL_DOWN",
	6: "TGC_INPUT_WHEEL_LEFT", 7: "TGC_INPUT_WHEEL_RIGHT",
	8: "TGC_INPUT_MOUSE_4", 9: "TGC_INPUT_MOUSE_5",
}


## The name of an event, or an empty string if it cannot be named: it is then neither
## shown nor saved, rather than appearing as "Joypad Axis 7".
static func of(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null and key.physical_keycode != KEY_NONE:
		return key_label(key.physical_keycode)
	var click := event as InputEventMouseButton
	if click != null:
		return _tr(MOUSE_BUTTONS.get(click.button_index, ""))
	var button := event as InputEventJoypadButton
	if button != null:
		return _tr(PAD_BUTTONS.get(button.button_index, ""))
	var motion := event as InputEventJoypadMotion
	if motion != null and PAD_AXES.has(motion.axis):
		return _tr((PAD_AXES[motion.axis] as Array)[1 if motion.axis_value > 0.0 else 0])
	return ""


## The label of a key **as it is engraved** on the player's keyboard: actions are bound to
## physical positions, and the W key of a QWERTY keyboard is the Z of an AZERTY one.
##
## The headless and web display servers know no keyboard layout, and complain at every
## question: there the physical position is read as is, so a web build names the keys as on
## a QWERTY keyboard.
static func key_label(physical: Key) -> String:
	if NAMED_KEYS.has(physical):
		return _tr(NAMED_KEYS[physical])
	if physical == KEY_ALT:
		return _tr("TGC_INPUT_KEY_OPTION" if OS.has_feature("macos") else "TGC_INPUT_KEY_ALT")
	if physical == KEY_META:
		if OS.has_feature("macos"):
			return _tr("TGC_INPUT_KEY_CMD")
		return _tr("TGC_INPUT_KEY_WIN" if OS.has_feature("windows") else "TGC_INPUT_KEY_SUPER")
	var label := physical
	if knows_keyboard_layout():
		var engraved := DisplayServer.keyboard_get_label_from_physical(physical)
		if engraved != KEY_NONE:
			label = engraved
	return OS.get_keycode_string(label)


## The first input of an action in the family asked for, named; "?" if there is none. What
## a game's on-screen help shows.
static func first_of(action: StringName, pad: bool) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad == pad:
			var text := of(event)
			if text != "":
				return text
	return "?"


## True if the display server can name a key from the keyboard's layout.
static func knows_keyboard_layout() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("web")


static func _tr(key: String) -> String:
	return "" if key.is_empty() else String(TranslationServer.translate(key))
