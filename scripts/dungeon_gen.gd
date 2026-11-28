class_name DungeonGen
extends RefCounted
## Procedural floor generator. Every run uses a fresh seed, so floors are never the same twice.
## Each band of floors has its own layout style and palette:
##   1-4 rooms, 5-8 warrens, 9-12 flooded caves, 13-16 pillared crypts, 17-19 lava caves, 20 throne hall.

const WALL := 0
const FLOOR := 1
const WATER := 2
const LAVA := 3

const THEMES := [
	{"name": "Sunken Cellars", "style": "rooms", "wall": "9c8b73", "floor": "5a5248", "pool": ""},
	{"name": "Goblin Warrens", "style": "warrens", "wall": "8a9a52", "floor": "4d5534", "pool": ""},
	{"name": "Flooded Caverns", "style": "caves", "wall": "6f8fae", "floor": "3c4d5e", "pool": "water"},
	{"name": "Bone Crypts", "style": "halls", "wall": "c8c2b6", "floor": "5c5852", "pool": ""},
	{"name": "Infernal Forge", "style": "caves", "wall": "b8653f", "floor": "5e3a2c", "pool": "lava"},
]
const THRONE := {"name": "Throne of the Hollow King", "style": "throne", "wall": "9d7fc9", "floor": "4a3b5e", "pool": ""}

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

var w := 60
var h := 44
var tiles := PackedByteArray()
var rng: RandomNumberGenerator


static func theme_for(n: int) -> Dictionary:
	if n >= 20:
		return THRONE
	return THEMES[clampi((n - 1) / 4, 0, THEMES.size() - 1)]


func generate(n: int, rand: RandomNumberGenerator) -> Dictionary:
	rng = rand
	var theme := theme_for(n)
	w = 50 + mini(n, 20)
	h = 36 + mini(n, 20) / 2
	tiles = PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(WALL)

	var rooms: Array = []
	var boss := Vector2i(-1, -1)
	match theme["style"]:
		"rooms":
			rooms = _rooms(7 + n % 4, 4, 9, false)
		"warrens":
			rooms = _rooms(14 + n % 4, 3, 6, false)
		"halls":
			rooms = _rooms(6 + n % 3, 7, 12, true)
		"caves":
			_caves()
		"throne":
			rooms = _throne()
			var hall: Rect2i = rooms[rooms.size() - 1]
			boss = hall.get_center()

	var start: Vector2i
	if rooms.size() > 0:
		var first: Rect2i = rooms[0]
		start = first.get_center()
	else:
		start = _random_floor()
	tiles[start.y * w + start.x] = FLOOR

	if theme["pool"] != "":
		_pools(start, LAVA if theme["pool"] == "lava" else WATER)

	var dist := _bfs(start)
	var reachable: Array = []
	var stairs := Vector2i(-1, -1)
	var far := -1
	for y in h:
		for x in w:
			var d := dist[y * w + x]
			if d >= 0:
				reachable.append(Vector2i(x, y))
				if d > far and tiles[y * w + x] == FLOOR:
					far = d
					stairs = Vector2i(x, y)
	if n >= 20:
		stairs = Vector2i(-1, -1)

	# R-27: hidden sanctuaries, carved after reachability so they stay off the normal map.
	var sanctums: Array = []
	if n < 20:
		sanctums = _sanctums(rng.randi_range(0, 3), reachable, start, stairs)

	return {"w": w, "h": h, "tiles": tiles, "start": start, "stairs": stairs, "boss": boss,
		"reachable": reachable, "dist": dist, "theme": theme, "sanctums": sanctums}


# --- Hidden sanctuaries (R-27, D-20) -----------------------------------------------

## Carves up to `count` small rooms into solid rock, each behind one secret door (left as WALL
## until found). Returns [{rect, door, fountain, kind, found, hinted, entered}].
func _sanctums(count: int, reachable: Array, start: Vector2i, stairs_pos: Vector2i) -> Array:
	var out: Array = []
	var cand: Array = reachable.duplicate()
	for _attempt in 400:
		if out.size() >= count or cand.is_empty():
			break
		var f: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
		if tiles[f.y * w + f.x] != FLOOR or f == start or f == stairs_pos:
			continue
		var dir: Vector2i = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)][rng.randi_range(0, 3)]
		var door := f + dir
		if door.x < 1 or door.y < 1 or door.x >= w - 1 or door.y >= h - 1 or tiles[door.y * w + door.x] != WALL:
			continue
		var rw := rng.randi_range(3, 4)
		var rh := rng.randi_range(3, 4)
		var r: Rect2i
		if dir.y != 0:
			var x0 := door.x - rng.randi_range(0, rw - 1)
			r = Rect2i(x0, door.y - rh if dir.y < 0 else door.y + 1, rw, rh)
		else:
			var y0 := door.y - rng.randi_range(0, rh - 1)
			r = Rect2i(door.x - rw if dir.x < 0 else door.x + 1, y0, rw, rh)
		if not _solid_block(r.grow(1), door):
			continue
		# The door must be a wall with only its outside neighbour open, so it reads as plain wall.
		var open_n := 0
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var q: Vector2i = door + d
			if tiles[q.y * w + q.x] != WALL:
				open_n += 1
		if open_n != 1:
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				tiles[y * w + x] = FLOOR
		var kinds := ["treasure", "healing", "both"]
		out.append({"rect": r, "door": door, "fountain": r.get_center(), "kind": kinds[rng.randi_range(0, 2)],
			"found": false, "hinted": false, "entered": false})
	return out


