# Depths of the Hollow King

A turn-based ASCII roguelike for Android, built in **Godot 4.5+**. You control one hero through 20 procedurally generated floors, fighting your way down to the Hollow King. Rules are 5E compatible (2024 rules, SRD 5.2.1).

## Run it

1. Install Godot 4.5 or newer (standard build, not .NET).
2. Project Manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. The window is phone-shaped (720×1280, portrait). The mouse works like a finger.

Desktop keys for testing: arrows / WASD / vi keys (HJKL YUBN) move, Space wait, Enter descend, Q potion, F class ability, E ranged attack, R spells (or Reckless), ? or F1 opens the Controls screen.

## What's in the starter

| Area | What it does |
|---|---|
| **New dungeon every run** | Fresh random seed each game. The seed is shown on the death/victory screen. |
| **20 different floors** | 1–4 Sunken Cellars (rooms), 5–8 Goblin Warrens (many small rooms), 9–12 Flooded Caverns (cellular-automata caves + water), 13–16 Bone Crypts (pillared halls), 17–19 Infernal Forge (caves + impassable lava), 20 Throne hall with the boss. Maps get larger as you go. |
| **Rising difficulty** | Each monster has a floor range, so stronger monsters replace weaker ones. More monsters per floor the deeper you go. |
| **Hero (2024 rules)** | 6 classes (Fighter, Rogue, Barbarian, Ranger, Wizard, Cleric) × 4 species (Human, Dwarf, Halfling, Orc). Standard array + background bonus, proficiency bonus, XP table, Hit Dice, ASIs at 4/8/12/16/19. |
| **Combat** | d20 + modifier + proficiency vs AC; nat 20 crits double the dice; nat 1 always misses; Advantage/Disadvantage. |
| **Enemies** | 16 SRD-style melee monsters (Giant Rat → Hill Giant), goblin and skeleton **archers**, 4 **spellcasters** (their save spells make *you* roll), **mini-bosses** on floors 5, 10, 15 that seal the stairs (`&`), and the Hollow King on 20. |
| **Rests** | Taking the stairs is a Short Rest (spend Hit Dice). Arriving on floors 5, 9, 13, 17 and 20 gives a Long Rest. |
| **Items** | Healing / Greater Healing potions, gold, +1/+2/+3 weapons and armor. |
| **Save / resume** | Autosaves after every action and when Android pauses or closes the app. **Continue** on the title screen. The save is deleted on death or victory (permadeath), and the dice state is saved, so quitting can't reroll bad luck. |
| **Sound, haptics, tiles** | 15 original sound effects, short vibrations on hits/level-ups/death, and an optional 16×16 pixel **tileset** instead of ASCII. Toggle all three in **Settings** (title screen or in-game); choices are remembered. |
| **Phone UX** | Tap to move/attack, tap far away to auto-walk (stops when enemies appear), tap yourself to wait or descend. Big buttons. Portrait. In-game **Controls** screen (button, ?/F1, or Android Back) lists every tap, key and map symbol. |

### Class features implemented
- **Fighter**: Defense style (AC 19), Second Wind (bonus action, 2/3/4 uses), Extra Attack at 5, 11, 20.
- **Rogue**: Hide (bonus action, Stealth with Expertise vs DC 15; monsters spot you if their passive Perception ≥ your roll), Sneak Attack with Advantage, Uncanny Dodge at 5.
- **Barbarian**: Unarmored Defense, Rage (halves physical damage, bonus melee damage), Reckless Attack toggle at 2, Extra Attack at 5.
- **Ranger**: longbow at range (Archery +2 from level 2), Hunter's Mark, Ensnaring Strike, Cure Wounds, Extra Attack at 5.
- **Wizard**: Mage Armor, Fire Bolt, Magic Missile, Burning Hands, Thunderwave, Shatter (3), Fireball (5), Arcane Recovery.
- **Cleric**: Protector (AC 18), Sacred Flame, Healing Word, Guiding Bolt, Turn Undead (2), Spirit Guardians (5).

### Spells and saving throws
Casters open the **Spells** menu (button or R). Save spells roll the monster's own save bonus against your spell DC (8 + casting modifier + proficiency). Conditions: Restrained, Turned (fleeing), Guided. Concentration is one spell at a time and breaks on a failed CON save when you take damage. The full spell table is in `claude-requirements.md` section 5.3.

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
scripts/main.gd        title screen, HUD, buttons, spell menu, settings, sound + haptics
audio/*.wav            sound effects (generated)
art/tiles.png          16x16 tileset atlas (generated); art/tiles_preview.png is a 6x preview
testing.html           smoke-test checklist (open in any browser)
tools/make_sounds.py   regenerates audio/  (python3 + numpy)
tools/make_tiles.py    regenerates art/    (python3 + Pillow); edit the pixel grids to redraw tiles
```
To use a different tileset, replace `art/tiles.png` with any 16×16 atlas in the same layout (see the top of `tools/make_tiles.py`).
Balance knobs: `XP_MULT` and `LONG_REST_FLOORS` in `game.gd`; monster `lo`/`hi` floor ranges in `game_data.gd`; monster count formula in `Game._spawn()`.

## Publishing to Google Play (checklist)
1. **Android export setup** in Godot: Editor → Editor Settings → Export → Android: set the Java SDK (JDK 17) and Android SDK paths. Project → Install Android Build Template.
2. Project → Export → Add **Android** preset. Enable **Use Gradle Build**, set **Export Format = AAB** (Play requires App Bundles), set a unique package name (e.g. `com.yourname.hollowking`), version code/name.
3. **Target SDK must be 36 (Android 16)** for new apps — check the preset's Target SDK field and raise it if your Godot version defaults lower.
4. Under **Permissions**, tick **Vibrate** (needed for haptics).
5. Create an upload keystore (`keytool -genkey ...`), set it in the preset's Release keystore fields. Keep it out of git (`.gitignore` already blocks `*.keystore`).
6. Play Console: one-time developer registration fee. **New personal accounts must run a closed test with at least 12 testers opted in for 14 continuous days** before applying for production. Organization accounts are exempt.
7. Store listing needs: icon 512×512, feature graphic 1024×500, phone screenshots, privacy policy URL (even if you collect nothing), content rating questionnaire, Data safety form.

## Legal
- Rules content is used under CC-BY-4.0 from SRD 5.2.1. The attribution statement is shown on the title screen; also put it in the store description.
- Don't use "Dungeons & Dragons", "D&D", or Wizards' logos/settings in the name, icon or listing. "5E compatible" is allowed.
- The Hollow King, all text, and the code are original.

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

## Suggested next steps
1. Inventory screen, shops between floors, scrolls/wands.
2. Balance pass across all six classes.
