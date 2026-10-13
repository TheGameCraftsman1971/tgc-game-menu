@tool
class_name TgcSaveProvider
extends RefCounted

## What the game owes the menu to save and load: **the game writes the saving**, the add-on
## only says when, and where.
##
## Extend this class, override the five methods, and hand an instance to the session
## (`session.saves = MySaves.new(...)`) with [member TgcMenuConfig.enable_saves] on. The menu
## and the shortcuts then call it without knowing anything of how a game is saved: in a file
## per slot, in one file, in the cloud. A slot is named by [member TgcSaveSlot.id].
##
## ## Loading a game
##
## Loading **starts a game**: the session stops the one in progress
## ([signal TgcMenuSession.game_stopped]), starts a fresh one
## ([signal TgcMenuSession.game_started]), then calls [method load_game], which restores the
## saved state over it. A game therefore loads exactly as it starts, plus its state.
##
## ## Trust
##
## What the game reads back from its own storage is its business, and should be checked like
## any file from outside. What it hands back to the menu is checked again: a [method describe]
## that returns anything but a [TgcSaveInfo] counts as an empty slot.


## False when the game cannot be saved right now (a cut-scene, a fight…): the Save button
## is disabled, and the quick save says so.
func can_save() -> bool:
	return true


## Writes the game's current state into `slot`. OK, or the error to report.
func save_game(_slot: TgcSaveSlot) -> Error:
	push_error("TGC Game Menu: %s does not override save_game()." % _name())
	return ERR_UNAVAILABLE


## Restores the state saved in `slot`, over the fresh game just started. OK, or the error to
## report (the session then goes back to the main menu).
func load_game(_slot: TgcSaveSlot) -> Error:
	push_error("TGC Game Menu: %s does not override load_game()." % _name())
	return ERR_UNAVAILABLE


## Removes what `slot` holds. OK, or the error to report.
func delete_save(_slot: TgcSaveSlot) -> Error:
	push_error("TGC Game Menu: %s does not override delete_save()." % _name())
	return ERR_UNAVAILABLE


## What `slot` holds, or null if it is empty. Called whenever the menu lists the slots: keep
## it cheap (a small header beside the save, rather than the whole save).
func describe(_slot: TgcSaveSlot) -> TgcSaveInfo:
	return null


func _name() -> String:
	var script := get_script() as Script
	return script.resource_path.get_file() if script != null else "the save provider"
