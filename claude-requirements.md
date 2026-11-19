# Depths of the Hollow King: Requirements (Source of Truth)

> **This file is the single source of truth for the game.** Code, README and store listing follow it.
> When a requirement changes, update this file **first**, then the code, in the same commit.
> If code and this file disagree, this file wins: fix the code, or fix the file on purpose.

**Owner:** Jim (jlyle) · **Repo:** jlyle/hollow-king · **Last updated:** 2026-11-19

---

## 1. How we use this file

- **IDs are permanent.** Requirements are `R-##`, decisions are `D-##`, backlog items are `B-##`. Never reuse or renumber; mark retired items `Dropped` instead of deleting them.
- **Status values:** `Done` · `In progress` · `Planned` · `Proposed` (idea, not yet agreed) · `Dropped`.
- Only Jim moves an item from `Proposed` to `Planned`.
- Every change gets one line in the **Change log** (section 8).
- Commit messages reference IDs, e.g. `R-07: add Controls screen`.

---

## 2. Vision

A roguelike game for Google Play. Each new game spawns new, unexplored levels. The player controls a character that follows the recent D&D ruleset (5E, 2024 rules). There are 20 levels, each different and progressively harder, with enemies to vanquish along the way.

---

## 3. Requirements

| ID | Requirement | Status | Notes |
|---|---|---|---|
| R-01 | Publish on Google Play (Android) | In progress | Builds run in Godot; store release not started. See section 6. |
| R-02 | Roguelike: permadeath, turn-based, grid movement | Done | 0 HP = run over (no death saves). |
| R-03 | A new game generates new, unexplored levels | Done | Fresh random seed per run; seed shown on end screen. Fog of war. |
| R-04 | The character follows the recent D&D ruleset (5E 2024 / SRD 5.2.1) | Done (core) | Simplifications are listed in section 5. |
| R-05 | 20 levels, each different | Done | 5 floor bands with distinct layout styles and palettes; floor 20 is the boss hall. |
| R-06 | Difficulty rises level by level | Done | Monster pool shifts by floor; count grows with depth; final boss on floor 20. |
| R-07 | Enemies to vanquish along the way | Done | 16 SRD-style monsters plus an original boss (Hollow King). |
| R-08 | Player can see every control / keybind in-game | Done | Controls screen: button, `?` / F1, Android Back. |

---

## 4. Decisions

| ID | Decision | Chosen | Date |
|---|---|---|---|
| D-01 | Engine | Godot 4.5+ (GDScript), GL Compatibility renderer | 2026-11-18 |
| D-02 | Combat style | Turn-based on a grid | 2026-11-18 |
| D-03 | Party | Single hero | 2026-11-18 |
| D-04 | Visual style | Minimal / ASCII | 2026-11-18 |
| D-05 | Orientation | Portrait, phone-first, touch + keyboard | 2026-11-18 |
| D-06 | Rules source | SRD 5.2.1 under CC-BY-4.0; market as "5E compatible", never "D&D" | 2026-11-18 |
| D-07 | Repo | github.com/jlyle/hollow-king, branch `main` | 2026-11-18 |
| D-08 | Source of truth | This file (`claude-requirements.md`) | 2026-11-19 |

---

## 5. Current game design (as built)

### 5.1 Floors
| Floors | Theme | Layout |
|---|---|---|
| 1–4 | Sunken Cellars | Rooms and corridors |
| 5–8 | Goblin Warrens | Many small rooms |
| 9–12 | Flooded Caverns | Cellular-automata caves with walkable water |
| 13–16 | Bone Crypts | Large pillared halls |
| 17–19 | Infernal Forge | Caves with impassable lava |
| 20 | Throne of the Hollow King | Pillared throne hall and side rooms, no stairs |

- Maps grow with depth (about 51×36 up to 70×46).
- Stairs are placed at the farthest reachable square from the start.
- Taking the stairs is a **Short Rest**. Arriving on floors **5, 9, 13, 17, 20** gives a **Long Rest**.

