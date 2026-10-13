# Changelog

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
  `progress_at_risk` on the session for a game that has just saved.
- Catalogue in English, French, German and Spanish; the languages offered are the game's.
