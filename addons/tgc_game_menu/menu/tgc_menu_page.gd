class_name TgcMenuPage
extends Control

## One page of the Settings sub-menu: a built-in one (General, Display, Sound, Controls), or one
## of the game's own ([member TgcMenuConfig.extra_pages]).
##
## A page shows settings and changes them, and nothing more. It does not apply them and does
## not save them: a setting is an observable Resource, and whoever holds it — the session
## for the built-in pages, the game for its own — applies and saves when it changes.
##
## **A page of the game's own**: a scene whose root extends this class, with a unique
## [member page_id] and a [member title], listed in [member TgcMenuConfig.extra_pages]. It
## gets its button in the Settings sub-menu, after the built-in pages'. Its "Back" button
## emits [signal closed]. The game gives it its settings through `session.menu().page(id)`,
## once the session is ready.

## The page wants to go back up to the Settings sub-menu.
signal closed

## The page's name, for [method TgcGameMenu.show_page]. Unique within a menu.
@export var page_id: StringName
## The caption of the button that opens the page from the Settings sub-menu: a translation
## key.
@export var title := ""

## The session the page serves, whose settings it shows. Set before the page enters the
## tree.
var session: TgcMenuSession


## Called by the menu **before** the page enters the tree.
func setup(with_session: TgcMenuSession) -> void:
	session = with_session


## False hides the page and its button: a language list with a single language, a sound page
## without a single bus.
func is_relevant() -> bool:
	return true


## Gives the focus to the page's first control, for the keyboard and the gamepad.
func focus_first() -> void:
	pass


## The page is being left: another page is shown, or the menu closes.
func leave() -> void:
	pass
