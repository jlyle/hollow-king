extends Control
## Draws the dungeon centred on the hero, as ASCII glyphs or as cartoon tiles (R-16, R-23),
## and turns mouse input into grid cells.

signal cell_tapped(cell: Vector2i)       ## left-click
signal inspect_requested(cell: Vector2i) ## right-click (R-22)
signal zoom_step(delta: int)             ## mouse wheel: +1 = zoom in, -1 = zoom out (R-22)

const ZOOM_COLS := [41, 31, 23]          ## Settings map zoom: Small / Medium / Large (squares across)

var cols := 31                           ## Squares shown across the map. Lower = bigger squares.

const ITEM_GLYPHS := {
	"potion": ["!", "ff6b8a"],
	"greater": ["!", "ff4fd8"],
	"gold": ["$", "ffd447"],
	"weapon": ["/", "7fe0ff"],
	"armor": ["[", "7fe0ff"],
	"chest": ["=", "ffd447"],
}
const SANCTUM_TINT := Color(1.0, 0.82, 0.45)   ## R-27: warm glow over sanctuary floors

## Floor theme name -> tile set prefix in TileAtlas (tools/make_tiles.py).
const THEME_TILES := {
	"Sunken Cellars": "cellars", "Goblin Warrens": "warrens", "Flooded Caverns": "caverns",
	"Bone Crypts": "crypts", "Infernal Forge": "forge", "Throne of the Hollow King": "throne",
}
const LIGHT_INNER := 2.5        ## squares of full torchlight around the hero
const DARK_REMEMBERED := Color(0.03, 0.03, 0.08, 0.62)
const DARK_EDGE := Color(0.02, 0.015, 0.04)

var game: Game
var use_tiles := false   ## Set from Settings (R-17)
var cell := 32.0
var origin := Vector2i.ZERO
var offset := Vector2.ZERO
var font: Font
var atlas: Texture2D
var glow_tex: GradientTexture2D   ## warm torch glow around the hero
var _anim_accum := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth painted art (D-15)
	if ResourceLoader.exists("res://art/tiles.png"):
		atlas = load("res://art/tiles.png")
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.72, 0.38, 0.22))
	g.set_color(1, Color(1.0, 0.6, 0.3, 0.0))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	resized.connect(queue_redraw)


## Gentle idle bob in tile mode: redraw ~20 times a second.
func _process(delta: float) -> void:
	if not (use_tiles and is_visible_in_tree() and game != null):
		return
	_anim_accum += delta
	if _anim_accum >= 0.05:
		_anim_accum = 0.0
		queue_redraw()


func _tile(tname: String, pos: Vector2, mod: Color = Color.WHITE, scale: float = 1.0) -> void:
	if not TileAtlas.INDEX.has(tname):
		return
	var idx: int = TileAtlas.INDEX[tname]
	var src := Rect2((idx % TileAtlas.COLS) * TileAtlas.CELL, (idx / TileAtlas.COLS) * TileAtlas.CELL, TileAtlas.CELL, TileAtlas.CELL)
	var sz := cell * scale
	draw_texture_rect_region(atlas, Rect2(pos + Vector2((cell - sz) / 2.0, cell - sz), Vector2(sz, sz)), src, mod)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.035))
	if game == null or game.tiles.is_empty():
		return
	cell = floorf(size.x / cols)
	if cell < 4.0:
		return
	var rows := int(size.y / cell)
	offset = Vector2((size.x - cols * cell) / 2.0, (size.y - rows * cell) / 2.0)
	var hp: Vector2i = game.hero["pos"]
	origin = Vector2i(
		clampi(hp.x - cols / 2, 0, maxi(0, game.w - cols)),
		clampi(hp.y - rows / 2, 0, maxi(0, game.h - rows)))

	if use_tiles and atlas != null:
		_draw_tiles(rows)
		return

	var fs := int(cell * 0.8)
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	var baseline := (cell - (asc + desc)) / 2.0 + asc
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
			var terrain: int = game.tiles[i]
			var mon: Dictionary = mons[p] if lit and mons.has(p) else {}

			_draw_ascii_cell(p, cell_pos, terrain, mon, lit, wall_col, floor_col, sealed, fs, baseline)
			if not mon.is_empty():
				_draw_target_and_health(mon, cell_pos)


func _draw_target_and_health(mon: Dictionary, cell_pos: Vector2) -> void:
	# Yellow frame around the selected target.
	if game.target != null and is_same(mon, game.target):
		draw_rect(Rect2(cell_pos + Vector2(1, 1), Vector2(cell - 2, cell - 2)), Color("ffd75e"), false, 2.0)
	# Small health bar under wounded monsters.
	var frac: float = float(mon["hp"]) / float(mon["hp_max"])
	if frac < 1.0:
		var bar := Rect2(cell_pos + Vector2(cell * 0.1, cell * 0.92), Vector2(cell * 0.8, maxf(3.0, cell * 0.08)))
		draw_rect(bar, Color(0.15, 0.03, 0.03))
		bar.size.x *= clampf(frac, 0.0, 1.0)
		draw_rect(bar, Color(0.95, 0.25, 0.2))


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
	var sanct = game.sanctum_at(p)
	if sanct != null:
		col = SANCTUM_TINT
		if p == sanct["door"]:
			ch = "+"
			col = Color("c08850")
		elif p == sanct["fountain"]:
			ch = "{"
			col = Color("7fd8ff")
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


