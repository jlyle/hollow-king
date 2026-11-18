class_name Game
extends RefCounted
## Core game state and turn loop. No UI code lives here, so it can be tested headless.
##
## Turn structure (2024 rules, adapted for a grid roguelike):
##   - The hero gets one Action per turn (move one square, attack, cast) plus one Bonus Action
##     (potion, Second Wind, Hide) that does NOT end the turn.
##   - Then every awake monster takes its turn.

const MAX_FLOOR := 20
const XP_MULT := 1.0          ## Tuning knob: raise to level faster.
const LOG_SIZE := 6
const LONG_REST_FLOORS := [5, 9, 13, 17, 20]   ## Arriving on these floors grants a Long Rest.

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
		"second_wind": 2, "slots": GameData.WIZARD_SLOTS[0], "arcane_used": false,
		"hidden": false, "stealth": 0,
		"inspiration": species == "Human", "relentless": species == "Orc",
		"kills": 0,
	}
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
	hero["pos"] = d["start"]
	hero["hidden"] = false
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


func hero_ac() -> int:
	var base := 10
	match hero["cls"]:
		"Fighter":
			base = 19  # chain mail 16 + shield 2 + Defense fighting style 1
		"Rogue":
			base = 11 + _mod("dex")  # leather armor
		"Wizard":
			base = 13 + _mod("dex")  # Mage Armor
	return base + int(hero["armor_bonus"])


func prof() -> int:
	return GameData.prof(hero["level"])


func xp_next() -> int:
	var lvl: int = hero["level"]
	return GameData.XP_TABLE[lvl] if lvl < 20 else -1


func describe(m: Dictionary) -> void:
	say("%s - AC %d, %s." % [m["name"], m["ac"], _health_word(m)])


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
		_hero_melee(m)
	else:
		hero["pos"] = t
		_pickup()
		if t == stairs:
			say("Stairs lead down. Tap Descend (or tap yourself).")
	_end_turn()
	return true


func player_step_toward(target: Vector2i) -> bool:
	var from: Vector2i = hero["pos"]
	var d := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
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


func plan_travel(target: Vector2i) -> void:
	travel.clear()
	var path := astar.get_id_path(hero["pos"], target)
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
	hero["hp"] = mini(hero["hp_max"], hero["hp"] + heal)
	bonus_used = true


func player_ability() -> void:
	if over:
		return
	match hero["cls"]:
		"Fighter":
			_second_wind()
		"Rogue":
			_hide()
		"Wizard":
			_magic_missile()


func player_firebolt(target = null) -> void:
	if over or hero["cls"] != "Wizard":
		return
	var t = target
	if t == null:
		var seen := _visible_monsters_by_distance()
		if seen.is_empty():
			say("No visible target for Fire Bolt.")
			return
		t = seen[0]
	var adv := 1 if hero["hidden"] else 0
	if _enemy_adjacent():
		adv -= 1  # ranged attack with an enemy within 5 ft: Disadvantage
	hero["hidden"] = false
	var bonus: int = _mod("int") + prof()
	var r := _hero_d20(adv)
	var hit := _is_hit(r, bonus, t["ac"])
	if not hit and hero["inspiration"]:
		hero["inspiration"] = false
		say("Heroic Inspiration - you reroll.")
		r = _hero_d20(adv)
		hit = _is_hit(r, bonus, t["ac"])
	if hit:
		var lvl: int = hero["level"]
		var dice := 1 + (1 if lvl >= 5 else 0) + (1 if lvl >= 11 else 0) + (1 if lvl >= 17 else 0)
		var dmg := roll(dice * (2 if r == 20 else 1), 10)
		say("Fire Bolt %s the %s for %d fire damage." % ["CRITS" if r == 20 else "hits", t["name"], dmg])
		_damage_monster(t, dmg, r == 20, "fire")
	else:
		say("Your Fire Bolt misses the %s." % t["name"])
	_end_turn()


