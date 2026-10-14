# The Asset Store listing

What goes into the form of the [Godot Asset Store](https://store.godotengine.org/), field by
field, as submitted. Kept here so that the next version starts from it. The rules come from
[Submitting to the Asset Store](https://docs.godotengine.org/en/4.7/community/asset_store/submitting_to_asset_store.html)
and the store's [guidelines](https://store.godotengine.org/guidelines/): English first, full
sentences, a 16:9 thumbnail, tags that are not the asset's name, the store's license matching
`LICENSE`, AI use disclosed.

## Upload Asset (first page)

| Field | Value |
| --- | --- |
| Publisher name | `TheGameCraftsman` |
| Publisher URL slug | `thegamecraftsman` |
| Asset name | `TGC Game Menu` |
| Asset URL | `tgc-game-menu` |

## Settings

**Asset summary**

> A main menu and a pause menu for Godot 4.7, configured from one resource: display, sound, remappable keyboard, mouse and gamepad controls, optional saves, and a live preview in the editor.

**Detailed description**

```text
TGC Game Menu gives your game the main menu, pause menu and settings that players expect, configured from a single resource in the Inspector. Add one node to your main scene, connect two signals to your game, and the menu works.

What it does:
- One menu, two faces: the main menu at start, the pause menu during a game (Esc, Start, or the window losing the focus).
- A Settings sub-menu with General, Display, Sound and Controls pages. Every row and every page is optional, and your own pages can be added after them.
- Display: window mode, window size, vsync, frame rate limit, 3D render scale, MSAA and interface size, with your project settings as defaults.
- Sound: one slider per audio bus, on a perceptual curve.
- Controls: keyboard-and-mouse and gamepad columns remapped on screen. Remapping one never touches the other, a key given to an action is taken from the one that had it, the pause always keeps a key, and keys are named as they are engraved on the player's keyboard (AZERTY, QWERTZ and others).
- Saving and loading, if you want them: save slots, quick saves on remappable shortcuts (F5 and F9), a Load page listing the saves with their date and your own summary, and optional deletion. Your code does the saving through one small class; the menu only calls it.
- No game lost by mistake: New game, Main menu and Quit ask first while a game is in progress.
- A live preview in the editor: pick a screen and a language, edit your theme or your config, and see the menu change without running the game.
- Settings are saved at each change and read back without trusting the file: a damaged file falls back on the defaults instead of crashing the game.
- Translated into English, French, German and Spanish. The menu offers your game's languages, not the add-on's.

The add-on has no dependency and ships no asset beyond its theme, its icon and its translations. It requires Godot 4.7 and was tested on 4.7.2.

After installing, enable "TGC Game Menu" in Project Settings > Plugins, then add a TgcMenuSession node to your main scene. The full reference is in addons/tgc_game_menu/README.md, with a French version in README.fr.md.

En français : TGC Game Menu donne à votre jeu un menu principal, un menu de pause et des réglages (affichage, son, commandes remaniables, sauvegardes en option), réglés depuis une seule ressource, avec un aperçu en direct dans l'éditeur. La documentation complète existe en français : addons/tgc_game_menu/README.fr.md.
```

**Tags** — `menu`, `main-menu`, `pause-menu`, `settings`, `options`, `input-remapping`,
`controls`, `gamepad`, `save-system`, `localization`, `ui`. If the store already offers a
tag in the other number (`menus`, `setting`…), take the existing one.

| Field | Value |
| --- | --- |
| Asset type | Addon |
| License | MIT |
| Link to source code | `https://github.com/TheGameCraftsman1971/tgc-game-menu` |

**AI usage disclosure**

```text
This add-on was developed with substantial help from Claude, an AI model by Anthropic. Most of the GDScript code, the automated checks, the documentation and the translations (French, German, Spanish) were written by the AI, under the author's direction and decisions. The author tested the result in Godot 4.7.2; the add-on's own test suite (220 automated checks, plus checks run inside the editor) passes. The icon and the thumbnail are drawn by code; the screenshots are captures of the menu itself. No AI-generated image, sound or 3D model is included.
```

## Media

| Field | File |
| --- | --- |
| Thumbnail (16:9) | `screenshots/store_thumbnail.png`, made by `tools/store_thumbnail.tscn` |
| Screenshots, in this order | `en_01_main_menu`, `en_02_settings`, `en_04_display`, `en_06_controls`, `en_11_editor_preview`, `en_09_pause`, `en_10_confirm`, `en_09_load`, `fr_09_save` (`.png`, in `screenshots/`) |
| Icon, if a link is asked | `https://raw.githubusercontent.com/TheGameCraftsman1971/tgc-game-menu/main/screenshots/store_icon.png` |

## Versions

| Field | Value |
| --- | --- |
| File | `tgc_game_menu-1.2.0.zip`, from the GitHub release `v1.2.0` (only `addons/tgc_game_menu/`) |
| Name | `1.2.0` |
| Minimum Godot version | 4.7 |
| Maximum Godot version | — |
| Changelog | the 1.2.0, 1.1.0 and 1.0.0 sections of `CHANGELOG.md` |
| Additional information | `Enable "TGC Game Menu" in Project Settings > Plugins after installing.` |

## Pricing

Free. No donation link for now. Reviews left on.

## Overview

**Submit**: the asset enters the review queue; a rejection comes with its reason.
