# Depths of the Hollow King

A turn-based ASCII roguelike for Android, built in **Godot 4.5+**. You control one hero through 20 procedurally generated floors, fighting your way down to the Hollow King. Rules are 5E compatible (2024 rules, SRD 5.2.1).

## Run it

1. Install Godot 4.5 or newer (standard build, not .NET).
2. Project Manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. The window is phone-shaped (720×1280, portrait). The mouse works like a finger.

Desktop keys for testing: arrows / WASD / vi keys (HJKL YUBN) move, Space wait, Enter descend, Q potion, F class ability, E Fire Bolt.

## What's in the starter

| Area | What it does |
|---|---|
| **New dungeon every run** | Fresh random seed each game. The seed is shown on the death/victory screen. |
| **20 different floors** | 1–4 Sunken Cellars (rooms), 5–8 Goblin Warrens (many small rooms), 9–12 Flooded Caverns (cellular-automata caves + water), 13–16 Bone Crypts (pillared halls), 17–19 Infernal Forge (caves + impassable lava), 20 Throne hall with the boss. Maps get larger as you go. |
| **Rising difficulty** | Each monster has a floor range, so stronger monsters replace weaker ones. More monsters per floor the deeper you go. |
| **Hero (2024 rules)** | 3 classes (Fighter, Rogue, Wizard) × 4 species (Human, Dwarf, Halfling, Orc). Standard array + background bonus, proficiency bonus, XP table, Hit Dice, ASIs at 4/8/12/16/19. |
| **Combat** | d20 + modifier + proficiency vs AC; nat 20 crits double the dice; nat 1 always misses; Advantage/Disadvantage. |
| **Enemies** | 16 SRD-style monsters (Giant Rat → Hill Giant) plus an original boss. Pack Tactics, Undead Fortitude, Troll regeneration (fire stops it), boss raises skeletons. |
| **Rests** | Taking the stairs is a Short Rest (spend Hit Dice). Arriving on floors 5, 9, 13, 17 and 20 gives a Long Rest. |
| **Items** | Healing / Greater Healing potions, gold, +1/+2/+3 weapons and armor. |
| **Phone UX** | Tap to move/attack, tap far away to auto-walk (stops when enemies appear), tap yourself to wait or descend. Big buttons. Portrait. |

### Class features implemented
- **Fighter**: Defense style (AC 19), Second Wind (bonus action, 2/3/4 uses), Extra Attack at 5, 11, 20.
- **Rogue**: Hide (bonus action, Stealth with Expertise vs DC 15; monsters spot you if their passive Perception ≥ your roll), Sneak Attack with Advantage, Uncanny Dodge at 5.
- **Wizard**: Mage Armor, Fire Bolt (scales at 5/11/17, Disadvantage with an enemy adjacent), Magic Missile (spends a slot, darts scale with your highest slot level), Arcane Recovery on the first Short Rest after each Long Rest.

### Species traits implemented
Human — Heroic Inspiration (auto-reroll a miss, once per Long Rest). Dwarf — +1 HP/level, Darkvision. Halfling — Luck (reroll natural 1s). Orc — Relentless Endurance, Darkvision. Darkvision lets you see 3 squares farther.

## Deliberate simplifications (roguelike conventions)
- Movement is one square per turn rather than 30 ft of speed; every awake monster acts once per hero turn (no initiative order).
- Hitting 0 HP is death — no death saves (permadeath is the genre).
- Spell slots are tracked as one pool instead of by level.
- Monster stat blocks are trimmed to attacks, AC, HP and one key trait. **Before publishing, check each name and number against SRD 5.2.1** — only use monsters that are in the SRD, or rename them.

## Files
```
project.godot          engine settings (portrait, mobile renderer)
scenes/main.tscn       single scene; everything else is built in code
scripts/game_data.gd   classes, species, monsters, XP table  ← tune balance here
scripts/dungeon_gen.gd floor generator (layout style per floor band)
scripts/game.gd        rules, turn loop, monster AI (no UI code)
scripts/map_view.gd    ASCII renderer + tap input
scripts/main.gd        title screen, HUD, buttons, end screens
```
Balance knobs: `XP_MULT` and `LONG_REST_FLOORS` in `game.gd`; monster `lo`/`hi` floor ranges in `game_data.gd`; monster count formula in `Game._spawn()`.

## Publishing to Google Play (checklist)
1. **Android export setup** in Godot: Editor → Editor Settings → Export → Android: set the Java SDK (JDK 17) and Android SDK paths. Project → Install Android Build Template.
2. Project → Export → Add **Android** preset. Enable **Use Gradle Build**, set **Export Format = AAB** (Play requires App Bundles), set a unique package name (e.g. `com.yourname.hollowking`), version code/name.
3. **Target SDK must be 36 (Android 16)** for new apps — check the preset's Target SDK field and raise it if your Godot version defaults lower.
4. Create an upload keystore (`keytool -genkey ...`), set it in the preset's Release keystore fields. Keep it out of git (`.gitignore` already blocks `*.keystore`).
5. Play Console: one-time developer registration fee. **New personal accounts must run a closed test with at least 12 testers opted in for 14 continuous days** before applying for production. Organization accounts are exempt.
6. Store listing needs: icon 512×512, feature graphic 1024×500, phone screenshots, privacy policy URL (even if you collect nothing), content rating questionnaire, Data safety form.

## Legal
- Rules content is used under CC-BY-4.0 from SRD 5.2.1. The attribution statement is shown on the title screen; also put it in the store description.
- Don't use "Dungeons & Dragons", "D&D", or Wizards' logos/settings in the name, icon or listing. "5E compatible" is allowed.
- The Hollow King, all text, and the code are original.

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

## Suggested next steps
1. Save/resume when Android closes the app mid-run.
2. More classes (Cleric, Barbarian, Ranger) and spells with saving throws.
3. Inventory screen, shops between floors, scrolls/wands.
4. Ranged and spellcasting monsters; floor-specific mini-bosses on 5/10/15.
5. Sound, haptics, and an optional tileset to replace the ASCII.
