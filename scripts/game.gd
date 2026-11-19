class_name Game
extends RefCounted
## Core game state and turn loop. No UI code lives here, so it can be tested headless.
## claude-requirements.md is the source of truth for the rules implemented here.
##
## Turn structure (2024 rules, adapted for a grid roguelike):
##   - The hero gets one Action per turn (move one square, attack, cast) plus one Bonus Action
##     (potion, Second Wind, Hide, Rage, Healing Word, Hunter's Mark...) that does NOT end the turn.
##   - Then every awake monster takes its turn.

const MAX_FLOOR := 20
const XP_MULT := 1.0          ## Tuning knob: raise to level faster.
const LOG_SIZE := 6
const LONG_REST_FLOORS := [5, 9, 13, 17, 20]   ## Arriving on these floors grants a Long Rest.
const SAVE_PATH := "user://run.save"   ## R-09: single autosave slot
const SAVE_TMP := "user://run.save.tmp"
const SAVE_VERSION := 2

## Ability indexes for monster saving throws ("sv" arrays).
const STR := 0
const DEX := 1
const CON := 2
const INT := 3
const WIS := 4
const CHA := 5

## Spells that need a visible enemy target.
const TARGETED := ["fire_bolt", "magic_missile", "burning_hands", "shatter", "fireball",
	"sacred_flame", "guiding_bolt", "hunters_mark"]

var rng := RandomNumberGenerator.new()
var seed_value := 0
var floor_num := 1
var floor_theme: Dictionary = {}
var w := 0
var h := 0
var tiles := PackedByteArray()
var explored := PackedByteArray()
var vis := PackedByteArray()
var stairs := Vector2i(-1, -1)
var monsters: Array = []
var items: Dictionary = {}       ## Vector2i -> "potion" | "greater" | "gold" | "weapon" | "armor"
var hero: Dictionary = {}
var astar := AStarGrid2D.new()
var over := false
var won := false
var turn := 0
var log_lines: Array = []
var travel: Array = []
var target = null                ## Currently selected enemy (Dictionary) or null
var bonus_used := false
var sneak_used := false
var uncanny_used := false
var death_cause := ""
var _spot_i := 0


# --- Setup -----------------------------------------------------------------------

func new_game(cls: String, species: String, seed_in: int = -1) -> void:
	seed_value = seed_in if seed_in >= 0 else randi()
	rng.seed = seed_value
	over = false
	won = false
	turn = 0
	log_lines.clear()
	_make_hero(cls, species)
	say("You descend into the dark as a %s %s." % [species, cls])
	start_floor(1)


func _make_hero(cls: String, species: String) -> void:
	var c: Dictionary = GameData.CLASSES[cls]
	var scores: Dictionary = c["scores"]
	hero = {
		"cls": cls, "species": species, "level": 1, "xp": 0,
		"scores": scores.duplicate(),
		"hp": 0, "hp_max": 0, "hit_dice": 1,
		"pos": Vector2i.ZERO,
		"potions": 2, "greater": 0, "gold": 0,
		"weapon_bonus": 0, "armor_bonus": 0,
		"second_wind": 0, "slots": 0, "rage_uses": 0, "channel": 0, "hm_free": 0,
		"arcane_used": false,
		"hidden": false, "stealth": 0,
		"rage": 0, "reckless": false,
		"conc": "", "ensnare_ready": false, "poisoned": 0,
		"inspiration": species == "Human", "relentless": species == "Orc",
		"kills": 0,
	}
	var pools := _pool_maxes()
	for k in pools:
		hero[k] = pools[k]
	var hp: int = c["hit_die"] + _mod("con") + (1 if species == "Dwarf" else 0)
	hero["hp_max"] = hp
	hero["hp"] = hp


func start_floor(n: int) -> void:
	floor_num = n
	var gen := DungeonGen.new()
	var d := gen.generate(n, rng)
	w = d["w"]
	h = d["h"]
	tiles = d["tiles"]
	floor_theme = d["theme"]
	stairs = d["stairs"]
	explored = PackedByteArray()
	explored.resize(w * h)
	explored.fill(0)
	vis = PackedByteArray()
	vis.resize(w * h)
	vis.fill(0)
	monsters.clear()
	items.clear()
	travel.clear()
	target = null
	hero["pos"] = d["start"]
	hero["hidden"] = false
	hero["rage"] = 0
	hero["conc"] = ""
	hero["ensnare_ready"] = false
	_setup_astar()
	_spawn(d)
	_compute_fov()
	say("[color=#e8c170]- Floor %d: %s -[/color]" % [n, floor_theme["name"]])
	if n == MAX_FLOOR:
		say("[color=#c58bff]A cold voice echoes: \"Kneel before the Hollow King.\"[/color]")


func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astar.update()
	for y in h:
		for x in w:
			if not _walkable(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)


func _spawn(d: Dictionary) -> void:
	var reach: Array = d["reachable"]
	var dist: PackedInt32Array = d["dist"]
	var far_cells: Array = []
	for item in reach:
		var p: Vector2i = item
		if dist[p.y * w + p.x] >= 7 and p != stairs and tiles[p.y * w + p.x] == DungeonGen.FLOOR:
			far_cells.append(p)
	_shuffle(far_cells)

	var eligible: Array = []
	for entry in GameData.MONSTERS:
		if floor_num >= entry["lo"] and floor_num <= entry["hi"]:
			eligible.append(entry)
	var count := 4 + floor_num / 2 + rng.randi_range(0, 2)
	if floor_num >= MAX_FLOOR:
		count = 6
	var ci := 0
	for _i in count:
		if ci >= far_cells.size() or eligible.is_empty():
			break
		var md: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
		var p: Vector2i = far_cells[ci]
		ci += 1
		if monster_at(p) != null:
			continue
		_add_monster(md, p)
		if md.get("pack", false):
			for _j in rng.randi_range(0, 2):
				var q = _free_neighbor(p)
				if q != null:
					_add_monster(md, q)

	# R-13: mini-boss guarding (and sealing) the stairs on floors 5, 10, 15.
	if GameData.MINI_BOSSES.has(floor_num) and stairs.x >= 0:
		var guard = _free_neighbor(stairs)
		if guard != null:
			_add_monster(GameData.MINI_BOSSES[floor_num], guard)

	var boss_pos: Vector2i = d["boss"]
	if boss_pos.x >= 0:
		_add_monster(GameData.BOSS, boss_pos)
		for _k in 3:
			var q = _free_neighbor(boss_pos)
			if q != null:
				_add_monster(GameData.monster("wight"), q)

	var spots: Array = reach.duplicate()
	_shuffle(spots)
	_spot_i = 0
	for _i in 1 + rng.randi_range(0, 1):
		_place_item(spots, "greater" if floor_num >= 8 and rng.randf() < 0.5 else "potion")
	for _i in 3 + rng.randi_range(0, 2):
		_place_item(spots, "gold")
	if floor_num >= 3 and hero["weapon_bonus"] < 3 and rng.randf() < 0.3:
		_place_item(spots, "weapon")
	if floor_num >= 5 and hero["armor_bonus"] < 3 and rng.randf() < 0.25:
		_place_item(spots, "armor")


func _add_monster(md: Dictionary, p: Vector2i) -> Dictionary:
	var m := md.duplicate(true)
	m["hp_max"] = md["hp"]
	m["hp"] = md["hp"]
	m["pos"] = p
	m["awake"] = false
	m["no_regen"] = false
	m["cd"] = 2
	m["restrained"] = false
	m["turned"] = 0
	m["guided"] = false
	m["marked"] = false
	m["cds"] = {}      # spell / summon cooldowns (R-12)
	monsters.append(m)
	return m


