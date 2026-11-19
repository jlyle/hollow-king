class_name GameData
extends RefCounted
## Rules data. Numbers follow the 2024 rules as published in SRD 5.2.1 where practical.
## claude-requirements.md (section 5) is the source of truth for what belongs here.

## XP needed to reach level (index + 1). Index 1 = 300 XP for level 2.
const XP_TABLE := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

## Total spell slots (all levels combined) at character level 1-20.
const FULL_CASTER_SLOTS := [2, 3, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22]
const HALF_CASTER_SLOTS := [2, 2, 3, 3, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15]

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]

## Ability scores = standard array (15,14,13,12,10,8) + background bonus (+2/+1).
## caster: casting ability ("" = none). slots: "full" | "half" | "". ranged: default long-range attack.
const CLASSES := {
	"Fighter": {
		"hit_die": 10, "primary": "str", "attack_ability": "str", "saves": ["str", "con"],
		"scores": {"str": 17, "dex": 13, "con": 15, "int": 10, "wis": 12, "cha": 8},
		"weapon": "Longsword", "dice": [1, 8], "caster": "", "slots": "", "ranged": "",
		"desc": "Chain mail, shield, longsword, Defense style (AC 19). Second Wind heals as a Bonus Action. Extra Attack at level 5.",
	},
	"Rogue": {
		"hit_die": 8, "primary": "dex", "attack_ability": "dex", "saves": ["dex", "int"],
		"scores": {"str": 8, "dex": 17, "con": 15, "int": 13, "wis": 12, "cha": 10},
		"weapon": "Rapier", "dice": [1, 8], "caster": "", "slots": "", "ranged": "",
		"desc": "Leather armor, rapier. Hide (Bonus Action, Stealth with Expertise) for Advantage and Sneak Attack. Uncanny Dodge at level 5.",
	},
	"Barbarian": {
		"hit_die": 12, "primary": "str", "attack_ability": "str", "saves": ["str", "con"],
		"scores": {"str": 17, "dex": 13, "con": 15, "int": 8, "wis": 12, "cha": 10},
		"weapon": "Greataxe", "dice": [1, 12], "caster": "", "slots": "", "ranged": "",
		"desc": "Unarmored Defense, greataxe. Rage (Bonus Action) halves physical damage and adds melee damage. Reckless Attack at level 2, Extra Attack at 5.",
	},
	"Ranger": {
		"hit_die": 10, "primary": "dex", "attack_ability": "dex", "saves": ["str", "dex"],
		"scores": {"str": 12, "dex": 17, "con": 14, "int": 10, "wis": 14, "cha": 8},
		"weapon": "Shortsword", "dice": [1, 6], "caster": "wis", "slots": "half", "ranged": "longbow",
		"desc": "Studded leather, shortsword and longbow (tap a far enemy to shoot). Hunter's Mark, Ensnaring Strike, Cure Wounds. Archery at 2, Extra Attack at 5.",
	},
	"Wizard": {
		"hit_die": 6, "primary": "int", "attack_ability": "dex", "saves": ["int", "wis"],
		"scores": {"str": 8, "dex": 13, "con": 15, "int": 17, "wis": 12, "cha": 10},
		"weapon": "Dagger", "dice": [1, 4], "caster": "int", "slots": "full", "ranged": "fire_bolt",
		"desc": "Mage Armor, dagger. Fire Bolt at range; Magic Missile, Burning Hands, Thunderwave, then Shatter (3) and Fireball (5).",
	},
	"Cleric": {
		"hit_die": 8, "primary": "wis", "attack_ability": "str", "saves": ["wis", "cha"],
		"scores": {"str": 13, "dex": 10, "con": 14, "int": 8, "wis": 17, "cha": 13},
		"weapon": "Mace", "dice": [1, 6], "caster": "wis", "slots": "full", "ranged": "sacred_flame",
		"desc": "Protector: chain mail and shield (AC 18), mace. Sacred Flame at range; Healing Word, Guiding Bolt, Turn Undead (2), Spirit Guardians (5).",
	},
}

