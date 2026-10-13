# TGC Game Menu

A main menu and a pause menu for Godot 4, with the settings players expect, configured
from a single resource.

- **One menu, two faces.** At start, the game's title, *Play*, *Settings* and *Quit*.
  During a game, *Paused*, *Resume*, *New game*, *Settings*, *Main menu* and *Quit*. *Quit*
  hides itself in a web build.
- **A Settings sub-menu** lists the pages below. *Back*, Esc or the gamepad's B goes up one
  level at a time — page, sub-menu, root — and the focus comes back to the button you left.
- **General**: the language, offered from **your game's** translations, each named in its
  own language, with *System language* (which reads the browser's interface language on
  the web, not just its first preferred one).
- **Display**: window mode (windowed, maximized, fullscreen), window size (only sizes with
  the screen's aspect ratio that fit on it), vsync, frame rate limit, 3D render scale, MSAA,
  interface size. Each row can be hidden. The defaults are what your project settings say.
- **Sound**: one slider per audio bus you name, heard on a perceptual curve (half the
  slider is a quarter of the gain, about −12 dB), muting the bus at zero.
- **Controls**: keyboard-and-mouse and gamepad columns, two slots each by default,
  remapped on screen. Remapping the keyboard never touches the gamepad. A key given to one
  action is taken from the one that had it. The pause always keeps a keyboard key. Keys are
  named as they are **engraved** on the player's keyboard (Z on an AZERTY for the W
  position), gamepad buttons for both families of pads ("A / Cross").
- **Confirmation before losing a game.** During a game, *New game*, *Main menu* and *Quit*
  first ask, in a modal whose focus starts on *Cancel* and cannot wander off. *Quit* asks
  from the main menu too. Right after a save or a load, there is nothing to lose, and
  nothing is asked.
- **Saving and loading, optional**: *Save* and *Load* pages listing the slots with their
  date and your summary, quick save and quick load on remappable shortcuts (F5, F9), a
  number of slots of each kind, optional *Delete*. **Your code does the saving**: the menu
  only calls it.
- **A live preview in the editor** (`TgcMenuPreview`): any screen, any language, your
  config and theme, redrawn as you edit them — without running the game.
- **Your own pages** after the built-in ones, each with its button in the sub-menu.
- **Settings saved at each change and read back without trusting the file**: wrong types,
  values off the list, unreadable inputs all fall back on the defaults instead of crashing.
  Inputs are stored as readable text (`t:87`, `b:0`, `a:1:+`), never as serialised objects.
- **Gamepad navigation out of the box**: `ui_accept` and `ui_cancel` get A and B when they
  have no gamepad button, which is the case of Godot's defaults.
- Translated into **English, French, German and Spanish**.

No dependency, no asset: one theme, one icon, a CSV catalogue.

Requires **Godot 4.7** (developed and tested on 4.7.2).

## Install

1. Copy `addons/tgc_game_menu/` into your project (or install it from the Asset Store).
2. *Project > Project Settings > Plugins*: enable **TGC Game Menu**. This registers the
   add-on's translations, and declares a `game_pause` action (Esc, Start) if you have none.
3. Add a **TgcMenuSession** node to your main scene.

That already gives a working menu, with the add-on's `default_menu_config.tres`. Then
connect your game to it:

```gdscript
@onready var _session: TgcMenuSession = $MenuSession
@onready var _game: MyGame = $Game

func _ready() -> void:
	_session.game_started.connect(_game.start)   # "Play", "New game"
	_session.game_stopped.connect(_game.stop)    # "Main menu", "New game", "Quit"
```

Your game does not need to know whether it is paused: the session pauses the tree, so make
sure the game's nodes are pausable (Godot's default) and that what must go on in pause
(music, interface sounds) is set to `PROCESS_MODE_ALWAYS`. A game that ends by itself calls
`_session.to_main_menu()`.

## Configure: `TgcMenuConfig`

Create a **TgcMenuConfig** resource (or duplicate `default_menu_config.tres`), edit it in
the Inspector, and assign it to the session's `config`. Everything has a working default.

