extends Control
## Builds all UI in code: title / character creation, game screen, and end-of-run overlay.

const MapView := preload("res://scripts/map_view.gd")

## Required CC-BY-4.0 attribution for SRD 5.2.1 content. Keep this in-game and on the store listing.
const ATTRIBUTION := "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."

## Rows for the Controls screen: [left column, right column]. A row with "" on the right is a section heading.
const CONTROLS := [
	["TOUCH", ""],
	["D-pad", "Tap an arrow to step or attack; hold to keep walking. Centre = Wait"],
	["Swipe on the map", "Step one square in that direction"],
	["Long-press the map", "Inspect a monster, item or square"],
	["Explore button", "Auto-walk to unexplored areas and items; stops when enemies appear"],
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
	["X", "Explore"],
	["R", "Spells menu (casters) / Reckless toggle (Barbarian)"],
	["?  or  F1", "Open / close this screen"],
	["Settings", "Sound, haptics, ASCII or Tiles, map zoom, D-pad (title screen or pause menu)"],
	["Esc", "Close a screen. During a run: pause menu. On the title: quit"],
	["Menu button / Back", "Pause menu: Resume, Controls, Settings, Save & return, Save & quit"],
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

# --- Visual style (D-11) ---
var c_bg := Color("0b0b12")
var c_panel := Color("13131c")
var c_line := Color("2a2a3a")
var c_text := Color("e9e6dc")
var c_muted := Color("8d8a99")
var c_gold := Color("e8c170")

var game: Game
var chosen_class := "Fighter"
var chosen_species := "Human"

var title_screen: Control
var game_screen: Control
var overlay: Control
var overlay_label: Label
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
var credits_panel: Control
var pause_panel: Control
# R-20 touch controls
var dpad_box: Control
var actions_grid: GridContainer
var btn_explore: Button
var dpad_timer: Timer
var dpad_dir := Vector2i.ZERO
var exploring := false
var zoom_button: Button
const ZOOM_NAMES := ["Small", "Medium", "Large"]
var pause_info: Label
var btn_menu: Button
var card_title: Label
var card_meta: Label
var card_tag: Label
var card_desc: Label
var card_species: RichTextLabel
var settings_panel: Control

# --- Settings, sound and haptics (R-14 .. R-17) ---
const SETTINGS_PATH := "user://settings.cfg"
const SOUNDS := ["step", "hit", "crit", "miss", "hurt", "kill", "spell", "heal", "pickup",
	"levelup", "descend", "death", "victory", "enemy_spell", "summon"]
const HAPTICS := {"hurt": 40, "crit": 30, "levelup": 80, "death": 400}   ## milliseconds
var settings := {"sound": true, "haptics": true, "tiles": false, "dpad": true, "zoom": 1}
var sounds := {}
var sfx: Array = []
var sfx_i := 0
var btn_start: Button
var btn_continue: Button


func _ready() -> void:
	theme = _make_theme()
	add_child(_make_background())
	_build_title()
	_build_game()
	_build_overlay()
	_load_settings()
	_build_audio()
	_build_spells()
	_build_pause()
	_build_controls()
	_build_settings()
	_build_credits()
	map_view.use_tiles = settings["tiles"]
	_apply_layout()
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
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 21)
	return b


