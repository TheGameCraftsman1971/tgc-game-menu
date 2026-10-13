@tool
class_name TgcPreviewSaves
extends TgcSaveProvider

## Saves that do not exist, for [TgcMenuPreview]: the first [member filled] regular slots and
## the first quick slot seem full, an hour and a half apart, so that the Save and Load pages
## show what they will look like. Nothing is ever written, read or deleted.

var filled := 2


func _init(count := 2) -> void:
	filled = count


func can_save() -> bool:
	return true


func save_game(_slot: TgcSaveSlot) -> Error:
	return ERR_UNAVAILABLE


func load_game(_slot: TgcSaveSlot) -> Error:
	return ERR_UNAVAILABLE


func delete_save(_slot: TgcSaveSlot) -> Error:
	return ERR_UNAVAILABLE


func describe(slot: TgcSaveSlot) -> TgcSaveInfo:
	if filled <= 0 or slot.index > (1 if slot.is_quick() else filled):
		return null
	var hours_ago := slot.index * 5400 + (0 if slot.is_quick() else 1800)
	var now := int(Time.get_unix_time_from_system())
	return TgcSaveInfo.new(now - hours_ago, TgcI18n.translate("TGC_PREVIEW_SUMMARY") % slot.index)
