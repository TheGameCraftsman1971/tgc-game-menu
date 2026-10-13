@tool
class_name TgcRemappableAction
extends Resource

## One row of the Controls page: an action the player can remap, and its caption.
##
## A list of these rather than a dictionary in [TgcMenuConfig]: a `.tres` saves a
## dictionary's keys sorted, and the page would lose the order the game chose.

## The action, as declared in the project's Input Map.
@export var action: StringName
## The caption's translation key, in the game's catalogue (`ACTION_JUMP`…). The add-on's
## catalogue has `TGC_ACTION_PAUSE`.
@export var label := ""
## The action always keeps at least one keyboard key. True for the pause: without a key,
## nothing would open the menu any more.
@export var essential := false


static func make(with_action: StringName, with_label: String, is_essential := false) -> TgcRemappableAction:
	var entry := TgcRemappableAction.new()
	entry.action = with_action
	entry.label = with_label
	entry.essential = is_essential
	return entry
