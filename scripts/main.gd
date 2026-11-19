extends Control
## Builds all UI in code: title / character creation, game screen, and end-of-run overlay.

const MapView := preload("res://scripts/map_view.gd")

## Required CC-BY-4.0 attribution for SRD 5.2.1 content. Keep this in-game and on the store listing.
const ATTRIBUTION := "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."

## Rows for the Controls screen: [left column, right column]. A row with "" on the right is a section heading.
const CONTROLS := [
	["TOUCH", ""],
	["Tap a neighbouring square", "Move / attack (diagonals too)"],
	["Tap a far explored square", "Auto-walk (stops when enemies appear)"],
	["Tap yourself", "Wait, or descend when on >"],
	["Tap a visible enemy", "Wizard: Fire Bolt. Others: step toward it"],
	["Buttons", "Wait, Potion, Ability, Fire Bolt, Descend"],
	["KEYBOARD", ""],
	["Arrows / WASD / HJKL", "Move or attack"],
	["Y  U  B  N", "Move diagonally"],
	["Numpad 1-9", "Move (8 directions)"],
	["Space  .  Numpad 5", "Wait a turn"],
	["Enter", "Descend stairs"],
	["Q", "Drink potion (Bonus Action)"],
	["F", "Class ability: Second Wind / Hide / Magic Missile"],
	["E", "Fire Bolt at nearest enemy (Wizard)"],
	["?  or  F1", "Open / close this screen"],
	["Esc", "Close this screen"],
	["MAP SYMBOLS", ""],
	["@", "You (faded = hidden)"],
	[">", "Stairs down"],
	["!", "Potion (pink = Greater Healing)"],
	["$", "Gold"],
	["/   [", "Better weapon / armor"],
	["#", "Wall"],
	["~", "Water (blue, walkable) / Lava (red, blocks)"],
	["letters", "Monsters (red bar = wounded)"],
	["RULES", ""],
	["Bonus Action", "Potion, Second Wind, Hide: one per turn, doesn't end your turn"],
	["Stairs", "Short Rest. Floors 5, 9, 13, 17, 20 give a Long Rest"],
]

var game: Game
var chosen_class := "Fighter"
var chosen_species := "Human"

var title_screen: Control
var game_screen: Control
var overlay: Control
var overlay_label: Label
var desc_label: Label
var status_label: Label
var log_label: RichTextLabel
var map_view: MapView
var btn_wait: Button
var btn_potion: Button
var btn_ability: Button
var btn_bolt: Button
var btn_descend: Button
var btn_help: Button
var controls_panel: Control
var travel_timer: Timer
var btn_start: Button
var btn_continue: Button


func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 26
	theme = th
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_title()
	_build_game()
	_build_overlay()
	_build_controls()
	# Let the Android back button close the Controls screen instead of quitting.
	get_tree().quit_on_go_back = false
	travel_timer = Timer.new()
	travel_timer.wait_time = 0.07
	travel_timer.timeout.connect(_on_travel_tick)
	add_child(travel_timer)
	_show_title()


# --- UI construction ---------------------------------------------------------------

