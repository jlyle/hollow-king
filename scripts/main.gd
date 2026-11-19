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
	["Tap a visible enemy", "Select it. Wizard/Cleric/Ranger also attack at range; others step toward it"],
	["Buttons", "Wait, Potion, Ability, Fire Bolt, Descend"],
	["KEYBOARD", ""],
	["Arrows / WASD / HJKL", "Move or attack"],
	["Y  U  B  N", "Move diagonally"],
	["Numpad 1-9", "Move (8 directions)"],
	["Space  .  Numpad 5", "Wait a turn"],
	["Enter", "Descend stairs"],
	["Q", "Drink potion (Bonus Action)"],
	["F", "Class ability (see CLASS BUTTONS)"],
	["E", "Ranged attack: Fire Bolt / Sacred Flame / Longbow"],
	["R", "Spells menu (casters) / Reckless toggle (Barbarian)"],
	["?  or  F1", "Open / close this screen"],
	["Esc", "Close this screen"],
	["MAP SYMBOLS", ""],
	["@", "You (faded = hidden)"],
	[">", "Stairs down (red = sealed by a mini-boss)"],
	["&", "Mini-boss: defeat it to unseal the stairs"],
	["!", "Potion (pink = Greater Healing)"],
	["$", "Gold"],
	["/   [", "Better weapon / armor"],
	["#", "Wall"],
	["~", "Water (blue, walkable) / Lava (red, blocks)"],
	["letters", "Monsters (red bar = wounded). Archers and casters attack from range"],
	["CLASS BUTTONS", ""],
	["Fighter", "Ability: Second Wind"],
	["Rogue", "Ability: Hide"],
	["Barbarian", "Ability: Rage. 2nd button: Reckless on/off"],
	["Ranger", "Ability: Hunter's Mark. Ranged: Longbow. Spells menu"],
	["Wizard", "Ability: Magic Missile. Ranged: Fire Bolt. Spells menu"],
	["Cleric", "Ability: Healing Word. Ranged: Sacred Flame. Spells menu"],
	["Target frame", "Yellow box = selected target; spells aim at it"],
	["RULES", ""],
	["Saving throws", "Save spells roll d20 + the monster's save bonus vs your spell DC"],
	["Concentration", "One at a time; taking damage forces a CON save"],
	["Enemy spells", "Some casters force YOUR saving throws (shown in the log)"],
	["Poisoned", "Disadvantage on your attack rolls for a few turns"],
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
var btn_ranged: Button
var btn_spells: Button
var spells_panel: Control
var spells_list: VBoxContainer
var spells_header: Label
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
	_build_spells()
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
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _action_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 80)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_title() -> void:
	title_screen = _full_margin(60)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	title_screen.add_child(v)

	var t := _label("DEPTHS OF THE\nHOLLOW KING", 46, Color("e8c170"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("20 floors. One hero. A new dungeon every run.", 22, Color(0.7, 0.7, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(_label("Class", 24, Color(0.85, 0.85, 0.9)))
	var cls_row := GridContainer.new()
	cls_row.columns = 3
	cls_row.add_theme_constant_override("h_separation", 6)
	cls_row.add_theme_constant_override("v_separation", 6)
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
	desc_label.custom_minimum_size = Vector2(0, 150)
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
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	btn_wait = _action_button(grid, "Wait", _on_wait)
	btn_potion = _action_button(grid, "Potion", _on_potion)
	btn_ability = _action_button(grid, "Ability", _on_ability)
	btn_ranged = _action_button(grid, "Ranged", _on_ranged)
	btn_spells = _action_button(grid, "Spells", _on_spells)
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
		elif spells_panel and spells_panel.visible:
			_hide_spells()
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
	status_label.text = "Floor %d/%d - %s\n%s %s  Lv %d  HP %d/%d  AC %d\nXP %d/%s  Gold %d\n%s" % [
		game.floor_num, Game.MAX_FLOOR, game.floor_theme["name"],
		hd["species"], hd["cls"], hd["level"], hd["hp"], hd["hp_max"], game.hero_ac(),
		hd["xp"], (str(nxt) if nxt > 0 else "max"), hd["gold"], game.status_extra()]
	log_label.text = "\n".join(PackedStringArray(game.log_lines))

	var pots: int = hd["potions"] + hd["greater"]
	btn_potion.text = "Potion (%d)" % pots
	btn_potion.disabled = pots == 0 or game.bonus_used
	var lvl: int = hd["level"]
	match hd["cls"]:
		"Fighter":
			btn_ability.text = "2nd Wind (%d)" % hd["second_wind"]
			btn_ability.disabled = hd["second_wind"] <= 0 or game.bonus_used
		"Rogue":
			btn_ability.text = "Hidden" if hd["hidden"] else "Hide"
			btn_ability.disabled = hd["hidden"] or game.bonus_used
		"Barbarian":
			btn_ability.text = ("Raging %d" % hd["rage"]) if int(hd["rage"]) > 0 else ("Rage (%d)" % hd["rage_uses"])
			btn_ability.disabled = int(hd["rage"]) > 0 or int(hd["rage_uses"]) <= 0 or game.bonus_used
		"Wizard":
			btn_ability.text = "M. Missile"
			btn_ability.disabled = game.cannot_cast("magic_missile") != ""
		"Cleric":
			btn_ability.text = "Heal Word"
			btn_ability.disabled = game.cannot_cast("healing_word") != ""
		"Ranger":
			btn_ability.text = "Mark (%d)" % hd["hm_free"]
			btn_ability.disabled = game.cannot_cast("hunters_mark") != ""
	var ranged_names := {"fire_bolt": "Fire Bolt", "sacred_flame": "Sac. Flame", "longbow": "Longbow"}
	var rk: String = GameData.CLASSES[hd["cls"]]["ranged"]
	btn_ranged.visible = rk != ""
	btn_ranged.text = ranged_names.get(rk, "Ranged")
	btn_ranged.disabled = not game.any_monster_visible()
	if hd["cls"] == "Barbarian":
		btn_spells.visible = true
		btn_spells.text = "Reckless " + ("ON" if hd["reckless"] else "off") if lvl >= 2 else "Reckless L2"
		btn_spells.disabled = lvl < 2
	else:
		btn_spells.visible = game.is_caster()
		btn_spells.text = "Spells (%d)" % hd["slots"]
		btn_spells.disabled = false
	btn_descend.disabled = not game.on_stairs()
	map_view.queue_redraw()

	if game.over:
		_stop_travel()
		if game.won:
			overlay_label.text = "VICTORY\n\nThe Hollow King is dust.\n\nLevel %d %s %s\n%d kills - %d gold\nSeed %d" % [
				hd["level"], hd["species"], hd["cls"], hd["kills"], hd["gold"], game.seed_value]
		else:
			overlay_label.text = "YOU DIED\n\nSlain by %s\non floor %d (%s).\n\nLevel %d %s %s\n%d kills - %d gold\nSeed %d" % [
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
		if m != null:
			game.set_target(m)
		if m != null and game.has_ranged():
			game.player_ranged(m)
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
	if spells_panel.visible:
		if key.keycode in [KEY_ESCAPE, KEY_R]:
			_hide_spells()
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
			_on_ranged()
			return
		KEY_R:
			_on_spells()
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


func _on_ranged() -> void:
	_stop_travel()
	game.player_ranged(null)
	_refresh()


## Casters open the spell menu; Barbarians toggle Reckless Attack.
func _on_spells() -> void:
	_stop_travel()
	if game.hero["cls"] == "Barbarian":
		game.toggle_reckless()
		_refresh()
	elif game.is_caster():
		_show_spells()


# --- Spell menu (R-11) -------------------------------------------------------------

func _build_spells() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.03, 0.03, 0.05, 0.97)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	spells_panel = panel
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 48)
	m.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var title := _label("SPELLS", 40, Color("e8c170"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	spells_header = _label("", 21, Color(0.8, 0.8, 0.85))
	spells_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(spells_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	spells_list = VBoxContainer.new()
	spells_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spells_list.add_theme_constant_override("separation", 10)
	scroll.add_child(spells_list)
	var close := Button.new()
	close.text = "Cancel"
	close.custom_minimum_size = Vector2(0, 88)
	close.pressed.connect(_hide_spells)
	v.add_child(close)
	panel.hide()


func _show_spells() -> void:
	for child in spells_list.get_children():
		child.queue_free()
	var hd: Dictionary = game.hero
	var tgt = game.target
	var tname: String = tgt["name"] if tgt != null else "nearest enemy"
	spells_header.text = "Slots %d/%d  -  Spell DC %d  -  Target: %s" % [hd["slots"], game.max_slots(), game.spell_dc(), tname]
	for sp in game.available_spells():
		var b := Button.new()
		var why: String = sp["why"]
		b.text = "%s   [%s]\n%s%s" % [sp["name"], sp["cost"], sp["desc"], ("\n> " + why) if why != "" else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.disabled = why != ""
		b.pressed.connect(_cast_from_menu.bind(String(sp["key"])))
		spells_list.add_child(b)
	spells_panel.show()


func _hide_spells() -> void:
	spells_panel.hide()


func _cast_from_menu(key: String) -> void:
	_hide_spells()
	game.cast(key)
	_refresh()


func _on_descend() -> void:
	_stop_travel()
	game.player_descend()
	_refresh()