func _action_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_title() -> void:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	title_screen = root
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 0)
	root.add_child(col)

	# Title block
	var t1 := _label("DEPTHS OF THE", 20, c_gold.darkened(0.25))
	t1.add_theme_font_override("font", _spaced(8))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t1)
	var t2 := _label("HOLLOW KING", 54, c_gold)
	t2.add_theme_font_override("font", _spaced(5, 0.5))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t2)
	col.add_child(_spacer(10))
	col.add_child(_ornament())
	col.add_child(_spacer(12))
	var sub := _label("Twenty floors. One hero. A new dungeon every run.", 18, c_muted)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_spacer(34))

	# Class chips
	col.add_child(_section_label("CLASS"))
	col.add_child(_spacer(10))
	var cls_grid := GridContainer.new()
	cls_grid.columns = 3
	cls_grid.add_theme_constant_override("h_separation", 10)
	cls_grid.add_theme_constant_override("v_separation", 10)
	col.add_child(cls_grid)
	var cg := ButtonGroup.new()
	for c in GameData.CLASSES.keys():
		var b := _choice_button(c, cg, c == chosen_class)
		b.pressed.connect(_on_class_pick.bind(c))
		cls_grid.add_child(b)
	col.add_child(_spacer(22))

	# Species chips
	col.add_child(_section_label("SPECIES"))
	col.add_child(_spacer(10))
	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 10)
	col.add_child(sp_row)
	var sg := ButtonGroup.new()
	for sname in GameData.SPECIES.keys():
		var b := _choice_button(sname, sg, sname == chosen_species)
		b.pressed.connect(_on_species_pick.bind(sname))
		sp_row.add_child(b)
	col.add_child(_spacer(22))

	# Class card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(c_panel, c_line, 1, 14, 22, 18))
	card.custom_minimum_size = Vector2(0, 236)
	col.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	card_title = _label("", 28, c_gold)
	cv.add_child(card_title)
	card_meta = _label("", 13, c_muted)
	card_meta.add_theme_font_override("font", _spaced(2))
	cv.add_child(card_meta)
	cv.add_child(_spacer(4))
	card_tag = _label("", 20, c_text)
	cv.add_child(card_tag)
	card_desc = _label("", 15, c_muted)
	cv.add_child(card_desc)
	cv.add_child(_spacer(6))
	var rule := ColorRect.new()
	rule.color = c_line
	rule.custom_minimum_size = Vector2(0, 1)
	cv.add_child(rule)
	cv.add_child(_spacer(6))
	card_species = RichTextLabel.new()
	card_species.bbcode_enabled = true
	card_species.fit_content = true
	card_species.scroll_active = false
	card_species.add_theme_font_size_override("normal_font_size", 16)
	card_species.add_theme_color_override("default_color", c_text)
	cv.add_child(card_species)
	col.add_child(_spacer(26))

	# Primary actions
	btn_continue = Button.new()
	btn_continue.custom_minimum_size = Vector2(0, 76)
	btn_continue.add_theme_font_size_override("font_size", 24)
	btn_continue.pressed.connect(_on_continue)
	col.add_child(btn_continue)
	col.add_child(_spacer(10))
	btn_start = Button.new()
	btn_start.custom_minimum_size = Vector2(0, 76)
	btn_start.add_theme_font_size_override("font_size", 26)
	btn_start.pressed.connect(_on_start)
	col.add_child(btn_start)
	col.add_child(_spacer(18))

	# Quiet links
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 6)
	col.add_child(links)
	var first := true
	for pair in [["Controls", _show_controls], ["Settings", _show_settings], ["Credits", _show_credits], ["Quit", _quit_game]]:
		if not first:
			links.add_child(_label("·", 18, c_line.lightened(0.3)))
		first = false
		links.add_child(_link_button(pair[0], pair[1]))
	col.add_child(_spacer(8))
	var foot := _label("5E compatible  ·  Rules from SRD 5.2.1 (CC-BY-4.0), see Credits", 12, c_muted.darkened(0.25))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _build_game() -> void:
	game_screen = _full_margin(40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	game_screen.add_child(v)

	status_label = _label("", 19, Color(0.93, 0.9, 0.82))
	v.add_child(status_label)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(0, 136)
	log_label.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(log_label)

	map_view = MapView.new()
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.cell_tapped.connect(_on_cell_tapped)
	map_view.swiped.connect(_on_swipe)
	map_view.long_pressed.connect(_on_long_press)
	v.add_child(map_view)

	# Control area: D-pad (left) + actions (right). R-20
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	dpad_box = _build_dpad()
	bottom.add_child(dpad_box)
	actions_grid = GridContainer.new()
	actions_grid.columns = 2
	actions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_grid.add_theme_constant_override("h_separation", 8)
	actions_grid.add_theme_constant_override("v_separation", 8)
	bottom.add_child(actions_grid)
	btn_wait = _action_button(actions_grid, "Wait", _on_wait)
	btn_potion = _action_button(actions_grid, "Potion", _on_potion)
	btn_ability = _action_button(actions_grid, "Ability", _on_ability)
	btn_ranged = _action_button(actions_grid, "Ranged", _on_ranged)
	btn_spells = _action_button(actions_grid, "Spells", _on_spells)
	btn_explore = _action_button(actions_grid, "Explore", _on_explore)
	btn_descend = _action_button(actions_grid, "Descend >", _on_descend)
	btn_help = _action_button(actions_grid, "Controls", _show_controls)
	btn_menu = _action_button(actions_grid, "Menu", _show_pause)

	dpad_timer = Timer.new()
	dpad_timer.one_shot = true
	dpad_timer.timeout.connect(_on_dpad_repeat)
	add_child(dpad_timer)


## 3x3 D-pad: 8 arrows, Wait in the centre. Hold an arrow to keep walking.
func _build_dpad() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var dirs := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	for d in dirs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(80, 80)
		b.focus_mode = Control.FOCUS_NONE
		if d == Vector2i.ZERO:
			b.text = "Wait"
			b.add_theme_font_size_override("font_size", 17)
			b.pressed.connect(_on_wait)
		else:
			b.icon = _arrow_icon(d)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_color_override("icon_normal_color", c_text)
			b.add_theme_color_override("icon_hover_color", Color.WHITE)
			b.add_theme_color_override("icon_pressed_color", c_gold)
			b.button_down.connect(_on_dpad_down.bind(d))
			b.button_up.connect(_on_dpad_up)
		g.add_child(b)
	return g


## Draws a white arrowhead pointing in direction d (no font glyphs needed).
func _arrow_icon(d: Vector2i) -> ImageTexture:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ang := Vector2(d).angle()
	var tip := Vector2(14, 0).rotated(ang)
	var left := Vector2(-9, -12).rotated(ang)
	var right := Vector2(-9, 12).rotated(ang)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			if _in_triangle(p, tip, left, right):
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)