| Group | Field | What it does |
| --- | --- | --- |
| Menu | `title` | Main menu title: a translation key or plain text. Empty: the project's name. |
| | `start_on_main_menu` | Off: a game starts at once, and the menu is only a pause menu. |
| | `pause_on_focus_loss` | Pause when the window loses the focus during a game. |
| | `hide_quit_on_web` | Hide *Quit* in a web build. |
| | `confirm_progress_loss` | Ask before *New game*, *Main menu* and *Quit* abandon a game in progress. Off for a game that saves all the time. |
| | `confirm_quit` | *Quit* asks even from the main menu, with no game in progress. |
| | `pause_action` | The action that opens and closes the pause menu (`game_pause`). |
| | `theme` | The menu's theme. Empty: your project's theme. |
| | `menu_scene` | Your own copy of `menu/tgc_game_menu.tscn`, to restyle the root. |
| Pages | `show_*_page` | Hide a built-in page. A page with nothing to show hides itself (General with a single language, Sound with no bus); with no page at all, *Settings* hides too. |
| | `extra_pages` | Your own pages (see below). |
| Languages | `languages` | The languages offered. Empty: those of your translations. |
| Display | `show_*` | Hide a row (MSAA and render scale mean nothing to a 2D game). |
| | `fps_limits`, `ui_scales`, `min_render_scale` | The values offered. `0` fps is *Unlimited*. |
| Sound | `audio_channels` | One **TgcAudioChannel** per slider: bus, caption key, default volume. Empty: the master volume alone. |
| Controls | `remappable_actions` | One **TgcRemappableAction** per row, in order: action, caption key, `essential`. Empty: the pause action alone. |
| | `slots_per_family` | Inputs per action and per family (1 to 4). |
| | `show_gamepad_column` | Off for a game not played with a gamepad. |
| | `capture_timeout` | Seconds the Controls page waits for an input. |
| | `gamepad_ui_buttons` | Give `ui_accept` / `ui_cancel` the A / B buttons when they have none. |
| Saves | `enable_saves` | *Save*, *Load*, the quick save and the quick load. Off by default. |
| | `save_slots` | Slots of the *Save* page (0: quick saves only). |
| | `quick_save_slots` | Slots the quick save writes in turn: the empty one first, then the oldest (0: no quick save). |
| | `allow_delete_saves` | A *Delete* button on each save, which asks first. |
| | `quick_save_action`, `quick_load_action` | The shortcuts' actions, added to the Controls page. Created with F5 and F9 if your project does not declare them. |
| | `show_save_notifications` | A short message on screen after a quick save or a quick load. |
| Files | `*_file` | Where the settings are saved (`user://settings_*.cfg`). |

The remappable actions must be declared in *Project Settings > Input Map*: their inputs
there are the defaults that *Restore default controls* brings back.

## Saving and loading

The add-on never knows how your game is saved. Turn `enable_saves` on, extend
**TgcSaveProvider**, and hand an instance to the session:

```gdscript
class_name MySaves
extends TgcSaveProvider

func save_game(slot: TgcSaveSlot) -> Error:        # write your state for slot.id
	...
func load_game(slot: TgcSaveSlot) -> Error:        # restore it over a fresh game
	...
func delete_save(slot: TgcSaveSlot) -> Error:
	...
func describe(slot: TgcSaveSlot) -> TgcSaveInfo:  # null when the slot is empty
	return TgcSaveInfo.new(saved_at_unix_time, "Chapter 3 — Harbour")
func can_save() -> bool:                           # optional: false in a cut-scene
	return true
```

```gdscript
_session.saves = MySaves.new(...)
```

- `slot.id` is `save_1`, `save_2`… or `quick_1`, `quick_2`…: key your storage with it.
- **Loading starts a game**: the session emits `game_stopped` (if one is running), then
  `game_started`, then calls `load_game()`. Restore your state over the fresh game.
- What `describe()` returns is shown as is; anything but a `TgcSaveInfo` counts as empty.
  Keep it cheap: it is called each time a page lists the slots.
- **Save** lists the regular slots; an empty one saves at once, a full one asks before
  overwriting. **Load** lists every save, regular and quick, the most recent first, and asks
  before abandoning a game whose progress is at risk. **Delete** always asks.
- **The quick save** (F5) writes the first empty quick slot, else the oldest; **the quick load**
  (F9) loads the most recent quick save. Both work during a game, menu open or not, and say
  what happened on screen. If the game has run since it was last saved, the quick load asks
  first: the game freezes under the modal alone, and *Cancel* lets it go on.
- An autosave is `session.save_to(slot)`, from your own code.

The demo's `demo/demo_saves.gd` is a complete provider: one small file per slot, read back
without trusting it.

