@tool
class_name TgcSystemLanguage
extends RefCounted

## The system's language, for the "System language" choice ([constant
## TgcGeneralSettings.AUTO]). Static functions, no state.
##
## On desktop and mobile, it is the one the OS gives Godot. On the web, Godot reads the
## browser's **first preferred language** for pages ([code]navigator.languages[0][/code]),
## which is not necessarily the system's: a Chrome whose interface is in English (macOS's)
## may prefer French pages. So the **language of the browser's interface** comes first
## ([code]Intl[/code], which follows the system until the user changes it), then the
## preferred languages. Checked in Chrome with preferred languages "fr-FR, fr, en" and an
## English interface: [code]navigator.languages[0][/code] = fr-FR, [code]Intl[/code] = en-GB.

## What the browser says, from the language of its interface to its preferred languages.
const WEB_QUERY := "[Intl.DateTimeFormat().resolvedOptions().locale].concat(navigator.languages || [navigator.language]).join(',')"


## The first language of the system that the game speaks, else `fallback`.
static func detect(supported: PackedStringArray, fallback: String) -> String:
	return pick(candidates(), supported, fallback)


## The system's languages, in the order to try them ("en-GB", "fr_BE"…).
static func candidates() -> PackedStringArray:
	if OS.has_feature("web"):
		var answer: Variant = JavaScriptBridge.eval(WEB_QUERY, true)
		if answer is String and answer != "":
			return (answer as String).split(",", false)
	return PackedStringArray([OS.get_locale()])


## The first of `candidates` that the game speaks — only the language counts: "en-GB" and
## "en_BE" are English —, else `fallback`. Pure computation.
static func pick(candidates: PackedStringArray, supported: PackedStringArray, fallback: String) -> String:
	for candidate in candidates:
		var language := candidate.strip_edges().replace("-", "_").get_slice("_", 0).to_lower()
		if supported.has(language):
			return language
	return fallback
