extends Control
## Draws the dungeon centred on the hero, as ASCII glyphs or as tiles (R-16), and turns taps into grid cells.

signal cell_tapped(cell: Vector2i)
signal swiped(dir: Vector2i)          ## R-20: swipe = one step in 8 directions
signal long_pressed(cell: Vector2i)   ## R-20: long-press = inspect

const ZOOM_COLS := [19, 15, 11]       ## Settings map zoom: Small / Medium / Large
const LONG_PRESS_MS := 450

var cols := 15                         ## Squares shown across the screen. Lower = bigger squares.
var _pressing := false
var _press_pos := Vector2.ZERO
var _press_ms := 0

const ITEM_GLYPHS := {
	"potion": ["!", "ff6b8a"],
	"greater": ["!", "ff4fd8"],
	"gold": ["$", "ffd447"],
	"weapon": ["/", "7fe0ff"],
	"armor": ["[", "7fe0ff"],
}

## Atlas indexes in art/tiles.png (8 columns of 16x16). Keep in sync with tools/make_tiles.py.
const TILE_SIZE := 16
const ATLAS_COLS := 8
const TILE := {
	"floor": 0, "wall": 1, "water": 2, "lava": 3, "stairs": 4, "sealed": 5, "hero": 6, "potion": 7,
	"greater": 8, "gold": 9, "weapon": 10, "armor": 11,
	"beast": 12, "humanoid": 13, "undead": 14, "large": 15, "caster": 16, "boss": 17,
}
## Monster key -> body sprite. Anything not listed uses "humanoid".
const BODY := {
	"rat": "beast", "wolf": "beast", "spider": "beast",
	"skeleton": "undead", "zombie": "undead", "ghoul": "undead", "wight": "undead", "wraith": "undead",
	"skeleton_archer": "undead", "bone_warden": "undead",
	"ogre": "large", "minotaur": "large", "troll": "large", "giant": "large", "bugbear": "large",
	"kobold_shaman": "caster", "cult_acolyte": "caster", "dark_adept": "caster", "necromancer": "caster", "oracle": "caster",
	"hollow_king": "boss",
}

var game: Game
var use_tiles := false   ## Set from Settings (R-17)
var cell := 32.0
var origin := Vector2i.ZERO
var offset := Vector2.ZERO
var font: Font
var atlas: Texture2D


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixels
	if ResourceLoader.exists("res://art/tiles.png"):
		atlas = load("res://art/tiles.png")
	resized.connect(queue_redraw)


func _tile(name: String, pos: Vector2, mod: Color) -> void:
	var idx: int = TILE[name]
	var src := Rect2((idx % ATLAS_COLS) * TILE_SIZE, (idx / ATLAS_COLS) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	draw_texture_rect_region(atlas, Rect2(pos, Vector2(cell, cell)), src, mod)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.035))
	if game == null or game.tiles.is_empty():
		return
	cell = floorf(size.x / cols)
	if cell < 4.0:
		return
	var tiles_mode := use_tiles and atlas != null
	var rows := int(size.y / cell)
	offset = Vector2((size.x - cols * cell) / 2.0, (size.y - rows * cell) / 2.0)
	var hp: Vector2i = game.hero["pos"]
	origin = Vector2i(
		clampi(hp.x - cols / 2, 0, maxi(0, game.w - cols)),
		clampi(hp.y - rows / 2, 0, maxi(0, game.h - rows)))

	var fs := int(cell * 0.8)
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	var baseline := (cell - (asc + desc)) / 2.0 + asc
	var small_fs := maxi(8, int(cell * 0.34))
	var wall_col := Color(str(game.floor_theme["wall"]))
	var floor_col := Color(str(game.floor_theme["floor"]))
	var sealed := game.stairs_sealed()

	var mons := {}
	for m in game.monsters:
		if m["hp"] > 0:
			mons[m["pos"]] = m

	for vy in rows:
		for vx in cols:
			var p := origin + Vector2i(vx, vy)
			if p.x >= game.w or p.y >= game.h:
				continue
			var i := p.y * game.w + p.x
			var lit := game.vis[i] == 1
			if not lit and game.explored[i] == 0:
				continue
			var cell_pos := offset + Vector2(vx * cell, vy * cell)
			var dim := 1.0 if lit else 0.4
			var terrain: int = game.tiles[i]
			var mon: Dictionary = mons[p] if lit and mons.has(p) else {}

			if tiles_mode:
				_draw_tile_cell(p, cell_pos, terrain, mon, lit, dim, wall_col, floor_col, sealed, small_fs)
			else:
				_draw_ascii_cell(p, cell_pos, terrain, mon, lit, wall_col, floor_col, sealed, fs, baseline)

			if not mon.is_empty():
				# Yellow frame around the selected target.
				if game.target != null and is_same(mon, game.target):
					draw_rect(Rect2(cell_pos + Vector2(1, 1), Vector2(cell - 2, cell - 2)), Color("ffd75e"), false, 2.0)
				# Small health bar under wounded monsters.
				var frac: float = float(mon["hp"]) / float(mon["hp_max"])
				if frac < 1.0:
					var bar := Rect2(cell_pos + Vector2(cell * 0.1, cell * 0.9), Vector2(cell * 0.8, maxf(2.0, cell * 0.07)))
					draw_rect(bar, Color(0.3, 0.05, 0.05))
					bar.size.x *= clampf(frac, 0.0, 1.0)
					draw_rect(bar, Color(0.9, 0.2, 0.2))