func _place_item(spots: Array, kind: String) -> void:
	while _spot_i < spots.size():
		var p: Vector2i = spots[_spot_i]
		_spot_i += 1
		if p == hero["pos"] or p == stairs or items.has(p):
			continue
		if tiles[p.y * w + p.x] != DungeonGen.FLOOR:
			continue
		items[p] = kind
		return


# --- Save / resume (R-09) ----------------------------------------------------------

## Writes the whole run to disk. Called after every action. Deletes the save once the run is over.
func save_run() -> void:
	if over:
		delete_save()
		return
	var data := {
		"version": SAVE_VERSION,
		"seed_value": seed_value, "rng_seed": rng.seed, "rng_state": rng.state,
		"floor_num": floor_num, "floor_theme": floor_theme, "w": w, "h": h,
		"tiles": tiles, "explored": explored, "stairs": stairs,
		"monsters": monsters, "items": items, "hero": hero,
		"turn": turn, "log_lines": log_lines, "bonus_used": bonus_used,
	}
	# Write to a temp file, then swap it in, so a kill mid-write never corrupts the save.
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(data)
	f.close()
	var real := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(real)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_TMP), real)


## Restores a saved run. Returns false if there is no valid save.
func load_run() -> bool:
	var data := Game.read_save()
	if data.is_empty():
		return false
	seed_value = data["seed_value"]
	rng.seed = data["rng_seed"]
	rng.state = data["rng_state"]  # same future rolls: quitting can't reroll a bad outcome
	floor_num = data["floor_num"]
	floor_theme = data["floor_theme"]
	w = data["w"]
	h = data["h"]
	tiles = data["tiles"]
	explored = data["explored"]
	stairs = data["stairs"]
	monsters = data["monsters"]
	items = data["items"]
	hero = data["hero"]
	turn = data["turn"]
	log_lines = data["log_lines"]
	bonus_used = data["bonus_used"]
	if not hero.has("poisoned"):
		hero["poisoned"] = 0
	for m in monsters:
		if not m.has("cds"):
			m["cds"] = {}
	over = false
	won = false
	target = null
	travel.clear()
	vis = PackedByteArray()
	vis.resize(w * h)
	vis.fill(0)
	_setup_astar()
	_compute_fov()
	say("[color=#7fc2ff]Run resumed.[/color]")
	return true


static func read_save() -> Dictionary:
	for path in [SAVE_PATH, SAVE_TMP]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data = f.get_var()
		f.close()
		if data is Dictionary and data.get("version", -1) == SAVE_VERSION and data.has("hero"):
			return data
	return {}


static func has_save() -> bool:
	return not read_save().is_empty()