## Show/hide the D-pad and resize the action grid to match (Settings). R-20
func _apply_layout() -> void:
	var dp: bool = settings["dpad"]
	dpad_box.visible = dp
	actions_grid.columns = 2 if dp else 4
	btn_wait.visible = not dp
	map_view.cols = MapView.ZOOM_COLS[clampi(int(settings["zoom"]), 0, 2)]
	map_view.queue_redraw()


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
	var phone := OS.has_feature("mobile")
	var skipping := false
	for row in CONTROLS:
		var left: String = row[0]
		var right: String = row[1]
		if right == "":
			skipping = phone and left == "KEYBOARD"   # R-20: phones show touch controls only
		if skipping:
			continue
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
		elif settings_panel and settings_panel.visible:
			settings_panel.hide()
		elif credits_panel and credits_panel.visible:
			credits_panel.hide()
		elif pause_panel and pause_panel.visible:
			pause_panel.hide()  # Back again = Resume
		elif game_screen and game_screen.visible and not (game and game.over):
			_show_pause()  # R-19: Back opens the pause menu, not an accidental quit
		else:
			_quit_game()


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
		btn_start.text = "Begin Descent"
		_style_primary(btn_start, true)
	else:
		var sh: Dictionary = saved["hero"]
		btn_continue.text = "Continue  -  Floor %d, Lv %d %s" % [saved["floor_num"], sh["level"], sh["cls"]]
		_style_primary(btn_continue, true)
		btn_start.text = "New Run  (replaces saved run)"
		_style_primary(btn_start, false)


func _on_class_pick(c: String) -> void:
	chosen_class = c
	_update_desc()


func _on_species_pick(s: String) -> void:
	chosen_species = s
	_update_desc()


