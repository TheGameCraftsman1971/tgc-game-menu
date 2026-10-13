@tool
class_name TgcI18n
extends RefCounted

## The add-on's own catalogue, kept apart from the game's. Static functions, no state.
##
## Every text the menu shows is a key of `tgc_game_menu.csv`, prefixed `TGC_` so that it can
## never collide with a key of the game. The plugin registers the compiled catalogues in the
## project settings when it is enabled, which is also what exports them; [method
## ensure_loaded] adds them at run time when it was not, so the menu never shows a raw key.
##
## **The add-on speaking a language does not mean the game does.** The languages offered to
## the player are those of the game's own catalogues ([method game_locales]), never the
## add-on's: an English-only game must not offer French because its menu happens to know it.
##
## A language the add-on lacks falls back on the project's fallback locale, as any missing
## key does in Godot. **One more language**: a column in the CSV, and its code in [constant
## LOCALES].

const DIR := "res://addons/tgc_game_menu/i18n/"
const CATALOG := "tgc_game_menu"
## The columns of the CSV.
const LOCALES: Array[String] = ["en", "fr", "de", "es"]


## The compiled catalogues, one per language, as the CSV importer writes them.
static func catalog_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for code in LOCALES:
		paths.append(DIR + CATALOG + "." + code + ".translation")
	return paths


## Adds the add-on's catalogues to the translation server, unless the project settings
## already did.
static func ensure_loaded() -> void:
	var loaded := PackedStringArray()
	for translation: Translation in TranslationServer.get_translations():
		loaded.append(translation.resource_path)
	for path in catalog_paths():
		if loaded.has(path) or not ResourceLoader.exists(path):
			continue
		var translation := load(path) as Translation
		if translation != null:
			TranslationServer.add_translation(translation)


## The languages of the game's own catalogues, without duplicates, sorted.
static func game_locales() -> PackedStringArray:
	var found := PackedStringArray()
	for translation: Translation in TranslationServer.get_translations():
		if translation.resource_path.begins_with(DIR):
			continue
		var code := translation.locale
		if code != "" and not found.has(code):
			found.append(code)
	found.sort()
	return found


## The name of a language **in that language** ("Français", "Deutsch"): a player lost in a
## language they cannot read must recognise their own. `TGC_LANGUAGE_SELF` of a catalogue of
## that language, the game's or the add-on's, else Godot's English name for it.
static func native_name(code: String) -> String:
	for translation: Translation in TranslationServer.find_translations(code, true):
		var name := String(translation.get_message(&"TGC_LANGUAGE_SELF"))
		if name != "":
			return name
	var english := TranslationServer.get_locale_name(code)
	return english if english != "" else code
