# Depths of the Hollow King: Requirements (Source of Truth)

> **This file is the single source of truth for the game.** Code and README follow it.
> When a requirement changes, update this file **first**, then the code, in the same commit.
> If code and this file disagree, this file wins: fix the code, or fix the file on purpose.

**Owner:** Jim (jlyle) · **Repo:** jlyle/hollow-king · **Last updated:** 2026-11-23

---

## 1. How we use this file

- **IDs are permanent.** Requirements are `R-##`, decisions are `D-##`, backlog items are `B-##`. Never reuse or renumber; mark retired items `Dropped` instead of deleting them.
- **Status values:** `Done` · `In progress` · `Planned` · `Proposed` (idea, not yet agreed) · `Dropped`.
- Only Jim moves an item from `Proposed` to `Planned`.
- Every change gets one line in the **Change log** (section 8).
- Commit messages reference IDs, e.g. `R-07: add Controls screen`.

---

## 2. Vision

A roguelike game for **Linux desktop** (D-14; originally planned for Google Play, see the `android-final` branch). Each new game spawns new, unexplored levels. The player controls a character that follows the recent D&D ruleset (5E, 2024 rules). There are 20 levels, each different and progressively harder, with enemies to vanquish along the way.

---

## 3. Requirements

| ID | Requirement | Status | Notes |
|---|---|---|---|
| R-01 | Publish on Google Play (Android) | Dropped | Replaced by R-21 on 2026-11-23 (Linux only, D-14). Last Android version: branch `android-final`. |
| R-02 | Roguelike: permadeath, turn-based, grid movement | Done | 0 HP = run over (no death saves). |
| R-03 | A new game generates new, unexplored levels | Done | Fresh random seed per run; seed shown on end screen. Fog of war. |
| R-04 | The character follows the recent D&D ruleset (5E 2024 / SRD 5.2.1) | Done (core) | Simplifications are listed in section 5. |
| R-05 | 20 levels, each different | Done | 5 floor bands with distinct layout styles and palettes; floor 20 is the boss hall. |
| R-06 | Difficulty rises level by level | Done | Monster pool shifts by floor; count grows with depth; final boss on floor 20. |
| R-07 | Enemies to vanquish along the way | Done | 16 SRD-style monsters plus an original boss (Hollow King). |
| R-08 | Player can see every control / keybind in-game | Done | Controls screen: button or `?` / F1. Lists keyboard and mouse controls. |
| R-09 | A run survives the game being closed: it is saved automatically and can be resumed | Done | Autosave after every turn and on window close; **Continue** on the title screen. From B-01. |
| R-10 | Six playable classes: Fighter, Rogue, Wizard, Cleric, Barbarian, Ranger | Done | Cleric, Barbarian, Ranger added from B-02. |
| R-11 | Spells, including spells that force saving throws, with conditions and Concentration | Done | Spell menu; monster saves use per-ability save bonuses. From B-02. See 5.3. |
| R-12 | Ranged and spellcasting monsters | Done | Archers shoot from range; casters force hero saving throws, heal allies, raise the dead. From B-04. See 5.4. |
| R-13 | Floor-specific mini-bosses on floors 5, 10 and 15 | Done | Each guards and seals the stairs until defeated. From B-05. See 5.4. |
| R-14 | Sound effects for key game events | Done | 15 original synthesized sounds. From B-06. See 5.8. |
| R-15 | Haptic feedback on phones | Dropped | Phone-only; removed with the Linux rebuild (D-14). |
| R-16 | Optional tileset as an alternative to ASCII | Done | Original 16×16 pixel tileset; switch in Settings. From B-07. See 5.8. |
| R-17 | Settings screen, remembered between sessions | Done | Sound, display mode (ASCII / Tiles), map zoom, fullscreen. |
| R-18 | Clean, readable, attractive title screen | Done | Single centred column, clear selection state, class card with tagline, one primary button, a row of secondary buttons (Controls, Settings, Credits, Quit), legal text under Credits. See 5.9. |
| R-19 | Pause menu and a way to quit | Done | In-game **Menu**: Resume, Controls, Settings, Save & return to title, Save & quit. Title screen has **Quit**. Esc opens the menu during a run. |
| R-20 | Easy to play on a phone without a keyboard | Dropped | Replaced by R-22 (desktop controls) on 2026-11-23. Was: On-screen D-pad (hold to repeat), swipe to move, long-press to inspect, **Explore** auto-walk, map zoom setting, touch-first Controls screen. |
| R-21 | Runs as a native Linux desktop app | Done | x86_64 binary built with `tools/build.sh`; installs to your user account with an app-menu entry. See D-14, 5.10. |
| R-22 | Comfortable desktop controls: keyboard first, mouse supported | Done | Full keyboard play, left-click move/attack/travel, right-click inspect, wheel zoom, **Explore**, F11 fullscreen. See 5.10. |
| R-23 | Graphics in a warm, chunky, hand-painted cartoon style, similar in feel to Spelunky 2 | Done | Original art only (D-15): textured rock walls with front faces, per-area textures, a sprite per class and per monster, torchlight around the hero, drop shadows, idle bob. Tiles are now the default display; ASCII stays available. See 5.8. |
| R-24 | Installable on any x86_64 Linux distro that has Flatpak, with its dependencies installed automatically | Done: built and played on Jim's Fedora machine 2026-11-23 | Single file `hollow-king.flatpak`; installing it pulls the Freedesktop runtime from Flathub (D-16). From B-11. |

