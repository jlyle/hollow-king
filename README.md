# Depths of the Hollow King

A turn-based roguelike for **Linux**, built in **Godot 4.7+**. You control one hero through 20 procedurally generated floors, fighting your way down to the Hollow King. Rules are 5E compatible (2024 rules, SRD 5.2.1).

The earlier Android/Google Play version is kept on the `android-final` branch.

## Build & install (Linux)

You need Godot 4.7+ (`godot --version`) and the **export templates for exactly that version**:
```bash
V=4.7.1   # match your godot --version
cd /tmp && curl -LO https://github.com/godotengine/godot/releases/download/$V-stable/Godot_v$V-stable_export_templates.tpz
unzip -q Godot_v$V-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/$V.stable && mv templates/* ~/.local/share/godot/export_templates/$V.stable/
```
Then, from this folder:

| Command | What it does |
|---|---|
| `tools/build.sh check` | Checks Godot and the export templates |
| `tools/build.sh run` | Builds if anything changed, then runs the game |
| `tools/build.sh build` | Builds one self-contained binary: `builds/hollow-king.x86_64` |
| `tools/build.sh install` | Installs for your user: `~/.local/bin/hollow-king` + app-menu entry (Games) + icon |
| `tools/build.sh uninstall` | Removes the binary, icon and menu entry (keeps saves) |

### Flatpak (share with any Linux distro)
```bash
sudo dnf install flatpak-builder     # once
tools/build.sh flatpak               # builds builds/hollow-king.flatpak and installs it for you
```
Send `builds/hollow-king.flatpak` to anyone on x86_64 Linux with Flatpak; they install it with
`flatpak install --user hollow-king.flatpak`, and the runtime it needs comes from Flathub automatically.
The Flatpak keeps its saves in `~/.var/app/io.github.jlyle.HollowKing/`.

For development you can also press **F5** in the Godot editor (`godot -e --path .`).
Saves and settings live in `~/.local/share/godot/app_userdata/Depths of the Hollow King/`.

## Controls
- **Keyboard:** arrows / WASD / HJKL + YUBN / numpad move and attack · Space wait · Enter descend · Q potion · F class ability · E ranged · R spells (Reckless for Barbarian) · X explore · `+`/`-` zoom · F11 fullscreen · `?`/F1 controls · Esc pause menu (quits on the title screen).
- **Mouse:** left-click to move, attack, select or auto-walk · right-click to inspect · wheel to zoom.

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
| **Save / resume** | Autosaves after every action and when the window loses focus or closes. **Continue** on the title screen. The save is deleted on death or victory (permadeath), and the dice state is saved, so quitting can't reroll bad luck. |
| **Graphics** | Warm, chunky cartoon art in the spirit of Spelunky 2, all original: textured rock walls with front faces, a look per area, a sprite for every class and monster, shadows, torchlight and a gentle idle bob. ASCII mode is still one switch away. |
| **Sound, settings** | 15 original sound effects. **Settings** (title screen or pause menu): sound, tiles, map zoom, fullscreen; remembered between sessions. |
| **Desktop UX** | Map across the top; under it a strip with status, message log and buttons (each labelled with its key). **Explore** auto-walks to unexplored areas. Resizable window, F11 fullscreen. In-game **Controls** screen (? / F1) lists every key, click and map symbol. |

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
- Monster stat blocks are trimmed to attacks, AC, HP and one key trait. **Before sharing the game publicly, check each name and number against SRD 5.2.1** (B-08) — only use monsters that are in the SRD, or rename them.

## Files
```
project.godot          engine settings (landscape desktop window, GL Compatibility renderer)
scenes/main.tscn       single scene; everything else is built in code
scripts/game_data.gd   classes, species, monsters, XP table  ← tune balance here
scripts/dungeon_gen.gd floor generator (layout style per floor band)
scripts/game.gd        rules, turn loop, monster AI (no UI code)
scripts/map_view.gd    ASCII / tile renderer + mouse input
scripts/main.gd        title screen, control strip, buttons, spell/pause/settings screens, sound
audio/*.wav            sound effects (generated)
art/tiles.png          64x64 cartoon tileset atlas (generated); art/tiles_preview.png shows every tile, labelled
scripts/tile_atlas.gd  tile name -> atlas index (generated with the atlas; don't edit by hand)
testing.html           smoke-test checklist (open in Chrome from this folder; graphics steps show sprite thumbnails)
tools/make_sounds.py   regenerates audio/  (python3 + numpy)
tools/make_tiles.py    paints the whole tileset (python3 + Pillow): edit colours/shapes there, re-run, done
tools/make_icons.py    regenerates art/icon_512.png (app-menu icon) from the hero sprite
tools/build.sh         Linux build: check | build | run | install | uninstall
packaging/             app-menu (.desktop) entry template; packaging/flatpak/ = Flatpak manifest, desktop entry, app-store metadata
export_presets.cfg     "Linux" export preset (x86_64, PCK embedded in the binary)
```
To change the art, edit `tools/make_tiles.py` and run it; it rewrites `art/tiles.png` and `scripts/tile_atlas.gd` together.
Balance knobs: `XP_MULT` and `LONG_REST_FLOORS` in `game.gd`; monster `lo`/`hi` floor ranges in `game_data.gd`; monster count formula in `Game._spawn()`.

## Legal
- Rules content is used under CC-BY-4.0 from SRD 5.2.1. The full attribution is on the in-game **Credits** screen and below.
- Don't use "Dungeons & Dragons", "D&D", or Wizards' logos/settings in the name, icon or any release page. "5E compatible" is allowed.
- The Hollow King, all text, and the code are original.

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

## Suggested next steps
1. Inventory screen, shops between floors, scrolls/wands.
2. Balance pass across all six classes.
3. Publish the Flatpak on Flathub (needs a licence decision and a public repo).
