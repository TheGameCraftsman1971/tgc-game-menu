@tool
class_name TgcGeneralSettings
extends Resource

## The player's general settings. The add-on puts only the **language** here.
##
## An **observable** Resource: every change emits `changed`. [TgcMenuSession] applies the
## language to the [TranslationServer] and saves; the General page only changes a field.
##
## ## The languages come from the game's catalogues
##
## No list of languages is written here: they are those of the game's own translations
## ([method TgcI18n.game_locales]), or those [member TgcMenuConfig.languages] names. `"auto"`
## follows the system's language when the game speaks it ([TgcSystemLanguage], which reads
## the browser's interface language on the web), and the project's fallback locale
## otherwise. A game with no translation of its own keeps its menu in the fallback locale,
## so that the menu and the game speak the same language.
##
## The file lives in `user://`, so anyone can write anything in it: each value is checked
## for its type, then brought back among the allowed ones. A damaged value falls back on the
## default and never crashes the game.

const AUTO := "auto"
const _SECTION := "general"

var locale := AUTO:
	set(value):
		value = value if value == AUTO or available_locales().has(value) else AUTO
		if value != locale:
			locale = value
			_notify()

var path := "user://settings_general.cfg"

var _languages := PackedStringArray()
var _quiet := false


func _init(menu_config: TgcMenuConfig = null) -> void:
	var config := menu_config if menu_config != null else TgcMenuConfig.new()
	_languages = config.languages.duplicate()
	_languages.sort()
	path = config.general_file


## The languages offered, without duplicates, sorted.
func available_locales() -> PackedStringArray:
	return _languages if not _languages.is_empty() else TgcI18n.game_locales()


## The language actually used: the one chosen, or the system's if the game speaks it, or
## the project's fallback locale.
func effective_locale() -> String:
	var known := available_locales()
	var fallback := String(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))
	if known.is_empty():
		return fallback
	if locale != AUTO and known.has(locale):
		return locale
	if not known.has(fallback):
		fallback = known[0]
	return TgcSystemLanguage.detect(known, fallback)


func apply() -> void:
	TranslationServer.set_locale(effective_locale())


func load_from_disk() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	_quiet = true
	var stored: Variant = file.get_value(_SECTION, "language", locale)
	if stored is String:
		locale = stored
	_quiet = false
	emit_changed()
	return true


func save() -> bool:
	var file := ConfigFile.new()
	file.set_value(_SECTION, "language", locale)
	var error := file.save(path)
	if error != OK:
		push_warning("TGC Game Menu: general settings not saved (%d): %s" % [error, path])
	return error == OK


func restore_defaults() -> void:
	_quiet = true
	locale = AUTO
	_quiet = false
	emit_changed()


## Notifies, except while reading the file back: a file of ten settings must not have them
## applied ten times.
func _notify() -> void:
	if not _quiet:
		emit_changed()