## True if every square of `r` (except `skip`) is in bounds and solid wall.
func _solid_block(r: Rect2i, skip: Vector2i) -> bool:
	if r.position.x < 1 or r.position.y < 1 or r.end.x > w - 1 or r.end.y > h - 1:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if Vector2i(x, y) != skip and tiles[y * w + x] != WALL:
				return false
	return true


# --- Room-and-corridor layouts -------------------------------------------------

func _rooms(count: int, min_s: int, max_s: int, pillars: bool, avoid: Array = []) -> Array:
	var rooms: Array = []
	var tries := 0
	while rooms.size() < count and tries < 800:
		tries += 1
		var rw := rng.randi_range(min_s, max_s)
		var rh := rng.randi_range(min_s, maxi(min_s, max_s - 2))
		var r := Rect2i(rng.randi_range(2, w - rw - 3), rng.randi_range(2, h - rh - 3), rw, rh)
		var ok := true
		for o in rooms + avoid:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)
	for r in rooms:
		_carve_room(r, pillars)
	rooms.sort_custom(func(a, b): return a.position.x < b.position.x)
	for i in range(1, rooms.size()):
		var a: Rect2i = rooms[i - 1]
		var b: Rect2i = rooms[i]
		_corridor(a.get_center(), b.get_center())
	# A couple of extra connections create loops, which make fights more tactical.
	for _i in 2:
		if rooms.size() > 3:
			var a: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
			var b: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
			_corridor(a.get_center(), b.get_center())
	return rooms


func _carve_room(r: Rect2i, pillars: bool) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var pillar := pillars and r.size.x >= 7 and r.size.y >= 7 \
				and (x - r.position.x) % 3 == 2 and (y - r.position.y) % 3 == 2 \
				and x < r.end.x - 2 and y < r.end.y - 2
			tiles[y * w + x] = WALL if pillar else FLOOR


func _corridor(a: Vector2i, b: Vector2i) -> void:
	if rng.randi_range(0, 1) == 0:
		_hline(a.x, b.x, a.y)
		_vline(a.y, b.y, b.x)
	else:
		_vline(a.y, b.y, a.x)
		_hline(a.x, b.x, b.y)


func _hline(x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		_open(x, y)


func _vline(y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		_open(x, y)


func _open(x: int, y: int) -> void:
	if x > 0 and y > 0 and x < w - 1 and y < h - 1:
		tiles[y * w + x] = FLOOR


func _throne() -> Array:
	var hall := Rect2i(w / 2 - 13, h / 2 - 7, 26, 14)
	_carve_room(hall, true)
	var side := _rooms(5, 4, 7, false, [hall])
	if side.is_empty():
		return [hall]
	var hc := hall.get_center()
	var nearest: Rect2i = side[0]
	var farthest: Rect2i = side[0]
	for item in side:
		var r: Rect2i = item
		if r.get_center().distance_to(hc) < nearest.get_center().distance_to(hc):
			nearest = r
		if r.get_center().distance_to(hc) > farthest.get_center().distance_to(hc):
			farthest = r
	_corridor(nearest.get_center(), hc)
	# Start in the side room farthest from the throne; the hall is always last.
	var out: Array = [farthest]
	for r in side:
		if r != farthest:
			out.append(r)
	out.append(hall)
	return out


# --- Cave layouts (cellular automaton) -----------------------------------------

func _caves() -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			tiles[y * w + x] = WALL if rng.randf() < 0.45 else FLOOR
	for _i in 5:
		var nxt := tiles.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var walls := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if tiles[(y + dy) * w + x + dx] == WALL:
							walls += 1
				nxt[y * w + x] = WALL if walls >= 5 else FLOOR
		tiles = nxt
	_keep_largest_region()


func _keep_largest_region() -> void:
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var best_id := -1
	var best_size := 0
	var next_id := 0
	for i in w * h:
		if tiles[i] != FLOOR or label[i] != -1:
			continue
		var region_size := 0
		var stack: Array = [i]
		label[i] = next_id
		while not stack.is_empty():
			var c: int = stack.pop_back()
			region_size += 1
			var cx := c % w
			var cy := c / w
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + d.x
				var ny: int = cy + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if tiles[ni] == FLOOR and label[ni] == -1:
					label[ni] = next_id
					stack.append(ni)
		if region_size > best_size:
			best_size = region_size
			best_id = next_id
		next_id += 1
	for i in w * h:
		if tiles[i] == FLOOR and label[i] != best_id:
			tiles[i] = WALL


func _random_floor() -> Vector2i:
	for _i in 5000:
		var p := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if tiles[p.y * w + p.x] == FLOOR:
			return p
	return Vector2i(w / 2, h / 2)


func _pools(start: Vector2i, kind: int) -> void:
	var count := rng.randi_range(4, 7)
	for _i in count:
		var c := _random_floor()
		if c.distance_to(start) < 6.0:
			continue
		var r := rng.randi_range(1, 3)
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if x < 1 or y < 1 or x >= w - 1 or y >= h - 1:
					continue
				if Vector2i(x, y).distance_to(c) <= r + 0.3 and tiles[y * w + x] == FLOOR:
					tiles[y * w + x] = kind


# --- Reachability ----------------------------------------------------------------

func _bfs(start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	dist[start.y * w + start.x] = 0
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if not _passable(n):
				continue
			if d.x != 0 and d.y != 0 and (not _passable(Vector2i(c.x + d.x, c.y)) or not _passable(Vector2i(c.x, c.y + d.y))):
				continue
			var ni := n.y * w + n.x
			if dist[ni] == -1:
				dist[ni] = dist[c.y * w + c.x] + 1
				queue.append(n)
	return dist


func _passable(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return false
	var t := tiles[p.y * w + p.x]
	return t == FLOOR or t == WATER