func player_descend() -> void:
	if over:
		return
	if not on_stairs():
		say("You need to stand on the stairs (>).")
		return
	var next := floor_num + 1
	if next in LONG_REST_FLOORS:
		_long_rest()
	else:
		_short_rest()
	start_floor(next)


# --- Class features ----------------------------------------------------------------

func _second_wind() -> void:
	if bonus_used:
		say("You've already used your Bonus Action this turn.")
		return
	if hero["second_wind"] <= 0:
		say("Second Wind is spent. Rest to recover it.")
		return
	hero["second_wind"] -= 1
	var heal := roll(1, 10) + int(hero["level"])
	hero["hp"] = mini(hero["hp_max"], hero["hp"] + heal)
	bonus_used = true
	say("Second Wind! You regain %d HP." % heal)


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


func _magic_missile() -> void:
	if hero["slots"] <= 0:
		say("No spell slots left. Rest on the stairs to recover.")
		return
	var targets := _visible_monsters_by_distance()
	if targets.is_empty():
		say("No visible target for Magic Missile.")
		return
	hero["slots"] -= 1
	hero["hidden"] = false
	var darts := 3 + _max_spell_level() - 1  # cast with your highest slot
	say("Magic Missile! %d glowing darts streak out." % darts)
	var ti := 0
	for _i in darts:
		while ti < targets.size() and targets[ti]["hp"] <= 0:
			ti += 1
		if ti >= targets.size():
			break
		_damage_monster(targets[ti], roll(1, 4) + 1, false, "force")
	_end_turn()


func _second_wind_max() -> int:
	var lvl: int = hero["level"]
	if lvl >= 10:
		return 4
	if lvl >= 4:
		return 3
	return 2


func _max_slots() -> int:
	return GameData.WIZARD_SLOTS[int(hero["level"]) - 1]


func _max_spell_level() -> int:
	return mini(9, ceili(int(hero["level"]) / 2.0))


# --- Resting -----------------------------------------------------------------------

func _short_rest() -> void:
	var die: int = GameData.CLASSES[hero["cls"]]["hit_die"]
	var healed := 0
	var spent := 0
	while hero["hit_dice"] > 0 and hero["hp_max"] - hero["hp"] >= die / 2 + 1:
		var amt := maxi(1, rng.randi_range(1, die) + _mod("con"))
		hero["hp"] = mini(hero["hp_max"], hero["hp"] + amt)
		hero["hit_dice"] -= 1
		healed += amt
		spent += 1
	hero["second_wind"] = mini(_second_wind_max(), hero["second_wind"] + 1)
	var extra := ""
	if hero["cls"] == "Wizard" and not hero["arcane_used"]:
		var regained := mini(_max_slots() - int(hero["slots"]), ceili(int(hero["level"]) / 2.0))
		if regained > 0:
			hero["slots"] += regained
			hero["arcane_used"] = true
			extra = " Arcane Recovery restores %d slot(s)." % regained
	say("Short Rest: spent %d Hit Dice, regained %d HP.%s" % [spent, healed, extra])


func _long_rest() -> void:
	hero["hp"] = hero["hp_max"]
	hero["hit_dice"] = hero["level"]
	hero["second_wind"] = _second_wind_max()
	hero["slots"] = _max_slots()
	hero["arcane_used"] = false
	if hero["species"] == "Orc":
		hero["relentless"] = true
	if hero["species"] == "Human":
		hero["inspiration"] = true
	say("[color=#7fc2ff]You find a sealed alcove and take a Long Rest. Fully restored.[/color]")


# --- Combat ------------------------------------------------------------------------

func _hero_melee(m: Dictionary) -> void:
	var lvl: int = hero["level"]
	var attacks := 1
	if hero["cls"] == "Fighter":
		attacks += (1 if lvl >= 5 else 0) + (1 if lvl >= 11 else 0) + (1 if lvl >= 20 else 0)
	for _i in attacks:
		if m["hp"] <= 0:
			break
		_weapon_attack(m)