func _full_margin(top: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", 28)
	add_child(m)
	return m


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choice_button(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _action_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_title() -> void:
	title_screen = _full_margin(60)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	title_screen.add_child(v)

	var t := _label("DEPTHS OF THE\nHOLLOW KING", 54, Color("e8c170"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("20 floors. One hero. A new dungeon every run.", 22, Color(0.7, 0.7, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(_label("Class", 24, Color(0.85, 0.85, 0.9)))
	var cls_row := HBoxContainer.new()
	v.add_child(cls_row)
	var cg := ButtonGroup.new()
	for c in GameData.CLASSES.keys():
		var b := _choice_button(c, cg, c == chosen_class)
		b.pressed.connect(_on_class_pick.bind(c))
		cls_row.add_child(b)

	v.add_child(_label("Species", 24, Color(0.85, 0.85, 0.9)))
	var sp_row := HBoxContainer.new()
	v.add_child(sp_row)
	var sg := ButtonGroup.new()
	for s in GameData.SPECIES.keys():
		var b := _choice_button(s, sg, s == chosen_species)
		b.pressed.connect(_on_species_pick.bind(s))
		sp_row.add_child(b)

	desc_label = _label("", 21, Color(0.8, 0.8, 0.85))
	desc_label.custom_minimum_size = Vector2(0, 170)
	v.add_child(desc_label)

	var ctl := Button.new()
	ctl.text = "Controls"
	ctl.custom_minimum_size = Vector2(0, 72)
	ctl.pressed.connect(_show_controls)
	v.add_child(ctl)

	btn_continue = Button.new()
	btn_continue.custom_minimum_size = Vector2(0, 96)
	btn_continue.add_theme_font_size_override("font_size", 28)
	btn_continue.add_theme_color_override("font_color", Color("7fc2ff"))
	btn_continue.pressed.connect(_on_continue)
	v.add_child(btn_continue)

	btn_start = Button.new()
	btn_start.custom_minimum_size = Vector2(0, 96)
	btn_start.add_theme_font_size_override("font_size", 32)
	btn_start.pressed.connect(_on_start)
	v.add_child(btn_start)

	var credits := _label("5E compatible. " + ATTRIBUTION, 14, Color(0.5, 0.5, 0.55))
	v.add_child(credits)


func _build_game() -> void:
	game_screen = _full_margin(44)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	game_screen.add_child(v)

	status_label = _label("", 22, Color(0.93, 0.9, 0.82))
	v.add_child(status_label)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, 176)
	log_label.add_theme_font_size_override("normal_font_size", 19)
	v.add_child(log_label)

	map_view = MapView.new()
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.cell_tapped.connect(_on_cell_tapped)
	v.add_child(map_view)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	btn_wait = _action_button(grid, "Wait", _on_wait)
	btn_potion = _action_button(grid, "Potion", _on_potion)
	btn_ability = _action_button(grid, "Ability", _on_ability)
	btn_bolt = _action_button(grid, "Fire Bolt", _on_bolt)
	btn_descend = _action_button(grid, "Descend >", _on_descend)
	btn_help = _action_button(grid, "Controls ?", _show_controls)


func _build_overlay() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	overlay = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	cc.add_child(v)
	overlay_label = _label("", 30, Color("e8c170"))
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.custom_minimum_size = Vector2(600, 0)
	v.add_child(overlay_label)
	var again := Button.new()
	again.text = "New Run"
	again.custom_minimum_size = Vector2(0, 96)
	again.pressed.connect(_show_title)
	v.add_child(again)


func _build_controls() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.03, 0.03, 0.05, 0.97)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks taps reaching the map
	add_child(panel)
	controls_panel = panel

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 48)
	m.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)

	var title := _label("CONTROLS", 40, Color("e8c170"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 22)
	text.add_theme_constant_override("table_v_separation", 6)
	text.add_theme_constant_override("table_h_separation", 18)
	var bb := "[table=2]"
	for row in CONTROLS:
		var left: String = row[0]
		var right: String = row[1]
		if right == "":
			bb += "[cell][b][color=#e8c170]\n%s[/color][/b][/cell][cell] [/cell]" % _esc(left)
		else:
			bb += "[cell expand=2][color=#ffd75e]%s[/color][/cell][cell expand=3]%s[/cell]" % [_esc(left), _esc(right)]
	bb += "[/table]"
	text.text = bb
	v.add_child(text)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 96)
	close.pressed.connect(_hide_controls)
	v.add_child(close)
	panel.hide()


## Escapes "[" so map symbols like "[" aren't read as BBCode tags.
func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _show_controls() -> void:
	_stop_travel()
	controls_panel.show()


func _hide_controls() -> void:
	controls_panel.hide()


func _toggle_controls() -> void:
	if controls_panel.visible:
		_hide_controls()
	else:
		_show_controls()


func _notification(what: int) -> void:
	# R-09: save whenever Android pauses, backgrounds or closes the app.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if game and game_screen and game_screen.visible:
			game.save_run()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if controls_panel and controls_panel.visible:
			_hide_controls()
		elif game_screen and game_screen.visible and not (game and game.over):
			_show_controls()  # back button = pause screen, not an accidental quit
		else:
			get_tree().quit()


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	_stop_travel()
	title_screen.show()
	game_screen.hide()
	overlay.hide()
	_update_desc()
	var saved := Game.read_save()
	btn_continue.visible = not saved.is_empty()
	if saved.is_empty():
		btn_start.text = "Descend"
	else:
		var sh: Dictionary = saved["hero"]
		btn_continue.text = "Continue - Floor %d, Lv %d %s" % [saved["floor_num"], sh["level"], sh["cls"]]
		btn_start.text = "New Run (replaces saved run)"


func _on_class_pick(c: String) -> void:
	chosen_class = c
	_update_desc()


func _on_species_pick(s: String) -> void:
	chosen_species = s
	_update_desc()


func _update_desc() -> void:
	var c: Dictionary = GameData.CLASSES[chosen_class]
	var s: Dictionary = GameData.SPECIES[chosen_species]
	desc_label.text = "%s (d%d Hit Die): %s\n\n%s: %s" % [chosen_class, c["hit_die"], c["desc"], chosen_species, s["desc"]]


func _on_start() -> void:
	Game.delete_save()
	game = Game.new()
	game.new_game(chosen_class, chosen_species)
	_enter_game()


func _on_continue() -> void:
	var g := Game.new()
	if not g.load_run():
		Game.delete_save()  # unreadable save: drop it and stay on the title screen
		_show_title()
		return
	game = g
	_enter_game()


func _enter_game() -> void:
	map_view.game = game
	title_screen.hide()
	game_screen.show()
	overlay.hide()
	_refresh()


func _refresh() -> void:
	if game == null:
		return
	game.save_run()  # R-09: autosave after every action (deletes the save once the run is over)
	var hd: Dictionary = game.hero
	var nxt := game.xp_next()
	status_label.text = "Floor %d/%d - %s\n%s %s  Lv %d  HP %d/%d  AC %d\nXP %d/%s  Gold %d%s" % [
		game.floor_num, Game.MAX_FLOOR, game.floor_theme["name"],
		hd["species"], hd["cls"], hd["level"], hd["hp"], hd["hp_max"], game.hero_ac(),
		hd["xp"], (str(nxt) if nxt > 0 else "max"), hd["gold"],
		"  [HIDDEN]" if hd["hidden"] else ""]
	log_label.text = "\n".join(PackedStringArray(game.log_lines))

	var pots: int = hd["potions"] + hd["greater"]
	btn_potion.text = "Potion (%d)" % pots
	btn_potion.disabled = pots == 0 or game.bonus_used
	match hd["cls"]:
		"Fighter":
			btn_ability.text = "Second Wind (%d)" % hd["second_wind"]
			btn_ability.disabled = hd["second_wind"] <= 0 or game.bonus_used
		"Rogue":
			btn_ability.text = "Hidden" if hd["hidden"] else "Hide"
			btn_ability.disabled = hd["hidden"] or game.bonus_used
		"Wizard":
			btn_ability.text = "Magic Missile (%d)" % hd["slots"]
			btn_ability.disabled = hd["slots"] <= 0
	btn_bolt.visible = hd["cls"] == "Wizard"
	btn_descend.disabled = not game.on_stairs()
	map_view.queue_redraw()

	if game.over:
		_stop_travel()
		if game.won:
			overlay_label.text = "VICTORY\n\nThe Hollow King is dust.\n\nLevel %d %s %s\n%d kills - %d gold\nSeed %d" % [
				hd["level"], hd["species"], hd["cls"], hd["kills"], hd["gold"], game.seed_value]
		else:
			overlay_label.text = "YOU DIED\n\nSlain by a %s\non floor %d (%s).\n\nLevel %d %s %s\n%d kills - %d gold\nSeed %d" % [
				game.death_cause, game.floor_num, game.floor_theme["name"],
				hd["level"], hd["species"], hd["cls"], hd["kills"], hd["gold"], game.seed_value]
		overlay.show()


# --- Input -------------------------------------------------------------------------

func _on_cell_tapped(c: Vector2i) -> void:
	if game == null or game.over:
		return
	_stop_travel()
	var hp: Vector2i = game.hero["pos"]
	var d := c - hp
	if d == Vector2i.ZERO:
		if game.on_stairs():
			game.player_descend()
		else:
			game.player_wait()
	elif absi(d.x) <= 1 and absi(d.y) <= 1:
		game.player_step(d)
	else:
		var m = game.visible_monster_at(c)
		if m != null and game.hero["cls"] == "Wizard":
			game.player_firebolt(m)
		elif m != null:
			game.describe(m)
			game.player_step_toward(c)
		elif game.explored_walkable(c) and not game.any_monster_visible():
			game.plan_travel(c)
			if not game.travel.is_empty():
				travel_timer.start()
		else:
			game.player_step_toward(c)
	_refresh()


func _on_travel_tick() -> void:
	if game == null or game.over or game.travel.is_empty() or game.any_monster_visible():
		_stop_travel()
		_refresh()
		return
	var nxt: Vector2i = game.travel.pop_front()
	var here: Vector2i = game.hero["pos"]
	if not game.player_step(nxt - here):
		game.travel.clear()
	_refresh()


func _stop_travel() -> void:
	if travel_timer:
		travel_timer.stop()
	if game:
		game.travel.clear()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Controls screen works from anywhere and pauses the game while open.
	if key.keycode in [KEY_F1, KEY_SLASH, KEY_QUESTION]:
		_toggle_controls()
		get_viewport().set_input_as_handled()
		return
	if controls_panel.visible:
		if key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_hide_controls()
		get_viewport().set_input_as_handled()
		return
	if game == null or game.over or not game_screen.visible:
		return
	var dir := Vector2i.ZERO
	match key.keycode:
		KEY_UP, KEY_W, KEY_K, KEY_KP_8:
			dir = Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_J, KEY_KP_2:
			dir = Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_H, KEY_KP_4:
			dir = Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_L, KEY_KP_6:
			dir = Vector2i(1, 0)
		KEY_Y, KEY_KP_7:
			dir = Vector2i(-1, -1)
		KEY_U, KEY_KP_9:
			dir = Vector2i(1, -1)
		KEY_B, KEY_KP_1:
			dir = Vector2i(-1, 1)
		KEY_N, KEY_KP_3:
			dir = Vector2i(1, 1)
		KEY_SPACE, KEY_PERIOD, KEY_KP_5:
			_on_wait()
			return
		KEY_ENTER, KEY_KP_ENTER:
			_on_descend()
			return
		KEY_Q:
			_on_potion()
			return
		KEY_F:
			_on_ability()
			return
		KEY_E:
			_on_bolt()
			return
		_:
			return
	_stop_travel()
	var here: Vector2i = game.hero["pos"]
	game.player_step_toward(here + dir)
	_refresh()
	get_viewport().set_input_as_handled()


func _on_wait() -> void:
	_stop_travel()
	game.player_wait()
	_refresh()


func _on_potion() -> void:
	game.player_potion()
	_refresh()


func _on_ability() -> void:
	_stop_travel()
	game.player_ability()
	_refresh()


func _on_bolt() -> void:
	_stop_travel()
	game.player_firebolt(null)
	_refresh()


func _on_descend() -> void:
	_stop_travel()
	game.player_descend()
	_refresh()

