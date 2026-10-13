class_name TgcSoundPage
extends TgcMenuPage

## The Sound page: one slider per channel of [TgcAudioSettings]. It shows the volumes and
## changes them, nothing more: the Resource notifies (`changed`), and the session applies to
## the buses and saves. It knows neither the buses nor the file.
##
## The rows are built in code, and that is as it should be: their number depends on the
## channels the config declares, which no scene can know in advance. A channel whose bus the
## project does not have gets no row. The frame is in `tgc_sound_page.tscn`.

var settings: TgcAudioSettings
## The buses shown, in the order of the rows.
var _buses: Array[StringName] = []
var _sliders: Array[HSlider] = []
var _values: Array[Label] = []

@onready var _grid: GridContainer = %Grid


func setup(with_session: TgcMenuSession) -> void:
	super(with_session)
	settings = session.audio
	for channel in settings.channels():
		if TgcAudioSettings.has_bus(channel.bus):
			_buses.append(channel.bus)


func is_relevant() -> bool:
	return not _buses.is_empty()


func _ready() -> void:
	for channel in settings.channels():
		if _buses.has(channel.bus):
			_add_row(channel)
	(%Restore as Button).pressed.connect(func() -> void: settings.restore_defaults())
	(%Back as Button).pressed.connect(closed.emit)
	settings.changed.connect(_show)
	_show()


func focus_first() -> void:
	if not _sliders.is_empty():
		_sliders[0].grab_focus()


## The slider of a bus. For benches.
func slider_of(bus: StringName) -> HSlider:
	var index := _buses.find(bus)
	return _sliders[index] if index >= 0 else null


func _add_row(channel: TgcAudioChannel) -> void:
	var caption := Label.new()
	# A key: the Label translates it, and follows the language.
	caption.text = channel.label
	_grid.add_child(caption)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(320.0, 0.0)
	row.add_theme_constant_override(&"separation", 14)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = TgcAudioSettings.STEP * 100.0
	var bus := channel.bus
	slider.value_changed.connect(func(value: float) -> void: settings.set_volume(bus, value / 100.0))
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(64.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# A number, not a key.
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(value)
	_grid.add_child(row)
	_sliders.append(slider)
	_values.append(value)


## Shows the volumes **without** emitting again: a slider set by the code is not a choice of
## the player's.
func _show() -> void:
	for index in _buses.size():
		var volume := settings.volume(_buses[index])
		_sliders[index].set_value_no_signal(volume * 100.0)
		_values[index].text = "%d %%" % roundi(volume * 100.0)
