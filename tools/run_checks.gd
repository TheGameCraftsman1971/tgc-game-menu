extends Node

## The add-on's bench: the pure logic, the catalogues, then the demonstration mounted in the
## tree and played through the session's public methods.
##
##   godot --headless --path . res://tools/checks.tscn
##
## It is a **scene** and not a script run by `--script`, so that it runs in the same
## conditions as a game. There is no linter and no third-party test framework here: **this
## bench is the test**, and `--editor --quit-after` is the syntax check. A check never
## recomputes what the code it checks computes: expected values are written by hand.
##
## It exits with a non-zero code on failure, and also fails on a script error raised along
## the way ([BenchLog]).

const DEMO_SCENE := preload("res://demo/demo.tscn")
const DEMO_CONFIG := preload("res://demo/demo_menu_config.tres")
const ADDON_CATALOG := "res://addons/tgc_game_menu/i18n/tgc_game_menu.csv"
const DEMO_CATALOG := "res://demo/i18n/demo.csv"
## Every file the bench writes is renamed with this: never the player's own settings.
const PREFIX := "bench_"

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("\n=== TGC Game Menu — bench ===\n")
	var player_files := _fingerprint(DEMO_CONFIG.player_files())
	var bench_log := BenchLog.new()
	_remove_bench_files()
	_check_codec()
	_check_bindings()
	_check_undeclared_action()
	_check_zero_trust()
	_check_display_sizes()
	_check_catalogs()
	_check_languages()
	await _check_demo()
	await _check_default_config()
	await _check_no_main_menu()
	_remove_bench_files()
	_section("Player files")
	_expect(_fingerprint(DEMO_CONFIG.player_files()) == player_files,
			"the bench neither created nor changed the player's settings")
	_expect(bench_log.script_errors() == 0, "no script error: every check ran to its end",
			"%d error(s), see the log" % bench_log.script_errors())
	print("\n--- %d check(s) passed, %d failure(s) ---\n" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _expect(condition: bool, label: String, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s%s" % [label, ("  — " + detail) if detail != "" else ""])


func _section(title: String) -> void:
	print("\n[%s]" % title)


func _bench_config() -> TgcMenuConfig:
	return DEMO_CONFIG.redirected(PREFIX)


func _remove_bench_files() -> void:
	for path in _bench_config().player_files():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _fingerprint(paths: PackedStringArray) -> Dictionary:
	var prints := {}
	for path in paths:
		prints[path] = "%s %d" % [FileAccess.get_md5(path), FileAccess.get_modified_time(path)] \
				if FileAccess.file_exists(path) else "absent"
	return prints


static func _key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	return event


# --- Inputs in plain text -------------------------------------------------------------

func _check_codec() -> void:
	_section("Inputs in plain text")
	_expect(TgcControlBindings.encode(_key(KEY_W)) == "t:87", "a key is written by its physical position")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	_expect(TgcControlBindings.encode(click) == "s:2", "a mouse button is written by its number")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.8
	_expect(TgcControlBindings.encode(stick) == "a:1:-", "an axis is written with its direction, not its strength")
	for text: String in ["t:87", "s:2", "b:6", "a:1:-"]:
		var event := TgcControlBindings.decode(text)
		_expect(event != null and TgcControlBindings.encode(event) == text, "\"%s\" reads back as itself" % text)
	for text: String in ["", "t", "t:-4", "t:abc", "s:12", "b:999", "a:1", "a:1:*", "a:42:+", "z:3"]:
		_expect(TgcControlBindings.decode(text) == null, "\"%s\" is refused" % text)
	_expect(TgcControlBindings.decode("b:0").device == -1, "an input read back answers to every gamepad")


func _check_bindings() -> void:
	_section("Remapping")
	var config := _bench_config()
	var bindings := TgcControlBindings.new(config)
	bindings.restore_defaults()
	var expected: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right",
			&"action_primary", &"game_pause"]
	_expect(bindings.actions() == expected, "the actions keep the config's order, through the .tres",
			str(bindings.actions()))
	_expect(bindings.label_of(&"action_primary") == "ACTION_JUMP", "each action has its caption key")
	_expect(bindings.is_essential(&"game_pause") and not bindings.is_essential(&"move_left"),
			"only the pause is essential")
	_expect(bindings.events(&"move_forward", TgcControlBindings.Family.KEYBOARD).size() == 2,
			"\"Move up\" has two keyboard inputs (W and ↑)")
	_expect(bindings.events(&"move_forward", TgcControlBindings.Family.PAD).size() == 2,
			"and two gamepad ones (stick and D-pad)")
	var changes := [0]
	bindings.changed.connect(func() -> void: changes[0] += 1)
	_expect(bindings.bind(&"move_back", TgcControlBindings.Family.KEYBOARD, 0, _key(KEY_W)),
			"W can go to \"Move down\"")
	_expect(changes[0] == 1, "a remapping is announced")
	_expect(bindings.holder_of(_key(KEY_W)) == &"move_back", "W is \"Move down\"'s")
	_expect(bindings.events(&"move_forward", TgcControlBindings.Family.KEYBOARD).size() == 1,
			"and \"Move up\" lost it: a key never triggers two actions")
	_expect(bindings.events(&"move_back", TgcControlBindings.Family.PAD).size() == 2,
			"remapping the keyboard does not touch the gamepad")
	_expect(not bindings.can_bind(&"move_left", TgcControlBindings.Family.KEYBOARD, _key(KEY_ESCAPE)),
			"Esc cannot leave \"Pause\", whose last key it is")
	_expect(not bindings.clear(&"game_pause", TgcControlBindings.Family.KEYBOARD, 0),
			"the last key of \"Pause\" cannot be cleared")
	_expect(not bindings.can_bind(&"move_left", TgcControlBindings.Family.PAD, _key(KEY_J)),
			"a key does not go in the gamepad column")
	_expect(bindings.save(), "the controls are saved")
	bindings.restore_defaults()
	_expect(bindings.holder_of(_key(KEY_W)) == &"move_forward", "\"Reset\" gives W back to \"Move up\"")
	_expect(bindings.load_from_disk(), "the file reads back")
	_expect(bindings.holder_of(_key(KEY_W)) == &"move_back", "and gives W to \"Move down\" again")
	bindings.restore_defaults()

	var one_slot := _bench_config()
	one_slot.slots_per_family = 1
	var narrow := TgcControlBindings.new(one_slot)
	_expect(narrow.slots == 1, "the number of slots comes from the config")
	_expect(narrow.bind(&"move_left", TgcControlBindings.Family.KEYBOARD, 3, _key(KEY_J)),
			"a slot out of range is brought back to the last one")
	_expect(narrow.events(&"move_left", TgcControlBindings.Family.KEYBOARD)[0].physical_keycode == KEY_J,
			"and J took it")
	narrow.restore_defaults()


## An action the project does not declare (the session creates the pause action when it is
## missing) takes its defaults from the InputMap at construction, not from the settings.
func _check_undeclared_action() -> void:
	_section("Undeclared action")
	var action := &"bench_undeclared"
	InputMap.add_action(action)
	InputMap.action_add_event(action, _key(KEY_K))
	var config := _bench_config()
	var entries: Array[TgcRemappableAction] = [TgcRemappableAction.make(action, "TGC_ACTION_PAUSE")]
	config.remappable_actions = entries
	var bindings := TgcControlBindings.new(config)
	_expect(bindings.defaults_of(action) == PackedStringArray(["t:75"]), "its defaults are what it had")
	bindings.bind(action, TgcControlBindings.Family.KEYBOARD, 0, _key(KEY_L))
	bindings.restore_defaults()
	_expect(bindings.holder_of(_key(KEY_K)) == action, "and \"Reset\" brings them back")
	InputMap.erase_action(action)


# --- Zero-Trust: a damaged file never crashes the game --------------------------------

func _check_zero_trust() -> void:
	_section("Damaged files")
	var config := _bench_config()
	var file := ConfigFile.new()
	file.set_value("general", "language", "klingon")
	file.save(config.general_file)
	var general := TgcGeneralSettings.new(config)
	general.load_from_disk()
	_expect(general.locale == TgcGeneralSettings.AUTO, "an unknown language falls back on \"auto\"")
	file = ConfigFile.new()
	file.set_value("general", "language", "de")
	file.save(config.general_file)
	general.load_from_disk()
	_expect(general.locale == TgcGeneralSettings.AUTO, "so does a language only the add-on speaks")

	file = ConfigFile.new()
	file.set_value("display", "mode", 7)
	file.set_value("display", "max_fps", 77)
	file.set_value("display", "ui_scale", 9.0)
	file.set_value("display", "vsync", "yes")
	file.set_value("display", "width", "large")
	file.set_value("display", "render_scale", 0.1)
	file.save(config.display_file)
	var display := TgcDisplaySettings.new(config)
	display.load_from_disk()
	_expect(display.window_mode == TgcDisplaySettings.declared_mode(), "an unreadable mode falls back on the project's")
	_expect(display.max_fps == 0, "77 fps is not offered: unlimited")
	_expect(is_equal_approx(display.ui_scale, 1.0), "an interface size off the list falls back to 100 %")
	_expect(display.vsync, "\"yes\" is not a boolean: vsync stays on")
	_expect(display.window_size == TgcDisplaySettings.declared_size(), "an unreadable width keeps the project's size")
	_expect(is_equal_approx(display.render_scale, 0.5), "a render scale under the minimum is brought back to it")
	_expect(display.msaa == Viewport.MSAA_4X, "the default MSAA is the project's (4×)")

	file = ConfigFile.new()
	file.set_value("audio", "Master", "loud")
	file.set_value("audio", "Effects", 250)
	file.set_value("audio", "Music", -40)
	file.set_value("audio", "Unknown", 30)
	file.save(config.audio_file)
	var audio := TgcAudioSettings.new(config)
	audio.load_from_disk()
	_expect(is_equal_approx(audio.volume(&"Master"), 1.0), "an unreadable volume falls back on the default")
	_expect(is_equal_approx(audio.volume(&"Effects"), 1.0), "250 % is brought back to 100 %")
	_expect(is_equal_approx(audio.volume(&"Music"), 0.0), "−40 % is brought back to 0")
	_expect(audio.channels().size() == 3, "a bus the config does not name is ignored")
	_expect(is_equal_approx(TgcAudioSettings.gain_of(0.5), 0.25), "half the slider is a quarter of the gain")

	file = ConfigFile.new()
	file.set_value("controls", "move_forward", 12)
	file.set_value("controls", "move_back", PackedStringArray(["t:-1", "anything"]))
	file.set_value("controls", "game_pause", PackedStringArray(["b:3"]))
	file.save(config.controls_file)
	var bindings := TgcControlBindings.new(config)
	bindings.load_from_disk()
	_expect(bindings.holder_of(_key(KEY_W)) == &"move_forward", "a list that is not one is ignored")
	_expect(bindings.holder_of(_key(KEY_S)) == &"move_back", "a list with nothing readable keeps the defaults")
	_expect(bindings.holder_of(_key(KEY_ESCAPE)) == &"game_pause",
			"\"Pause\" without a keyboard key falls back on its defaults")
	bindings.restore_defaults()
	_remove_bench_files()


func _check_display_sizes() -> void:
	_section("Window sizes")
	var sizes := TgcDisplaySettings.window_sizes(Vector2i(2560, 1600), Vector2i(2560, 1575))
	_expect(not sizes.is_empty(), "a 16:10 screen has sizes to offer")
	var shaped := true
	for size in sizes:
		shaped = shaped and absf(float(size.x) / size.y - 1.6) < 0.01 and size.y <= 1575 * 0.92
	_expect(shaped, "all of them 16:10, and under the title bar")
	_expect(TgcDisplaySettings.nearest_size(sizes, Vector2i(1700, 0)).x == 1680, "1700 wide comes back to 1680")
	_expect(not TgcDisplaySettings.window_sizes(Vector2i(0, 0), Vector2i(0, 0)).is_empty(),
			"with no known screen (headless), a fallback screen")
	var config := _bench_config()
	var fps: Array[int] = [30, 60]
	config.fps_limits = fps
	var display := TgcDisplaySettings.new(config)
	display.max_fps = 144
	_expect(display.max_fps == 30, "without \"unlimited\" on offer, a refused rate falls back on the first one")


# --- Catalogues -------------------------------------------------------------------------

func _check_catalogs() -> void:
	_section("Catalogues")
	var addon := _read_catalog(ADDON_CATALOG)
	var demo := _read_catalog(DEMO_CATALOG)
	var header := FileAccess.open(ADDON_CATALOG, FileAccess.READ).get_csv_line()
	var columns: Array[String] = []
	columns.assign(header.slice(1))
	_expect(columns == TgcI18n.LOCALES, "TgcI18n.LOCALES lists the CSV's columns", ", ".join(header))
	for catalog: Dictionary in [addon, demo]:
		var holes := PackedStringArray()
		for key: String in catalog:
			for value: String in catalog[key]:
				if value.strip_edges() == "":
					holes.append(key)
		_expect(holes.is_empty(), "every key has a text in every language (%d keys)" % catalog.size(), ", ".join(holes))
	var stray := PackedStringArray()
	for key: String in addon:
		if not key.begins_with("TGC_"):
			stray.append(key)
	_expect(stray.is_empty(), "every key of the add-on starts with TGC_", ", ".join(stray))
	var missing := PackedStringArray()
	for key in _used_keys("res://addons/tgc_game_menu"):
		if not addon.has(key):
			missing.append(key)
	_expect(missing.is_empty(), "every key the add-on uses is in its catalogue", ", ".join(missing))
	missing.clear()
	for key in _used_keys("res://demo"):
		if not addon.has(key) and not demo.has(key):
			missing.append(key)
	_expect(missing.is_empty(), "every key the demonstration uses is in a catalogue", ", ".join(missing))

	TgcI18n.ensure_loaded()
	var previous := TranslationServer.get_locale()
	for row: Array in [["en", "Play", "Esc"], ["fr", "Jouer", "Échap"], ["de", "Spielen", "Esc"], ["es", "Jugar", "Esc"]]:
		TranslationServer.set_locale(row[0])
		_expect(tr("TGC_PLAY") == row[1] and TgcInputLabels.of(_key(KEY_ESCAPE)) == row[2],
				"in \"%s\", TGC_PLAY says \"%s\" and Esc is \"%s\"" % row)
	TranslationServer.set_locale("en")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	_expect(TgcInputLabels.of(pad) == "Start", "the Start button is named")
	_expect(TgcInputLabels.first_of(&"not_an_action", false) == "?", "an unknown action is named \"?\"")
	TranslationServer.set_locale(previous)


func _check_languages() -> void:
	_section("Languages")
	_expect(TgcI18n.game_locales() == PackedStringArray(["en", "fr"]),
			"the game's languages are its own, not the add-on's", ", ".join(TgcI18n.game_locales()))
	_expect(TgcI18n.native_name("fr") == "Français" and TgcI18n.native_name("de") == "Deutsch",
			"each language is named in itself")
	_expect(TgcI18n.native_name("pt") == "Portuguese", "a language nobody names gets Godot's English name")
	var config := _bench_config()
	config.languages = PackedStringArray(["fr"])
	var general := TgcGeneralSettings.new(config)
	_expect(general.available_locales() == PackedStringArray(["fr"]), "the config can name the languages itself")
	general.locale = "en"
	_expect(general.locale == TgcGeneralSettings.AUTO, "and then refuses the others")
	_expect(general.effective_locale() == "fr", "a fallback the game does not speak gives way to the game's language")
	var langs := PackedStringArray(["fr", "en"])
	_expect(TgcSystemLanguage.pick(PackedStringArray(["en-GB", "fr-FR", "fr", "en-US"]), langs, "en") == "en",
			"web: the browser's interface language comes before its preferred languages")
	_expect(TgcSystemLanguage.pick(PackedStringArray(["fr_BE"]), langs, "en") == "fr",
			"a system in Belgian French: French")
	_expect(TgcSystemLanguage.pick(PackedStringArray(["de-DE", "nl", "FR-ca"]), langs, "en") == "fr",
			"an interface the game does not speak: the first preferred language it does")
	_expect(TgcSystemLanguage.pick(PackedStringArray(["ja-JP", "ko"]), langs, "en") == "en",
			"no known language: the fallback")


## A catalogue: key → the texts of each language.
func _read_catalog(path: String) -> Dictionary:
	var out := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1:
			out[row[0]] = row.slice(1)
	return out


## The keys scenes and code use: any scene text in CAPITALS, and any CAPITALS literal that
## starts with a key prefix.
func _used_keys(dir: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var scene_key := RegEx.create_from_string("(?:text|title) = \"([A-Z][A-Z0-9_]+)\"")
	var code_key := RegEx.create_from_string("\"((?:TGC|ACTION|DEMO)_[A-Z0-9_]+)\"")
	for path in _files(dir, ["tscn", "gd", "tres"]):
		var text := FileAccess.get_file_as_string(path)
		for regex: RegEx in [scene_key, code_key]:
			for found in regex.search_all(text):
				if not keys.has(found.get_string(1)):
					keys.append(found.get_string(1))
	return keys


func _files(dir: String, extensions: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_files_at(dir):
		if extensions.has(name.get_extension()):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub), extensions))
	return out