func _weapon_attack(m: Dictionary) -> void:
	var adv := 1 if hero["hidden"] else 0
	hero["hidden"] = false
	var c: Dictionary = GameData.CLASSES[hero["cls"]]
	var ab_mod := _mod(c["attack_ability"])
	var bonus: int = ab_mod + prof() + int(hero["weapon_bonus"])
	var r := _hero_d20(adv)
	var hit := _is_hit(r, bonus, m["ac"])
	if not hit and hero["inspiration"]:
		hero["inspiration"] = false
		say("Heroic Inspiration - you reroll.")
		r = _hero_d20(adv)
		hit = _is_hit(r, bonus, m["ac"])
	if not hit:
		say("You miss the %s." % m["name"])
		return
	var crit := r == 20
	var dice: Array = c["dice"]
	var dmg: int = roll(dice[0] * (2 if crit else 1), dice[1]) + ab_mod + int(hero["weapon_bonus"])
	var note := ""
	if hero["cls"] == "Rogue" and adv > 0 and not sneak_used:
		sneak_used = true
		var sa := ceili(int(hero["level"]) / 2.0)
		dmg += roll(sa * (2 if crit else 1), 6)
		note = " (Sneak Attack)"
	dmg = maxi(1, dmg)
	say("You %s the %s for %d%s." % ["CRIT" if crit else "hit", m["name"], dmg, note])
	_damage_monster(m, dmg, crit, "")


func _damage_monster(m: Dictionary, dmg: int, crit: bool, kind: String) -> void:
	m["hp"] -= dmg
	m["awake"] = true
	if kind == "fire":
		m["no_regen"] = true
	if m["hp"] <= 0 and m.get("fortitude", false) and not crit and kind != "radiant":
		# Undead Fortitude: Constitution save, DC 5 + damage taken.
		if d20() + 3 >= 5 + dmg:
			m["hp"] = 1
			say("The %s refuses to fall!" % m["name"])
	if m["hp"] <= 0:
		_kill(m)


func _kill(m: Dictionary) -> void:
	var gained := int(int(m["xp"]) * XP_MULT)
	hero["xp"] += gained
	hero["kills"] += 1
	say("The %s is destroyed! (+%d XP)" % [m["name"], gained])
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
		hero["level"] += 1
		var lvl: int = hero["level"]
		var c: Dictionary = GameData.CLASSES[hero["cls"]]
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
		if hero["cls"] == "Wizard":
			hero["slots"] += GameData.WIZARD_SLOTS[lvl - 1] - GameData.WIZARD_SLOTS[lvl - 2]
		say("[color=#ffe066]Level up! You are now level %d (+%d HP).[/color]" % [lvl, gain])
		if lvl == 5:
			match hero["cls"]:
				"Fighter":
					say("New feature: Extra Attack.")
				"Rogue":
					say("New feature: Uncanny Dodge.")
				"Wizard":
					say("Fire Bolt now deals 2d10.")


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
			say("[color=#ff5555]You were slain by a %s on floor %d.[/color]" % [source, floor_num])


func _end_turn() -> void:
	_compute_fov()
	uncanny_used = false
	for m in monsters.duplicate():
		if over:
			break
		if m["hp"] > 0:
			_monster_act(m)
	monsters = monsters.filter(func(mm): return mm["hp"] > 0)
	turn += 1
	bonus_used = false
	sneak_used = false
	_compute_fov()


# --- Monster AI --------------------------------------------------------------------