const SPECIES := {
	"Human": {"darkvision": false, "desc": "Resourceful: Heroic Inspiration after each Long Rest - a missed attack is rerolled automatically."},
	"Dwarf": {"darkvision": true, "desc": "Dwarven Toughness: +1 HP per level. Darkvision (see farther in the dark)."},
	"Halfling": {"darkvision": false, "desc": "Luck: when you roll a natural 1 on an attack, reroll it."},
	"Orc": {"darkvision": true, "desc": "Relentless Endurance: drop to 1 HP instead of 0, once per Long Rest. Darkvision."},
}

## lvl: spell level (0 = cantrip, -1 = Channel Divinity). min: character level needed.
## cast: "action" ends your turn, "bonus" uses your Bonus Action.
const SPELLS := {
	"fire_bolt": {"name": "Fire Bolt", "cls": "Wizard", "lvl": 0, "min": 1, "cast": "action",
		"desc": "Spell attack, 1d10 fire (scales). Stops regeneration."},
	"magic_missile": {"name": "Magic Missile", "cls": "Wizard", "lvl": 1, "min": 1, "cast": "action",
		"desc": "Never misses: 1d4+1 force darts, 3 + 1 per slot level above 1st."},
	"burning_hands": {"name": "Burning Hands", "cls": "Wizard", "lvl": 1, "min": 1, "cast": "action",
		"desc": "DEX save. 3d6 fire in a 3-square cone toward your target, half on a save."},
	"thunderwave": {"name": "Thunderwave", "cls": "Wizard", "lvl": 1, "min": 1, "cast": "action",
		"desc": "CON save. 2d8 thunder to adjacent enemies and push 2 squares; half, no push on a save."},
	"shatter": {"name": "Shatter", "cls": "Wizard", "lvl": 2, "min": 3, "cast": "action",
		"desc": "CON save. 3d8 thunder within 2 squares of your target, half on a save. Can hit you!"},
	"fireball": {"name": "Fireball", "cls": "Wizard", "lvl": 3, "min": 5, "cast": "action",
		"desc": "DEX save. 8d6 fire within 4 squares of your target, half on a save. Can hit you!"},
	"sacred_flame": {"name": "Sacred Flame", "cls": "Cleric", "lvl": 0, "min": 1, "cast": "action",
		"desc": "DEX save or 1d8 radiant (scales). Radiant beats Undead Fortitude."},
	"healing_word": {"name": "Healing Word", "cls": "Cleric", "lvl": 1, "min": 1, "cast": "bonus",
		"desc": "Bonus Action. Heal 2d4 + WIS, +2d4 per slot level above 1st."},
	"guiding_bolt": {"name": "Guiding Bolt", "cls": "Cleric", "lvl": 1, "min": 1, "cast": "action",
		"desc": "Spell attack, 4d6 radiant. Your next attack on it has Advantage."},
	"turn_undead": {"name": "Turn Undead", "cls": "Cleric", "lvl": -1, "min": 2, "cast": "action",
		"desc": "Channel Divinity. Undead within 6 squares: WIS save or flee for 10 turns."},
	"spirit_guardians": {"name": "Spirit Guardians", "cls": "Cleric", "lvl": 3, "min": 5, "cast": "action",
		"desc": "Concentration. Enemies ending a turn within 3 squares: WIS save, 3d8 radiant, half on save."},
	"hunters_mark": {"name": "Hunter's Mark", "cls": "Ranger", "lvl": 1, "min": 1, "cast": "bonus",
		"desc": "Bonus Action, Concentration. +1d6 force on weapon hits vs your target. Free uses first."},
	"ensnaring_strike": {"name": "Ensnaring Strike", "cls": "Ranger", "lvl": 1, "min": 1, "cast": "bonus",
		"desc": "Bonus Action, Concentration. Next hit: STR save or Restrained (1d6 per turn)."},
	"cure_wounds": {"name": "Cure Wounds", "cls": "Ranger", "lvl": 1, "min": 1, "cast": "action",
		"desc": "Heal 2d8 + WIS, +2d8 per slot level above 1st."},
}