func _monster_color(mon: Dictionary) -> Color:
	var col := Color(str(mon["color"]))
	if mon.get("restrained", false):
		col = col.lerp(Color("7fc24f"), 0.5)  # vines
	if int(mon.get("turned", 0)) > 0:
		col = col.darkened(0.45)  # fleeing
	return col


func _draw_ascii_cell(p: Vector2i, cell_pos: Vector2, terrain: int, mon: Dictionary, lit: bool,
		wall_col: Color, floor_col: Color, sealed: bool, fs: int, baseline: float) -> void:
	var ch := "."
	var col := floor_col.lightened(0.35)
	match terrain:
		DungeonGen.WALL:
			ch = "#"
			col = wall_col
		DungeonGen.WATER:
			ch = "~"
			col = Color("3f8fe0")
		DungeonGen.LAVA:
			ch = "~"
			col = Color("ff5a1f")
	if lit and terrain != DungeonGen.WALL:
		draw_rect(Rect2(cell_pos, Vector2(cell, cell)), Color(floor_col, 0.22))
	if p == game.stairs:
		ch = ">"
		col = Color("ff5a5a") if sealed else Color("ffffff")  # R-13: red = sealed
	if game.items.has(p):
		var g: Array = ITEM_GLYPHS[game.items[p]]
		ch = g[0]
		col = Color(str(g[1]))
	if not mon.is_empty():
		ch = mon["ch"]
		col = _monster_color(mon)
	if p == game.hero["pos"]:
		ch = "@"
		col = Color("ffd75e")
		if game.hero["hidden"]:
			col.a = 0.45
	if not lit:
		col = col.darkened(0.6)
	draw_string(font, cell_pos + Vector2(0, baseline), ch, HORIZONTAL_ALIGNMENT_CENTER, cell, fs, col)


func _draw_tile_cell(p: Vector2i, cell_pos: Vector2, terrain: int, mon: Dictionary, lit: bool, dim: float,
		wall_col: Color, floor_col: Color, sealed: bool, small_fs: int) -> void:
	var shade := Color(dim, dim, dim)
	# Terrain, tinted with the floor theme.
	match terrain:
		DungeonGen.WALL:
			_tile("wall", cell_pos, wall_col * shade)
		DungeonGen.WATER:
			_tile("water", cell_pos, shade)
		DungeonGen.LAVA:
			_tile("lava", cell_pos, shade)
		_:
			_tile("floor", cell_pos, floor_col.lightened(0.25) * shade)
	if p == game.stairs:
		_tile("sealed" if sealed else "stairs", cell_pos, shade)
	if game.items.has(p):
		_tile(String(game.items[p]), cell_pos, shade)
	if not mon.is_empty():
		var body: String = BODY.get(String(mon["key"]), "humanoid")
		_tile(body, cell_pos, _monster_color(mon))
		# Letter in the corner so different monsters with the same body stay identifiable.
		var letter: String = mon["ch"]
		draw_string(font, cell_pos + Vector2(1, small_fs), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color(0, 0, 0, 0.8))
		draw_string(font, cell_pos + Vector2(0, small_fs - 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color.WHITE)
	if p == game.hero["pos"]:
		_tile("hero", cell_pos, Color(1, 1, 1, 0.45 if game.hero["hidden"] else 1.0))


func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - offset
	return Vector2i(int(floorf(local.x / cell)), int(floorf(local.y / cell))) + origin


## Tap, swipe or long-press. Decided when the finger lifts.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_pressing = true
		_press_pos = mb.position
		_press_ms = Time.get_ticks_msec()
		accept_event()
		return
	if not _pressing:
		return
	_pressing = false
	accept_event()
	var delta := mb.position - _press_pos
	if delta.length() >= maxf(28.0, cell * 0.6):
		# 8-way direction from the swipe angle (0 = right, screen y points down).
		var octant := posmod(int(roundf(delta.angle() / (PI / 4.0))), 8)
		var dirs := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
			Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
		swiped.emit(dirs[octant])
	elif Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		long_pressed.emit(_cell_at(_press_pos))
	elif _press_pos.x >= offset.x and _press_pos.y >= offset.y:
		cell_tapped.emit(_cell_at(_press_pos))
