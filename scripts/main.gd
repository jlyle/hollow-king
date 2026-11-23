extends Control
## Builds all UI in code: title / character creation, game screen, and end-of-run overlay.

const MapView := preload("res://scripts/map_view.gd")

## Required CC-BY-4.0 attribution for SRD 5.2.1 content. Keep it in-game on the Credits screen (C-04).
## Godot Engine's MIT notice must ship with every build (C-14).
const GODOT_NOTICE := "Godot Engine, MIT licence. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Full text in LICENSES.md."
const ATTRIBUTION := "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."

## Rows for the Controls screen: [left column, right column]. A row with "" on the right is a section heading.
const CONTROLS := [
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
	["X", "Explore: auto-walk to unexplored areas and items"],
	["+  /  -", "Zoom the map in / out"],
	["M", "Music on / off (volume in Settings)"],
	["F11", "Fullscreen on / off"],
	["?  or  F1", "Open / close this screen"],
	["Esc", "Close a screen. During a run: pause menu. On the title: quit"],
	["MOUSE", ""],
	["Left-click next to you", "Move / attack (diagonals too)"],
	["Left-click a far square", "Auto-walk there (stops when enemies appear)"],
	["Left-click yourself", "Wait, or descend when on >"],
	["Left-click an enemy", "Select it. Wizard/Cleric/Ranger also attack at range; others step toward it"],
	["Right-click", "Inspect a monster, item or square"],
	["Mouse wheel", "Zoom the map"],
	["Buttons under the map", "Potion, Ability, Ranged, Spells, Explore, Descend, Wait, Controls, Menu"],
	["Settings", "Sound, ASCII or Tiles, map zoom, fullscreen (title screen or pause menu)"],
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
var status_label: RichTextLabel
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
# R-22 desktop controls
var actions_grid: GridContainer
var btn_explore: Button
var exploring := false
var zoom_button: Button
var settings_toggles := {}   ## setting key -> CheckButton, so F11 can update the Settings switch
const ZOOM_NAMES := ["Small", "Medium", "Large"]
var pause_info: Label
var btn_menu: Button
var card_title: Label
var card_meta: Label
var card_tag: Label
var card_desc: Label
var card_species: RichTextLabel
var settings_panel: Control

# --- Settings and sound (R-14, R-16, R-17) ---
const SETTINGS_PATH := "user://settings.cfg"
const SOUNDS := ["step", "hit", "crit", "miss", "hurt", "kill", "spell", "heal", "pickup",
	"levelup", "descend", "death", "victory", "enemy_spell", "summon"]
var settings := {"sound": true, "music": true, "music_vol": 1, "tiles": true, "zoom": 1, "fullscreen": false}   ## R-23: tiles by default; R-26 music
var sounds := {}
var sfx: Array = []
var sfx_i := 0
# --- Music (R-26, D-18) ---
const MUSIC_TRACKS := ["title", "cellars", "warrens", "caverns", "crypts", "forge", "boss"]
const AREA_MUSIC := {"Sunken Cellars": "cellars", "Goblin Warrens": "warrens", "Flooded Caverns": "caverns",
		"Bone Crypts": "crypts", "Infernal Forge": "forge", "Throne of the Hollow King": "boss"}
const MUSIC_VOL_NAMES := ["Quiet", "Normal", "Loud"]
const MUSIC_VOL_DB := [-22.0, -14.0, -8.0]
const MUSIC_FADE := 1.5
var music := {}               ## track name -> AudioStreamOggVorbis
var music_players: Array = [] ## two players, crossfaded
var music_active := 0
var music_now := ""
var music_boss_seen := -1     ## floor on which the mini-boss was spotted (boss music until it dies)
var music_vol_button: Button
var _music_fading := false
var _music_tweens: Array = [null, null]
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
	get_window().min_size = Vector2i(1024, 640)
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
	col.add_child(_spacer(24))

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
	col.add_child(_spacer(16))

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
	col.add_child(_spacer(16))

	# Class card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(c_panel, c_line, 1, 14, 22, 18))
	card.custom_minimum_size = Vector2(0, 196)
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
	col.add_child(_spacer(18))

	# Primary actions
	btn_continue = Button.new()
	btn_continue.custom_minimum_size = Vector2(0, 66)
	btn_continue.add_theme_font_size_override("font_size", 24)
	btn_continue.pressed.connect(_on_continue)
	col.add_child(btn_continue)
	col.add_child(_spacer(10))
	btn_start = Button.new()
	btn_start.custom_minimum_size = Vector2(0, 66)
	btn_start.add_theme_font_size_override("font_size", 26)
	btn_start.pressed.connect(_on_start)
	col.add_child(btn_start)
	col.add_child(_spacer(18))

	# Secondary actions: a row of equal buttons under the primary one
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for pair in [["Controls", _show_controls], ["Settings", _show_settings], ["Credits", _show_credits], ["Quit", _quit_game]]:
		row.add_child(_secondary_button(pair[0], pair[1]))
	col.add_child(_spacer(14))
	var foot := _label("5E compatible  ·  Rules from SRD 5.2.1 (CC-BY-4.0), see Credits", 12, c_muted.darkened(0.25))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _build_game() -> void:
	game_screen = _full_margin(20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	game_screen.add_child(col)

	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.cell_tapped.connect(_on_cell_tapped)
	map_view.inspect_requested.connect(_on_inspect)
	map_view.zoom_step.connect(_on_zoom_step)
	col.add_child(map_view)

	# Control strip under the map (R-22): status | message log | action buttons.
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(0, 210)
	strip.add_theme_stylebox_override("panel", _box(c_panel, c_line, 1, 14, 18, 14))
	col.add_child(strip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	strip.add_child(h)

	status_label = RichTextLabel.new()   ## 5.10: values in bright red (STATUS_VALUE), labels in normal text
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("normal_font_size", 19)
	status_label.add_theme_color_override("default_color", Color(0.93, 0.9, 0.82))
	status_label.custom_minimum_size = Vector2(330, 0)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(status_label)
	h.add_child(_vrule())

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 18)
	h.add_child(log_label)
	h.add_child(_vrule())

	actions_grid = GridContainer.new()
	actions_grid.columns = 3
	actions_grid.custom_minimum_size = Vector2(600, 0)
	actions_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(actions_grid)
	actions_grid.add_theme_constant_override("h_separation", 8)
	actions_grid.add_theme_constant_override("v_separation", 8)
	btn_potion = _action_button(actions_grid, "Potion  (Q)", _on_potion)
	btn_ability = _action_button(actions_grid, "Ability  (F)", _on_ability)
	btn_ranged = _action_button(actions_grid, "Ranged  (E)", _on_ranged)
	btn_spells = _action_button(actions_grid, "Spells  (R)", _on_spells)
	btn_explore = _action_button(actions_grid, "Explore  (X)", _on_explore)
	btn_descend = _action_button(actions_grid, "Descend  (Enter)", _on_descend)
	btn_wait = _action_button(actions_grid, "Wait  (Space)", _on_wait)
	btn_help = _action_button(actions_grid, "Controls  (?)", _show_controls)
	btn_menu = _action_button(actions_grid, "Menu  (Esc)", _show_pause)


## Thin vertical divider for the control strip.
func _vrule() -> ColorRect:
	var r := ColorRect.new()
	r.color = c_line
	r.custom_minimum_size = Vector2(1, 0)
	return r


## Applies zoom and fullscreen settings (R-17, R-22).
func _apply_layout() -> void:
	map_view.cols = MapView.ZOOM_COLS[clampi(int(settings["zoom"]), 0, 2)]
	map_view.queue_redraw()
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


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
	# R-09: save when the window loses focus or is closed.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if game and game_screen and game_screen.visible:
			game.save_run()


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	_stop_travel()
	title_screen.show()
	game_screen.hide()
	overlay.hide()
	_update_music()
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
	music_boss_seen = -1
	map_view.game = game
	title_screen.hide()
	game_screen.show()
	overlay.hide()
	_refresh()


const STATUS_VALUE := "ff3b3b"   ## 5.10: bright red for the numbers in the status panel


## Wraps a status value in bright red (5.10).
func _val(t: String) -> String:
	return "[color=#%s]%s[/color]" % [STATUS_VALUE, t]


func _refresh() -> void:
	if game == null:
		return
	game.save_run()  # R-09: autosave after every action (deletes the save once the run is over)
	_play_events()
	_update_music()
	var hd: Dictionary = game.hero
	var nxt := game.xp_next()
	status_label.text = "Floor %s - %s\n%s %s  Lv %s  HP %s  AC %s\nXP %s  Gold %s\n%s" % [
		_val("%d/%d" % [game.floor_num, Game.MAX_FLOOR]), game.floor_theme["name"],
		hd["species"], hd["cls"], _val(str(hd["level"])), _val("%d/%d" % [hd["hp"], hd["hp_max"]]),
		_val(str(game.hero_ac())), _val("%d/%s" % [hd["xp"], (str(nxt) if nxt > 0 else "max")]),
		_val(str(hd["gold"])), String(game.status_extra()).replace("[", "[lb]")]
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
	if key.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_M:
		_toggle_music()
		get_viewport().set_input_as_handled()
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
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_on_zoom_step(1)
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			_on_zoom_step(-1)
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


# --- Settings and sound (R-14, R-16, R-17) ---------------------------------------------

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
	for tname in MUSIC_TRACKS:
		var mpath := "res://audio/music_%s.ogg" % tname
		if ResourceLoader.exists(mpath):
			var st = load(mpath)
			if st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = true
			music[tname] = st
	for _i in 2:
		var mp := AudioStreamPlayer.new()
		mp.volume_db = -80.0
		add_child(mp)
		music_players.append(mp)


## R-26: which track should be playing right now ("" = silence).
func _wanted_music() -> String:
	if not settings["music"]:
		return ""
	if title_screen != null and title_screen.visible:
		return "title"
	if game == null or not game_screen.visible:
		return music_now
	if game.over:
		return ""
	var track: String = AREA_MUSIC.get(String(game.floor_theme.get("name", "")), "cellars")
	if game.stairs_sealed():
		for m in game.monsters:
			if m["hp"] > 0 and m.get("mini", false) and game.visible_monster_at(m["pos"]) != null:
				music_boss_seen = game.floor_num
		if music_boss_seen == game.floor_num:
			track = "boss"
	return track


## Crossfade to the wanted track if it changed.
func _update_music() -> void:
	if music_players.is_empty():
		return
	var want := _wanted_music()
	var vol: float = MUSIC_VOL_DB[clampi(int(settings["music_vol"]), 0, 2)]
	if want == music_now:
		var cur: AudioStreamPlayer = music_players[music_active]
		if cur.playing and not _music_fading:
			cur.volume_db = vol
		return
	music_now = want
	var old: AudioStreamPlayer = music_players[music_active]
	if old.playing:
		_music_tween(music_active).tween_property(old, "volume_db", -60.0, MUSIC_FADE)
		_music_tweens[music_active].tween_callback(old.stop)
	if want == "" or not music.has(want):
		return
	music_active = 1 - music_active
	var nxt: AudioStreamPlayer = music_players[music_active]
	nxt.stream = music[want]
	nxt.volume_db = -50.0
	nxt.play()
	var tw := _music_tween(music_active)
	_music_fading = true
	tw.tween_property(nxt, "volume_db", vol, MUSIC_FADE)
	tw.tween_callback(func(): _music_fading = false)


## A fresh tween for player i, cancelling any fade still running on it.
func _music_tween(i: int) -> Tween:
	var old_tw: Tween = _music_tweens[i]
	if old_tw != null and old_tw.is_valid():
		old_tw.kill()
		_music_fading = false
	var tw := create_tween()
	_music_tweens[i] = tw
	return tw


func _toggle_music() -> void:
	settings["music"] = not settings["music"]
	_save_settings()
	_sync_settings_toggles()
	_update_music()


func _on_music_vol_cycle() -> void:
	settings["music_vol"] = (int(settings["music_vol"]) + 1) % MUSIC_VOL_NAMES.size()
	_save_settings()
	_update_music_vol_label()
	_update_music()


func _update_music_vol_label() -> void:
	music_vol_button.text = "Music volume: %s" % MUSIC_VOL_NAMES[clampi(int(settings["music_vol"]), 0, 2)]


func _play(sname: String) -> void:
	if not settings["sound"] or not sounds.has(sname):
		return
	var pl: AudioStreamPlayer = sfx[sfx_i]
	sfx_i = (sfx_i + 1) % sfx.size()
	pl.stream = sounds[sname]
	pl.volume_db = -8.0 if sname == "step" else 0.0
	pl.play()


## Plays the sounds the last action produced (at most 3 at once).
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
		["music", "Music  (M)"],
		["tiles", "Tile graphics (off = ASCII)"],
		["fullscreen", "Fullscreen  (F11)"],
	]
	for row in rows:
		var cb := CheckButton.new()
		cb.text = row[1]
		cb.button_pressed = settings[row[0]]
		cb.custom_minimum_size = Vector2(0, 84)
		cb.add_theme_font_size_override("font_size", 26)
		cb.toggled.connect(_on_setting.bind(String(row[0])))
		settings_toggles[row[0]] = cb
		v.add_child(cb)
	music_vol_button = Button.new()
	music_vol_button.custom_minimum_size = Vector2(0, 76)
	music_vol_button.add_theme_font_size_override("font_size", 24)
	music_vol_button.pressed.connect(_on_music_vol_cycle)
	v.add_child(music_vol_button)
	_update_music_vol_label()
	zoom_button = Button.new()
	zoom_button.custom_minimum_size = Vector2(0, 76)
	zoom_button.add_theme_font_size_override("font_size", 24)
	zoom_button.pressed.connect(_on_zoom_cycle)
	v.add_child(zoom_button)
	_update_zoom_label()
	var note := _label("Sounds, music and tiles are original, generated by the scripts in tools/.", 17, Color(0.55, 0.55, 0.6))
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
		"music":
			_update_music()
		"fullscreen":
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


## Outlined panel button for secondary actions (Controls, Settings, Credits, Quit).
## Same height and width as its neighbours; the gold primary button stays the only filled one (D-11).
func _secondary_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _box(c_panel, c_line, 1, 10))
	b.add_theme_stylebox_override("hover", _box(c_panel.lightened(0.06), c_gold.darkened(0.2), 1, 10))
	b.add_theme_stylebox_override("pressed", _box(c_panel.darkened(0.2), c_gold, 1, 10))
	b.add_theme_stylebox_override("hover_pressed", _box(c_panel.darkened(0.2), c_gold, 1, 10))
	b.add_theme_color_override("font_color", c_text)
	b.add_theme_color_override("font_hover_color", c_gold)
	b.add_theme_color_override("font_pressed_color", c_gold)
	b.add_theme_color_override("font_hover_pressed_color", c_gold)
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
		["ART & SOUND", "Original tiles, sound effects and cheesy synth music, generated by the scripts in tools/."],
		["LICENCE", "Free and open source (D-17). Code: MIT. Art, sound and text: CC-BY-4.0, by Jim Lyle. Source: github.com/jlyle/hollow-king"],
		["RULES", "5E compatible. " + ATTRIBUTION],
		["ENGINE", GODOT_NOTICE],
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


# --- Desktop controls (R-22) ---------------------------------------------------------------

## Right-click: inspect a square (R-22).
func _on_inspect(c: Vector2i) -> void:
	if game == null or game.over:
		return
	game.inspect(c)
	_refresh()


## Mouse wheel or +/-: change map zoom (R-22).
func _on_zoom_step(delta: int) -> void:
	settings["zoom"] = clampi(int(settings["zoom"]) + delta, 0, 2)
	_save_settings()
	_update_zoom_label()
	_apply_layout()


func _toggle_fullscreen() -> void:
	settings["fullscreen"] = not settings["fullscreen"]
	_save_settings()
	_apply_layout()
	_sync_settings_toggles()


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


func _on_zoom_cycle() -> void:
	settings["zoom"] = (int(settings["zoom"]) + 1) % ZOOM_NAMES.size()
	_save_settings()
	_update_zoom_label()
	_apply_layout()


func _update_zoom_label() -> void:
	zoom_button.text = "Map zoom: %s" % ZOOM_NAMES[clampi(int(settings["zoom"]), 0, 2)]


func _sync_settings_toggles() -> void:
	for k in settings_toggles:
		var cb: CheckButton = settings_toggles[k]
		cb.set_pressed_no_signal(bool(settings[k]))
