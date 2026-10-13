@tool
class_name TgcSaveInfo
extends RefCounted

## What a slot holds, as the game describes it ([method TgcSaveProvider.describe]): when it
## was saved, and a line of the game's own ("Chapter 3 — Harbour, 2 h 14").

## When the save was written, in seconds since the Unix epoch (UTC):
## `Time.get_unix_time_from_system()` at the moment of saving.
var saved_at := 0
## A line chosen by the game, already in the player's language. May be empty.
var summary := ""


func _init(at := 0, with_summary := "") -> void:
	saved_at = at
	summary = with_summary


## The date and time of the save, in the player's local time: `2026-10-13 14:32`.
func when() -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var moment := Time.get_datetime_dict_from_unix_time(saved_at + bias)
	return "%04d-%02d-%02d %02d:%02d" % [moment.year, moment.month, moment.day, moment.hour, moment.minute]


## The line the menu shows under the slot's name: the date, then the game's summary.
func line() -> String:
	return when() if summary.is_empty() else "%s · %s" % [when(), summary]
