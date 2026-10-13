class_name DemoSaves
extends TgcSaveProvider

## The demonstration's saving: what a game writes for TGC Game Menu.
##
## One small file per slot (`<directory>/<slot id>.cfg`) holding the square's position and
## the moment of the save. The add-on never sees it: it calls the four methods below with a
## slot, and shows what [method describe] says. The file comes from outside, so it is read
## back in Zero-Trust: a value of the wrong type, or out of the screen, makes the slot count
## as damaged — empty for the menu, refused by [method load_game] — rather than crash.
##
## It cannot save in the middle of a jump ([method can_save]), to show what the menu does
## then: "Save" disabled, the quick save saying so.

const _SECTION := "save"

var _world: DemoWorld
var _directory := ""


func _init(world: DemoWorld, directory: String) -> void:
	_world = world
	_directory = directory


func can_save() -> bool:
	return not _world.is_jumping()


func save_game(slot: TgcSaveSlot) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error != OK:
		return error
	var file := ConfigFile.new()
	file.set_value(_SECTION, "saved_at", int(Time.get_unix_time_from_system()))
	file.set_value(_SECTION, "x", roundi(_world.player_position().x))
	file.set_value(_SECTION, "y", roundi(_world.player_position().y))
	return file.save(_path(slot))


func load_game(slot: TgcSaveSlot) -> Error:
	var position: Variant = _read(slot).get("position")
	if not position is Vector2:
		return ERR_FILE_CORRUPT
	_world.place_player(position)
	return OK


func delete_save(slot: TgcSaveSlot) -> Error:
	if not FileAccess.file_exists(_path(slot)):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(_path(slot))


func describe(slot: TgcSaveSlot) -> TgcSaveInfo:
	var read := _read(slot)
	if read.is_empty():
		return null
	var position: Vector2 = read.position
	return TgcSaveInfo.new(read.saved_at, TranslationServer.translate("DEMO_SAVE_SUMMARY") % [position.x, position.y])


## What a slot holds, checked: `{saved_at, position}`, or an empty dictionary if the file is
## missing or anything in it is not what was written.
func _read(slot: TgcSaveSlot) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(_path(slot)) != OK:
		return {}
	var saved_at: Variant = file.get_value(_SECTION, "saved_at", null)
	var x: Variant = file.get_value(_SECTION, "x", null)
	var y: Variant = file.get_value(_SECTION, "y", null)
	if not (saved_at is int and x is int and y is int):
		return {}
	if x < 0 or y < 0 or x > 10000 or y > 10000:
		return {}
	return {"saved_at": saved_at, "position": Vector2(x, y)}


func _path(slot: TgcSaveSlot) -> String:
	return _directory.path_join(slot.id + ".cfg")