# --- The demonstration, mounted ---------------------------------------------------------

func _mount(config: TgcMenuConfig) -> Demo:
	var demo: Demo = DEMO_SCENE.instantiate()
	# Before entering the tree: `_ready()` reads the settings.
	(demo.get_node("MenuSession") as TgcMenuSession).config = config
	add_child(demo)
	return demo


func _unmount(node: Node) -> void:
	node.queue_free()
	await get_tree().process_frame
	get_tree().paused = false


func _check_demo() -> void:
	_section("Demonstration")
	var demo := _mount(_bench_config())
	await get_tree().process_frame
	var session := demo.session()
	var menu := session.menu()
	var world := demo.world()
	var title: Label = menu.get_node("%Title")
	var resume: Button = menu.get_node("%Resume")
	var play: Button = menu.get_node("%Play")
	var started := [0, 0]
	session.game_started.connect(func() -> void: started[0] += 1)
	session.game_stopped.connect(func() -> void: started[1] += 1)
	_expect(get_tree().paused and menu.is_open(), "the program opens on the menu, paused")
	_expect(not session.is_in_game() and not world.is_running(), "without starting a game")
	_expect(title.text == "TGC Game Menu" and not resume.visible, "the main menu: the project's name, nothing to resume")
	var pages: Array[StringName] = [&"general", &"display", &"sound", &"controls", &"gameplay"]
	_expect(menu.page_ids() == pages, "the built-in pages, then the game's own", str(menu.page_ids()))
	_expect(menu.get_node("%PageButtons").get_child_count() == 5, "each with its button")
	_expect(InputMap.action_get_events(&"ui_accept").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton),
			"ui_accept answers to a gamepad button")

	session.general.locale = "fr"
	_expect(TranslationServer.get_locale() == "fr", "choosing French changes the language")
	_expect(play.atr(play.text) == "Jouer", "and the button says \"Jouer\"")
	_expect(FileAccess.file_exists(session.config.general_file), "the choice is saved")
	var general_page := menu.page(&"general") as TgcGeneralPage
	var offered: Array[String] = ["auto", "en", "fr"]
	_expect(general_page.locales() == offered, "the General page offers the game's languages only",
			str(general_page.locales()))
	session.general.locale = "en"

	play.pressed.emit()
	await get_tree().process_frame
	_expect(not get_tree().paused and not menu.is_open() and world.is_running(), "\"Play\" starts a game")
	_expect(started == [1, 0], "game_started was emitted once", str(started))

	var start := world.player_position()
	Input.action_press(&"move_right")
	for frame in 10:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	_expect(world.player_position().x > start.x + 20.0, "\"Move right\" moves the square")

	session.toggle_pause()
	await get_tree().process_frame
	_expect(get_tree().paused and menu.is_open() and resume.visible, "the pause gesture opens the pause menu")
	_expect(title.text == "TGC_PAUSE" and play.text == "TGC_NEW_GAME", "titled \"Paused\", with \"New game\"")
	var frozen := world.player_position()
	Input.action_press(&"move_right")
	for frame in 5:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	_expect(world.player_position().is_equal_approx(frozen), "in pause, the game no longer moves")

	menu.show_page(&"display")
	session.toggle_pause()
	_expect(get_tree().paused and menu.current_page() == TgcGameMenu.ROOT, "in a settings page, the gesture goes up one page")
	session.toggle_pause()
	_expect(not get_tree().paused and not menu.is_open(), "at the root, it resumes the game")

	session.pause()
	menu.show_page(&"display")
	var display_page := menu.page(&"display")
	_expect(not (display_page.get_node("%RenderScaleRow") as Control).visible
			and not (display_page.get_node("%MsaaCaption") as Control).visible
			and (display_page.get_node("%Vsync") as Control).visible,
			"the rows the config hides are hidden, with their captions")
	session.display.vsync = false
	_expect(FileAccess.file_exists(session.config.display_file), "a display change is saved")
	session.display.restore_defaults()

	menu.show_page(&"controls")
	var controls := menu.page(&"controls") as TgcControlsPage
	_expect(controls.slot_text(&"move_forward", TgcControlBindings.Family.KEYBOARD, 1) == "↑",
			"the Controls page reads the InputMap", controls.slot_text(&"move_forward", TgcControlBindings.Family.KEYBOARD, 1))
	var remapped := [0]
	session.controls_changed.connect(func(_bindings: TgcControlBindings) -> void: remapped[0] += 1)
	_expect(controls.assign(&"move_forward", TgcControlBindings.Family.KEYBOARD, 0, _key(KEY_T)),
			"T goes to \"Move up\"")
	_expect(controls.slot_text(&"move_forward", TgcControlBindings.Family.KEYBOARD, 0) == "T", "and the page shows it")
	_expect(FileAccess.file_exists(session.config.controls_file), "the remapping is saved by the session")
	_expect(remapped[0] == 1, "and announced to the game")
	_expect(world.get_node("%Help").get("text").begins_with("Move: T "), "whose help follows",
			str(world.get_node("%Help").get("text")))
	_expect(not controls.assign(&"move_left", TgcControlBindings.Family.KEYBOARD, 0, _key(KEY_ESCAPE)),
			"Esc is refused to \"Move left\"")
	_expect(controls.hint_text().contains("Pause"), "and the page says why", controls.hint_text())
	controls.begin_capture(&"move_left", TgcControlBindings.Family.KEYBOARD, 0)
	menu.show_page(TgcGameMenu.ROOT)
	_expect(not controls.is_capturing(), "leaving the page gives up the wait")
	session.bindings.restore_defaults()

	menu.show_page(&"sound")
	var sound := menu.page(&"sound") as TgcSoundPage
	_expect(sound.slider_of(&"Music") != null and sound.slider_of(&"Effects") != null, "one slider per bus")
	sound.slider_of(&"Music").value = 0.0
	var music := AudioServer.get_bus_index(&"Music")
	_expect(AudioServer.is_bus_mute(music), "music at 0 mutes its bus")
	sound.slider_of(&"Music").value = 50.0
	_expect(not AudioServer.is_bus_mute(music) and is_equal_approx(AudioServer.get_bus_volume_linear(music), 0.25),
			"at 50 %, the bus plays at a quarter of the gain")

	var help: Label = world.get_node("%Help")
	world.settings.show_help = false
	_expect(not help.visible, "the game's own page changes the game's own setting")
	world.settings.show_help = true

	session.to_main_menu()
	_expect(get_tree().paused and menu.is_open() and not world.is_running() and not resume.visible,
			"\"Main menu\" abandons the game and reopens the start menu")
	_expect(started == [1, 1], "game_stopped was emitted once", str(started))
	session.play()
	session.play()
	_expect(started == [3, 2], "\"New game\" stops the game before starting another", str(started))
	session.to_main_menu()
	await _unmount(demo)