func _update_desc() -> void:
	var c: Dictionary = GameData.CLASSES[chosen_class]
	var sp: Dictionary = GameData.SPECIES[chosen_species]
	card_title.text = chosen_class
	card_meta.text = "%s  ·  D%d HIT DIE  ·  %s" % [String(c["role"]).to_upper(), c["hit_die"], String(c["primary"]).to_upper()]
	card_tag.text = c["tagline"]
	card_desc.text = c["desc"]
	card_species.text = "[color=#e8c170]%s[/color]  [color=#8d8a99]-[/color]  %s" % [chosen_species, sp["tagline"]]


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
	_play_events()
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
	if game == null or game.over or game.any_monster_visible():
		_stop_travel()
		_refresh()
		return
	if game.travel.is_empty():
		# Explore keeps going: plan the next unexplored spot. R-20
		if exploring:
			var msg := game.plan_explore()
			if msg != "":
				game.say(msg)
		if game.travel.is_empty():
			_stop_travel()
			_refresh()
			return
	var nxt: Vector2i = game.travel.pop_front()
	var here: Vector2i = game.hero["pos"]
	var hp_before: int = game.hero["hp"]
	if not game.player_step(nxt - here) or int(game.hero["hp"]) < hp_before:
		_stop_travel()
	_refresh()


func _stop_travel() -> void:
	exploring = false
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
	if credits_panel.visible:
		if key.keycode == KEY_ESCAPE:
			credits_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if settings_panel.visible:
		if key.keycode == KEY_ESCAPE:
			settings_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if spells_panel.visible:
		if key.keycode in [KEY_ESCAPE, KEY_R]:
			_hide_spells()
		get_viewport().set_input_as_handled()
		return
	if pause_panel.visible:
		if key.keycode == KEY_ESCAPE:
			pause_panel.hide()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		if title_screen.visible:
			_quit_game()
		elif game_screen.visible and game != null and not game.over:
			_show_pause()
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
		KEY_X:
			_on_explore()
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


# --- Settings, sound and haptics (R-14 .. R-17) ---------------------------------------

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("options", k, settings[k])


func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("options", k, settings[k])
	cf.save(SETTINGS_PATH)


func _build_audio() -> void:
	for sname in SOUNDS:
		var path := "res://audio/%s.wav" % sname
		if ResourceLoader.exists(path):
			sounds[sname] = load(path)
	for _i in 6:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		sfx.append(pl)


func _play(sname: String) -> void:
	if not settings["sound"] or not sounds.has(sname):
		return
	var pl: AudioStreamPlayer = sfx[sfx_i]
	sfx_i = (sfx_i + 1) % sfx.size()
	pl.stream = sounds[sname]
	pl.volume_db = -8.0 if sname == "step" else 0.0
	pl.play()


func _buzz(sname: String) -> void:
	if not settings["haptics"] or not HAPTICS.has(sname) or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(HAPTICS[sname])


## Plays the sounds/haptics the last action produced (at most 3 sounds at once).
func _play_events() -> void:
	if game == null:
		return
	var ev: Array = game.events.duplicate()
	game.events.clear()
	if ev.has("death"):
		ev.erase("hurt")
	if ev.has("victory"):
		ev.erase("kill")
	if ev.size() > 1:
		ev.erase("step")
	var played := 0
	for e in ev:
		if played < 3:
			_play(e)
			played += 1
		_buzz(e)