## lo/hi = floor range where the monster appears. dmg = [dice, sides, bonus]. pp = passive Perception.
## sv = saving throw bonuses [STR, DEX, CON, INT, WIS, CHA]. dtype = damage type dealt.
const MONSTERS := [
	{"key": "rat", "name": "Giant Rat", "ch": "r", "color": "b08d6a", "xp": 25, "ac": 13, "hp": 7, "atk": 5, "dmg": [1, 4, 3], "attacks": 1, "lo": 1, "hi": 3, "pp": 13, "pack": true, "sv": [-2, 2, 0, -4, 0, -3]},
	{"key": "kobold", "name": "Kobold", "ch": "k", "color": "c9844a", "xp": 25, "ac": 14, "hp": 7, "atk": 4, "dmg": [1, 4, 2], "attacks": 1, "lo": 1, "hi": 4, "pp": 8, "pack": true, "sv": [-2, 2, -1, -1, -2, -1]},
	{"key": "goblin", "name": "Goblin", "ch": "g", "color": "7fc24f", "xp": 50, "ac": 15, "hp": 10, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 1, "hi": 6, "pp": 9, "sv": [-1, 2, 0, 0, -1, -1]},
	{"key": "skeleton", "name": "Skeleton", "ch": "s", "color": "e6e1d3", "xp": 50, "ac": 14, "hp": 13, "atk": 5, "dmg": [1, 6, 3], "attacks": 1, "lo": 3, "hi": 8, "pp": 9, "undead": true, "sv": [0, 3, 2, -2, -1, -3]},
	{"key": "zombie", "name": "Zombie", "ch": "z", "color": "8fa37a", "xp": 50, "ac": 8, "hp": 15, "atk": 3, "dmg": [1, 6, 1], "attacks": 1, "lo": 3, "hi": 8, "pp": 8, "fortitude": true, "undead": true, "sv": [1, -2, 3, -4, 0, -3]},
	{"key": "wolf", "name": "Wolf", "ch": "w", "color": "a3a3a3", "xp": 50, "ac": 12, "hp": 11, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 3, "hi": 8, "pp": 15, "pack": true, "sv": [2, 2, 1, -4, 1, -2]},
	{"key": "hobgoblin", "name": "Hobgoblin", "ch": "h", "color": "e07a3f", "xp": 100, "ac": 18, "hp": 11, "atk": 3, "dmg": [1, 10, 1], "attacks": 1, "lo": 5, "hi": 10, "pp": 10, "sv": [1, 1, 1, 0, 0, -1]},
	{"key": "ghoul", "name": "Ghoul", "ch": "G", "color": "9bb88a", "xp": 200, "ac": 12, "hp": 22, "atk": 4, "dmg": [1, 6, 2], "attacks": 2, "lo": 6, "hi": 12, "pp": 10, "undead": true, "sv": [1, 2, 0, -2, 0, -2]},
	{"key": "bugbear", "name": "Bugbear", "ch": "B", "color": "c2a060", "xp": 200, "ac": 14, "hp": 33, "atk": 4, "dmg": [2, 6, 2], "attacks": 1, "lo": 7, "hi": 13, "pp": 10, "sv": [2, 2, 1, -1, 0, -1]},
	{"key": "spider", "name": "Giant Spider", "ch": "A", "color": "8c6bb1", "xp": 200, "ac": 14, "hp": 26, "atk": 5, "dmg": [1, 10, 3], "attacks": 1, "lo": 7, "hi": 12, "pp": 14, "sv": [2, 3, 1, -4, 0, -3]},
	{"key": "ogre", "name": "Ogre", "ch": "O", "color": "d9b36c", "xp": 450, "ac": 11, "hp": 68, "atk": 6, "dmg": [2, 8, 4], "attacks": 1, "lo": 9, "hi": 15, "pp": 8, "sv": [4, -1, 3, -3, -2, -2]},
	{"key": "minotaur", "name": "Minotaur", "ch": "M", "color": "b5653d", "xp": 700, "ac": 14, "hp": 85, "atk": 6, "dmg": [2, 12, 4], "attacks": 1, "lo": 12, "hi": 18, "pp": 17, "sv": [4, 0, 3, -2, 3, -1]},
	{"key": "wight", "name": "Wight", "ch": "W", "color": "8fb3d9", "xp": 700, "ac": 14, "hp": 82, "atk": 4, "dmg": [1, 8, 2], "attacks": 2, "lo": 12, "hi": 19, "pp": 13, "undead": true, "sv": [2, 2, 3, 0, 1, 2]},
	{"key": "wraith", "name": "Wraith", "ch": "R", "color": "6b6bb5", "xp": 1800, "ac": 13, "hp": 67, "atk": 6, "dmg": [3, 8, 3], "attacks": 1, "lo": 15, "hi": 20, "pp": 12, "undead": true, "dtype": "necrotic", "sv": [-2, 3, 3, 1, 2, 2]},
	{"key": "troll", "name": "Troll", "ch": "T", "color": "5fae5f", "xp": 1800, "ac": 15, "hp": 94, "atk": 7, "dmg": [2, 6, 4], "attacks": 3, "lo": 16, "hi": 20, "pp": 15, "regen": 15, "sv": [4, 1, 5, -2, -1, -2]},
	# --- Ranged and spellcasting monsters (R-12) ---
	{"key": "goblin_archer", "name": "Goblin Archer", "ch": "g", "color": "d4e86a", "xp": 50, "ac": 15, "hp": 10, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 2, "hi": 7, "pp": 9, "sv": [-1, 2, 0, 0, -1, -1],
		"ranged": {"name": "shortbow", "atk": 4, "dmg": [1, 6, 2], "range": 12}},
	{"key": "skeleton_archer", "name": "Skeleton Archer", "ch": "s", "color": "c9d6ff", "xp": 50, "ac": 14, "hp": 13, "atk": 5, "dmg": [1, 6, 3], "attacks": 1, "lo": 4, "hi": 9, "pp": 9, "undead": true, "sv": [0, 3, 2, -2, -1, -3],
		"ranged": {"name": "shortbow", "atk": 5, "dmg": [1, 6, 3], "range": 12}},
	{"key": "kobold_shaman", "name": "Kobold Shaman", "ch": "k", "color": "ff9f43", "xp": 50, "ac": 12, "hp": 9, "atk": 4, "dmg": [1, 4, 2], "attacks": 1, "lo": 2, "hi": 6, "pp": 10, "sv": [-2, 2, 0, 0, 1, 0],
		"spells": [{"name": "Fire Bolt", "kind": "attack", "atk": 4, "dmg": [1, 10, 0], "dtype": "fire", "range": 10, "cd": 0}]},
	{"key": "cult_acolyte", "name": "Cult Acolyte", "ch": "c", "color": "e0c3ff", "xp": 100, "ac": 13, "hp": 18, "atk": 3, "dmg": [1, 6, 1], "attacks": 1, "lo": 4, "hi": 10, "pp": 12, "sv": [0, 0, 1, 0, 3, 1],
		"spells": [
			{"name": "Mend", "kind": "heal", "dmg": [2, 4, 2], "range": 6, "cd": 3},
			{"name": "Sacred Flame", "kind": "save", "ability": "dex", "dc": 12, "dmg": [1, 8, 0], "dtype": "radiant", "half": false, "range": 10, "cd": 0}]},
	{"key": "dark_adept", "name": "Dark Adept", "ch": "d", "color": "b07cd8", "xp": 450, "ac": 12, "hp": 40, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 9, "hi": 15, "pp": 11, "sv": [0, 2, 1, 3, 2, 1],
		"spells": [
			{"name": "Sickening Ray", "kind": "save", "ability": "con", "dc": 13, "dmg": [2, 8, 0], "dtype": "poison", "half": true, "range": 10, "cd": 2, "effect": "poison"},
			{"name": "Fire Bolt", "kind": "attack", "atk": 5, "dmg": [2, 10, 0], "dtype": "fire", "range": 10, "cd": 0}]},
	{"key": "necromancer", "name": "Necromancer", "ch": "N", "color": "9b6bd6", "xp": 1800, "ac": 13, "hp": 66, "atk": 5, "dmg": [1, 8, 2], "attacks": 1, "lo": 14, "hi": 20, "pp": 13, "sv": [0, 2, 2, 6, 4, 1],
		"summon": {"key": "skeleton", "n": 2, "cd": 6, "msg": "chants, and the dead rise!"},
		"spells": [{"name": "Blight", "kind": "save", "ability": "con", "dc": 15, "dmg": [4, 8, 0], "dtype": "necrotic", "half": true, "range": 10, "cd": 2}]},
	{"key": "giant", "name": "Hill Giant", "ch": "H", "color": "c79a6b", "xp": 1800, "ac": 13, "hp": 105, "atk": 8, "dmg": [3, 8, 5], "attacks": 2, "lo": 17, "hi": 20, "pp": 12, "sv": [5, -1, 4, -3, -1, -2]},
]

