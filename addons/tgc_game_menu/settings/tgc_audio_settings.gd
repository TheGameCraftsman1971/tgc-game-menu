class_name TgcAudioSettings
extends Resource

## The player's volumes, one per channel of [member TgcMenuConfig.audio_channels].
##
## An **observable** Resource: every change emits `changed`. [TgcMenuSession] applies to the
## buses and saves; the Sound page only changes a volume. Each volume is a bus's, so neither
## the sound effects nor the music ever need to know the settings: a sound plays **on its
## bus**, and that is all.
##
## A volume goes from 0 to 1, by steps of 5 %. It follows the ear rather than the
## amplitude: the gain applied is its **square**, so half the slider sounds about half as
## loud (−12 dB) instead of almost as loud (−6 dB). At 0, the bus is muted.
##
## The file lives in `user://` and is read back in Zero-Trust. Volumes are written in
## percent, by bus name, readable. A value of another type falls back on the default, a
## value out of bounds is brought back within them.

const STEP := 0.05
const _SECTION := "audio"

var path := "user://settings_audio.cfg"

var _channels: Array[TgcAudioChannel] = []
var _volumes: Dictionary[StringName, float] = {}
var _quiet := false


func _init(menu_config: TgcMenuConfig = null) -> void:
	var config := menu_config if menu_config != null else TgcMenuConfig.new()
	path = config.audio_file
	for channel in config.volume_channels():
		if channel != null and not _volumes.has(channel.bus):
			_channels.append(channel)
			_volumes[channel.bus] = _volume(channel.default_volume)


## The channels, in the order of the sliders.
func channels() -> Array[TgcAudioChannel]:
	return _channels


## A bus's volume, from 0 to 1. 0 for a bus that is not a channel.
func volume(bus: StringName) -> float:
	return _volumes[bus] if _volumes.has(bus) else 0.0


func set_volume(bus: StringName, value: float) -> void:
	if not _volumes.has(bus):
		return
	value = _volume(value)
	if not is_equal_approx(value, _volumes[bus]):
		_volumes[bus] = value
		_notify()


## Gives each bus its volume. A bus the project does not have is skipped: a volume never
## crashes the game.
func apply() -> void:
	for bus: StringName in _volumes:
		_apply_bus(bus, _volumes[bus])


## The gain a slider's volume is worth.
static func gain_of(value: float) -> float:
	return value * value


## True if the project's bus layout has this bus.
static func has_bus(bus: StringName) -> bool:
	return AudioServer.get_bus_index(bus) >= 0


func load_from_disk() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	for channel in _channels:
		var stored: Variant = file.get_value(_SECTION, String(channel.bus), null)
		if stored is int or stored is float:
			_volumes[channel.bus] = _volume(float(stored) / 100.0)
	emit_changed()
	return true


func save() -> bool:
	var file := ConfigFile.new()
	for channel in _channels:
		file.set_value(_SECTION, String(channel.bus), roundi(_volumes[channel.bus] * 100.0))
	var error := file.save(path)
	if error != OK:
		push_warning("TGC Game Menu: audio settings not saved (%d): %s" % [error, path])
	return error == OK


func restore_defaults() -> void:
	_quiet = true
	for channel in _channels:
		set_volume(channel.bus, channel.default_volume)
	_quiet = false
	emit_changed()


static func _apply_bus(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_linear(index, gain_of(value))


static func _volume(value: float) -> float:
	return snappedf(clampf(value, 0.0, 1.0), STEP)


func _notify() -> void:
	if not _quiet:
		emit_changed()