func _build_settings() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.03, 0.03, 0.05, 0.97)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	settings_panel = panel
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.custom_minimum_size = Vector2(600, 0)
	cc.add_child(v)
	var title := _label("SETTINGS", 40, Color("e8c170"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var rows := [
		["sound", "Sound effects"],
		["haptics", "Vibration (haptics)"],
		["tiles", "Tile graphics (off = ASCII)"],
		["dpad", "On-screen D-pad"],
	]
	for row in rows:
		var cb := CheckButton.new()
		cb.text = row[1]
		cb.button_pressed = settings[row[0]]
		cb.custom_minimum_size = Vector2(0, 84)
		cb.add_theme_font_size_override("font_size", 26)
		cb.toggled.connect(_on_setting.bind(String(row[0])))
		v.add_child(cb)
	zoom_button = Button.new()
	zoom_button.custom_minimum_size = Vector2(0, 76)
	zoom_button.add_theme_font_size_override("font_size", 24)
	zoom_button.pressed.connect(_on_zoom_cycle)
	v.add_child(zoom_button)
	_update_zoom_label()
	var note := _label("Sounds and tiles are original, generated by the scripts in tools/.", 17, Color(0.55, 0.55, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 96)
	close.pressed.connect(settings_panel.hide)
	v.add_child(close)
	panel.hide()


func _show_settings() -> void:
	_stop_travel()
	settings_panel.show()


func _on_setting(pressed: bool, key: String) -> void:
	settings[key] = pressed
	_save_settings()
	match key:
		"tiles":
			map_view.use_tiles = pressed
			map_view.queue_redraw()
		"sound":
			if pressed:
				_play("pickup")
		"haptics":
			if pressed:
				_buzz("crit")
		"dpad":
			_apply_layout()


# --- Visual style helpers (D-11) -------------------------------------------------------

func _box(bg: Color, border: Color, bw: int, radius: int = 10, px: int = 16, py: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	sb.anti_aliasing = true
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 24
	th.set_stylebox("normal", "Button", _box(c_panel, c_line, 1))
	th.set_stylebox("hover", "Button", _box(c_panel.lightened(0.04), c_line.lightened(0.3), 1))
	th.set_stylebox("pressed", "Button", _box(Color("2a2214"), c_gold, 2))
	th.set_stylebox("hover_pressed", "Button", _box(Color("31281a"), c_gold, 2))
	th.set_stylebox("disabled", "Button", _box(c_panel.darkened(0.35), c_line.darkened(0.3), 1))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", c_text)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", c_gold)
	th.set_color("font_hover_pressed_color", "Button", c_gold)
	th.set_color("font_focus_color", "Button", c_text)
	th.set_color("font_disabled_color", "Button", c_muted.darkened(0.35))
	return th


## Dark background with a faint warm glow near the top.
func _make_background() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.14, 0.105, 0.055))
	g.set_color(1, c_bg)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.08)
	gt.fill_to = Vector2(0.5, 0.75)
	gt.width = 256
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