### 5.2 Hero
- **Classes:** Fighter, Rogue, Wizard. **Species:** Human, Dwarf, Halfling, Orc.
- Ability scores use the standard array plus a +2/+1 background bonus.
- Also implemented: proficiency bonus, the XP table to level 20, Hit Dice, and Ability Score Improvements at levels 4, 8, 12, 16 and 19.
- Each turn has one **Action** (move, attack or cast) and one **Bonus Action** (potion, Second Wind or Hide), which does not end the turn.
- **Fighter:** AC 19 (Defense fighting style), Second Wind, Extra Attack at levels 5, 11 and 20.
- **Rogue:** Hide (Stealth with Expertise vs DC 15), Sneak Attack with Advantage, Uncanny Dodge at level 5.
- **Wizard:** Mage Armor, Fire Bolt (scales at levels 5, 11 and 17; it stops a Troll's regeneration), Magic Missile (costs a slot), Arcane Recovery.
- **Species traits:** Human gets Heroic Inspiration, Dwarf gets +1 HP per level and Darkvision, Halfling gets Luck, Orc gets Relentless Endurance and Darkvision.

### 5.3 Enemies
- Giant Rat, Kobold, Goblin, Skeleton, Zombie, Wolf, Hobgoblin, Ghoul, Bugbear, Giant Spider, Ogre, Minotaur, Wight, Wraith, Troll and Hill Giant.
- **Boss:** the Hollow King (AC 18, 200 HP, 3 attacks), who raises skeletons.
- **Traits:** Pack Tactics, Undead Fortitude, Regeneration.

### 5.4 Items
- Potion of Healing (2d4+2) and Greater Healing (4d4+4).
- Gold.
- Weapon and armor upgrades from +1 to +3.

### 5.5 Deliberate simplifications of the rules
- One square per turn. Every awake monster acts once per hero turn, with no initiative order.
- No death saves.
- Wizard spell slots are a single pool, not tracked by spell level.
- Monster stat blocks are trimmed to AC, HP, attacks and one key trait.

---

## 6. Constraints (Google Play and legal)

| ID | Constraint |
|---|---|
| C-01 | New apps must target **Android 16 (API 36)** or higher. |
| C-02 | Upload as an **AAB** (Gradle build enabled in the Godot export). |
| C-03 | Personal Play developer account: a **closed test with ≥12 testers for 14 continuous days** before production access. |
| C-04 | SRD 5.2.1 attribution statement must appear in-game (title screen, done) and in the store description. |
| C-05 | No "Dungeons & Dragons" / "D&D" names, logos or setting IP. "5E compatible" is allowed. |
| C-06 | Monster names and stats must exist in SRD 5.2.1, or be original. Verify before release. |
| C-07 | Store listing needs a 512×512 icon, 1024×500 feature graphic, screenshots, privacy policy URL, content rating and Data safety form. |
| C-08 | Never commit keystores or signing passwords. |

---

## 7. Backlog

| ID | Item | Status |
|---|---|---|
| B-01 | Save/resume a run when Android closes the app | Proposed |
| B-02 | More classes (Cleric, Barbarian, Ranger) and spells with saving throws | Proposed |
| B-03 | Inventory screen; shops between floors; scrolls and wands | Proposed |
| B-04 | Ranged and spellcasting monsters | Proposed |
| B-05 | Mini-bosses on floors 5, 10, 15 | Proposed |
| B-06 | Sound effects and haptics | Proposed |
| B-07 | Optional tileset to replace ASCII | Proposed |
| B-08 | Verify all monster stats against SRD 5.2.1 (C-06) | Planned |
| B-09 | Android export preset: AAB, API 36, signing (C-01, C-02) | Planned |
| B-10 | Balance pass: playtest all 3 classes to floor 20; tune `XP_MULT` and monster counts | Proposed |

---

## 8. Change log

| Date | Change |
|---|---|
| 2026-11-18 | Initial build: R-01 to R-07, D-01 to D-07. |
| 2026-11-19 | R-08 Controls screen added. |
| 2026-11-19 | D-08: this file created as the source of truth. |
