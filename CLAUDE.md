# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Godot 4.7 project that serves as the development bench and demo for **one deliverable
add-on**: `addons/tgc_game_menu/`. That folder is the product. Everything outside it
(`demo/`, `tools/`, `screenshots/`, `project.godot`, `icon.svg`) exists only to develop,
check and show it, and is **not** shipped (`.gitattributes`, `export-ignore`).

The add-on is a main menu and a pause menu with the player's settings — language, display,
volumes per bus, keyboard/mouse/gamepad controls remapped on screen — configured from one
resource (`TgcMenuConfig`). It is meant for the **Godot Asset Library / Asset Store**.

It was extracted from the TheGameCraftsman project template
(`../../___Template-Godot___/project/`, then `src/app/`, `src/menu/`, `src/settings/`), which
now **uses it**: the template holds a copy of `addons/tgc_game_menu/`, and so do the games
created from it. **This repository is the source.** A change is made here, checked by the
bench here, then copied into the template (and into the games that want it) with
`tools/install-into.sh <project>`, after which the template's own bench is run too. A fix made
in a copy is lost at the next copy.

## Language

**The add-on is written entirely in English**: identifiers, node names, docstrings (`##`),
comments, user documentation, error messages. Its user-facing **texts** are keys of its own
catalogue (`addons/tgc_game_menu/i18n/tgc_game_menu.csv`, `keys,en,fr,de,es`), all prefixed
`TGC_`, so they never collide with a game's.

**User documentation ships in two versions, English first.** While the add-on is being
worked on, only the English version is written; the French translation is made at the very
end of a release, so that the two never drift. Files: `README.md` (the store page) and
`addons/tgc_game_menu/README.md` (the reference, shipped).

Conversation with the author is in French. That is a separate matter from what gets written
to disk.

## Architecture reference

`BONNES-PRATIQUES-GODOT4-SOLID.md`, at the repository root, is **authoritative on
architecture**. It is deliberately **not** versioned (see `.gitignore`): a personal reference
kept beside each project it governs, not this repository's to publish. The add-on's code does
not cite its sections, since its readers do not have it. Check its §12 checklist before adding
a system.

What it has already decided here, and which must not be quietly undone:

- **§4/§10 — a Context, not an Autoload.** `TgcMenuSession` is a node the game places, and it
  holds the settings. There is no autoload: a game that has a menu of its own pays nothing.
- **The session is the only one that knows whether the game is paused.** The menu asks (signals
  up), the session decides; the game only learns that a game starts (`game_started`) or stops
  (`game_stopped`). The session never calls the game.
- **§5 — observable settings.** `TgcGeneralSettings`, `TgcDisplaySettings`,
  `TgcAudioSettings` (Resources) and `TgcControlBindings` (RefCounted, with its own `changed`)
  emit `changed`; the session applies and saves. A page only changes a field: it never
  applies, never saves.
- **§9 — configuration is data.** `TgcMenuConfig` is a Resource; nothing reads it after the
  session started, nothing writes to it. Benches work on `config.redirected(prefix)`.
- **§9 — Zero-Trust on the player's files.** Each value is checked for its type, then bounded
  or brought back among the allowed ones; inputs are plain text (`t:87`, `s:1`, `b:0`,
  `a:1:+`), never serialised objects.
- **The languages offered are the game's** (`TgcI18n.game_locales()`, which leaves out the
  add-on's own catalogue). That the menu speaks German must never make an English game offer
  German.
- **Display defaults are what the project declares** (window mode and size, vsync, max fps,
  3D scale, 3D MSAA). The config decides what is shown and offered, not the defaults.
- **§11 — YAGNI.** Four built-in pages and an extension point (`TgcMenuPage`,
  `extra_pages`). A game-specific setting is the game's: its own Resource, its own page, its
  own file.

## Branches

**One branch per piece of work, and merging is the author's call.** Create the branch before
the first edit, name it after the work, commit and push to it as you go — then stop. Announce
that the branch is ready; never merge, and never delete a merged branch, without being asked.
Anything that only states the convention goes straight to `main`.

## Commands

No build system, no linter. The Godot binary on this machine:

