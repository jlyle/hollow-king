class_name GameData
extends RefCounted
## Rules data. Numbers follow the 2024 rules as published in SRD 5.2.1 where practical.
## See README.md for the list of deliberate simplifications.

## XP needed to reach level (index + 1). Index 1 = 300 XP for level 2.
const XP_TABLE := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000]

## Wizard: total spell slots (all levels combined) at each class level 1-20.
const WIZARD_SLOTS := [2, 3, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22]

## Ability scores = standard array (15,14,13,12,10,8) + background bonus (+2/+1).
const CLASSES := {
	"Fighter": {
		"hit_die": 10, "primary": "str", "attack_ability": "str",
		"scores": {"str": 17, "dex": 13, "con": 15, "int": 10, "wis": 12, "cha": 8},
		"weapon": "Longsword", "dice": [1, 8],
		"desc": "Chain mail, shield, longsword, Defense fighting style (AC 19). Second Wind heals as a bonus action. Extra Attack at level 5.",
	},
	"Rogue": {
		"hit_die": 8, "primary": "dex", "attack_ability": "dex",
		"scores": {"str": 8, "dex": 17, "con": 15, "int": 13, "wis": 12, "cha": 10},
		"weapon": "Rapier", "dice": [1, 8],
		"desc": "Leather armor, rapier. Hide (bonus action, Stealth with Expertise) for advantage and Sneak Attack. Uncanny Dodge at level 5.",
	},
	"Wizard": {
		"hit_die": 6, "primary": "int", "attack_ability": "dex",
		"scores": {"str": 8, "dex": 13, "con": 15, "int": 17, "wis": 12, "cha": 10},
		"weapon": "Dagger", "dice": [1, 4],
		"desc": "Mage Armor, dagger. Tap a distant enemy to cast Fire Bolt (stops regeneration). Magic Missile spends a slot and never misses.",
	},
}

const SPECIES := {
	"Human": {"darkvision": false, "desc": "Resourceful: Heroic Inspiration after each Long Rest - a missed attack is rerolled automatically."},
	"Dwarf": {"darkvision": true, "desc": "Dwarven Toughness: +1 HP per level. Darkvision (see farther in the dark)."},
	"Halfling": {"darkvision": false, "desc": "Luck: when you roll a natural 1 on an attack, reroll it."},
	"Orc": {"darkvision": true, "desc": "Relentless Endurance: drop to 1 HP instead of 0, once per Long Rest. Darkvision."},
}

## lo/hi = floor range where the monster appears. dmg = [dice, sides, bonus]. pp = passive Perception.
const MONSTERS := [
	{"key": "rat", "name": "Giant Rat", "ch": "r", "color": "b08d6a", "xp": 25, "ac": 13, "hp": 7, "atk": 5, "dmg": [1, 4, 3], "attacks": 1, "lo": 1, "hi": 3, "pp": 13, "pack": true},
	{"key": "kobold", "name": "Kobold", "ch": "k", "color": "c9844a", "xp": 25, "ac": 14, "hp": 7, "atk": 4, "dmg": [1, 4, 2], "attacks": 1, "lo": 1, "hi": 4, "pp": 8, "pack": true},
	{"key": "goblin", "name": "Goblin", "ch": "g", "color": "7fc24f", "xp": 50, "ac": 15, "hp": 10, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 1, "hi": 6, "pp": 9},
	{"key": "skeleton", "name": "Skeleton", "ch": "s", "color": "e6e1d3", "xp": 50, "ac": 14, "hp": 13, "atk": 5, "dmg": [1, 6, 3], "attacks": 1, "lo": 3, "hi": 8, "pp": 9},
	{"key": "zombie", "name": "Zombie", "ch": "z", "color": "8fa37a", "xp": 50, "ac": 8, "hp": 15, "atk": 3, "dmg": [1, 6, 1], "attacks": 1, "lo": 3, "hi": 8, "pp": 8, "fortitude": true},
	{"key": "wolf", "name": "Wolf", "ch": "w", "color": "a3a3a3", "xp": 50, "ac": 12, "hp": 11, "atk": 4, "dmg": [1, 6, 2], "attacks": 1, "lo": 3, "hi": 8, "pp": 15, "pack": true},
	{"key": "hobgoblin", "name": "Hobgoblin", "ch": "h", "color": "e07a3f", "xp": 100, "ac": 18, "hp": 11, "atk": 3, "dmg": [1, 10, 1], "attacks": 1, "lo": 5, "hi": 10, "pp": 10},
	{"key": "ghoul", "name": "Ghoul", "ch": "G", "color": "9bb88a", "xp": 200, "ac": 12, "hp": 22, "atk": 4, "dmg": [1, 6, 2], "attacks": 2, "lo": 6, "hi": 12, "pp": 10},
	{"key": "bugbear", "name": "Bugbear", "ch": "B", "color": "c2a060", "xp": 200, "ac": 14, "hp": 33, "atk": 4, "dmg": [2, 6, 2], "attacks": 1, "lo": 7, "hi": 13, "pp": 10},
	{"key": "spider", "name": "Giant Spider", "ch": "A", "color": "8c6bb1", "xp": 200, "ac": 14, "hp": 26, "atk": 5, "dmg": [1, 10, 3], "attacks": 1, "lo": 7, "hi": 12, "pp": 14},
	{"key": "ogre", "name": "Ogre", "ch": "O", "color": "d9b36c", "xp": 450, "ac": 11, "hp": 68, "atk": 6, "dmg": [2, 8, 4], "attacks": 1, "lo": 9, "hi": 15, "pp": 8},
	{"key": "minotaur", "name": "Minotaur", "ch": "M", "color": "b5653d", "xp": 700, "ac": 14, "hp": 85, "atk": 6, "dmg": [2, 12, 4], "attacks": 1, "lo": 12, "hi": 18, "pp": 17},
	{"key": "wight", "name": "Wight", "ch": "W", "color": "8fb3d9", "xp": 700, "ac": 14, "hp": 82, "atk": 4, "dmg": [1, 8, 2], "attacks": 2, "lo": 12, "hi": 19, "pp": 13},
	{"key": "wraith", "name": "Wraith", "ch": "R", "color": "6b6bb5", "xp": 1800, "ac": 13, "hp": 67, "atk": 6, "dmg": [3, 8, 3], "attacks": 1, "lo": 15, "hi": 20, "pp": 12},
	{"key": "troll", "name": "Troll", "ch": "T", "color": "5fae5f", "xp": 1800, "ac": 15, "hp": 94, "atk": 7, "dmg": [2, 6, 4], "attacks": 3, "lo": 16, "hi": 20, "pp": 15, "regen": 15},
	{"key": "giant", "name": "Hill Giant", "ch": "H", "color": "c79a6b", "xp": 1800, "ac": 13, "hp": 105, "atk": 8, "dmg": [3, 8, 5], "attacks": 2, "lo": 17, "hi": 20, "pp": 12},
]

## Original final boss (not from the SRD).
const BOSS := {"key": "hollow_king", "name": "Hollow King", "ch": "K", "color": "c58bff", "xp": 5900, "ac": 18, "hp": 200, "atk": 9, "dmg": [2, 8, 5], "attacks": 3, "lo": 20, "hi": 20, "pp": 16, "boss": true}


static func mod(score: int) -> int:
	return floori((score - 10) / 2.0)


static func prof(level: int) -> int:
	return 2 + (level - 1) / 4


static func monster(key: String) -> Dictionary:
	for m in MONSTERS:
		if m["key"] == key:
			return m
	return MONSTERS[0]
