@tool
class_name BenchLog
extends RefCounted

## The script errors raised during a bench, read from the engine's log.
##
## A script error in the middle of a check does not fail the bench: it interrupts the
## function in progress, which returns as if nothing had happened, and its last checks are
## never made. The bench would then end green, with fewer checks. The log keeps the trace:
## each bench reads it again on its way out.
##
## Only what was written since the start is counted: another instance of the engine may have
## written before, and the file may have been started over in between.

const PATH := "user://logs/godot.log"

var _start := 0


func _init() -> void:
	_start = _size()


## The script errors written to the log since this object was created.
func script_errors() -> int:
	var text := FileAccess.get_file_as_string(PATH)
	var from := _start if text.length() >= _start else 0
	return text.substr(from).count("SCRIPT ERROR")


func _size() -> int:
	return FileAccess.get_file_as_string(PATH).length() if FileAccess.file_exists(PATH) else 0