## With no config at all, the session takes the add-on's default one: a working menu.
func _check_default_config() -> void:
	_section("Default config")
	var session := TgcMenuSession.new()
	var config := (load(TgcMenuSession.DEFAULT_CONFIG) as TgcMenuConfig).redirected(PREFIX)
	session.config = config
	add_child(session)
	await get_tree().process_frame
	var menu := session.menu()
	_expect(menu.is_open() and get_tree().paused, "it opens on the main menu")
	var pages: Array[StringName] = [&"general", &"display", &"sound", &"controls"]
	_expect(menu.page_ids() == pages, "with the four built-in pages", str(menu.page_ids()))
	var actions: Array[StringName] = [&"game_pause"]
	_expect(session.bindings.actions() == actions, "the Controls page has the pause action alone")
	_expect(session.bindings.is_essential(&"game_pause"), "which keeps a keyboard key")
	await _unmount(session)
	_remove_bench_files()


## With `start_on_main_menu` off, a game starts at once, and the menu is a pause menu only.
func _check_no_main_menu() -> void:
	_section("Without a main menu")
	var config := _bench_config()
	config.start_on_main_menu = false
	var demo := _mount(config)
	await get_tree().process_frame
	_expect(demo.world().is_running() and not get_tree().paused and not demo.session().menu().is_open(),
			"the game starts at once")
	demo.session().toggle_pause()
	_expect((demo.session().menu().get_node("%Resume") as Button).visible, "and the menu opens as a pause menu")
	await _unmount(demo)
