# Changelog

## 1.3.0 — unreleased

- **A pause menu for applications**, not only games: `pause_title` gives the pause menu a
  title of its own (the application's name, for a menu behind a button), `show_new_game`
  and `show_main_menu_button` hide *New game* and *Main menu*. With `start_on_main_menu`
  off, a metronome, a tool or an editor opens straight on its screen, and its menu keeps
  only *Resume*, *Settings* and *Quit*. `wording` set to `APPLICATION` makes *Quit game*
  say *Quit*, and its question *Quit?*, in the four languages.
- **A drop-down menu**: `presentation` set to `DROP_DOWN` hangs the root and *Settings*
  under a button of the game (`TgcGameMenu.drop_from()`), unrolls them from it and rolls
  them back into it (`drop_down_seconds`), over a lighter veil a click on which closes the
  menu. `TgcMenuSession.toggle_menu()` is a menu button's gesture: open, or close whatever
  the menu shows. The defaults change nothing.

## 1.2.0 — 2026-10-13

- **A live preview of the menu in the editor**: `TgcMenuPreview`, with a config, a theme to
  try, a screen (main menu, pause menu, Settings, a page, Save, Load, a confirmation, a
  notification), a language, made-up saves and a background. A theme edit shows at once; a
  config edit redraws it. It touches nothing: no file, no input action, no language but its
  own translation domain. The page and the language are picked from lists (the config's
  pages, the languages the add-on or the game speaks); the page shows only for the screen
  that needs it. A redraw never takes the focus from the editor's field being typed in.
- The documentation in French: `README.fr.md`, beside each `README.md`.
- Every script of the add-on is a tool script, and does nothing in the editor unless a preview
  drives it. A game's page is drawn live if its script is a tool, as its scene draws it
  otherwise.

## 1.1.0 — 2026-10-13

- Saving and loading, off by default (`enable_saves`): **Save** and **Load** pages at the
  root, a number of regular and quick slots, quick save and quick load on remappable
  shortcuts (F5, F9, added to the Controls page), optional **Delete** (`allow_delete_saves`),
  a short message on screen after a shortcut. The game does the saving through a
  `TgcSaveProvider` it hands to the session; the menu never knows how.
- Loading over a game at risk — from the Load page or with the quick load —, overwriting a
  save and deleting one ask first. The quick load's question freezes the game under the modal
  alone; "Cancel" lets it go on.
- `progress_at_risk` is kept by the session: false after a save or a load, true again as
  soon as the game runs.

## 1.0.0 — 2026-10-13

First version, extracted from the TheGameCraftsman Godot project template, where the menu,
the settings and the remappable controls had been written and checked first.

- `TgcMenuSession`: the pause, the main menu and the pause menu, the player's settings.
- `TgcMenuConfig`: everything a game decides, in one resource.
- A Settings sub-menu with the pages: General (language), Display, Sound (one slider per
  bus), Controls (keyboard and mouse, gamepad), and the game's own pages (`TgcMenuPage`).
  Going back climbs one level at a time and gives the focus back to the button left.
- Confirmations before "New game", "Main menu" and "Quit" abandon a game in progress: a
  modal with the focus on "Cancel", trapped there; `confirm_progress_loss` in the config,
  `progress_at_risk` on the session for a game that has just saved. "Quit" asks from the
  main menu too (`confirm_quit`), without the line about what would be lost.
- Catalogue in English, French, German and Spanish; the languages offered are the game's.