```
GODOT="/Applications/Godot v4.7.2.app/Contents/MacOS/Godot"
```

| Goal | Command |
|---|---|
| Run the demo | `"$GODOT" --path .` |
| **Import, and check every script parses** (rebuilds the class cache and the catalogues) | `"$GODOT" --headless --path . --editor --quit-after 150` |
| **The bench** — codec, remapping, damaged files, window sizes, catalogues, languages, then the demo mounted and played | `"$GODOT" --headless --path . res://tools/checks.tscn` |
| **Screenshots** of every page (opens a window), in `captures/` | `"$GODOT" --path . res://tools/capture.tscn --resolution 1600x900 -- en fr de es` |
| **Copy the add-on into a project** (the template, a game) | `tools/install-into.sh <project folder>` |

The bench exits non-zero on failure, and also fails on a script error raised along the way
(`tools/bench_log.gd`): an error in the middle of a check interrupts it silently otherwise.
macOS has no `timeout`: `perl -e 'alarm shift; exec @ARGV' 120 "$GODOT" …`. After changing
the CSV, run the import before the bench. `screenshots/` holds the pictures of the store page,
chosen among `captures/`.

## Verified pitfalls

| Pitfall | Symptom | The rule |
|---|---|---|
| **A `Dictionary` saved in a `.tres`** | its keys come back **sorted**: the order the game chose is lost | an ordered list of small Resources (`TgcRemappableAction`, `TgcAudioChannel`) |
| **`ui_accept` and `ui_cancel` have no gamepad button** in Godot 4.7 | the menu is browsed with the D-pad but nothing confirms | the session gives them A and B at run time (`gamepad_ui_buttons`) |
| On the web, `OS.get_locale()` is the browser's **first preferred language**, not its interface's | an English Chrome preferring French pages opens the game in French on "System language" | `TgcSystemLanguage`: `Intl` first, then the preferred languages |
| `keyboard_get_label_from_physical` headless or on the web | one error per key named | `TgcInputLabels.knows_keyboard_layout()` |
| **macOS gives a window leaving fullscreen its old position back**, after the animation | the window comes back off-centre | `TgcDisplaySettings._size_window` places it again 0.8 s later |
| The wait for an input read in `_unhandled_input` | the left click cannot be bound, the hovered button takes it | read it in `_input`, keep presses only |
| Default inputs read from the InputMap | "Reset" restores what an earlier instance remapped | read them from `ProjectSettings` (`input/<action>`); an undeclared action is snapshotted when the bindings are built |
| A property set **after** `add_child` | `_ready()` has already read the player's files | set `TgcMenuSession.config` before `add_child` |
| A page built before `setup()` | `_ready()` finds no session | the menu calls `setup(session)` **before** adding the page; the session does the same for the menu |
| The tree's root is pausable, but a bench parent may not be | a game under a `PROCESS_MODE_ALWAYS` bench node never pauses | the demo's `World` declares `process_mode = PAUSABLE` itself |
| A lambda captures locals **by value** | a signal counter stays at zero, and the check passes | count in an array |
| A fabricated click does not reach `_unhandled_input()` headless | a bench that "clicks" triggers nothing | play through public methods (`session.play()`, `page.assign()`) |

## Invariants

- **The add-on never reads nor writes a player file outside its four settings objects**, at
  the paths of the config.
- **A bench never reads nor writes the player's files**, and checks it (fingerprint in, out).
  The InputMap is global: a bench that remaps restores the defaults on its way out.
- **A file read from disk never crashes the game.**
- **No text on screen outside a catalogue**, and no catalogue with a hole: the bench checks
  the add-on's and the demo's, every key used, and that every add-on key starts with `TGC_`.
- **A check never recomputes what the code it checks computes**: expected values are written
  by hand.

## Where this stands

Version **1.0.0**, the first: extracted, checked (bench: 128 checks), installed back into the
template (its own bench: 48 checks). The GitHub repository is private like the other add-ons.
Not yet submitted to the Asset Library: making the repository public and filling in the store
page (`README.md`, `screenshots/`) is the author's call. The French translation of the user
documentation is to be done at that point.
