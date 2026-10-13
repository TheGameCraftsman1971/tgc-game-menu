class_name TgcGeneralPage
extends TgcMenuPage

## The General page: the language. It shows [TgcGeneralSettings] and changes it, nothing
## more: the Resource notifies (`changed`), and the session applies (the
## [TranslationServer]) and saves.
##
## The languages are the game's ([method TgcGeneralSettings.available_locales]), each named
## **in its own language**: a player lost in a language they cannot read must recognise
## theirs. With a single language there is nothing to choose, and the page is not shown.

var settings: TgcGeneralSettings
## The language codes offered, in the order of the list ("auto" first).
var _locales: Array[String] = []

@onready var _language: OptionButton = %Language


func setup(with_session: TgcMenuSession) -> void:
	super(with_session)
	settings = session.general


func is_relevant() -> bool:
	return settings.available_locales().size() > 1


func _ready() -> void:
	_language.item_selected.connect(func(index: int) -> void: settings.locale = _locales[index])
	(%Restore as Button).pressed.connect(func() -> void: settings.restore_defaults())
	(%Back as Button).pressed.connect(closed.emit)
	settings.changed.connect(_show)
	_show()


func focus_first() -> void:
	_language.grab_focus()


## The codes offered. For benches.
func locales() -> Array[String]:
	return _locales


## Shows the setting **without** emitting again: a choice made by the code is not a choice
## of the player's.
func _show() -> void:
	_locales = [TgcGeneralSettings.AUTO]
	_locales.append_array(settings.available_locales())
	_language.clear()
	for code in _locales:
		# "TGC_LANGUAGE_AUTO" is a key, which the OptionButton translates; a language's name
		# is not one, and goes through as it is.
		_language.add_item("TGC_LANGUAGE_AUTO" if code == TgcGeneralSettings.AUTO else TgcI18n.native_name(code))
	_language.select(maxi(_locales.find(settings.locale), 0))