---

## 4. Decisions

| ID | Decision | Chosen | Date |
|---|---|---|---|
| D-01 | Engine | Godot 4.7+ (GDScript), GL Compatibility renderer (was 4.5+; Jim's machine runs 4.7.1) | 2026-11-19 |
| D-02 | Combat style | Turn-based on a grid | 2026-11-18 |
| D-03 | Party | Single hero | 2026-11-18 |
| D-04 | Visual style | Minimal / ASCII | 2026-11-18 |
| D-05 | Window and input | Landscape desktop window (resizable, F11 fullscreen), keyboard + mouse. Was: portrait, phone-first, touch | 2026-11-23 |
| D-06 | Rules source | SRD 5.2.1 under CC-BY-4.0; market as "5E compatible", never "D&D" | 2026-11-18 |
| D-07 | Repo | github.com/jlyle/hollow-king, branch `main` | 2026-11-18 |
| D-08 | Source of truth | This file (`claude-requirements.md`) | 2026-11-19 |
| D-09 | Audio and art assets | Original, generated by script (`tools/`), no third-party licences. The tile generator also writes `scripts/tile_atlas.gd` (name → atlas index), so the atlas layout can change freely | 2026-11-23 |
| D-10 | Smoke testing | `testing.html`: interactive checklist in lettered sections (A-01, D-07, …), each step mapped to an R-/C-/D- ID. Graphics steps show the real sprites as thumbnails from `art/tiles.png`; the tile index is built into the page by `tools/make_tiles.py`. Add or update steps whenever a requirement changes | 2026-11-23 |
| D-11 | Visual style | Dark background with a warm gold accent; rounded panels; uppercase spaced section labels; one gold primary button per screen. Palette in 5.9 | 2026-11-19 |
| D-12 | ~~Android package name~~ **Dropped 2026-11-23** (D-14) | `com.jlyle.hollowking` (**permanent after the first Play upload** — confirm before uploading). Display name "Hollow King". Version name `0.1.0`, version code starts at 1 and **must increase with every upload** | 2026-11-19 |
| D-13 | ~~Android build setup~~ **Dropped 2026-11-23** (D-14) | Two export presets in `export_presets.cfg`: **Android Debug (APK)** for sideloading to a phone, **Android Release (AAB)** for Play (Gradle build, target SDK 36, arm64 + armv7). Built from the command line with `tools/android.sh`; guide in `ANDROID.md` | 2026-11-19 |
| D-14 | Platform | **Linux only** (x86_64). Godot Linux export (`export_presets.cfg`, preset "Linux"), PCK embedded in one binary. `tools/build.sh check | build | run | install | uninstall`; install puts the binary in `~/.local/bin/hollow-king`, an app-menu entry in `~/.local/share/applications/` and the icon in `~/.local/share/icons/`. Android version preserved on branch `android-final` | 2026-11-23 |
| D-15 | Art style | Cartoon style *inspired by* Spelunky 2 (bold dark outlines, earthy palette, shaded rounded shapes, big-headed characters), drawn from scratch by `tools/make_tiles.py`. **No Spelunky characters, sprites or other assets are copied or traced** (C-05 spirit). 64×64 atlas cells, smooth (linear) scaling | 2026-11-23 |
| D-16 | Flatpak packaging | App ID `io.github.jlyle.HollowKing` (**permanent once shared** — changing it later makes it a different app). Runtime `org.freedesktop.Platform` **25.08** (supported to Aug 2027; move to the next August release before then). Bundles the exported Godot binary; permissions: X11 + GPU + audio only (no network, no file access). Bundle built with `--runtime-repo` = Flathub so installs fetch the runtime. Files in `packaging/flatpak/` | 2026-11-23 |

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
- **Classes:** Fighter, Rogue, Wizard, Cleric, Barbarian, Ranger. **Species:** Human, Dwarf, Halfling, Orc.
- Ability scores use the standard array plus a +2/+1 background bonus.
- Also implemented: proficiency bonus, the XP table to level 20, Hit Dice, and Ability Score Improvements at levels 4, 8, 12, 16 and 19.
- Each turn has one **Action** (move, attack or cast) and one **Bonus Action** (potion, Second Wind or Hide), which does not end the turn.
- **Fighter:** AC 19 (Defense fighting style), Second Wind, Extra Attack at levels 5, 11 and 20.
- **Rogue:** Hide (Stealth with Expertise vs DC 15), Sneak Attack with Advantage, Uncanny Dodge at level 5, Evasion at level 7 (DEX save for half damage: none on a success, half on a failure).
- **Wizard:** Mage Armor (AC 13 + DEX), spells (5.3), Arcane Recovery.
- **Cleric (Protector):** chain mail + shield (AC 18), mace. Spells (5.3). Channel Divinity uses: 2 at level 2, 3 at 6, 4 at 18.
- **Barbarian:** Unarmored Defense (10 + DEX + CON), greataxe. **Rage** (bonus action, 10 turns): halves physical damage taken, +2/+3/+4 melee damage. Uses 2/3/4/5/6 at levels 1/3/6/12/17. **Reckless Attack** toggle from level 2 (Advantage on your melee attacks, enemies get Advantage on you). Extra Attack at level 5.
- **Ranger:** studded leather (AC 12 + DEX), shortsword + **longbow** (tap a far enemy to shoot). Archery style (+2 ranged) from level 2. Extra Attack at level 5. **Hunter's Mark** free uses 2/3/4/5/6 at levels 1/5/9/13/17, then slots.
- **Saving throw proficiencies:** Fighter STR/CON, Rogue DEX/INT, Wizard INT/WIS, Cleric WIS/CHA, Barbarian STR/CON, Ranger STR/DEX. Spell save DC = 8 + casting modifier + proficiency bonus.
- **Species traits:** Human gets Heroic Inspiration, Dwarf gets +1 HP per level and Darkvision, Halfling gets Luck, Orc gets Relentless Endurance and Darkvision.

### 5.3 Spells (R-11)
| Spell | Class | Level (char. lvl) | Effect |
|---|---|---|---|
| Fire Bolt | Wizard | cantrip | Spell attack, 1d10 fire (scales 5/11/17). Stops regeneration. |
| Magic Missile | Wizard | 1st | Auto-hit darts, 1d4+1 force each, 3 + 1 per slot level above 1st. |
| Burning Hands | Wizard | 1st | **DEX save**, cone 3 squares: 3d6 fire, half on save. |
| Thunderwave | Wizard | 1st | **CON save**, adjacent enemies: 2d8 thunder + push 2; half, no push on save. |
| Shatter | Wizard | 2nd (lvl 3) | **CON save**, 2-square burst: 3d8 thunder, half on save. Can hit you. |
| Fireball | Wizard | 3rd (lvl 5) | **DEX save**, 4-square burst: 8d6 fire, half on save. Can hit you. |
| Sacred Flame | Cleric | cantrip | **DEX save**, 1d8 radiant (scales), nothing on save. Radiant beats Undead Fortitude. |
| Healing Word | Cleric | 1st | Bonus Action. Heal 2d4 + WIS, +2d4 per slot level above 1st. |
| Guiding Bolt | Cleric | 1st | Spell attack, 4d6 radiant; your next attack on it has Advantage. |
| Turn Undead | Cleric | Channel Divinity (lvl 2) | **WIS save**, undead within 6 squares flee for 10 turns; ends if damaged. Boss immune. |
| Spirit Guardians | Cleric | 3rd (lvl 5) | Concentration. Enemies ending a turn within 3 squares: **WIS save**, 3d8 radiant, half on save. |
| Hunter's Mark | Ranger | 1st | Bonus Action, Concentration. +1d6 force on weapon hits against the mark. |
| Ensnaring Strike | Ranger | 1st | Bonus Action, Concentration. Next hit: **STR save** or Restrained (can't move, 1d6/turn, repeats save). |
| Cure Wounds | Ranger | 1st | Heal 2d8 + WIS, +2d8 per slot level above 1st. |

- **Conditions:** Restrained (no movement, Disadvantage on its attacks, Advantage against it, Disadvantage on DEX saves); Frightened by Turn Undead (flees, can't attack); Guided (next attack has Advantage).
- **Concentration:** one spell at a time. Casting another ends it. Taking damage forces a CON save, DC 10 or half the damage (whichever is higher). It also ends on a new floor.
- Monster stat blocks carry save bonuses for all six abilities, plus undead/damage-type tags.

### 5.4 Enemies
- **Melee:** Giant Rat, Kobold, Goblin, Skeleton, Zombie, Wolf, Hobgoblin, Ghoul, Bugbear, Giant Spider, Ogre, Minotaur, Wight, Wraith, Troll and Hill Giant.
- **Traits:** Pack Tactics, Undead Fortitude, Regeneration.

**Ranged (R-12)**. Archers shoot when you're 2+ squares away and in sight, and fight in melee when you're adjacent.

| Monster | Floors | Ranged attack |
|---|---|---|
| Goblin Archer | 2–7 | Shortbow +4, 1d6+2, 12 squares |
| Skeleton Archer | 4–9 | Shortbow +5, 1d6+3, 12 squares |

**Spellcasters (R-12).** These have original names and simplified spells. Their save spells make **you** roll a saving throw against their DC.

| Monster | Floors | Spells |
|---|---|---|
| Kobold Shaman | 2–6 | Fire Bolt (spell attack +4, 1d10 fire) |
| Cult Acolyte | 4–10 | Sacred Flame (DEX DC 12, 1d8 radiant, nothing on a save); Mend (heals a wounded ally 2d4+2) |
| Dark Adept | 9–15 | Sickening Ray (CON DC 13, 2d8 poison, half on a save, **Poisoned** 2 turns on a fail); Fire Bolt (+5, 2d10) |
| Necromancer | 14–20 | Blight (CON DC 15, 4d8 necrotic, half on a save); raises 2 skeletons every 6 turns |

- **Poisoned (hero):** Disadvantage on your attack rolls while it lasts.

**Mini-bosses (R-13).** Each stands guard by the stairs and **seals them** (red `>`) until defeated. Shown as `&`.

| Floor | Mini-boss | Highlights |
|---|---|---|
| 5 | Goblin Warchief | AC 17, 52 HP, 2 attacks, shortbow, calls 2 goblins every 6 turns |
| 10 | The Drowned Oracle | AC 14, 85 HP; Tidal Lash (CON DC 14, 3d8, push 2); Sickening Ray; Mend |
| 15 | The Bone Warden | Undead (immune to Turn Undead), AC 17, 130 HP, 2 attacks; Grave Chill (WIS DC 15, 3d8 necrotic); raises skeletons |

**Final boss:** the Hollow King on floor 20 (AC 18, 200 HP, 3 attacks), who raises skeletons.

### 5.5 Items
- Potion of Healing (2d4+2) and Greater Healing (4d4+4).
- Gold.
- Weapon and armor upgrades from +1 to +3.

### 5.6 Saving (R-09)
- One save slot, stored in `user://run.save` on the device.
- Autosaves after every action, and when the window loses focus or is closed. The save is written to a temp file first, so a kill mid-write can't corrupt it.
- The random number generator's state is saved too. Reloading replays the same rolls, so quitting can't be used to reroll a bad outcome (save-scumming).
- The save is deleted when the run ends (death or victory). This keeps permadeath (R-02).
- Title screen shows **Continue (Floor N, Lv N class)** when a save exists. Starting a new run replaces the saved run; the button says so.

### 5.7 Deliberate simplifications of the rules
- One square per turn. Every awake monster acts once per hero turn, with no initiative order.
- No death saves.
- Spell slots are a single pool, not tracked by spell level. Leveled spells are always cast at your highest available slot level.
- Areas are measured in squares (1 square = 5 ft); cones aim at your current target.
- Ensnaring Strike is primed before the hit; Hunter's Mark moves to the next creature you hit for free when its target dies.
- Rage lasts 10 turns. Spirit Guardians lasts until Concentration breaks or you change floors.
- Monster stat blocks are trimmed to AC, HP, attacks and one key trait. Spellcasting monsters and mini-bosses are original creatures with simplified spells, each on its own cooldown.


### 5.8 Presentation: sound, tiles, settings (R-14, R-16, R-17)
- **Settings** (title screen and pause menu), saved to `~/.local/share/godot/app_userdata/Depths of the Hollow King/settings.cfg`: Sound on/off, Display ASCII / Tiles, Map zoom, Fullscreen. Defaults: sound on, Tiles, Medium, windowed.
- **Sounds** (`audio/*.wav`, mono 22 kHz): step, hit, crit, miss, hurt, kill, spell, heal, pickup, level up, descend, death, victory, enemy spell, summon.
- **Tileset (R-23, D-15)** `art/tiles.png`, 64×64 cells, index in `scripts/tile_atlas.gd`:
  - Per area (cellars, warrens, caverns, crypts, forge, throne): wall **top**, wall **face** (drawn when floor is below the wall, for depth), two floor variants (picked per square so floors don't look tiled).
  - Water, lava, stairs (trapdoor with ladder), sealed stairs (chained grate).
  - Six hero sprites, one per class; one sprite per monster, mini-boss and the Hollow King; potion, greater potion, gold, weapon, armor.
  - In-game: soft drop shadows under figures and items, warm torchlight that fades with distance from the hero, darker blue-grey tint on remembered squares, gentle idle bob. Selection frame and health bars as before.
- **Display default:** Tiles (new settings files). ASCII remains a Settings option.


### 5.9 Visual style (R-18, D-11)
- **Palette:** background `#0b0b12` with a faint warm glow at the top; panels `#13131c`, borders `#2a2a3a`; text `#e9e6dc`, muted text `#8d8a99`; accent gold `#e8c170`.
- **Title screen**, top to bottom: title, tagline, CLASS chips (3×2), SPECIES chips, class card (name, role line, one-line tagline, details, species line), primary button (**Begin Descent**, or **Continue** when a save exists, with New Run below it), a row of four equal-width **secondary buttons** (Controls, Settings, Credits, Quit: outlined panels, 52 px tall, gold text and border on hover), one-line SRD note. Changed 2026-11-23 at Jim's request (were small text links).
- **Selected chips** get a gold border and gold text. Content is a fixed-width centred column (620 px) in the middle of the window.
- **Window:** opens at 1280×800, resizable (minimum 1024×640); the UI is designed at 1600×1000 and scales with the window. F11 or Settings toggles fullscreen.
- **Pause menu (R-19):** opened by the in-game **Menu** button or Esc. Resume (gold primary), Controls, Settings, Save & return to title, Save & quit. Settings moves into this menu; the in-game controls are described in 5.10.
- **Quitting:** the title screen's secondary buttons are Controls, Settings, Credits and Quit; Esc on the title screen (with nothing open) also quits. The run is always saved before leaving.

### 5.10 Desktop layout and controls (R-21, R-22)
- **Game screen:** map across the full width at the top; a **control strip under the map** (about 210 px) with three parts side by side: status on the left, the message log in the middle (fills the space), and the action buttons on the right in a 3×3 grid (Potion, Ability, Ranged, Spells/Reckless, Explore, Descend, Wait, Controls, Menu). Buttons a class doesn't use are hidden. Changed 2026-11-23 at Jim's request (was: sidebar on the right).
- **Keyboard (primary):** arrows / WASD / HJKL + YUBN / numpad move and attack; Space or `.` wait; Enter descend; Q potion; F ability; E ranged; R spells (Reckless for Barbarian); X explore; `+` / `-` zoom; F11 fullscreen; `?` / F1 controls; Esc pause menu (quit on the title screen).
- **Mouse:** left-click a neighbouring square to move/attack; left-click a distant explored square to auto-walk; left-click an enemy to select it (casters/Ranger also attack); **right-click** to inspect any square; **mouse wheel** to zoom.
- **Explore:** auto-walks to the nearest unexplored area or visible item; stops when an enemy appears or you're hurt. When nothing is left, it walks to the stairs.
- **Map zoom** (Settings, wheel, +/-): Small 41 / Medium 31 / Large 23 squares across. Default Medium.
---

## 6. Constraints (platform and legal)

| ID | Constraint |
|---|---|
| C-01 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~New apps must target **Android 16 (API 36)** or higher.~~ |
| C-02 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~Upload as an **AAB** (Gradle build enabled in the Godot export).~~ |
| C-03 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~Personal Play developer account: a **closed test with ≥12 testers for 14 continuous days** before production access.~~ |
| C-04 | SRD 5.2.1 attribution statement must appear in-game (full text on the **Credits** screen, linked from the title screen, with a short SRD/CC-BY note on the title screen itself) and in the README of any public release. |
| C-05 | No "Dungeons & Dragons" / "D&D" names, logos or setting IP. "5E compatible" is allowed. |
| C-06 | Monster names and stats must exist in SRD 5.2.1, or be original. Verify before release. |
| C-07 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~Store listing needs a 512×512 icon, 1024×500 feature graphic, screenshots, privacy policy URL, content rating and Data safety form.~~ |
| C-08 | Never commit keystores or signing passwords. |
| C-09 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~Android export preset must enable the **VIBRATE** permission for haptics (R-15).~~ |
| C-10 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~The upload keystore lives **outside the repo** (`~/.android-keys/`) with an offline backup; its password is never written to any file in the repo. Losing it means contacting Google to reset the upload key.~~ |
| C-11 | **Dropped 2026-11-23 (Google Play / Android only, D-14).** ~~Launcher icons: 192×192 main + 432×432 adaptive foreground/background; Play listing icon 512×512. Generated by `tools/make_icons.py` from the hero sprite (D-09).~~ |
| C-12 | Linux build needs Godot export templates that match the editor version exactly (e.g. 4.7.1.stable). Renderer stays GL Compatibility (OpenGL 3.3), so it runs on older and integrated GPUs. |
| C-13 | Flatpak: x86_64 only (no ARM build yet). Target PC needs Flatpak itself (preinstalled on Fedora, Mint, Pop!_OS, etc.; `apt install flatpak` on Debian/Ubuntu). The Flatpak keeps its saves in `~/.var/app/io.github.jlyle.HollowKing/`, separate from the `tools/build.sh install` version. |

---

## 7. Backlog

| ID | Item | Status |
|---|---|---|
| B-01 | Save/resume a run when the game is closed | Done (see R-09) |
| B-02 | More classes (Cleric, Barbarian, Ranger) and spells with saving throws | Done (see R-10, R-11) |
| B-03 | Inventory screen; shops between floors; scrolls and wands | Proposed |
| B-04 | Ranged and spellcasting monsters | Done (see R-12) |
| B-05 | Mini-bosses on floors 5, 10, 15 | Done (see R-13) |
| B-06 | Sound effects and haptics | Done (see R-14, R-15) |
| B-07 | Optional tileset to replace ASCII | Done (see R-16) |
| B-08 | Verify all monster stats against SRD 5.2.1 (C-06) | Planned |
| B-09 | Android export preset: AAB, API 36, signing (C-01, C-02) | Dropped (Linux only, D-14). A debug APK was built and played on Jim's phone 2026-11-19. |
| B-10 | Balance pass: playtest all 6 classes to floor 20; tune `XP_MULT` and monster counts | Proposed |
| B-11 | Package as Flatpak or AppImage for easy sharing with other Linux users | Done as R-24 (Flatpak chosen by Jim 2026-11-23) |

---

## 8. Change log

| Date | Change |
|---|---|
| 2026-11-18 | Initial build: R-01 to R-07, D-01 to D-07. |
| 2026-11-19 | R-08 Controls screen added. |
| 2026-11-19 | D-08: this file created as the source of truth. |
| 2026-11-19 | B-01 built as R-09: autosave every turn, Continue on title, save deleted on death/victory. |
| 2026-11-19 | B-02 built as R-10/R-11: Cleric, Barbarian, Ranger; spell menu with saving-throw spells, conditions, Concentration. Save format v2 (older saves are discarded). |
| 2026-11-19 | B-04/B-05 built as R-12/R-13: archers, spellcasting monsters (hero saving throws, Poisoned), mini-bosses on 5/10/15 sealing the stairs; Rogue Evasion. |
| 2026-11-19 | B-06/B-07 built as R-14 to R-17: sounds, haptics, original tileset, Settings screen; D-09, C-09 added. |
| 2026-11-19 | D-10: added `testing.html` smoke test checklist (56 steps). |
| 2026-11-19 | R-18, D-11: title screen redesign; C-04 updated (attribution moved to a Credits screen); desktop window phone-shaped. |
| 2026-11-19 | R-19: pause menu (Resume / Controls / Settings / Save & return / Save & quit), Quit on title, Esc/Back open the menu. |
| 2026-11-19 | B-09 started: export presets, launcher/store icons, `tools/android.sh`, `ANDROID.md`; D-12, D-13, C-10, C-11 added. |
| 2026-11-19 | D-13: enabled ETC2/ASTC texture import in `project.godot` (required by Godot for Android export). |
| 2026-11-19 | D-01: project marked for Godot 4.7 (`config/features`), matching Jim's editor so it stops rewriting `project.godot`. |
| 2026-11-19 | R-20: touch-first controls (D-pad, swipe, long-press inspect, Explore, map zoom, phone Controls screen). |
| 2026-11-23 | **Linux-only rebuild (D-14).** R-01, R-15, R-20, D-12, D-13, B-09 and Android/Play constraints C-01–C-03, C-07, C-09–C-11 dropped; R-21 (Linux desktop app), R-22 (desktop controls), C-12, B-11 added; D-05, R-08, R-09, R-17, R-19, C-04 updated. Android version kept on branch `android-final`. |
| 2026-11-23 | R-23, D-15: Spelunky 2-inspired cartoon art (original), 64 px atlas with per-area walls/floors, class and monster sprites, torchlight; Tiles default; D-09 updated. |
| 2026-11-23 | D-10: `testing.html` rewritten for the Linux build (85 steps, sections A–N) with a full graphics section (D–G) showing sprite thumbnails; `tools/make_tiles.py` now also writes `art/tiles_index.js`. |
| 2026-11-23 | D-10: tile index built into `testing.html` (no separate `art/tiles_index.js`); clearer warning when `art/tiles.png` can't be found. |
| 2026-11-23 | R-22: controls moved from a right-hand sidebar to a strip under the map (status · log · 3×3 buttons). |
| 2026-11-23 | R-18: title screen Controls / Settings / Credits / Quit are now a row of outlined buttons instead of small text links; 5.9 and `testing.html` B-01 updated. |
| 2026-11-23 | B-11 → R-24: Flatpak packaging (D-16, C-13); game version 0.2.0 set in `project.godot`. |
| 2026-11-23 | R-24 and B-11 → Done: first Flatpak build installs, runs and plays on Jim's machine. |
