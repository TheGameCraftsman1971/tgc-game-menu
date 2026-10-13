# Changelog

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
