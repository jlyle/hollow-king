extends Control
## Draws the dungeon as ASCII glyphs centred on the hero and turns taps into grid cells.

signal cell_tapped(cell: Vector2i)

const COLS := 19   ## Squares shown across the screen. Lower = bigger glyphs.

const ITEM_GLYPHS := {
	"potion": ["!", "ff6b8a"],
	"greater": ["!", "ff4fd8"],
	"gold": ["$", "ffd447"],
	"weapon": ["/", "7fe0ff"],
	"armor": ["[", "7fe0ff"],
}

var game: Game
var cell := 32.0
var origin := Vector2i.ZERO
var offset := Vector2.ZERO
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.035))
	if game == null or game.tiles.is_empty():
		return
	cell = floorf(size.x / COLS)
	if cell < 4.0:
		return
	var rows := int(size.y / cell)
	offset = Vector2((size.x - COLS * cell) / 2.0, (size.y - rows * cell) / 2.0)
	var hp: Vector2i = game.hero["pos"]
	origin = Vector2i(
		clampi(hp.x - COLS / 2, 0, maxi(0, game.w - COLS)),
		clampi(hp.y - rows / 2, 0, maxi(0, game.h - rows)))

	var fs := int(cell * 0.8)
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	var baseline := (cell - (asc + desc)) / 2.0 + asc
	var wall_col := Color(str(game.floor_theme["wall"]))
	var floor_col := Color(str(game.floor_theme["floor"]))

	var mons := {}
	for m in game.monsters:
		if m["hp"] > 0:
			mons[m["pos"]] = m

	for vy in rows:
		for vx in COLS:
			var p := origin + Vector2i(vx, vy)
			if p.x >= game.w or p.y >= game.h:
				continue
			var i := p.y * game.w + p.x
			var lit := game.vis[i] == 1
			if not lit and game.explored[i] == 0:
				continue
			var cell_pos := offset + Vector2(vx * cell, vy * cell)
			var ch := "."
			var col := floor_col.lightened(0.35)
			match game.tiles[i]:
				DungeonGen.WALL:
					ch = "#"
					col = wall_col
				DungeonGen.WATER:
					ch = "~"
					col = Color("3f8fe0")
				DungeonGen.LAVA:
					ch = "~"
					col = Color("ff5a1f")
			if lit and game.tiles[i] != DungeonGen.WALL:
				draw_rect(Rect2(cell_pos, Vector2(cell, cell)), Color(floor_col, 0.22))
			if p == game.stairs:
				ch = ">"
				col = Color("ffffff")
			if game.items.has(p):
				var g: Array = ITEM_GLYPHS[game.items[p]]
				ch = g[0]
				col = Color(str(g[1]))
			if lit and mons.has(p):
				var m: Dictionary = mons[p]
				ch = m["ch"]
				col = Color(str(m["color"]))
			if p == hp:
				ch = "@"
				col = Color("ffd75e")
				if game.hero["hidden"]:
					col.a = 0.45
			if not lit:
				col = col.darkened(0.6)
			draw_string(font, cell_pos + Vector2(0, baseline), ch, HORIZONTAL_ALIGNMENT_CENTER, cell, fs, col)

			# Small health bar under wounded, visible monsters.
			if lit and mons.has(p) and p != hp:
				var mm: Dictionary = mons[p]
				var frac: float = float(mm["hp"]) / float(mm["hp_max"])
				if frac < 1.0:
					var bar := Rect2(cell_pos + Vector2(cell * 0.1, cell * 0.9), Vector2(cell * 0.8, maxf(2.0, cell * 0.07)))
					draw_rect(bar, Color(0.3, 0.05, 0.05))
					bar.size.x *= clampf(frac, 0.0, 1.0)
					draw_rect(bar, Color(0.9, 0.2, 0.2))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = mb.position - offset
		if local.x < 0.0 or local.y < 0.0:
			return
		var c := Vector2i(int(local.x / cell), int(local.y / cell)) + origin
		cell_tapped.emit(c)
		accept_event()
