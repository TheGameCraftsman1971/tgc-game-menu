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
  from the main menu too. A game that
  has just saved can say there is nothing to lose (`progress_at_risk = false`).
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
| Files | `*_file` | Where the settings are saved (`user://settings_*.cfg`). |

The remappable actions must be declared in *Project Settings > Input Map*: their inputs
there are the defaults that *Restore default controls* brings back.

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
| `progress_at_risk` | True when a game starts. Set it to false when the game has just saved, back to true when there is something new to lose: the confirmations only appear while it is true. |
| `general`, `display`, `audio`, `bindings` | The settings: observable objects (`changed`) that the session applies and saves. |

For automated tests that must not touch the player's files, give the session a copy of the
config whose files are renamed: `config.redirected("test_")`, **before** it enters the
tree.

## License

MIT — see `LICENSE.txt`. © 2026 Ulric — TheGameCraftsman.