static func delete_save() -> void:
	for path in [SAVE_PATH, SAVE_TMP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- Queries used by the UI --------------------------------------------------------

func say(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > LOG_SIZE:
		log_lines.pop_front()


func monster_at(p: Vector2i):
	for m in monsters:
		if m["hp"] > 0 and m["pos"] == p:
			return m
	return null


func visible_monster_at(p: Vector2i):
	if not _in_bounds(p) or vis[p.y * w + p.x] == 0:
		return null
	return monster_at(p)


func any_monster_visible() -> bool:
	for m in monsters:
		var p: Vector2i = m["pos"]
		if m["hp"] > 0 and vis[p.y * w + p.x] == 1:
			return true
	return false


func explored_walkable(p: Vector2i) -> bool:
	return _in_bounds(p) and explored[p.y * w + p.x] == 1 and _walkable(p)


func on_stairs() -> bool:
	return hero["pos"] == stairs


## R-13: the stairs stay sealed while a mini-boss on this floor lives.
func stairs_sealed() -> bool:
	for m in monsters:
		if m["hp"] > 0 and m.get("mini", false):
			return true
	return false


func _guardian_name() -> String:
	for m in monsters:
		if m["hp"] > 0 and m.get("mini", false):
			return m["name"]
	return ""


func hero_ac() -> int:
	var base := 10
	match hero["cls"]:
		"Fighter":
			base = 19  # chain mail 16 + shield 2 + Defense fighting style 1
		"Cleric":
			base = 18  # chain mail 16 + shield 2 (Protector)
		"Rogue":
			base = 11 + _mod("dex")  # leather armor
		"Ranger":
			base = 12 + _mod("dex")  # studded leather
		"Wizard":
			base = 13 + _mod("dex")  # Mage Armor
		"Barbarian":
			base = 10 + _mod("dex") + _mod("con")  # Unarmored Defense
	return base + int(hero["armor_bonus"])


func prof() -> int:
	return GameData.prof(hero["level"])


func xp_next() -> int:
	var lvl: int = hero["level"]
	return GameData.XP_TABLE[lvl] if lvl < 20 else -1


func describe(m: Dictionary) -> void:
	var tags := ""
	if m.get("restrained", false):
		tags += ", restrained"
	if int(m.get("turned", 0)) > 0:
		tags += ", turned"
	if m.get("marked", false):
		tags += ", marked"
	say("%s - AC %d, %s%s." % [m["name"], m["ac"], _health_word(m), tags])


func set_target(m) -> void:
	target = m


func has_ranged() -> bool:
	return _cls()["ranged"] != ""


func is_caster() -> bool:
	return _cls()["caster"] != ""


func max_slots() -> int:
	match _cls()["slots"]:
		"full":
			return GameData.FULL_CASTER_SLOTS[int(hero["level"]) - 1]
		"half":
			return GameData.HALF_CASTER_SLOTS[int(hero["level"]) - 1]
	return 0


func max_spell_level() -> int:
	var lvl: int = hero["level"]
	match _cls()["slots"]:
		"full":
			return mini(9, ceili(lvl / 2.0))
		"half":
			return mini(5, (lvl - 1) / 4 + 1)
	return 0


func spell_dc() -> int:
	return 8 + _caster_mod() + prof()


## Short extra status line for the HUD.
func status_extra() -> String:
	var parts: Array = []
	if is_caster():
		parts.append("Slots %d/%d" % [hero["slots"], max_slots()])
		parts.append("DC %d" % spell_dc())
	if hero["cls"] == "Cleric" and int(hero["level"]) >= 2:
		parts.append("Channel %d" % hero["channel"])
	if hero["cls"] == "Barbarian":
		parts.append("Rage %d left" % hero["rage_uses"])
		if int(hero["rage"]) > 0:
			parts.append("RAGING %d" % hero["rage"])
		if hero["reckless"]:
			parts.append("Reckless")
	if hero["conc"] != "":
		parts.append("Conc: %s" % GameData.SPELLS[hero["conc"]]["name"])
	if int(hero.get("poisoned", 0)) > 0:
		parts.append("POISONED %d" % hero["poisoned"])
	if hero["hidden"]:
		parts.append("HIDDEN")
	return "  ".join(PackedStringArray(parts))


## Every spell of the hero's class, with "why" = "" when castable right now.
func available_spells() -> Array:
	var out: Array = []
	for key in GameData.SPELLS:
		var sp: Dictionary = GameData.SPELLS[key]
		if sp["cls"] != hero["cls"]:
			continue
		out.append({"key": key, "name": sp["name"], "desc": sp["desc"], "cost": _cost_text(sp, key), "why": cannot_cast(key)})
	return out


# --- Player actions ----------------------------------------------------------------

## Moves or attacks one square. Returns true if a turn was spent.
func player_step(d: Vector2i) -> bool:
	if over or d == Vector2i.ZERO:
		return false
	var from: Vector2i = hero["pos"]
	var t: Vector2i = from + d
	if not _can_step(from, d):
		return false
	var m = monster_at(t)
	if m != null:
		target = m
		_hero_attack_action(m, false)
	else:
		hero["pos"] = t
		_pickup()
		if t == stairs:
			if stairs_sealed():
				say("[color=#ff6b6b]A ward seals the stairs. Defeat the %s first.[/color]" % _guardian_name())
			else:
				say("Stairs lead down. Tap Descend (or tap yourself).")
	_end_turn()
	return true


func player_step_toward(dest: Vector2i) -> bool:
	var from: Vector2i = hero["pos"]
	var d := Vector2i(signi(dest.x - from.x), signi(dest.y - from.y))
	if player_step(d):
		return true
	if d.x != 0 and player_step(Vector2i(d.x, 0)):
		return true
	if d.y != 0 and player_step(Vector2i(0, d.y)):
		return true
	return false


func player_wait() -> void:
	if over:
		return
	_end_turn()


func plan_travel(dest: Vector2i) -> void:
	travel.clear()
	var path := astar.get_id_path(hero["pos"], dest)
	for i in range(1, path.size()):
		travel.append(path[i])


func player_potion() -> void:
	if over:
		return
	if bonus_used:
		say("You've already used your Bonus Action this turn.")
		return
	var normal: int = hero["potions"]
	var greater: int = hero["greater"]
	if normal + greater == 0:
		say("You have no potions.")
		return
	var missing: int = hero["hp_max"] - hero["hp"]
	var heal := 0
	if greater > 0 and (missing >= 14 or normal == 0):
		hero["greater"] = greater - 1
		heal = roll(4, 4) + 4
		say("You drink a Potion of Greater Healing (+%d HP)." % heal)
	else:
		hero["potions"] = normal - 1
		heal = roll(2, 4) + 2
		say("You drink a Potion of Healing (+%d HP)." % heal)
	_heal(heal)
	bonus_used = true


## The class's main button: Second Wind, Hide, Rage, Magic Missile, Healing Word or Hunter's Mark.
func player_ability() -> void:
	if over:
		return
	match hero["cls"]:
		"Fighter":
			_second_wind()
		"Rogue":
			_hide()
		"Barbarian":
			_rage()
		"Wizard":
			cast("magic_missile")
		"Cleric":
			cast("healing_word")
		"Ranger":
			cast("hunters_mark")


## Long-range attack: Fire Bolt (Wizard), Sacred Flame (Cleric) or Longbow (Ranger).
func player_ranged(pref = null) -> void:
	if over:
		return
	var kind: String = _cls()["ranged"]
	if kind == "":
		return
	if kind == "longbow":
		var t = _pick_target(pref)
		if t == null:
			say("No visible target for your longbow.")
			return
		_hero_attack_action(t, true)
		_end_turn()
	else:
		cast(kind, pref)


func toggle_reckless() -> void:
	if hero["cls"] != "Barbarian" or int(hero["level"]) < 2:
		say("Reckless Attack unlocks at Barbarian level 2.")
		return
	hero["reckless"] = not hero["reckless"]
	say("Reckless Attack %s." % ("ON: Advantage on your attacks, enemies get Advantage on you" if hero["reckless"] else "OFF"))


func player_descend() -> void:
	if over:
		return
	if not on_stairs():
		say("You need to stand on the stairs (>).")
		return
	if stairs_sealed():
		say("[color=#ff6b6b]The stairs are sealed until the %s falls.[/color]" % _guardian_name())
		return
	var next := floor_num + 1
	if next in LONG_REST_FLOORS:
		_long_rest()
	else:
		_short_rest()
	start_floor(next)


# --- Spells (R-11) -----------------------------------------------------------------

## Returns "" if the spell can be cast right now, otherwise the reason it can't.
func cannot_cast(key: String) -> String:
	if not GameData.SPELLS.has(key):
		return "Unknown spell."
	var sp: Dictionary = GameData.SPELLS[key]
	var lvl: int = sp["lvl"]
	if sp["cls"] != hero["cls"]:
		return "Not a %s spell." % hero["cls"]
	if int(hero["level"]) < int(sp["min"]):
		return "Requires level %d." % sp["min"]
	if sp["cast"] == "bonus" and bonus_used:
		return "Bonus Action already used this turn."
	if lvl == -1 and int(hero["channel"]) <= 0:
		return "No Channel Divinity left."
	if lvl >= 1:
		var free := key == "hunters_mark" and int(hero["hm_free"]) > 0
		if not free and int(hero["slots"]) <= 0:
			return "No spell slots left."
		if lvl > max_spell_level():
			return "Needs a level %d slot." % lvl
	if key in TARGETED:
		var t = _pick_target(null, false)
		if t == null:
			return "No visible target."
		if key == "burning_hands" and _cheb(t["pos"], hero["pos"]) > 3:
			return "Target must be within 3 squares."
	if key == "thunderwave" and not _enemy_adjacent():
		return "No enemy next to you."
	if key == "turn_undead" and _undead_in_range().is_empty():
		return "No undead within 6 squares."
	return ""


func cast(key: String, pref = null) -> void:
	if over:
		return
	if pref != null:
		target = pref
	var why := cannot_cast(key)
	if why != "":
		say(why)
		return
	var sp: Dictionary = GameData.SPELLS[key]
	var lvl: int = sp["lvl"]
	var t = _pick_target(pref) if key in TARGETED else null
	var up := maxi(0, max_spell_level() - lvl) if lvl >= 1 else 0
	# Pay the cost.
	if lvl >= 1:
		if key == "hunters_mark" and int(hero["hm_free"]) > 0:
			hero["hm_free"] -= 1
		else:
			hero["slots"] -= 1
	elif lvl == -1:
		hero["channel"] -= 1
	hero["hidden"] = false
	var is_bonus: bool = sp["cast"] == "bonus"
	if is_bonus:
		bonus_used = true
	var dc := spell_dc()

	match key:
		"fire_bolt":
			_spell_attack(t, "Fire Bolt", roll_spec(_cantrip_dice(), 10), "fire")
		"guiding_bolt":
			if _spell_attack(t, "Guiding Bolt", roll_spec(4 + up, 6), "radiant") and t["hp"] > 0:
				t["guided"] = true
		"sacred_flame":
			var d := roll(_cantrip_dice(), 8)
			if _monster_save(t, DEX, dc):
				say("The %s dodges the Sacred Flame." % t["name"])
			else:
				say("Sacred Flame sears the %s for %d radiant." % [t["name"], d])
				_damage_monster(t, d, false, "radiant")
		"magic_missile":
			var darts := 3 + up
			say("Magic Missile! %d glowing darts streak out." % darts)
			var targets := _visible_monsters_by_distance()
			targets.erase(t)
			targets.push_front(t)
			var ti := 0
			for _i in darts:
				while ti < targets.size() and targets[ti]["hp"] <= 0:
					ti += 1
				if ti >= targets.size():
					break
				_damage_monster(targets[ti], roll(1, 4) + 1, false, "force")
		"burning_hands":
			var tp: Vector2i = t["pos"]
			var me: Vector2i = hero["pos"]
			var dir := Vector2(tp - me).normalized()
			var hit: Array = []
			for m in _visible_monsters_by_distance():
				var mpos: Vector2i = m["pos"]
				var off: Vector2i = mpos - me
				if _cheb(m["pos"], hero["pos"]) <= 3 and Vector2(off).normalized().dot(dir) >= 0.7:
					hit.append(m)
			_area_save(hit, "Burning Hands", roll(3 + up, 6), "fire", DEX, dc, false)
		"thunderwave":
			var hit: Array = []
			for m in monsters:
				if m["hp"] > 0 and _cheb(m["pos"], hero["pos"]) <= 1:
					hit.append(m)
			_area_save(hit, "Thunderwave", roll(2 + up, 8), "thunder", CON, dc, true)
		"shatter":
			_area_save(_monsters_near(t["pos"], 2), "Shatter", roll(3 + up, 8), "thunder", CON, dc, false, t["pos"], 2)
		"fireball":
			_area_save(_monsters_near(t["pos"], 4), "Fireball", roll(8 + up, 6), "fire", DEX, dc, false, t["pos"], 4)
		"healing_word":
			var amt := roll(2 * (1 + up), 4) + _caster_mod()
			_heal(amt)
			say("Healing Word: +%d HP." % amt)
		"cure_wounds":
			var amt := roll(2 * (1 + up), 8) + _caster_mod()
			_heal(amt)
			say("Cure Wounds: +%d HP." % amt)
		"turn_undead":
			var turned := 0
			for m in _undead_in_range():
				if not _monster_save(m, WIS, dc):
					m["turned"] = 10
					m["awake"] = true
					turned += 1
			say("You present your holy symbol. %d undead flee in terror." % turned)
		"spirit_guardians":
			_set_conc(key)
			say("Spectral guardians swirl around you.")
		"hunters_mark":
			_set_conc(key)
			for m in monsters:
				m["marked"] = false
			t["marked"] = true
			say("You mark the %s as your quarry." % t["name"])
		"ensnaring_strike":
			_set_conc(key)
			hero["ensnare_ready"] = true
			say("Thorny vines coil around your weapon. Your next hit can ensnare.")

	if not is_bonus:
		_end_turn()


## Rolls a ready-made damage number (helper keeps match arms short).
func roll_spec(count: int, sides: int) -> Array:
	return [count, sides]


## Spell attack roll. Returns true on a hit.
func _spell_attack(t: Dictionary, sname: String, dice: Array, kind: String) -> bool:
	var adv := 0
	var dis := 0
	if t.get("guided", false):
		adv += 1
		t["guided"] = false
	if t.get("restrained", false):
		adv += 1
	if _enemy_adjacent():
		dis += 1  # ranged attack with an enemy within 5 ft
	if int(hero.get("poisoned", 0)) > 0:
		dis += 1  # Poisoned: Disadvantage on attack rolls
	var a := _net_adv(adv, dis)
	var bonus: int = _caster_mod() + prof()
	var r := _hero_d20(a)
	var hit := _is_hit(r, bonus, t["ac"])
	if not hit and hero["inspiration"]:
		hero["inspiration"] = false
		say("Heroic Inspiration - you reroll.")
		r = _hero_d20(a)
		hit = _is_hit(r, bonus, t["ac"])
	if not hit:
		say("Your %s misses the %s." % [sname, t["name"]])
		return false
	var crit := r == 20
	var dmg := roll(int(dice[0]) * (2 if crit else 1), dice[1])
	say("%s %s the %s for %d %s." % [sname, "CRITS" if crit else "hits", t["name"], dmg, kind])
	_damage_monster(t, dmg, crit, kind)
	return true


## Saving-throw damage to a group. Optional center/radius lets the blast catch the hero too.
func _area_save(targets: Array, sname: String, dmg: int, kind: String, ability: int, dc: int,
		push: bool, center := Vector2i(-99, -99), radius := 0) -> void:
	var results: Array = []
	var saved_list: Array = []
	for m in targets:
		var saved := _monster_save(m, ability, dc)
		saved_list.append(saved)
		results.append("%s %s" % [m["name"], "saves" if saved else "fails"])
	var who := ", ".join(PackedStringArray(results)) if not results.is_empty() else "nothing caught"
	say("%s (%d %s, DC %d): %s." % [sname, dmg, kind, dc, who])
	for i in targets.size():
		var m: Dictionary = targets[i]
		var saved: bool = saved_list[i]
		if m["hp"] <= 0:
			continue
		_damage_monster(m, dmg / 2 if saved else dmg, false, kind)
		if push and not saved and m["hp"] > 0:
			_push(m, 2)
	if radius > 0 and _cheb(center, hero["pos"]) <= radius:
		var hs := ["str", "dex", "con", "int", "wis", "cha"][ability] as String
		var res := _hero_save_damage(hs, dc, dmg, true)
		say("[color=#ff9966]You're caught in your own %s (%d)![/color]" % [sname, res[0]])
		if int(res[0]) > 0:
			_hurt_hero(res[0], "your own %s" % sname)


func _set_conc(key: String) -> void:
	if hero["conc"] != "":
		_end_conc(false)
	hero["conc"] = key


func _end_conc(announce: bool) -> void:
	var key: String = hero["conc"]
	if key == "":
		return
	match key:
		"hunters_mark":
			for m in monsters:
				m["marked"] = false
		"ensnaring_strike":
			hero["ensnare_ready"] = false
			for m in monsters:
				m["restrained"] = false
	hero["conc"] = ""
	if announce:
		say("[color=#ff9966]Your concentration breaks: %s ends.[/color]" % GameData.SPELLS[key]["name"])


func _cost_text(sp: Dictionary, key: String) -> String:
	var lvl: int = sp["lvl"]
	if lvl == 0:
		return "Cantrip"
	if lvl == -1:
		return "Channel Divinity (%d left)" % hero["channel"]
	if key == "hunters_mark" and int(hero["hm_free"]) > 0:
		return "Free use (%d left)" % hero["hm_free"]
	var cast_at := maxi(lvl, max_spell_level())
	return "1 slot (cast at level %d)" % cast_at


# --- Class features ----------------------------------------------------------------

func _second_wind() -> void:
	if bonus_used:
		say("You've already used your Bonus Action this turn.")
		return
	if hero["second_wind"] <= 0:
		say("Second Wind is spent. Rest to recover it.")
		return
	hero["second_wind"] -= 1
	var amt := roll(1, 10) + int(hero["level"])
	_heal(amt)
	bonus_used = true
	say("Second Wind! You regain %d HP." % amt)


func _hide() -> void:
	if hero["hidden"]:
		say("You are already hidden.")
		return
	if bonus_used:
		say("You've already used your Bonus Action this turn.")
		return
	if _enemy_adjacent():
		say("You can't hide with an enemy right next to you.")
		return
	bonus_used = true
	var total := d20() + _mod("dex") + prof() * 2  # Expertise in Stealth
	if total >= 15:
		hero["hidden"] = true
		hero["stealth"] = total
		say("You melt into the shadows (Stealth %d)." % total)
	else:
		say("You fail to find cover (Stealth %d)." % total)


func _rage() -> void:
	if int(hero["rage"]) > 0:
		say("You are already raging.")
		return
	if bonus_used:
		say("You've already used your Bonus Action this turn.")
		return
	if int(hero["rage_uses"]) <= 0:
		say("No Rage left. Rest to recover it.")
		return
	hero["rage_uses"] -= 1
	hero["rage"] = 10
	bonus_used = true
	say("[color=#ff6b4a]You RAGE! Half damage from weapons and claws, +%d melee damage.[/color]" % _rage_bonus())


func _pool_maxes() -> Dictionary:
	var lvl: int = hero["level"]
	var cls: String = hero["cls"]
	var out := {"second_wind": 0, "rage_uses": 0, "channel": 0, "hm_free": 0, "slots": max_slots()}
	match cls:
		"Fighter":
			out["second_wind"] = 4 if lvl >= 10 else (3 if lvl >= 4 else 2)
		"Barbarian":
			out["rage_uses"] = 6 if lvl >= 17 else (5 if lvl >= 12 else (4 if lvl >= 6 else (3 if lvl >= 3 else 2)))
		"Cleric":
			out["channel"] = 4 if lvl >= 18 else (3 if lvl >= 6 else (2 if lvl >= 2 else 0))
		"Ranger":
			out["hm_free"] = 6 if lvl >= 17 else (5 if lvl >= 13 else (4 if lvl >= 9 else (3 if lvl >= 5 else 2)))
	return out


func _rage_bonus() -> int:
	var lvl: int = hero["level"]
	return 4 if lvl >= 16 else (3 if lvl >= 9 else 2)


func _cantrip_dice() -> int:
	var lvl: int = hero["level"]
	return 1 + (1 if lvl >= 5 else 0) + (1 if lvl >= 11 else 0) + (1 if lvl >= 17 else 0)


# --- Resting -----------------------------------------------------------------------

func _short_rest() -> void:
	var die: int = _cls()["hit_die"]
	var healed := 0
	var spent := 0
	while hero["hit_dice"] > 0 and hero["hp_max"] - hero["hp"] >= die / 2 + 1:
		var amt := maxi(1, rng.randi_range(1, die) + _mod("con"))
		hero["hp"] = mini(hero["hp_max"], hero["hp"] + amt)
		hero["hit_dice"] -= 1
		healed += amt
		spent += 1
	# Features that regain one use on a Short Rest.
	var maxes := _pool_maxes()
	for k in ["second_wind", "rage_uses", "channel"]:
		hero[k] = mini(int(maxes[k]), int(hero[k]) + 1)
	var extra := ""
	if hero["cls"] == "Wizard" and not hero["arcane_used"]:
		var regained := mini(max_slots() - int(hero["slots"]), ceili(int(hero["level"]) / 2.0))
		if regained > 0:
			hero["slots"] += regained
			hero["arcane_used"] = true
			extra = " Arcane Recovery restores %d slot(s)." % regained
	say("Short Rest: spent %d Hit Dice, regained %d HP.%s" % [spent, healed, extra])


func _long_rest() -> void:
	hero["hp"] = hero["hp_max"]
	hero["hit_dice"] = hero["level"]
	var maxes := _pool_maxes()
	for k in maxes:
		hero[k] = maxes[k]
	hero["arcane_used"] = false
	if hero["species"] == "Orc":
		hero["relentless"] = true
	if hero["species"] == "Human":
		hero["inspiration"] = true
	say("[color=#7fc2ff]You find a sealed alcove and take a Long Rest. Fully restored.[/color]")


# --- Combat ------------------------------------------------------------------------

func _hero_attack_action(m: Dictionary, ranged: bool) -> void:
	var lvl: int = hero["level"]
	var attacks := 1
	match hero["cls"]:
		"Fighter":
			attacks += (1 if lvl >= 5 else 0) + (1 if lvl >= 11 else 0) + (1 if lvl >= 20 else 0)
		"Barbarian", "Ranger":
			attacks += 1 if lvl >= 5 else 0
	for _i in attacks:
		if m["hp"] <= 0:
			break
		_weapon_attack(m, ranged)


func _weapon_attack(m: Dictionary, ranged: bool) -> void:
	var c := _cls()
	var adv := 0
	var dis := 0
	if hero["hidden"]:
		adv += 1
	hero["hidden"] = false
	if m.get("guided", false):
		adv += 1
		m["guided"] = false
	if m.get("restrained", false):
		adv += 1
	if not ranged and hero["reckless"] and c["attack_ability"] == "str":
		adv += 1
	if ranged and _enemy_adjacent():
		dis += 1
	if int(hero.get("poisoned", 0)) > 0:
		dis += 1  # Poisoned: Disadvantage on attack rolls
	var a := _net_adv(adv, dis)

	var ab: String = "dex" if ranged else c["attack_ability"]
	var ab_mod := _mod(ab)
	var archery := 2 if ranged and hero["cls"] == "Ranger" and int(hero["level"]) >= 2 else 0
	var bonus: int = ab_mod + prof() + int(hero["weapon_bonus"]) + archery
	var r := _hero_d20(a)
	var hit := _is_hit(r, bonus, m["ac"])
	if not hit and hero["inspiration"]:
		hero["inspiration"] = false
		say("Heroic Inspiration - you reroll.")
		r = _hero_d20(a)
		hit = _is_hit(r, bonus, m["ac"])
	var wname: String = "longbow" if ranged else String(c["weapon"]).to_lower()
	if not hit:
		say("Your %s misses the %s." % [wname, m["name"]])
		return
	var crit := r == 20
	var dice: Array = [1, 8] if ranged else c["dice"]
	var mult := 2 if crit else 1
	var dmg: int = roll(int(dice[0]) * mult, dice[1]) + ab_mod + int(hero["weapon_bonus"])
	var note := ""
	if not ranged and int(hero["rage"]) > 0:
		dmg += _rage_bonus()
		note += " +Rage"
	if hero["cls"] == "Rogue" and a > 0 and not sneak_used:
		sneak_used = true
		dmg += roll(ceili(int(hero["level"]) / 2.0) * mult, 6)
		note += " +Sneak Attack"
	if hero["conc"] == "hunters_mark":
		if not _any_marked():
			m["marked"] = true  # mark moves to the next creature you hit
		if m["marked"]:
			dmg += roll(mult, 6)
			note += " +Mark"
	dmg = maxi(1, dmg)
	say("Your %s %s the %s for %d%s." % [wname, "CRITS" if crit else "hits", m["name"], dmg, note])
	_damage_monster(m, dmg, crit, "")
	if hero["ensnare_ready"] and m["hp"] > 0:
		hero["ensnare_ready"] = false
		if _monster_save(m, STR, spell_dc()):
			say("The %s tears through the vines." % m["name"])
			_end_conc(false)
		else:
			m["restrained"] = true
			say("[color=#7fc24f]Vines ensnare the %s! It is Restrained.[/color]" % m["name"])


func _damage_monster(m: Dictionary, dmg: int, crit: bool, kind: String) -> void:
	m["hp"] -= dmg
	m["awake"] = true
	m["turned"] = 0  # Turn Undead ends when the creature takes damage
	if kind == "fire":
		m["no_regen"] = true
	if m["hp"] <= 0 and m.get("fortitude", false) and not crit and kind != "radiant":
		# Undead Fortitude: Constitution save, DC 5 + damage taken.
		if d20() + int(m["sv"][CON]) >= 5 + dmg:
			m["hp"] = 1
			say("The %s refuses to fall!" % m["name"])
	if m["hp"] <= 0:
		_kill(m)


func _kill(m: Dictionary) -> void:
	var gained := int(int(m["xp"]) * XP_MULT)
	hero["xp"] += gained
	hero["kills"] += 1
	say("The %s is destroyed! (+%d XP)" % [m["name"], gained])
	if is_same(m, target):
		target = null
	if m.get("restrained", false) and hero["conc"] == "ensnaring_strike":
		_end_conc(false)
	var p: Vector2i = m["pos"]
	if rng.randf() < 0.3 and not items.has(p) and p != stairs:
		items[p] = "gold"
	if m.get("boss", false):
		won = true
		over = true
		say("[color=#e8c170]The Hollow King crumbles to dust. The dungeon falls silent.[/color]")
	_check_level_up()


func _check_level_up() -> void:
	while int(hero["level"]) < 20 and int(hero["xp"]) >= GameData.XP_TABLE[int(hero["level"])]:
		var before := _pool_maxes()
		hero["level"] += 1
		var lvl: int = hero["level"]
		var c := _cls()
		var scores: Dictionary = hero["scores"]
		if lvl in [4, 8, 12, 16, 19]:
			var prim: String = c["primary"]
			if scores[prim] <= 18:
				scores[prim] += 2
				say("Ability Score Improvement: %s +2." % prim.to_upper())
			elif scores["con"] <= 18:
				scores["con"] += 2
				say("Ability Score Improvement: CON +2.")
		var die: int = c["hit_die"]
		var gain := maxi(1, die / 2 + 1 + _mod("con") + (1 if hero["species"] == "Dwarf" else 0))
		hero["hp_max"] += gain
		hero["hp"] += gain
		hero["hit_dice"] += 1
		var after := _pool_maxes()
		for k in after:
			hero[k] = int(hero[k]) + int(after[k]) - int(before[k])
		say("[color=#ffe066]Level up! You are now level %d (+%d HP).[/color]" % [lvl, gain])
		var feat := _new_feature(String(hero["cls"]), lvl)
		if feat != "":
			say("New: %s" % feat)


func _new_feature(cls: String, lvl: int) -> String:
	var table := {
		"Fighter": {5: "Extra Attack.", 11: "Two Extra Attacks."},
		"Rogue": {5: "Uncanny Dodge.", 7: "Evasion (DEX saves: none on success, half on failure)."},
		"Barbarian": {2: "Reckless Attack (button).", 5: "Extra Attack."},
		"Ranger": {2: "Archery: +2 to longbow attacks.", 5: "Extra Attack."},
		"Wizard": {3: "Shatter.", 5: "Fireball. Fire Bolt now 2d10."},
		"Cleric": {2: "Turn Undead.", 5: "Spirit Guardians. Sacred Flame now 2d8."},
	}
	var ct: Dictionary = table.get(cls, {})
	return ct.get(lvl, "")


func _heal(amt: int) -> void:
	hero["hp"] = mini(int(hero["hp_max"]), int(hero["hp"]) + amt)


func _hurt_hero(dmg: int, source: String) -> void:
	hero["hp"] -= dmg
	travel.clear()
	if hero["hp"] <= 0:
		if hero["relentless"]:
			hero["relentless"] = false
			hero["hp"] = 1
			say("[color=#ff9966]Relentless Endurance! You refuse to fall.[/color]")
		else:
			hero["hp"] = 0
			over = true
			death_cause = source
			say("[color=#ff5555]You were slain by %s on floor %d.[/color]" % [source, floor_num])
			return
	# Concentration check: CON save, DC 10 or half the damage.
	if hero["conc"] != "" and dmg > 0:
		var dc := mini(30, maxi(10, dmg / 2))
		if _hero_save("con") < dc:
			_end_conc(true)


func _end_turn() -> void:
	_compute_fov()
	uncanny_used = false
	for m in monsters.duplicate():
		if over:
			break
		if m["hp"] > 0:
			_monster_act(m)
		if m["hp"] > 0 and not over:
			_guardian_check(m)
	monsters = monsters.filter(func(mm): return mm["hp"] > 0)
	if target != null and target["hp"] <= 0:
		target = null
	if int(hero.get("poisoned", 0)) > 0:
		hero["poisoned"] -= 1
		if int(hero["poisoned"]) == 0:
			say("The poison wears off.")
	if int(hero["rage"]) > 0:
		hero["rage"] -= 1
		if int(hero["rage"]) == 0:
			say("Your Rage fades.")
	turn += 1
	bonus_used = false
	sneak_used = false
	_compute_fov()


# --- Monster AI --------------------------------------------------------------------

func _monster_act(m: Dictionary) -> void:
	if not m.has("cds"):
		m["cds"] = {}
	var cds: Dictionary = m["cds"]
	for k in cds.keys():
		cds[k] = maxi(0, int(cds[k]) - 1)
	var regen: int = m.get("regen", 0)
	if regen > 0 and m["hp"] < m["hp_max"]:
		if m["no_regen"]:
			m["no_regen"] = false
		else:
			m["hp"] = mini(m["hp_max"], m["hp"] + regen)
	if m.get("restrained", false):
		var bite := roll(1, 6)
		say("Thorny vines bite the %s (%d)." % [m["name"], bite])
		_damage_monster(m, bite, false, "piercing")
		if m["hp"] <= 0:
			return
		if _monster_save(m, STR, spell_dc()):
			m["restrained"] = false
			say("The %s breaks free of the vines." % m["name"])
			if hero["conc"] == "ensnaring_strike":
				_end_conc(false)
	if int(m.get("turned", 0)) > 0:
		m["turned"] -= 1
		_monster_flee(m)
		return

	var mp: Vector2i = m["pos"]
	var hp: Vector2i = hero["pos"]
	var sees := vis[mp.y * w + mp.x] == 1
	var dist := _cheb(mp, hp)

	if hero["hidden"]:
		if sees and dist <= 8 and int(m["pp"]) >= int(hero["stealth"]):
			hero["hidden"] = false
			say("The %s spots you!" % m["name"])
		else:
			if m["awake"] and rng.randf() < 0.5 and not m.get("restrained", false):
				_monster_wander(m)
			return

	if sees and not m["awake"]:
		m["awake"] = true
		if m.get("boss", false):
			say("[color=#c58bff]The Hollow King rises from his throne.[/color]")
		elif m.get("mini", false):
			say("[color=#ff6b6b]The %s stands guard over the stairs![/color]" % m["name"])
	if not m["awake"]:
		return

	if _monster_special(m, dist, sees):
		return

	if dist <= 1 and _can_step(mp, hp - mp):
		_monster_attack(m)
	elif not m.get("restrained", false):
		_monster_move(m)


func _monster_attack(m: Dictionary) -> void:
	_monster_attack_rolls(m, int(m["attacks"]), int(m["atk"]), m["dmg"], String(m.get("dtype", "phys")), "hits")


## Attack rolls against the hero (melee, ranged weapon, or spell attack).
func _monster_attack_rolls(m: Dictionary, n: int, atk: int, dice: Array, dtype: String, verb: String) -> void:
	var ac := hero_ac()
	var hits := 0
	var total := 0
	var physical: bool = dtype == "phys"
	var raging := int(hero["rage"]) > 0
	for _i in n:
		var adv := 0
		var dis := 0
		if m.get("pack", false) and _ally_adjacent(m):
			adv += 1
		if hero["reckless"]:
			adv += 1
		if m.get("restrained", false):
			dis += 1
		var r := d20(_net_adv(adv, dis))
		if r == 20 or (r != 1 and r + atk >= ac):
			var dmg: int = roll(int(dice[0]) * (2 if r == 20 else 1), dice[1]) + int(dice[2])
			if raging and physical:
				dmg = dmg / 2
			if hero["cls"] == "Rogue" and int(hero["level"]) >= 5 and not uncanny_used:
				uncanny_used = true
				dmg = dmg / 2
				say("Uncanny Dodge halves the blow.")
			hits += 1
			total += dmg
	if hits == 0:
		say("The %s misses you%s." % [m["name"], "" if verb == "hits" else " (" + verb + ")"])
		return
	var rage_note := " (Rage halves it)" if raging and physical else ""
	if n == 1:
		say("The %s %s you for %d%s." % [m["name"], verb, total, rage_note])
	else:
		say("The %s %s you %d of %d times for %d%s." % [m["name"], verb, hits, n, total, rage_note])
	_hurt_hero(total, "a " + String(m["name"]))


## R-12: summons, spells and ranged attacks. Returns true if the monster used its turn.
func _monster_special(m: Dictionary, dist: int, sees: bool) -> bool:
	var cds: Dictionary = m["cds"]
	if m.has("summon") and int(cds.get("summon", 2)) <= 0:
		var sm: Dictionary = m["summon"]
		cds["summon"] = sm["cd"]
		var mp: Vector2i = m["pos"]
		var raised := 0
		for d in DungeonGen.DIRS:
			if raised >= int(sm["n"]) or monsters.size() > 16:
				break
			var q: Vector2i = mp + d
			if _walkable(q) and q != hero["pos"] and monster_at(q) == null:
				var s := _add_monster(GameData.monster(sm["key"]), q)
				s["awake"] = true
				raised += 1
		if raised > 0:
			say("[color=#c58bff]The %s %s[/color]" % [m["name"], sm["msg"]])
			return true
	elif m.has("summon") and not cds.has("summon"):
		cds["summon"] = 2  # first summon a couple of turns after waking

	if not sees:
		return false
	for item in m.get("spells", []):
		var sp: Dictionary = item
		var sname: String = sp["name"]
		if int(cds.get(sname, 0)) > 0:
			continue
		match sp["kind"]:
			"heal":
				var patient = _wounded_ally(m, int(sp["range"]))
				if patient != null:
					var dice: Array = sp["dmg"]
					var amt := roll(dice[0], dice[1]) + int(dice[2])
					patient["hp"] = mini(int(patient["hp_max"]), int(patient["hp"]) + amt)
					cds[sname] = sp["cd"]
					var who := "itself" if is_same(patient, m) else "the " + String(patient["name"])
					say("The %s casts %s on %s (+%d HP)." % [m["name"], sname, who, amt])
					return true
			"attack":
				if dist >= 2 and dist <= int(sp["range"]):
					cds[sname] = sp["cd"]
					_monster_attack_rolls(m, 1, int(sp["atk"]), sp["dmg"], String(sp["dtype"]), "casts " + sname + " at")
					return true
			"save":
				if dist <= int(sp["range"]):
					cds[sname] = sp["cd"]
					_monster_save_spell(m, sp)
					return true
	if m.has("ranged") and dist >= 2:
		var rg: Dictionary = m["ranged"]
		if dist <= int(rg["range"]):
			_monster_attack_rolls(m, 1, int(rg["atk"]), rg["dmg"], "phys", "shoots")
			return true
	return false


## A spell that forces the hero to make a saving throw.
func _monster_save_spell(m: Dictionary, sp: Dictionary) -> void:
	var dice: Array = sp["dmg"]
	var dmg := roll(dice[0], dice[1]) + int(dice[2])
	var ab: String = sp["ability"]
	var dc: int = sp["dc"]
	var res := _hero_save_damage(ab, dc, dmg, bool(sp.get("half", false)))
	var dealt: int = res[0]
	var saved: bool = res[1]
	say("The %s casts %s: you %s the %s save (DC %d) and take %d %s." % [
		m["name"], sp["name"], "make" if saved else "fail", ab.to_upper(), dc, dealt, sp["dtype"]])
	if not saved:
		match String(sp.get("effect", "")):
			"poison":
				hero["poisoned"] = maxi(int(hero.get("poisoned", 0)), 2)
				say("[color=#9be04f]You are Poisoned (Disadvantage on attacks).[/color]")
			"push":
				_push_hero(m["pos"], 2)
	if dealt > 0:
		_hurt_hero(dealt, "the %s's %s" % [m["name"], sp["name"]])


## Returns [damage taken, saved]. Rogue Evasion (level 7) improves DEX saves.
func _hero_save_damage(ability: String, dc: int, dmg: int, half: bool) -> Array:
	var saved := _hero_save(ability) >= dc
	if ability == "dex" and hero["cls"] == "Rogue" and int(hero["level"]) >= 7 and half:
		return [0 if saved else dmg / 2, saved]
	if saved:
		return [dmg / 2 if half else 0, true]
	return [dmg, false]


func _wounded_ally(m: Dictionary, rng_sq: int):
	var best = null
	var best_frac := 0.6  # only heal allies below 60% HP
	for o in monsters:
		if o["hp"] <= 0 or _cheb(o["pos"], m["pos"]) > rng_sq:
			continue
		var frac: float = float(o["hp"]) / float(o["hp_max"])
		if frac < best_frac:
			best_frac = frac
			best = o
	return best


func _push_hero(from: Vector2i, steps: int) -> void:
	for _i in steps:
		var hp: Vector2i = hero["pos"]
		var dir := Vector2i(signi(hp.x - from.x), signi(hp.y - from.y))
		var q := hp + dir
		if dir == Vector2i.ZERO or not _can_step(hp, dir) or monster_at(q) != null:
			break
		hero["pos"] = q
	travel.clear()


func _monster_move(m: Dictionary) -> void:
	var mp: Vector2i = m["pos"]
	var hp: Vector2i = hero["pos"]
	var path := astar.get_id_path(mp, hp)
	if path.size() >= 2 and path.size() < 40:
		var nxt: Vector2i = path[1]
		if nxt != hp and monster_at(nxt) == null:
			m["pos"] = nxt
			return
	# Path blocked by another monster: try any step that gets closer.
	var best_d := _cheb(mp, hp)
	var best := mp
	for d in DungeonGen.DIRS:
		var q: Vector2i = mp + d
		if q == hp or monster_at(q) != null or not _can_step(mp, d):
			continue
		var dd := _cheb(q, hp)
		if dd < best_d:
			best_d = dd
			best = q
	m["pos"] = best


func _monster_flee(m: Dictionary) -> void:
	if m.get("restrained", false):
		return
	var mp: Vector2i = m["pos"]
	var hp: Vector2i = hero["pos"]
	var best_d := _cheb(mp, hp)
	var best := mp
	for d in DungeonGen.DIRS:
		var q: Vector2i = mp + d
		if q == hp or monster_at(q) != null or not _can_step(mp, d):
			continue
		var dd := _cheb(q, hp)
		if dd > best_d:
			best_d = dd
			best = q
	m["pos"] = best


func _monster_wander(m: Dictionary) -> void:
	var mp: Vector2i = m["pos"]
	var d: Vector2i = DungeonGen.DIRS[rng.randi_range(0, 7)]
	var q := mp + d
	if q != hero["pos"] and monster_at(q) == null and _can_step(mp, d):
		m["pos"] = q


func _push(m: Dictionary, steps: int) -> void:
	var hp: Vector2i = hero["pos"]
	for _i in steps:
		var mp: Vector2i = m["pos"]
		var dir := Vector2i(signi(mp.x - hp.x), signi(mp.y - hp.y))
		var q := mp + dir
		if dir == Vector2i.ZERO or not _can_step(mp, dir) or monster_at(q) != null or q == hp:
			return
		m["pos"] = q


## Spirit Guardians: enemies ending their turn within 3 squares make a WIS save.
func _guardian_check(m: Dictionary) -> void:
	if hero["conc"] != "spirit_guardians" or _cheb(m["pos"], hero["pos"]) > 3:
		return
	var up := maxi(0, max_spell_level() - 3)
	var dmg := roll(3 + up, 8)
	var saved := _monster_save(m, WIS, spell_dc())
	var dealt := dmg / 2 if saved else dmg
	say("Spirit Guardians sear the %s for %d%s." % [m["name"], dealt, " (saved)" if saved else ""])
	_damage_monster(m, dealt, false, "radiant")


func _ally_adjacent(m: Dictionary) -> bool:
	var hp: Vector2i = hero["pos"]
	for o in monsters:
		if not is_same(o, m) and o["hp"] > 0 and _cheb(o["pos"], hp) <= 1:
			return true
	return false


# --- Dice and saves ----------------------------------------------------------------

func roll(count: int, sides: int) -> int:
	var t := 0
	for _i in count:
		t += rng.randi_range(1, sides)
	return t


## adv > 0: Advantage, adv < 0: Disadvantage.
func d20(adv: int = 0) -> int:
	var a := rng.randi_range(1, 20)
	if adv == 0:
		return a
	var b := rng.randi_range(1, 20)
	return maxi(a, b) if adv > 0 else mini(a, b)


## Any Advantage and any Disadvantage cancel out (2024 rule).
func _net_adv(adv: int, dis: int) -> int:
	if adv > 0 and dis == 0:
		return 1
	if dis > 0 and adv == 0:
		return -1
	return 0


func _hero_d20(adv: int) -> int:
	var r := d20(adv)
	if r == 1 and hero["species"] == "Halfling":
		r = rng.randi_range(1, 20)  # Luck
	return r


## Hero saving throw total (d20 + modifier + proficiency if proficient).
func _hero_save(ability: String) -> int:
	var adv := 1 if ability == "str" and int(hero["rage"]) > 0 else 0
	var total := _hero_d20(adv) + _mod(ability)
	if ability in _cls()["saves"]:
		total += prof()
	return total


func _monster_save(m: Dictionary, ability: int, dc: int) -> bool:
	var sv: Array = m.get("sv", [0, 0, 0, 0, 0, 0])
	var adv := -1 if ability == DEX and m.get("restrained", false) else 0
	return d20(adv) + int(sv[ability]) >= dc


func _is_hit(r: int, bonus: int, ac: int) -> bool:
	return r == 20 or (r != 1 and r + bonus >= ac)


# --- Helpers -----------------------------------------------------------------------

func _cls() -> Dictionary:
	return GameData.CLASSES[hero["cls"]]


func _mod(ability: String) -> int:
	var scores: Dictionary = hero["scores"]
	return GameData.mod(scores[ability])


func _caster_mod() -> int:
	var ab: String = _cls()["caster"]
	return _mod(ab) if ab != "" else 0


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


func _walkable(p: Vector2i) -> bool:
	if not _in_bounds(p):
		return false
	var t := tiles[p.y * w + p.x]
	return t == DungeonGen.FLOOR or t == DungeonGen.WATER


## No squeezing diagonally between two walls.
func _can_step(from: Vector2i, d: Vector2i) -> bool:
	var t := from + d
	if not _walkable(t):
		return false
	if d.x != 0 and d.y != 0:
		return _walkable(Vector2i(from.x + d.x, from.y)) and _walkable(Vector2i(from.x, from.y + d.y))
	return true


func _enemy_adjacent() -> bool:
	var hp: Vector2i = hero["pos"]
	for m in monsters:
		if m["hp"] > 0 and _cheb(m["pos"], hp) <= 1 and int(m.get("turned", 0)) == 0:
			return true
	return false


func _any_marked() -> bool:
	for m in monsters:
		if m["hp"] > 0 and m.get("marked", false):
			return true
	return false


func _undead_in_range() -> Array:
	var out: Array = []
	for m in _visible_monsters_by_distance():
		if m.get("undead", false) and not m.get("turn_immune", false) and _cheb(m["pos"], hero["pos"]) <= 6:
			out.append(m)
	return out


func _monsters_near(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for m in monsters:
		if m["hp"] > 0 and _cheb(m["pos"], center) <= radius:
			out.append(m)
	return out


func _visible_monsters_by_distance() -> Array:
	var out: Array = []
	for m in monsters:
		var p: Vector2i = m["pos"]
		if m["hp"] > 0 and vis[p.y * w + p.x] == 1:
			out.append(m)
	var hp: Vector2i = hero["pos"]
	out.sort_custom(func(a, b): return _cheb(a["pos"], hp) < _cheb(b["pos"], hp))
	return out


## Preferred enemy if still visible, else the selected target, else the nearest visible enemy.
func _pick_target(pref, remember := true):
	var chosen = null
	for cand in [pref, target]:
		if cand != null and cand["hp"] > 0:
			var p: Vector2i = cand["pos"]
			if vis[p.y * w + p.x] == 1:
				chosen = cand
				break
	if chosen == null:
		var seen := _visible_monsters_by_distance()
		if not seen.is_empty():
			chosen = seen[0]
	if remember and chosen != null:
		target = chosen
	return chosen


func _free_neighbor(p: Vector2i):
	var dirs: Array = DungeonGen.DIRS.duplicate()
	_shuffle(dirs)
	for item in dirs:
		var q: Vector2i = p + item
		if _walkable(q) and q != hero["pos"] and q != stairs and monster_at(q) == null:
			return q
	return null


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _pickup() -> void:
	var p: Vector2i = hero["pos"]
	if not items.has(p):
		return
	var kind: String = items[p]
	items.erase(p)
	match kind:
		"potion":
			hero["potions"] += 1
			say("You pick up a Potion of Healing.")
		"greater":
			hero["greater"] += 1
			say("You pick up a Potion of Greater Healing.")
		"gold":
			var g := rng.randi_range(5, 15) * floor_num
			hero["gold"] += g
			say("You find %d gold." % g)
		"weapon":
			hero["weapon_bonus"] = mini(3, int(hero["weapon_bonus"]) + 1)
			say("[color=#7fe0ff]You find a +%d weapon![/color]" % hero["weapon_bonus"])
		"armor":
			hero["armor_bonus"] = mini(3, int(hero["armor_bonus"]) + 1)
			say("[color=#7fe0ff]You find +%d armor![/color]" % hero["armor_bonus"])


func _health_word(m: Dictionary) -> String:
	var frac: float = float(m["hp"]) / float(m["hp_max"])
	if frac >= 1.0:
		return "unhurt"
	if frac > 0.5:
		return "wounded"
	if frac > 0.2:
		return "badly wounded"
	return "nearly dead"


func _compute_fov() -> void:
	vis.fill(0)
	var hp: Vector2i = hero["pos"]
	var sp: Dictionary = GameData.SPECIES[hero["species"]]
	var r := 6 + (3 if sp["darkvision"] else 0)
	for y in range(hp.y - r, hp.y + r + 1):
		for x in range(hp.x - r, hp.x + r + 1):
			var p := Vector2i(x, y)
			if not _in_bounds(p):
				continue
			if (x - hp.x) * (x - hp.x) + (y - hp.y) * (y - hp.y) > r * r + r:
				continue
			if _los(hp, p):
				var i := y * w + x
				vis[i] = 1
				explored[i] = 1


func _los(a: Vector2i, b: Vector2i) -> bool:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := -absi(b.y - y0)
	var sx := 1 if x0 < b.x else -1
	var sy := 1 if y0 < b.y else -1
	var err := dx + dy
	while true:
		if x0 == b.x and y0 == b.y:
			return true
		if not (x0 == a.x and y0 == a.y) and tiles[y0 * w + x0] == DungeonGen.WALL:
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true