func _spaced(spacing: int, bold: float = 0.0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = spacing
	fv.variation_embolden = bold
	return fv


func _section_label(text: String) -> Label:
	var l := _label(text, 13, c_muted)
	l.add_theme_font_override("font", _spaced(4))
	return l


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Thin gold line - dot - line, centred under the title.
func _ornament() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for w in [70, 6, 70]:
		var r := ColorRect.new()
		r.color = Color(c_gold, 0.55 if w > 6 else 0.9)
		r.custom_minimum_size = Vector2(w, 2 if w > 6 else 6)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return row


func _link_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", c_muted)
	b.add_theme_color_override("font_hover_color", c_gold)
	b.add_theme_color_override("font_pressed_color", c_gold)
	b.pressed.connect(cb)
	return b


## Gold filled button for the main action on a screen (or reset to the normal style).
func _style_primary(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.remove_theme_stylebox_override(st)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.remove_theme_color_override(fc)
	if not on:
		return
	b.add_theme_stylebox_override("normal", _box(c_gold, c_gold, 0, 12))
	b.add_theme_stylebox_override("hover", _box(c_gold.lightened(0.12), c_gold.lightened(0.12), 0, 12))
	b.add_theme_stylebox_override("pressed", _box(c_gold.darkened(0.15), c_gold.darkened(0.15), 0, 12))
	b.add_theme_stylebox_override("hover_pressed", _box(c_gold.darkened(0.1), c_gold.darkened(0.1), 0, 12))
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(fc, Color("1a140a"))


# --- Credits (C-04) ---------------------------------------------------------------------

func _build_credits() -> void:
	var panel := ColorRect.new()
	panel.color = Color(c_bg, 0.97)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	credits_panel = panel
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(600, 0)
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var title := _label("CREDITS", 34, c_gold)
	title.add_theme_font_override("font", _spaced(6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_ornament())
	v.add_child(_spacer(8))
	for pair in [
		["GAME", "Depths of the Hollow King. Design: Jim (jlyle). Built with Godot Engine."],
		["ART & SOUND", "Original tiles and sound effects, generated by the scripts in tools/."],
		["RULES", "5E compatible. " + ATTRIBUTION],
	]:
		v.add_child(_section_label(pair[0]))
		v.add_child(_label(pair[1], 17, c_text))
		v.add_child(_spacer(6))
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 72)
	close.pressed.connect(credits_panel.hide)
	v.add_child(close)
	panel.hide()


func _show_credits() -> void:
	credits_panel.show()


# --- Pause menu and quitting (R-19) -------------------------------------------------------

func _build_pause() -> void:
	var panel := ColorRect.new()
	panel.color = Color(c_bg, 0.94)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	pause_panel = panel
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	var title := _label("PAUSED", 38, c_gold)
	title.add_theme_font_override("font", _spaced(8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_ornament())
	pause_info = _label("", 17, c_muted)
	pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pause_info)
	v.add_child(_spacer(14))
	var resume := _menu_button(v, "Resume", pause_panel.hide)
	_style_primary(resume, true)
	_menu_button(v, "Controls", _show_controls)
	_menu_button(v, "Settings", _show_settings)
	v.add_child(_spacer(10))
	_menu_button(v, "Save & return to title", _save_and_title)
	_menu_button(v, "Save & quit", _quit_game)
	panel.hide()


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 23)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show_pause() -> void:
	if game == null or game.over:
		return
	_stop_travel()
	_hide_spells()
	var hd: Dictionary = game.hero
	pause_info.text = "Floor %d  ·  Level %d %s %s  ·  HP %d/%d" % [game.floor_num, hd["level"], hd["species"], hd["cls"], hd["hp"], hd["hp_max"]]
	pause_panel.show()


func _save_and_title() -> void:
	if game != null and not game.over:
		game.save_run()
	pause_panel.hide()
	_show_title()


## Saves any run in progress, then closes the app.
func _quit_game() -> void:
	if game != null and not game.over and game_screen.visible:
		game.save_run()
	get_tree().quit()


# --- Touch controls (R-20) ----------------------------------------------------------------

func _on_swipe(d: Vector2i) -> void:
	if game == null or game.over:
		return
	_stop_travel()
	var here: Vector2i = game.hero["pos"]
	game.player_step_toward(here + d)
	_refresh()


func _on_long_press(c: Vector2i) -> void:
	if game == null or game.over:
		return
	game.inspect(c)
	_buzz("crit")  # small tick so the long-press feels acknowledged
	_refresh()


func _on_explore() -> void:
	if game == null or game.over:
		return
	_stop_travel()
	var msg := game.plan_explore()
	if msg != "":
		game.say(msg)
	if not game.travel.is_empty():
		exploring = true
		travel_timer.start()
	_refresh()


func _on_dpad_down(d: Vector2i) -> void:
	dpad_dir = d
	if _dpad_step():
		dpad_timer.start(0.3)   # first repeat after a short pause
	else:
		dpad_timer.stop()


func _on_dpad_up() -> void:
	dpad_timer.stop()
	dpad_dir = Vector2i.ZERO


func _on_dpad_repeat() -> void:
	if dpad_dir == Vector2i.ZERO or not _dpad_step():
		dpad_timer.stop()
		return
	dpad_timer.start(0.14)


## One D-pad step. Returns false when holding should stop (blocked, hurt, or a new enemy in view).
func _dpad_step() -> bool:
	if game == null or game.over or dpad_dir == Vector2i.ZERO:
		return false
	_stop_travel()
	var here: Vector2i = game.hero["pos"]
	var hp_before: int = game.hero["hp"]
	var seen_before := game.visible_count()
	var acted := game.player_step_toward(here + dpad_dir)
	_refresh()
	return acted and not game.over and int(game.hero["hp"]) >= hp_before and game.visible_count() <= seen_before


func _on_zoom_cycle() -> void:
	settings["zoom"] = (int(settings["zoom"]) + 1) % ZOOM_NAMES.size()
	_save_settings()
	_update_zoom_label()
	_apply_layout()


func _update_zoom_label() -> void:
	zoom_button.text = "Map zoom: %s" % ZOOM_NAMES[clampi(int(settings["zoom"]), 0, 2)]
