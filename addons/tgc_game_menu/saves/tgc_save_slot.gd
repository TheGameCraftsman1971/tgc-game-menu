class_name TgcSaveSlot
extends RefCounted

## One save slot: a regular one (the Save page) or a quick one (the quick-save shortcut).
##
## The add-on numbers the slots and never stores anything in them: it hands one to the
## game's [TgcSaveProvider], which writes, reads, describes or deletes what the slot holds,
## however it likes. [member id] is what the game keys its storage with.

enum Kind {
	REGULAR, ## chosen by the player on the Save page
	QUICK, ## written by the quick-save shortcut, in turn
}

var kind := Kind.REGULAR
## From 1.
var index := 1
## A stable name for the game's storage: `save_1`, `save_2`… and `quick_1`, `quick_2`…
var id := "save_1"


func _init(with_kind := Kind.REGULAR, with_index := 1) -> void:
	kind = with_kind
	index = with_index
	id = ("quick_%d" if kind == Kind.QUICK else "save_%d") % index


func is_quick() -> bool:
	return kind == Kind.QUICK


## The slot's name for the player, translated: "Slot 2", "Quick save", "Quick save 2".
## `quick_count`: how many quick slots there are; with one, it needs no number.
func caption(quick_count := 1) -> String:
	if kind == Kind.REGULAR:
		return TranslationServer.translate("TGC_SLOT_N") % index
	if quick_count <= 1:
		return String(TranslationServer.translate("TGC_QUICK_SLOT"))
	return TranslationServer.translate("TGC_QUICK_SLOT_N") % index