## Preview in the editor

Open `preview/tgc_menu_preview.tscn`, or better, add a **TgcMenuPreview** node to a scene of
your own, and set in the Inspector:

| Field | |
| --- | --- |
| `config` | Your `TgcMenuConfig` (empty: the add-on's default). |
| `theme_override` | A theme to try instead of the config's. |
| `screen` | Main menu, pause menu, Settings, one page (`page`: `general`, `display`, `sound`, `controls`, or yours), Save, Load, a confirmation, a notification. |
| `locale` | The preview's language: any your game or the add-on speaks. |
| `filled_slots` | How many made-up saves the Save and Load pages show. |
| `background_color`, `background` | What lies behind the menu: a colour, or a screenshot of your game. |

Edit the theme the menu uses — the config's, or your project's (`gui/theme/custom`) — and the
preview follows at once; change the config or the screen and it redraws within half a second
(the **Redraw** button forces it). Resize the node to see the menu at another resolution.

**The preview touches nothing**: no file read or written, no input action created, neither
the editor's language nor the game's changed (it speaks through a translation domain of its
own). The saves it shows do not exist.

Your own pages are drawn live if their script is a tool script (`@tool`, with a `_ready()`
that does nothing harmful in the editor); otherwise they are shown as their scene draws
them. The add-on's scripts are all tool scripts for this reason, and do nothing at all in the
editor unless a preview drives them: a `TgcMenuSession` in a scene you open reads no file and
touches nothing.

## Your game's help reads the Input Map

Never write key names by hand: they would lie at the first remapping. Ask the add-on:

```gdscript
_help.text = tr("HELP_JUMP") % TgcInputLabels.first_of(&"jump", false)  # true: gamepad
```

and redo it on `controls_changed` and on `NOTIFICATION_TRANSLATION_CHANGED`.

## Your own page

A scene whose root extends **TgcMenuPage**, with a unique `page_id` and a `title` (a
translation key), whose *Back* button emits `closed` (back up to the Settings sub-menu).
List it in `extra_pages`; its button appears in the sub-menu, after the built-in pages'. The page
shows your settings and changes them; your game applies and saves them. Give it your
settings once the session is ready:

```gdscript
(_session.menu().page(&"gameplay") as GameplayPage).bind(_gameplay_settings)
```

Override `setup(session)`, `is_relevant()`, `focus_first()` and `leave()` as needed.

## Translations

The add-on's texts are keys prefixed `TGC_`, in `i18n/tgc_game_menu.csv`; they never collide
with yours. The languages offered to the player are **your game's**, never the add-on's: an
English-only game does not offer French because its menu happens to speak it. A game with
no translation at all keeps the menu in the project's fallback locale.

To add a language your game speaks and the add-on does not: add `TGC_*` keys for it to your
own catalogue (`TGC_LANGUAGE_SELF` is the language's name in itself), or contribute a column
to the add-on's CSV.

## The session's API

| Member | |
| --- | --- |
| `game_started`, `game_stopped` | Start and stop your game. |
| `paused_changed(paused)` | The tree was paused or resumed. |
| `controls_changed(bindings)` | A control was remapped: refresh your on-screen help. |
| `play()`, `resume()`, `pause()`, `toggle_pause()`, `to_main_menu()`, `quit()` | What the buttons do, for your own code and your tests. |
| `is_paused()`, `is_in_game()`, `menu()` | |
| `progress_at_risk` | Whether the game has run since it was last saved or loaded. The session keeps it: false after a save or a load, true again as soon as the game runs. The confirmations only appear while it is true. |
| `saves` | Your `TgcSaveProvider`. |
| `save_to(slot)`, `load_from(slot)`, `delete_save(slot)`, `quick_save()`, `quick_load()` | What the pages and the shortcuts call; an autosave calls `save_to`. |
| `save_slots()`, `quick_slots()`, `existing_saves()`, `describe(slot)`, `can_save()` | |
| `saved(slot)`, `loaded(slot)`, `save_deleted(slot)` | Signals. |
| `general`, `display`, `audio`, `bindings` | The settings: observable objects (`changed`) that the session applies and saves. |

For automated tests that must not touch the player's files, give the session a copy of the
config whose files are renamed: `config.redirected("test_")`, **before** it enters the
tree.

## License

MIT — see `LICENSE.txt`. © 2026 Ulric — TheGameCraftsman.