func _monster_act(m: Dictionary) -> void:
	var regen: int = m.get("regen", 0)
	if regen > 0 and m["hp"] < m["hp_max"]:
		if m["no_regen"]:
			m["no_regen"] = false
		else:
			m["hp"] = mini(m["hp_max"], m["hp"] + regen)
	var mp: Vector2i = m["pos"]
	var hp: Vector2i = hero["pos"]
	var sees := vis[mp.y * w + mp.x] == 1
	var dist := _cheb(mp, hp)

	if hero["hidden"]:
		if sees and dist <= 8 and int(m["pp"]) >= int(hero["stealth"]):
			hero["hidden"] = false
			say("The %s spots you!" % m["name"])
		else:
			if m["awake"] and rng.randf() < 0.5:
				_monster_wander(m)
			return

	if sees and not m["awake"]:
		m["awake"] = true
		if m.get("boss", false):
			say("[color=#c58bff]The Hollow King rises from his throne.[/color]")
	if not m["awake"]:
		return

	if m.get("boss", false):
		m["cd"] -= 1
		if m["cd"] <= 0:
			m["cd"] = 5
			var raised := 0
			for d in DungeonGen.DIRS:
				if raised >= 2 or monsters.size() > 14:
					break
				var q: Vector2i = mp + d
				if _walkable(q) and q != hp and monster_at(q) == null:
					var s := _add_monster(GameData.monster("skeleton"), q)
					s["awake"] = true
					raised += 1
			if raised > 0:
				say("[color=#c58bff]The Hollow King raises the dead![/color]")
				return

	if dist <= 1 and _can_step(mp, hp - mp):
		_monster_attack(m)
	else:
		_monster_move(m)


func _monster_attack(m: Dictionary) -> void:
	var ac := hero_ac()
	var hits := 0
	var total := 0
	var n: int = m["attacks"]
	var dice: Array = m["dmg"]
	for _i in n:
		var adv := 1 if m.get("pack", false) and _ally_adjacent(m) else 0
		var r := d20(adv)
		if r == 20 or (r != 1 and r + int(m["atk"]) >= ac):
			var dmg: int = roll(dice[0] * (2 if r == 20 else 1), dice[1]) + dice[2]
			if hero["cls"] == "Rogue" and int(hero["level"]) >= 5 and not uncanny_used:
				uncanny_used = true
				dmg = dmg / 2
				say("Uncanny Dodge halves the blow.")
			hits += 1
			total += dmg
	if hits == 0:
		say("The %s misses you." % m["name"])
		return
	if n == 1:
		say("The %s hits you for %d." % [m["name"], total])
	else:
		say("The %s hits you %d of %d times for %d." % [m["name"], hits, n, total])
	_hurt_hero(total, m["name"])


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


func _monster_wander(m: Dictionary) -> void:
	var mp: Vector2i = m["pos"]
	var d: Vector2i = DungeonGen.DIRS[rng.randi_range(0, 7)]
	var q := mp + d
	if q != hero["pos"] and monster_at(q) == null and _can_step(mp, d):
		m["pos"] = q


func _ally_adjacent(m: Dictionary) -> bool:
	var hp: Vector2i = hero["pos"]
	for o in monsters:
		if not is_same(o, m) and o["hp"] > 0 and _cheb(o["pos"], hp) <= 1:
			return true
	return false


# --- Helpers -----------------------------------------------------------------------

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


func _hero_d20(adv: int) -> int:
	var r := d20(adv)
	if r == 1 and hero["species"] == "Halfling":
		r = rng.randi_range(1, 20)  # Luck
	return r


func _is_hit(r: int, bonus: int, ac: int) -> bool:
	return r == 20 or (r != 1 and r + bonus >= ac)


func _mod(ability: String) -> int:
	var scores: Dictionary = hero["scores"]
	return GameData.mod(scores[ability])


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
		if m["hp"] > 0 and _cheb(m["pos"], hp) <= 1:
			return true
	return false


func _visible_monsters_by_distance() -> Array:
	var out: Array = []
	for m in monsters:
		var p: Vector2i = m["pos"]
		if m["hp"] > 0 and vis[p.y * w + p.x] == 1:
			out.append(m)
	var hp: Vector2i = hero["pos"]
	out.sort_custom(func(a, b): return _cheb(a["pos"], hp) < _cheb(b["pos"], hp))
	return out


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