## Original final boss (not from the SRD). Immune to Turn Undead.
const BOSS := {"key": "hollow_king", "name": "Hollow King", "ch": "K", "color": "c58bff", "xp": 5900, "ac": 18, "hp": 200, "atk": 9, "dmg": [2, 8, 5], "attacks": 3, "lo": 20, "hi": 20, "pp": 16, "boss": true, "undead": true, "turn_immune": true, "sv": [5, 1, 9, 2, 7, 4],
	"summon": {"key": "skeleton", "n": 2, "cd": 5, "msg": "raises the dead!"}}

## Original mini-bosses (R-13), keyed by floor. They guard and seal the stairs until defeated.
const MINI_BOSSES := {
	5: {"key": "warchief", "name": "Goblin Warchief", "ch": "&", "color": "9be04f", "xp": 700, "ac": 17, "hp": 52, "atk": 5, "dmg": [1, 8, 3], "attacks": 2, "lo": 5, "hi": 5, "pp": 12, "mini": true, "sv": [3, 2, 2, 0, 0, 1],
		"ranged": {"name": "shortbow", "atk": 5, "dmg": [1, 6, 3], "range": 12},
		"summon": {"key": "goblin", "n": 2, "cd": 6, "msg": "bellows for reinforcements!"}},
	10: {"key": "oracle", "name": "Drowned Oracle", "ch": "&", "color": "4fc3e0", "xp": 1800, "ac": 14, "hp": 85, "atk": 6, "dmg": [1, 8, 3], "attacks": 1, "lo": 10, "hi": 10, "pp": 15, "mini": true, "sv": [1, 2, 3, 2, 4, 3],
		"spells": [
			{"name": "Mend", "kind": "heal", "dmg": [3, 8, 3], "range": 6, "cd": 5},
			{"name": "Tidal Lash", "kind": "save", "ability": "con", "dc": 14, "dmg": [3, 8, 0], "dtype": "bludgeoning", "half": true, "range": 8, "cd": 2, "effect": "push"},
			{"name": "Sickening Ray", "kind": "save", "ability": "con", "dc": 14, "dmg": [2, 8, 0], "dtype": "poison", "half": true, "range": 10, "cd": 3, "effect": "poison"}]},
	15: {"key": "bone_warden", "name": "Bone Warden", "ch": "&", "color": "f2ead3", "xp": 2900, "ac": 17, "hp": 130, "atk": 7, "dmg": [2, 8, 4], "attacks": 2, "lo": 15, "hi": 15, "pp": 14, "mini": true, "undead": true, "turn_immune": true, "sv": [5, 1, 5, 0, 3, 2],
		"summon": {"key": "skeleton_archer", "n": 2, "cd": 5, "msg": "drags archers from the ossuary!"},
		"spells": [{"name": "Grave Chill", "kind": "save", "ability": "wis", "dc": 15, "dmg": [3, 8, 0], "dtype": "necrotic", "half": true, "range": 8, "cd": 3}]},
}


static func mod(score: int) -> int:
	return floori((score - 10) / 2.0)


static func prof(level: int) -> int:
	return 2 + (level - 1) / 4


static func monster(key: String) -> Dictionary:
	for m in MONSTERS:
		if m["key"] == key:
			return m
	return MONSTERS[0]