## Tile mode (R-23): three passes so sprites can overlap neighbouring squares.
##   1. terrain   2. shadows, items, figures, frames   3. torchlight and memory darkness
func _draw_tiles(rows: int) -> void:
	var theme: String = THEME_TILES.get(String(game.floor_theme["name"]), "cellars")
	var hp: Vector2i = game.hero["pos"]
	var sealed := game.stairs_sealed()
	var t := Time.get_ticks_msec() / 1000.0
	var mons := {}
	for m in game.monsters:
		if m["hp"] > 0:
			mons[m["pos"]] = m
	var cells: Array = []   # [p, cell_pos, lit]
	for vy in rows:
		for vx in cols:
			var p := origin + Vector2i(vx, vy)
			if p.x >= game.w or p.y >= game.h:
				continue
			var i := p.y * game.w + p.x
			var lit := game.vis[i] == 1
			if not lit and game.explored[i] == 0:
				continue
			cells.append([p, offset + Vector2(vx * cell, vy * cell), lit])

	# 1. Terrain
	for c in cells:
		var p: Vector2i = c[0]
		var pos: Vector2 = c[1]
		var v := "a" if ((p.x * 73856093) ^ (p.y * 19349663)) & 1 == 0 else "b"
		match game.tiles[p.y * game.w + p.x]:
			DungeonGen.WALL:
				var below := p + Vector2i(0, 1)
				var face := below.y < game.h and game.tiles[below.y * game.w + below.x] != DungeonGen.WALL
				_tile("%s_%s_%s" % [theme, "face" if face else "top", v], pos)
			DungeonGen.WATER:
				_tile("water", pos)
			DungeonGen.LAVA:
				_tile("lava", pos)
			_:
				_tile("%s_floor_%s" % [theme, v], pos)
		if p == game.stairs:
			_tile("sealed" if sealed else "stairs", pos)
		var sanct = game.sanctum_at(p)
		if sanct != null:
			if p == sanct["door"]:
				_tile("door", pos)
			else:
				var pulse := 0.16 + 0.06 * sin(t * 2.0 + p.x + p.y)
				draw_rect(Rect2(pos, Vector2(cell, cell)), Color(SANCTUM_TINT, pulse))
				if p == sanct["fountain"]:
					_tile("fountain", pos)

	# 2. Items, then figures (shadow first), with a gentle bob
	for c in cells:
		var p: Vector2i = c[0]
		var pos: Vector2 = c[1]
		var lit: bool = c[2]
		var bob := sin(t * 3.0 + p.x * 1.7 + p.y * 2.3) * cell * 0.025
		if game.items.has(p):
			_shadow(pos, 0.24)
			_tile(String(game.items[p]), pos + Vector2(0, bob * 0.6 - cell * 0.04), Color.WHITE, 0.8)
		if lit and mons.has(p):
			var mon: Dictionary = mons[p]
			_shadow(pos, 0.34)
			var mod := Color.WHITE
			if mon.get("restrained", false):
				mod = Color(0.7, 1.0, 0.6)
			if int(mon.get("turned", 0)) > 0:
				mod = Color(0.6, 0.6, 0.7, 0.8)
			_tile("m_" + String(mon["key"]), pos + Vector2(0, bob - cell * 0.05), mod)
			_draw_target_and_health(mon, pos)
		if p == hp:
			_shadow(pos, 0.32)
			var alpha := 0.45 if game.hero["hidden"] else 1.0
			_tile("hero_" + String(game.hero["cls"]).to_lower(), pos + Vector2(0, bob - cell * 0.05), Color(1, 1, 1, alpha))

	# 3. Lighting: darkness grows with distance from the hero; remembered squares are dim and cool.
	var sp: Dictionary = GameData.SPECIES[game.hero["species"]]
	var radius := 6.0 + (3.0 if sp["darkvision"] else 0.0)
	for c in cells:
		var p: Vector2i = c[0]
		var pos: Vector2 = c[1]
		if not c[2]:
			draw_rect(Rect2(pos, Vector2(cell, cell)), DARK_REMEMBERED)
			continue
		var d := Vector2(p - hp).length()
		var k := clampf((d - LIGHT_INNER) / maxf(1.0, radius - LIGHT_INNER), 0.0, 1.0)
		if k > 0.0:
			draw_rect(Rect2(pos, Vector2(cell, cell)), Color(DARK_EDGE, 0.7 * pow(k, 1.3)))
	var centre := offset + (Vector2(hp - origin) + Vector2(0.5, 0.5)) * cell
	var glow_r := cell * (LIGHT_INNER + 2.0)
	draw_texture_rect(glow_tex, Rect2(centre - Vector2(glow_r, glow_r), Vector2(glow_r, glow_r) * 2.0), false)


## Soft oval shadow under an item or figure.
func _shadow(pos: Vector2, width: float) -> void:
	draw_set_transform(pos + Vector2(cell * 0.5, cell * 0.9), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, cell * width, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - offset
	return Vector2i(int(floorf(local.x / cell)), int(floorf(local.y / cell))) + origin


## Left-click = move/attack/travel, right-click = inspect, wheel = zoom (R-22).
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if mb.position.x >= offset.x and mb.position.y >= offset.y:
				cell_tapped.emit(_cell_at(mb.position))
		MOUSE_BUTTON_RIGHT:
			inspect_requested.emit(_cell_at(mb.position))
		MOUSE_BUTTON_WHEEL_UP:
			zoom_step.emit(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step.emit(-1)
		_:
			return
	accept_event()
