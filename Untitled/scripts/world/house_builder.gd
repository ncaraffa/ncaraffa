class_name HouseBuilder
extends RefCounted
## Builds the player's single-storey house (local metres, floor at y = 0,
## front of the house facing local +Z).
##
##   x:  0 ........ 4.2 ... 5.6 ... 7.6 ........ 11 ........ 16 ...... 22.5
##   z 0  BEDROOM 1 | BATH          | DINING     | KITCHEN    |
##        (start)   |---------------|            |            |  GARAGE
##   2.8            |HALL | LAUNDRY |            |            | (2..11)
##   5    ----------|     |---------|-----------------------  |
##        BEDROOM 2 |     | CLOSET  |       LIVING ROOM       |
##   8.2            |---- FOYER ----|                         |
##   11   ------------- front door -------------------------------------

const H := 2.6          # ceiling height
const EXT := 0.24       # exterior wall thickness
const INT := 0.12       # interior wall thickness

var house: House
var interior: Node3D
var structure: Node3D


func build(parent: Node3D, origin: Vector3, rot_y := 0.0) -> House:
	house = House.new()
	house.name = "PlayerHouse"
	parent.add_child(house)
	house.position = origin
	house.rotation_degrees.y = rot_y
	WorldState.register("house", house)
	structure = B.node(house, "Structure")
	interior = B.node(house, "Interior")
	_floors_and_ceiling()
	_walls()
	_doors()
	_windows()
	_exterior()
	_lights_and_switches()
	_bedroom1()
	_bedroom2()
	_hall_bath_laundry()
	_foyer()
	_living()
	_dining()
	_kitchen()
	_garage()
	_points()
	_acoustics()
	return house


# ================================================================== walls
## Wall along local X (axis "x", at z = c) or along Z (axis "z", at x = c).
## neg/pos: material spans for each face: [[from, to, material_key], ...].
## openings: [{c, w, b, t}] (centre along the wall, width, bottom, top).
func wall(axis: String, c: float, u0: float, u1: float, neg: Array, pos: Array, openings: Array = [],
		thick := INT, y0 := 0.0, y1 := H, neg_inside := true, pos_inside := true) -> void:
	var cuts := [u0, u1]
	for o in openings:
		cuts.append(o.c - o.w / 2.0)
		cuts.append(o.c + o.w / 2.0)
	for s in neg + pos:
		cuts.append(s[0])
		cuts.append(s[1])
	var clean := []
	for v in cuts:
		var cv: float = clamp(v, u0, u1)
		var dup := false
		for e in clean:
			if absf(e - cv) < 0.001:
				dup = true
		if not dup:
			clean.append(cv)
	clean.sort()
	for i in clean.size() - 1:
		var a: float = clean[i]
		var b: float = clean[i + 1]
		if b - a < 0.002:
			continue
		var mid := (a + b) / 2.0
		var op = null
		for o in openings:
			if mid > o.c - o.w / 2.0 and mid < o.c + o.w / 2.0:
				op = o
		var pieces := []
		if op != null:
			if op.b > y0 + 0.001:
				pieces.append([y0, float(op.b)])
			if op.t < y1 - 0.001:
				pieces.append([float(op.t), y1])
		else:
			pieces.append([y0, y1])
		for p in pieces:
			var length := b - a
			var h: float = p[1] - p[0]
			var cy: float = (p[0] + p[1]) / 2.0
			if axis == "x":
				B.collider(structure, Vector3(length, h, thick), Vector3(mid, cy, c), Vector3.ZERO, "wood")
			else:
				B.collider(structure, Vector3(thick, h, length), Vector3(c, cy, mid), Vector3.ZERO, "wood")
			for side: float in [-1.0, 1.0]:
				var spans: Array = neg if side < 0 else pos
				var key := _span(spans, mid)
				if key == "":
					continue
				var m := Mats.m(key)
				var off: float = side * thick / 4.0
				if axis == "x":
					B.box(structure, Vector3(length, h, thick / 2.0), Vector3(mid, cy, c + off), m)
				else:
					B.box(structure, Vector3(thick / 2.0, h, length), Vector3(c + off, cy, mid), m)
				var inside := neg_inside if side < 0 else pos_inside
				if inside and absf(p[0] - y0) < 0.001 and y0 >= -0.01:
					# baseboard
					var bo: float = side * (thick / 2.0 + 0.008)
					if axis == "x":
						B.box(structure, Vector3(length, 0.09, 0.016), Vector3(mid, 0.045, c + bo), Mats.m("trim"))
					else:
						B.box(structure, Vector3(0.016, 0.09, length), Vector3(c + bo, 0.045, mid), Mats.m("trim"))
	# jambs: line the sides and head of door openings (no more raw wall edges)
	for o in openings:
		if o.b > 0.05 or o.w > 2.0:
			continue
		var jt := thick + 0.01
		var hw2: float = o.w / 2.0
		var jy: float = (o.t + max(o.b, 0.0)) / 2.0
		var jh: float = o.t - max(o.b, 0.0)
		if axis == "x":
			B.box(structure, Vector3(0.025, jh, jt), Vector3(o.c - hw2 + 0.0125, jy, c), Mats.m("trim"))
			B.box(structure, Vector3(0.025, jh, jt), Vector3(o.c + hw2 - 0.0125, jy, c), Mats.m("trim"))
			B.box(structure, Vector3(o.w, 0.025, jt), Vector3(o.c, o.t - 0.0125, c), Mats.m("trim"))
		else:
			B.box(structure, Vector3(jt, jh, 0.025), Vector3(c, jy, o.c - hw2 + 0.0125), Mats.m("trim"))
			B.box(structure, Vector3(jt, jh, 0.025), Vector3(c, jy, o.c + hw2 - 0.0125), Mats.m("trim"))
			B.box(structure, Vector3(jt, 0.025, o.w), Vector3(c, o.t - 0.0125, o.c), Mats.m("trim"))
	# casing trim around door openings on interior faces
	for o in openings:
		if o.b > 0.05:
			continue
		for side: float in [-1.0, 1.0]:
			var inside := neg_inside if side < 0 else pos_inside
			if not inside:
				continue
			var off: float = side * (thick / 2.0 + 0.01)
			var hw: float = o.w / 2.0
			if axis == "x":
				B.box(structure, Vector3(0.07, o.t, 0.02), Vector3(o.c - hw - 0.035, o.t / 2.0, c + off), Mats.m("trim"))
				B.box(structure, Vector3(0.07, o.t, 0.02), Vector3(o.c + hw + 0.035, o.t / 2.0, c + off), Mats.m("trim"))
				B.box(structure, Vector3(o.w + 0.14, 0.07, 0.02), Vector3(o.c, o.t + 0.035, c + off), Mats.m("trim"))
			else:
				B.box(structure, Vector3(0.02, o.t, 0.07), Vector3(c + off, o.t / 2.0, o.c - hw - 0.035), Mats.m("trim"))
				B.box(structure, Vector3(0.02, o.t, 0.07), Vector3(c + off, o.t / 2.0, o.c + hw + 0.035), Mats.m("trim"))
				B.box(structure, Vector3(0.02, 0.07, o.w + 0.14), Vector3(c + off, o.t + 0.035, o.c), Mats.m("trim"))


func _span(spans: Array, u: float) -> String:
	for s in spans:
		if u >= s[0] - 0.0001 and u <= s[1] + 0.0001:
			return s[2]
	return ""


func op(c: float, w: float, b := 0.0, t := 2.05) -> Dictionary:
	return {"c": c, "w": w, "b": b, "t": t}


func win(c: float, w: float, b := 0.9, t := 2.1) -> Dictionary:
	return {"c": c, "w": w, "b": b, "t": t}


func _walls() -> void:
	var SID := "siding_white"
	var X0 := -0.12
	# exterior
	wall("x", 0.0, X0, 16.12, [[X0, 16.12, SID]],
		[[X0, 4.2, "wallpaper"], [4.2, 7.6, "tile_bath"], [7.6, 11.0, "wallpaper_stripe"], [11.0, 16.12, "paint_yellow"]],
		[win(2.1, 1.1), win(6.4, 0.6, 1.5, 2.05), win(9.3, 1.4), win(12.0, 1.0, 1.05, 2.05), op(13.6, 0.9, 0.0, 2.1)],
		EXT, 0.0, H, false, true)
	wall("x", 11.0, X0, 16.12,
		[[X0, 4.2, "paint_blue"], [4.2, 7.6, "paint_cream"], [7.6, 16.12, "paint_cream"]], [[X0, 16.12, SID]],
		[win(2.1, 1.2), op(5.9, 0.95, 0.0, 2.12), win(9.9, 1.5), win(13.6, 1.5)],
		EXT, 0.0, H, true, false)
	wall("z", 0.0, X0, 11.12, [[X0, 11.12, SID]], [[X0, 5.0, "wallpaper"], [5.0, 11.12, "paint_blue"]],
		[win(1.4, 1.0), win(8.6, 1.0)], EXT, 0.0, H, false, true)
	wall("z", 16.0, X0, 11.12, [[X0, 6.2, "paint_yellow"], [6.2, 11.12, "paint_cream"]],
		[[X0, 2.0, SID], [2.0, 11.12, "paint_garage"]], [op(4.8, 0.85)], EXT, 0.0, H, true, true)
	# garage shell (floor at -0.3)
	wall("x", 2.0, 16.12, 22.6, [[16.0, 22.6, SID]], [[16.0, 22.6, "paint_garage"]], [win(20.5, 0.8, 1.2, 1.9)], 0.2, -0.3, H, false, true)
	wall("z", 22.5, 1.9, 11.1, [[1.9, 11.1, "paint_garage"]], [[1.9, 11.1, SID]], [win(6.5, 0.8, 1.2, 1.9)], 0.2, -0.3, H, true, false)
	wall("x", 11.0, 16.12, 22.6, [[16.0, 22.6, "paint_garage"]], [[16.0, 22.6, SID]], [op(19.25, 5.3, -0.3, 2.1)], 0.2, -0.3, H, true, false)
	# interior
	wall("z", 4.2, 0.0, 11.0, [[0.0, 5.0, "wallpaper"], [5.0, 11.0, "paint_blue"]],
		[[0.0, 2.8, "tile_bath"], [2.8, 8.2, "paint_cream"], [8.2, 11.0, "paint_cream"]], [op(4.2, 0.9), op(6.0, 0.9)])
	wall("x", 5.0, 0.0, 4.2, [[0.0, 4.2, "wallpaper"]], [[0.0, 4.2, "paint_blue"]])
	wall("x", 2.8, 4.2, 7.6, [[4.2, 7.6, "tile_bath"]], [[4.2, 5.6, "paint_cream"], [5.6, 7.6, "paint_white"]], [op(4.9, 0.8)])
	wall("z", 5.6, 2.8, 8.2, [[2.8, 8.2, "paint_cream"]], [[2.8, 8.2, "paint_white"]], [op(4.2, 0.8), op(7.0, 0.8)])
	wall("x", 5.6, 5.6, 7.6, [[5.6, 7.6, "paint_white"]], [[5.6, 7.6, "paint_white"]])
	wall("x", 8.2, 5.6, 7.6, [[5.6, 7.6, "paint_white"]], [[5.6, 7.6, "paint_cream"]])
	wall("z", 7.6, 0.0, 11.0, [[0.0, 2.8, "tile_bath"], [2.8, 8.2, "paint_white"], [8.2, 11.0, "paint_cream"]],
		[[0.0, 6.2, "wallpaper_stripe"], [6.2, 11.0, "paint_cream"]], [op(9.5, 1.8, 0.0, 2.2)])
	wall("x", 6.2, 7.6, 16.0, [[7.6, 11.0, "wallpaper_stripe"], [11.0, 16.0, "paint_yellow"]], [[7.6, 16.0, "paint_cream"]],
		[op(9.4, 2.4, 0.0, 2.2), op(12.6, 1.0, 0.0, 2.1)])
	wall("z", 11.0, 0.0, 6.2, [[0.0, 6.2, "wallpaper_stripe"]], [[0.0, 6.2, "paint_yellow"]], [op(3.1, 3.0, 0.0, 2.2)])


func _floors_and_ceiling() -> void:
	# foundation (under the floor) and the floor finishes per room
	B.box(structure, Vector3(16.3, 0.3, 11.3), Vector3(8.0, -0.17, 5.5), Mats.m("concrete"), true, Vector3.ZERO, "wood")
	var rooms := [
		[0.0, 4.2, 0.0, 5.0, "wood_floor", "wood"],
		[0.0, 4.2, 5.0, 11.0, "carpet", "carpet"],
		[4.2, 7.6, 0.0, 2.8, "tile_bath", "tile"],
		[4.2, 5.6, 2.8, 8.2, "wood_floor", "wood"],
		[5.6, 7.6, 2.8, 5.6, "tile_kitchen", "tile"],
		[5.6, 7.6, 5.6, 8.2, "wood_floor", "wood"],
		[4.2, 7.6, 8.2, 11.0, "tile_kitchen", "tile"],
		[7.6, 16.0, 6.2, 11.0, "wood_floor", "wood"],
		[7.6, 11.0, 0.0, 6.2, "wood_floor", "wood"],
		[11.0, 16.0, 0.0, 6.2, "tile_kitchen", "tile"],
	]
	for r in rooms:
		var size := Vector3(r[1] - r[0], 0.02, r[3] - r[2])
		B.box(structure, size, Vector3((r[0] + r[1]) / 2.0, -0.01, (r[2] + r[3]) / 2.0), Mats.m(r[4]), true, Vector3.ZERO, r[5])
	# thresholds under doorways get the floor of the side they open onto
	B.box(structure, Vector3(0.95, 0.02, 0.3), Vector3(5.9, -0.01, 11.0), Mats.m("wood_dark"), true, Vector3.ZERO, "wood")
	B.box(structure, Vector3(0.9, 0.02, 0.3), Vector3(13.6, -0.01, 0.0), Mats.m("wood_dark"), true, Vector3.ZERO, "wood")
	B.box(structure, Vector3(0.3, 0.02, 0.85), Vector3(16.0, -0.01, 4.8), Mats.m("wood_dark"), true, Vector3.ZERO, "wood")
	# garage slab
	B.box(structure, Vector3(6.4, 0.3, 9.0), Vector3(19.3, -0.45, 6.5), Mats.m("concrete_dark"), true, Vector3.ZERO, "concrete")
	B.box(structure, Vector3(0.7, 0.3, 1.2), Vector3(16.45, -0.15, 4.8), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	B.box(structure, Vector3(0.4, 0.15, 1.2), Vector3(17.0, -0.245, 4.8), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	# ceilings
	B.box(structure, Vector3(16.24, 0.1, 11.24), Vector3(8.0, H + 0.05, 5.5), Mats.m("ceiling"))
	B.box(structure, Vector3(6.6, 0.1, 9.2), Vector3(19.3, H + 0.05, 6.5), Mats.m("ceiling"))
	# crown trim in the main rooms for a lived-in look
	for seg in [[7.6, 16.0, 10.87, "x"], [7.6, 16.0, 6.27, "x"], [0.12, 4.14, 0.13, "x"], [0.12, 4.14, 4.93, "x"]]:
		B.box(structure, Vector3(seg[1] - seg[0], 0.06, 0.03), Vector3((seg[0] + seg[1]) / 2.0, H - 0.03, seg[2]), Mats.m("trim"))


# ================================================================== doors
## axis/c: wall; u0..u1 opening; hinge_low: hinge at u0; into_pos: swings to the + side.
func door(id: String, axis: String, c: float, center: float, w: float, h: float, hinge_low: bool, into_pos: bool,
		start_open := false, mat_key := "door_white", thick := 0.045) -> Door:
	var d := Door.new()
	d.name = "Door_" + id
	interior.add_child(d)
	var u := center - w / 2.0 if hinge_low else center + w / 2.0
	var sgn := 1.0 if hinge_low else -1.0
	if axis == "x":
		d.position = Vector3(u, 0.0, c)
		d.rotation_degrees.y = 0.0 if hinge_low else 180.0
		sgn *= (-1.0 if into_pos else 1.0)
	else:
		d.position = Vector3(c, 0.0, u)
		d.rotation_degrees.y = -90.0 if hinge_low else 90.0
		sgn *= (1.0 if into_pos else -1.0)
	d.setup(id, w, h, thick, Mats.m(mat_key), sgn, start_open)
	return d


func _doors() -> void:
	door("door_b1", "z", 4.2, 4.2, 0.88, 2.04, false, false, false)
	door("door_b2", "z", 4.2, 6.0, 0.88, 2.04, true, false, true)
	door("door_bath", "x", 2.8, 4.9, 0.78, 2.04, true, false, true)
	door("door_laundry", "z", 5.6, 4.2, 0.78, 2.04, true, true, false)
	door("door_closet", "z", 5.6, 7.0, 0.78, 2.04, false, true, false)
	var front := door("door_front", "x", 11.0, 5.9, 0.93, 2.1, true, false, false, "wood_dark", 0.05)
	front.sound_close = "door_close"
	front.volume_db = 1.0
	var back := door("door_back", "x", 0.0, 13.6, 0.88, 2.08, false, true, false, "door_white", 0.05)
	# deadbolts (inside faces only). Front: hinge-low node, inside = -Z local.
	# Back: hinge-high node (rotated 180), inside (kitchen, +Z world) = -Z local.
	_deadbolt(front, -1.0)
	_deadbolt(back, -1.0)
	door("door_garage", "z", 16.0, 4.8, 0.83, 2.03, false, false, false)


func _deadbolt(d: Door, inside_sign: float) -> void:
	d.inside_sign = inside_sign
	var db := Deadbolt.new()
	db.name = "Deadbolt"
	d.body.add_child(db)
	db.position = Vector3(d.width - 0.08, 1.15, 0)
	db.setup(d, 0.05)


# ================================================================== windows
func window(axis: String, c: float, center: float, w: float, b: float, t: float, thick := EXT, shutters := false, lower_glass := true) -> void:
	var h := t - b
	var cy := (b + t) / 2.0
	var root := B.node(structure, "Window")
	if axis == "x":
		root.position = Vector3(center, cy, c)
	else:
		root.position = Vector3(c, cy, center)
		root.rotation_degrees.y = 90.0
	var trim := Mats.m("trim")
	var fw := 0.05
	B.box(root, Vector3(w, fw, thick + 0.02), Vector3(0, h / 2 - fw / 2, 0), trim)
	B.box(root, Vector3(w, fw, thick + 0.02), Vector3(0, -h / 2 + fw / 2, 0), trim)
	B.box(root, Vector3(fw, h, thick + 0.02), Vector3(-w / 2 + fw / 2, 0, 0), trim)
	B.box(root, Vector3(fw, h, thick + 0.02), Vector3(w / 2 - fw / 2, 0, 0), trim)
	# sash: two panes, middle rail, muntins
	B.box(root, Vector3(w - fw * 2, 0.04, 0.05), Vector3(0, 0, 0), trim)
	B.box(root, Vector3(0.025, h - fw * 2, 0.03), Vector3(0, 0, 0.0), trim)
	if lower_glass:
		B.box(root, Vector3(w - fw * 2, h - fw * 2, 0.006), Vector3(0, 0, 0), Mats.glass())
	else:
		# the lower pane belongs to a sliding sash (WindowSash)
		B.box(root, Vector3(w - fw * 2, h / 2.0 - fw, 0.006), Vector3(0, h / 4.0, 0), Mats.glass())
	B.collider(root, Vector3(w, h, 0.06), Vector3.ZERO)
	# sills
	B.box(root, Vector3(w + 0.12, 0.035, 0.14), Vector3(0, -h / 2 - 0.017, thick / 2 + 0.03), trim)
	B.box(root, Vector3(w + 0.12, 0.035, 0.1), Vector3(0, -h / 2 - 0.017, -thick / 2 - 0.02), trim)
	if shutters:
		var sm := Mats.color(Color(0.16, 0.22, 0.2), 0.7)
		for s: float in [-1.0, 1.0]:
			B.box(root, Vector3(w * 0.42, h + 0.08, 0.03), Vector3(s * (w / 2 + w * 0.21 + 0.04), 0, thick / 2 + 0.03), sm)


func _sash(id: String, center: Vector3, rot_y: float, w: float, h: float) -> void:
	var ws := WindowSash.new()
	ws.name = "Sash_" + id
	interior.add_child(ws)
	ws.position = center + Vector3(0, 0, 0.0)
	ws.rotation_degrees.y = rot_y
	ws.setup(id, w - 0.1, h - 0.1)


func _windows() -> void:
	window("x", 0.0, 2.1, 1.1, 0.9, 2.1)
	window("x", 0.0, 6.4, 0.6, 1.5, 2.05)
	window("x", 0.0, 9.3, 1.4, 0.9, 2.1)
	window("x", 0.0, 12.0, 1.0, 1.05, 2.05, EXT, false, false)
	window("x", 11.0, 2.1, 1.2, 0.9, 2.1, EXT, true, false)
	window("x", 11.0, 9.9, 1.5, 0.9, 2.1, EXT, true, false)
	window("x", 11.0, 13.6, 1.5, 0.9, 2.1, EXT, true)
	window("z", 0.0, 1.4, 1.0, 0.9, 2.1)
	window("z", 0.0, 8.6, 1.0, 0.9, 2.1)
	window("x", 2.0, 20.5, 0.8, 1.2, 1.9, 0.2)
	window("z", 22.5, 6.5, 0.8, 1.2, 1.9, 0.2)
	_sash("win_kitchen", Vector3(12.0, 1.55, 0.0), 0.0, 1.0, 1.0)
	_sash("win_living", Vector3(9.9, 1.5, 11.0), 180.0, 1.5, 1.2)
	_sash("win_b2", Vector3(2.1, 1.5, 11.0), 180.0, 1.2, 1.2)
	# front door has a small glass light above it (transom)
	B.box(structure, Vector3(0.93, 0.02, 0.26), Vector3(5.9, 2.13, 11.0), Mats.m("trim"))


# ================================================================== exterior
func _exterior() -> void:
	var ext := B.node(house, "Exterior")
	var sh := Mats.m("shingles")
	var sid := Mats.m("siding_white")
	B.roof(ext, -0.12, 16.12, -0.12, 11.12, H + 0.1, 2.3, sh, sid, true, 0.5)
	B.roof(ext, 16.0, 22.6, 1.9, 11.1, H + 0.1, 1.5, sh, sid, false, 0.4)
	# fascia boards along the eaves
	for z: float in [-0.6, 11.6]:
		B.box(ext, Vector3(17.0, 0.16, 0.04), Vector3(8.0, H - 0.1, z), Mats.m("trim"))
	# exterior foundation strip (visible concrete under the siding)
	B.box(ext, Vector3(16.36, 0.32, 0.02), Vector3(8.0, -0.15, 11.13), Mats.m("concrete"))
	B.box(ext, Vector3(16.36, 0.32, 0.02), Vector3(8.0, -0.15, -0.13), Mats.m("concrete"))
	B.box(ext, Vector3(0.02, 0.32, 11.3), Vector3(-0.13, -0.15, 5.5), Mats.m("concrete"))
	# corner boards
	for p: Vector3 in [Vector3(-0.13, 1.3, -0.13), Vector3(-0.13, 1.3, 11.13), Vector3(16.13, 1.3, -0.13)]:
		B.box(ext, Vector3(0.1, H + 0.1, 0.1), p, Mats.m("trim"))
	# front porch: slab, posts, small roof
	# Landings are flush with the interior floor; the step down is at the outer
	# edge, never under the door, so nobody trips on the threshold + jamb at once.
	B.box(ext, Vector3(3.2, 0.3, 1.7), Vector3(5.9, -0.15, 11.95), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	B.box(ext, Vector3(3.8, 0.14, 2.1), Vector3(5.9, -0.23, 12.0), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	for x: float in [4.45, 7.35]:
		B.box(ext, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.1, 12.7), Mats.m("trim"), true)
	B.box(ext, Vector3(3.4, 0.12, 1.9), Vector3(5.9, 2.45, 11.95), Mats.m("trim"))
	B.box(ext, Vector3(3.5, 0.06, 2.0), Vector3(5.9, 2.53, 11.95), sh)
	# doormat
	B.box(ext, Vector3(0.9, 0.012, 0.55), Vector3(5.9, 0.006, 11.5), Mats.color(Color(0.3, 0.24, 0.16), 1.0))
	# house number
	B.label(ext, "14", Vector3(7.0, 1.75, 11.135), 0.006, Color(0.12, 0.1, 0.08), Vector3.ZERO, 48)
	# back patio
	B.box(ext, Vector3(4.8, 0.3, 2.6), Vector3(13.8, -0.15, -1.42), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	B.box(ext, Vector3(5.6, 0.14, 3.0), Vector3(13.8, -0.23, -1.62), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	B.box(ext, Vector3(0.9, 0.012, 0.5), Vector3(13.6, 0.006, -0.45), Mats.color(Color(0.25, 0.22, 0.18), 1.0))
	# garage apron
	B.box(ext, Vector3(5.6, 0.04, 0.8), Vector3(19.25, -0.28, 11.4), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	# garage side light
	B.box(ext, Vector3(0.12, 0.2, 0.08), Vector3(16.35, 2.2, 11.13), Mats.m("metal_dark"))
	# gutters + downspouts
	var gut := Mats.color(Color(0.8, 0.8, 0.76), 0.5)
	for z: float in [-0.67, 11.67]:
		B.box(ext, Vector3(17.0, 0.1, 0.1), Vector3(8.0, H - 0.12, z), gut)
	for p: Vector3 in [Vector3(-0.45, 1.1, 11.67), Vector3(16.4, 1.1, -0.67), Vector3(-0.45, 1.1, -0.67)]:
		B.box(ext, Vector3(0.07, 2.6, 0.07), p, gut)
	# AC unit by the garage
	var ac := B.node(ext, "AC", Vector3(22.95, -0.3, 4.0))
	B.box(ac, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), Mats.color(Color(0.7, 0.7, 0.66), 0.5), true)
	B.cyl(ac, 0.28, 0.28, 0.02, Vector3(0, 0.71, 0), Mats.m("metal_dark"), false, Vector3.ZERO, 20)


# ================================================================== lights
func _switch(id: String, pos: Vector3, rot_y: float, targets: PackedStringArray) -> LightSwitch:
	var s := LightSwitch.new()
	s.name = "Switch_" + id
	interior.add_child(s)
	s.position = pos
	s.rotation_degrees.y = rot_y
	s.setup(id, targets)
	return s


func _lights_and_switches() -> void:
	var L := interior
	Props.ceiling_light(L, Vector3(2.1, H, 2.5), "b1_ceiling", false, 1.5, 6.5, true)
	Props.ceiling_light(L, Vector3(2.1, H, 8.0), "b2_ceiling", false, 1.5, 6.5, true)
	Props.ceiling_light(L, Vector3(4.9, H, 5.2), "hall_ceiling", true, 1.25, 6.5, true)
	Props.ceiling_light(L, Vector3(4.9, H, 7.5), "hall_ceiling_b", false, 0.6, 4.0, false)
	Props.ceiling_light(L, Vector3(5.9, H, 1.4), "bath_ceiling", false, 1.3, 5.0, false)
	Props.wall_sconce(L, Vector3(7.52, 2.1, 1.9), -90, "bath_vanity", false, 0.7)
	Props.ceiling_light(L, Vector3(6.6, H, 4.2), "laundry_bulb", false, 1.1, 4.5, false, 1)
	Props.ceiling_light(L, Vector3(6.6, H, 6.9), "closet_bulb", false, 0.8, 3.5, false, 1)
	Props.ceiling_light(L, Vector3(5.9, H, 9.6), "foyer_ceiling", false, 1.2, 5.5, true)
	Props.ceiling_light(L, Vector3(11.8, H, 8.6), "living_ceiling", false, 1.8, 8.0, true)
	Props.ceiling_light(L, Vector3(9.3, H, 3.1), "dining_chandelier", false, 1.4, 6.5, true, 2)
	Props.ceiling_light(L, Vector3(13.5, H, 3.0), "kitchen_ceiling", false, 1.8, 7.0, true)
	Props.wall_sconce(L, Vector3(12.0, 2.25, 0.13), 0, "kitchen_sink", true, 1.0)
	Props.ceiling_light(L, Vector3(19.3, H, 6.5), "garage_tube", false, 2.0, 8.0, true, 3)
	Props.wall_sconce(L, Vector3(6.75, 1.95, 11.13), 0, "porch_front", true, 1.0, true, Color(1.0, 0.8, 0.55))
	Props.wall_sconce(L, Vector3(14.45, 1.95, -0.13), 180, "porch_back", true, 1.0, true, Color(1.0, 0.78, 0.52))
	Props.wall_sconce(L, Vector3(16.35, 2.2, 11.13), 0, "garage_flood", false, 1.2, false, Color(0.95, 0.9, 0.8))
	# backyard flood light under the eave: the yard is never pitch black
	var yf := LightFixture.new()
	yf.name = "YardFlood"
	L.add_child(yf)
	yf.position = Vector3(8.0, 2.35, -0.2)
	B.box(yf, Vector3(0.22, 0.14, 0.12), Vector3(0, 0, -0.06), Mats.m("metal_dark"))
	var yg := B.box(yf, Vector3(0.18, 0.1, 0.01), Vector3(0, -0.01, -0.125), Mats.m("plastic_white"))
	yf.add_glow(yg)
	yf.add_light(B.spot(yf, Vector3(0, -0.05, -0.2), Vector3(-28, 180, 0), Color(0.95, 0.9, 0.78), 2.2, 26.0, 58.0, true))
	yf.setup("yard_flood", true, Color(0.95, 0.9, 0.78), 3.0)

	_switch("sw_b1", Vector3(4.135, 1.2, 3.5), -90, ["b1_ceiling"])
	_switch("sw_b2", Vector3(4.135, 1.2, 6.7), -90, ["b2_ceiling"])
	_switch("sw_hall", Vector3(4.265, 1.2, 7.6), 90, ["hall_ceiling", "hall_ceiling_b"])
	_switch("sw_bath", Vector3(5.5, 1.2, 2.735), 180, ["bath_ceiling", "bath_vanity"])
	_switch("sw_laundry", Vector3(5.665, 1.2, 4.85), 90, ["laundry_bulb"])
	_switch("sw_closet", Vector3(5.665, 1.2, 6.35), 90, ["closet_bulb"])
	_switch("sw_foyer", Vector3(6.6, 1.2, 10.935), 180, ["foyer_ceiling"])
	_switch("sw_porch", Vector3(6.72, 1.2, 10.935), 180, ["porch_front"])
	_switch("sw_living", Vector3(7.665, 1.2, 8.35), 90, ["living_ceiling"])
	_switch("sw_dining", Vector3(7.95, 1.2, 6.135), 180, ["dining_chandelier"])
	_switch("sw_kitchen", Vector3(11.065, 1.2, 5.0), 90, ["kitchen_ceiling"])
	_switch("sw_backporch", Vector3(12.85, 1.25, 0.135), 0, ["porch_back", "yard_flood"])
	_switch("sw_garage", Vector3(16.12, 1.0, 4.0), 90, ["garage_tube"])
	_switch("sw_garage_flood", Vector3(16.12, 1.0, 3.85), 90, ["garage_flood"])
	Props.smoke_detector(L, Vector3(4.9, H, 3.9))
	Props.smoke_detector(L, Vector3(11.0, H, 8.6))


# ================================================================== rooms
func _curtain(id: String, pos: Vector3, rot_y: float, w: float, mat_key: String, open := true) -> void:
	var c := Curtain.new()
	c.name = "Curtain_" + id
	interior.add_child(c)
	c.position = pos
	c.rotation_degrees.y = rot_y
	c.setup(id, w, 2.25, Mats.m(mat_key), open)


func _photo(id: String, tex: String, pos: Vector3, rot_y: float, size := Vector2(0.3, 0.38)) -> PictureFrame:
	var p := PictureFrame.new()
	p.name = "Photo_" + id
	interior.add_child(p)
	p.position = pos
	p.rotation_degrees.y = rot_y
	p.setup(id, tex, size)
	return p


func _note(id: String, text: String, pos: Vector3, rot := Vector3.ZERO, size := Vector2(0.15, 0.2), flat := true) -> Readable:
	var r := Readable.new()
	r.name = "Note_" + id
	interior.add_child(r)
	r.position = pos
	r.rotation_degrees = rot
	r.setup(id, text, size, null, flat)
	return r


func _bedroom1() -> void:
	var R := interior
	Props.bed(R, Vector3(0.15, 0, 3.5), 90, 1.4, 2.0, "fabric_red")
	var bed := Bed.new()
	bed.name = "BedSleep"
	R.add_child(bed)
	bed.position = Vector3(1.15, 0, 3.5)
	bed.setup("bed", Vector3(2.0, 0.7, 1.4))
	var pad := Notepad.new()
	pad.name = "Notepad"
	R.add_child(pad)
	pad.position = Vector3(0.36, 0.552, 2.33)
	pad.rotation_degrees.y = 72
	pad.setup("notepad")
	Props.nightstand(R, Vector3(0.35, 0, 2.45), 90)
	Props.table_lamp(R, Vector3(0.35, 0.55, 2.5), "b1_lamp", true, Color(0.95, 0.88, 0.72), 1.15, true)
	var ac := B.node(R, "AlarmClock", Vector3(0.42, 0.55, 2.32), Vector3(0, 90, 0))
	B.box(ac, Vector3(0.14, 0.07, 0.07), Vector3(0, 0.035, 0), Mats.m("plastic_black"))
	var clk := WallClock.new()
	ac.add_child(clk)
	clk.position = Vector3(0, 0.04, 0.036)
	clk.setup_digital("clock_bedroom", Color(1.0, 0.15, 0.08), 0.0011)
	_note("b1_notepad", "couldn't sleep.\n\na car went around the court twice.\nslow. headlights on the ceiling both times.\n\nprobably someone lost.", Vector3(0.24, 0.551, 2.66), Vector3(0, 80, 0), Vector2(0.09, 0.12))
	Props.wardrobe(R, Vector3(3.84, 0, 1.8), -90, 1.2, 2.0)
	Props.desk(R, Vector3(2.75, 0, 4.64), 180, 1.1, 0.6)
	var comp := Computer.new()
	comp.name = "Computer"
	R.add_child(comp)
	comp.position = Vector3(2.85, 0.757, 4.72)
	comp.rotation_degrees.y = 180
	comp.setup("computer")
	Props.office_chair(R, Vector3(2.75, 0, 3.95), 0)
	Props.bookshelf(R, Vector3(3.4, 0, 0.29), 0, 0.8, 1.2, 0.3)
	Props.rug(R, Vector3(2.2, 0, 2.5), Vector2(1.7, 2.3), Mats.textured("carpet", 1.0, 1.0, "", true, Color(0.75, 0.55, 0.45)))
	_curtain("b1_west", Vector3(0.14, 0, 1.4), 90, 1.0, "fabric_white", true)
	_curtain("b1_back", Vector3(2.1, 0, 0.14), 0, 1.1, "fabric_white", true)
	_photo("photo_b1", "photo_3", Vector3(0.135, 1.6, 3.5), 90, Vector2(0.28, 0.34))
	Props.mug(R, Vector3(3.2, 0.76, 4.5), "mug_b1")
	B.box(R, Vector3(0.4, 0.01, 0.3), Vector3(2.4, 0.76, 4.6), Mats.m("paper"), false, Vector3(0, 12, 0))


func _bedroom2() -> void:
	var R := interior
	Props.bed(R, Vector3(0.15, 0, 6.2), 90, 1.0, 1.95, "fabric_blue")
	Props.dresser(R, Vector3(3.9, 0, 8.6), -90, 1.1, 0.9)
	Props.desk(R, Vector3(3.3, 0, 10.58), 180, 1.0, 0.55)
	Props.simple_chair(R, Vector3(3.3, 0, 10.0), 0, Mats.m("wood_painted"))
	var d := B.quad(R, Vector2(0.32, 0.25), Vector3(3.3, 1.35, 10.865), Mats.picture("drawing"), Vector3(0, 180, 0))
	d.rotation_degrees.z = 3.0
	Props.boxes(R, Vector3(0.6, 0, 10.4), 3, 11)
	Props.boxes(R, Vector3(1.3, 0, 10.45), 2, 12)
	Props.boxes(R, Vector3(0.55, 0, 9.65), 1, 13)
	Props.rug(R, Vector3(2.2, 0, 8.0), Vector2(1.4, 1.9), Mats.textured("carpet", 1.0, 1.0, "", true, Color(0.6, 0.65, 0.7)))
	_curtain("b2_front", Vector3(2.1, 0, 10.86), 180, 1.2, "fabric_stripe", false)
	_curtain("b2_west", Vector3(0.14, 0, 8.6), 90, 1.0, "fabric_stripe", true)
	_photo("photo_b2", "photo_1", Vector3(4.135, 1.55, 9.9), -90, Vector2(0.24, 0.3))


func _hall_bath_laundry() -> void:
	var R := interior
	Props.rug(R, Vector3(4.9, 0, 5.4), Vector2(0.8, 4.2), Mats.textured("carpet", 1.0, 1.0, "", true, Color(0.7, 0.45, 0.35)))
	var ph := _photo("photo_hall", "photo_5", Vector3(5.535, 1.55, 5.6), -90, Vector2(0.4, 0.5))
	ph.set_tilt(0.0)
	_photo("photo_hall2", "photo_0", Vector3(4.265, 1.6, 5.1), 90, Vector2(0.3, 0.38))
	Props.thermostat(R, Vector3(4.265, 1.45, 7.05), 90)
	# bathroom
	Props.toilet(R, Vector3(4.75, 0, 0.36), 0)
	Props.bathtub(R, Vector3(6.62, 0, 0.5), 0, 1.7)
	Props.vanity(R, Vector3(7.29, 0, 1.9), -90, 0.9)
	Props.mirror(R, Vector3(7.535, 1.55, 1.9), -90)
	var fb := Faucet.new()
	fb.name = "Faucet_bath"
	R.add_child(fb)
	fb.position = Vector3(7.42, 0.84, 1.9)
	fb.rotation_degrees.y = -90
	fb.setup("faucet_bath", 0.16)
	Props.towel(R, Vector3(4.265, 1.25, 1.5), 90, "fabric_blue")
	B.cyl(R, 0.05, 0.05, 0.1, Vector3(4.4, 0.7, 0.75), Mats.m("plastic_white"), false, Vector3(0, 0, 90), 12)
	# laundry
	Props.washer(R, Vector3(7.2, 0, 3.3), -90)
	Props.washer(R, Vector3(7.2, 0, 4.0), -90, true)
	B.box(R, Vector3(0.32, 0.025, 1.5), Vector3(7.38, 1.65, 3.65), Mats.m("wood_light"))
	for i in 5:
		B.cyl(R, 0.05, 0.05, 0.22, Vector3(7.38, 1.77, 3.1 + i * 0.25), Mats.color([Color(0.2, 0.4, 0.8), Color(0.9, 0.9, 0.85), Color(0.9, 0.5, 0.1)][i % 3], 0.4), false, Vector3.ZERO, 10)
	Props.water_heater(R, Vector3(6.95, 0, 5.15))
	B.cyl(R, 0.22, 0.19, 0.4, Vector3(6.05, 0.2, 3.2), Mats.color(Color(0.85, 0.85, 0.8), 0.6), true, Vector3.ZERO, 16)
	B.box(R, Vector3(0.36, 0.1, 0.3), Vector3(6.05, 0.42, 3.2), Mats.m("fabric_white"))
	# closet
	Props.coats(R, Vector3(7.25, 0, 6.9), 90, 2.2)
	Props.boxes(R, Vector3(6.0, 0, 5.95), 2, 21)
	B.cyl(R, 0.12, 0.12, 0.35, Vector3(6.2, 0.175, 7.9), Mats.color(Color(0.5, 0.15, 0.12), 0.5), false, Vector3.ZERO, 12)
	B.cyl(R, 0.015, 0.015, 1.0, Vector3(6.2, 0.75, 7.9), Mats.m("metal"), false, Vector3(0, 0, 8), 6)


func _foyer() -> void:
	var R := interior
	Props.side_table(R, Vector3(4.5, 0, 9.8), 90, 0.75)
	var phone := Phone.new()
	phone.name = "Phone"
	R.add_child(phone)
	phone.position = Vector3(4.5, 0.75, 9.75)
	phone.rotation_degrees.y = 90
	phone.setup("phone")
	_note("foyer_note", "Back late.\nLeftovers in the fridge.\n\nIf the phone rings it's probably for me.\nLet it ring.\n\n- M", Vector3(4.47, 0.751, 10.05), Vector3(0, 95, 0), Vector2(0.1, 0.13))
	Props.rug(R, Vector3(5.9, 0, 10.3), Vector2(1.3, 0.8), Mats.textured("carpet", 1.0, 1.0, "", true, Color(0.5, 0.42, 0.36)))
	_photo("photo_foyer", "photo_2", Vector3(6.6, 1.6, 8.265), 0, Vector2(0.26, 0.32))
	Props.mirror(R, Vector3(4.265, 1.55, 8.9), 90, Vector2(0.45, 0.65))
	# coat hooks + shoes
	B.box(R, Vector3(0.6, 0.08, 0.03), Vector3(7.25, 1.75, 10.87), Mats.m("wood_dark"))
	B.box(R, Vector3(0.1, 0.8, 0.4), Vector3(7.3, 1.35, 10.68), Mats.m("fabric_sofa"), false, Vector3(0, 0, 4))
	for i in 3:
		B.box(R, Vector3(0.11, 0.08, 0.27), Vector3(6.75 + i * 0.16, 0.04, 10.65), Mats.color(Color(0.15 + i * 0.1, 0.1, 0.08), 0.6), false, Vector3(0, i * 9 - 9, 0))


func _living() -> void:
	var R := interior
	var stand := Props.tv_stand(R, Vector3(15.6, 0, 8.6), -90)
	var tv := TV.new()
	tv.name = "TV"
	R.add_child(tv)
	tv.position = Vector3(15.52, 0.5, 8.6)
	tv.rotation_degrees.y = -90
	tv.setup("tv")
	var vcr := WallClock.new()
	stand.add_child(vcr)
	vcr.position = Vector3(-0.08, 0.17, 0.232)
	vcr.blink_noon = true
	vcr.setup_digital("clock_vcr", Color(0.3, 1.0, 0.6), 0.0008)
	Props.sofa(R, Vector3(11.9, 0, 8.6), 90, 2.1, "fabric_sofa")
	Props.coffee_table(R, Vector3(13.4, 0, 8.6), 90)
	Props.armchair(R, Vector3(14.3, 0, 10.35), 200, "fabric_green")
	Props.floor_lamp(R, Vector3(15.45, 0, 10.55), "living_floorlamp", true, 1.5)
	Props.side_table(R, Vector3(11.9, 0, 10.15), 0)
	Props.table_lamp(R, Vector3(11.9, 0.58, 10.15), "living_lamp", false, Color(0.9, 0.85, 0.7), 1.0, false)
	Props.bookshelf(R, Vector3(14.8, 0, 6.43), 0, 0.9, 1.8, 0.32)
	Props.plant(R, Vector3(8.05, 0, 10.6), 1.0)
	Props.rug(R, Vector3(13.2, 0, 8.6), Vector2(3.0, 2.4), Mats.textured("carpet", 1.0, 1.0, "", true, Color(0.62, 0.5, 0.4)))
	Props.pickup_box(R, Vector3(13.3, 0.425, 8.45), "remote", Vector3(0.05, 0.022, 0.18), Mats.m("plastic_black"), 0.15)
	Props.mug(R, Vector3(13.55, 0.425, 8.9), "mug_living", Color(0.4, 0.5, 0.6))
	B.box(R, Vector3(0.22, 0.015, 0.3), Vector3(13.2, 0.428, 8.95), Mats.color(Color(0.7, 0.3, 0.25), 0.7), false, Vector3(0, 20, 0))
	var lc := WallClock.new()
	R.add_child(lc)
	lc.position = Vector3(7.665, 1.95, 7.4)
	lc.rotation_degrees.y = 90
	lc.setup_analog("clock_living", 0.16, Color(0.95, 0.93, 0.86), true)
	_photo("photo_living", "photo_4", Vector3(11.75, 1.55, 10.865), 180, Vector2(0.45, 0.36))
	_curtain("living_w1", Vector3(9.9, 0, 10.86), 180, 1.5, "fabric_red", true)
	_curtain("living_w2", Vector3(13.6, 0, 10.86), 180, 1.5, "fabric_red", true)


func _dining() -> void:
	var R := interior
	Props.table(R, Vector3(9.3, 0, 3.1), 0, 1.6, 0.95, 0.76, Mats.m("wood_dark"))
	var wd := Mats.m("wood_dark")
	var cush := Mats.m("fabric_green")
	Props.simple_chair(R, Vector3(8.85, 0, 2.35), 0, wd, cush)
	Props.simple_chair(R, Vector3(9.75, 0, 2.35), 0, wd, cush)
	Props.simple_chair(R, Vector3(8.85, 0, 3.85), 180, wd, cush)
	Props.simple_chair(R, Vector3(9.75, 0, 3.85), 180, wd, cush)
	Props.dresser(R, Vector3(7.91, 0, 3.3), 90, 1.3, 0.9)
	for i in 4:
		B.cyl(R, 0.11, 0.11, 0.015, Vector3(7.85, 1.0 + i * 0.016, 2.95), Mats.m("porcelain"), false, Vector3.ZERO, 18)
	B.cyl(R, 0.06, 0.05, 0.2, Vector3(7.9, 1.0, 3.65), Mats.color(Color(0.3, 0.45, 0.5), 0.2), false, Vector3.ZERO, 12)
	B.cyl(R, 0.15, 0.15, 0.02, Vector3(9.3, 0.77, 3.1), Mats.color(Color(0.85, 0.82, 0.75), 0.4), false, Vector3.ZERO, 20)
	_curtain("dining_back", Vector3(9.3, 0, 0.14), 0, 1.4, "fabric_green", true)
	var p := B.node(R, "LandscapePrint", Vector3(10.935, 1.6, 5.4), Vector3(0, -90, 0))
	B.box(p, Vector3(0.62, 0.48, 0.02), Vector3(0, 0, 0.01), Mats.m("wood_light"))
	B.quad(p, Vector2(0.56, 0.42), Vector3(0, 0, 0.022), Mats.picture("photo_4"))


func _kitchen() -> void:
	var R := interior
	var top := Mats.color(Color(0.7, 0.66, 0.56), 0.35)
	Props.counter(R, Vector3(11.98, 0, 0.41), 0, 1.84, top)
	Props.sink_basin(R, Vector3(12.0, 0.9, 0.42), 0, 0.7)
	var fk := Faucet.new()
	fk.name = "Faucet_kitchen"
	R.add_child(fk)
	fk.position = Vector3(12.0, 0.9, 0.17)
	fk.setup("faucet_kitchen", 0.3)
	Props.counter(R, Vector3(14.825, 0, 0.41), 0, 1.15, top)
	Props.counter(R, Vector3(15.59, 0, 1.055), -90, 0.69, top)
	Props.stove(R, Vector3(15.57, 0, 1.78), -90)
	Props.counter(R, Vector3(15.59, 0, 2.83), -90, 1.34, top)
	Props.upper_cabinet(R, Vector3(15.06, 1.45, 0.29), 0, 1.64)
	Props.upper_cabinet(R, Vector3(15.71, 1.45, 2.1), -90, 2.6)
	B.box(R, Vector3(0.5, 0.25, 0.76), Vector3(15.63, 1.32, 1.78), Mats.color(Color(0.75, 0.73, 0.68), 0.4))
	# backsplash
	var bs := Mats.m("backsplash")
	B.box(R, Vector3(0.44, 0.55, 0.012), Vector3(11.28, 1.18, 0.127), bs)
	B.box(R, Vector3(1.0, 0.15, 0.012), Vector3(12.0, 0.98, 0.127), bs)
	B.box(R, Vector3(0.38, 0.55, 0.012), Vector3(12.71, 1.18, 0.127), bs)
	B.box(R, Vector3(1.65, 0.55, 0.012), Vector3(15.06, 1.18, 0.127), bs)
	B.box(R, Vector3(0.012, 0.55, 3.4), Vector3(15.873, 1.18, 1.8), bs)
	Props.microwave(R, Vector3(14.7, 0.9, 0.36), 0)
	var mw := WallClock.new()
	R.add_child(mw)
	mw.position = Vector3(14.87, 1.05, 0.545)
	mw.setup_digital("clock_microwave", Color(0.35, 1.0, 0.55), 0.0007, true)
	Props.toaster(R, Vector3(15.55, 0.9, 2.75), -90)
	B.cyl(R, 0.09, 0.07, 0.2, Vector3(15.55, 1.0, 3.25), Mats.color(Color(0.85, 0.83, 0.78), 0.3), false, Vector3.ZERO, 14)
	# fridge with a real door (+ interior light + hum)
	Props.fridge_body(R, Vector3(15.53, 0, 3.92), -90)
	var fd := Door.new()
	fd.name = "FridgeDoor"
	R.add_child(fd)
	fd.position = Vector3(15.15, 0.04, 3.55)
	fd.rotation_degrees.y = -90
	fd.sound_open = "fridge_open"
	fd.sound_close = "fridge_close"
	fd.duration = 0.6
	fd.open_angle = 100
	fd.setup("fridge_door", 0.74, 1.66, 0.06, Mats.color(Color(0.86, 0.85, 0.8), 0.3), -1.0, false, false)
	B.box(fd.body, Vector3(0.03, 0.5, 0.04), Vector3(0.66, 1.0, 0.06), Mats.m("chrome"))
	var fl := B.omni(R, Vector3(15.45, 1.2, 3.92), Color(0.9, 0.95, 1.0), 0.8, 2.0, false)
	fl.visible = false
	fd.opened.connect(func(): fl.visible = true)
	fd.closed.connect(func(): fl.visible = false)
	var letter := Readable.new()
	letter.name = "FridgeLetter"
	fd.body.add_child(letter)
	letter.position = Vector3(0.42, 1.18, 0.034)
	letter.setup("fridge_letter", FRIDGE_LETTER, Vector2(0.17, 0.22), Mats.color(Color(0.93, 0.9, 0.8), 0.9), false)
	letter.rotation_degrees.z = -4
	B.box(fd.body, Vector3(0.03, 0.03, 0.012), Vector3(0.42, 1.28, 0.04), Mats.color(Color(0.8, 0.2, 0.15), 0.4))
	var hum := AudioManager.make_emitter(R, "fridge_hum", Vector3(15.5, 1.7, 3.92))
	hum.name = "FridgeHum"
	WorldState.register("fridge_hum", hum)
	# little table + the two chairs the world sometimes moves
	Props.table(R, Vector3(13.6, 0, 4.3), 0, 0.85, 0.85, 0.74, Mats.m("wood_light"), true)
	Props.movable_chair(R, Vector3(13.6, 0, 4.98), 180, "kitchen_chair_a", Mats.m("wood_light"))
	Props.movable_chair(R, Vector3(12.92, 0, 4.3), 90, "kitchen_chair_b", Mats.m("wood_light"))
	var kc := WallClock.new()
	R.add_child(kc)
	kc.position = Vector3(14.6, 1.95, 6.135)
	kc.rotation_degrees.y = 180
	kc.setup_analog("clock_kitchen", 0.15, Color(0.96, 0.95, 0.9), true)
	B.quad(R, Vector2(0.26, 0.32), Vector3(11.065, 1.5, 5.35), Mats.picture("calendar"), Vector3(0, 90, 0))
	_note("mail", "R. HALLOWAY\n14 LARKSPUR COURT\n\nFINAL NOTICE\nPlease contact us to update the name\nassociated with this account.", Vector3(11.35, 0.902, 0.5), Vector3(0, 8, 0), Vector2(0.22, 0.11))
	Props.mug(R, Vector3(14.3, 0.9, 0.45), "mug_kitchen", Color(0.85, 0.82, 0.7))
	Props.can(R, Vector3(13.45, 0.74, 4.2), "can_kitchen", Color(0.7, 0.15, 0.1))
	B.box(R, Vector3(0.3, 0.2, 0.22), Vector3(15.5, 1.0, 0.45), Mats.color(Color(0.75, 0.6, 0.3), 0.8))
	B.box(R, Vector3(0.18, 0.28, 0.06), Vector3(15.7, 1.04, 0.7), Mats.color(Color(0.2, 0.3, 0.6), 0.8))
	B.box(R, Vector3(0.5, 0.02, 0.35), Vector3(11.4, 0.91, 0.42), Mats.m("wood_light"), false, Vector3(0, 0, 0))
	# trash can (chore), dirty dishes + drying rack (chore), burner knob (chore)
	var tc := TrashCan.new()
	tc.name = "TrashCan"
	R.add_child(tc)
	tc.position = Vector3(11.3, 0, 1.2)
	tc.setup("trash_can")
	var rack := B.node(R, "DryingRack", Vector3(11.35, 0.92, 0.42))
	B.box(rack, Vector3(0.42, 0.02, 0.3), Vector3(0, 0.0, 0), Mats.m("chrome"))
	for i in 6:
		B.box(rack, Vector3(0.006, 0.16, 0.26), Vector3(-0.18 + i * 0.072, 0.08, 0), Mats.m("chrome"))
	var dd := DirtyDishes.new()
	dd.name = "Dishes"
	R.add_child(dd)
	dd.position = Vector3(11.95, 0.77, 0.45)
	dd.setup("dishes", rack)
	var knob := StoveKnob.new()
	knob.name = "StoveKnob"
	R.add_child(knob)
	knob.position = Vector3(15.25, 0.84, 1.53)
	knob.rotation_degrees.y = -90
	knob.setup("stove_knob", Vector3(-0.15, 0.075, 0.31))


func _garage() -> void:
	var R := interior
	var car := Vehicles.car_model(R, Color(0.28, 0.32, 0.28), true)
	car.position = Vector3(19.6, -0.3, 6.7)
	B.collider(car, Vector3(1.8, 1.4, 4.6), Vector3(0, 0.7, 0))
	Props.table(R, Vector3(18.0, -0.3, 2.45), 0, 1.8, 0.6, 0.9, Mats.m("wood_light"))
	B.box(R, Vector3(1.6, 0.6, 0.02), Vector3(18.0, 1.3, 2.11), Mats.color(Color(0.55, 0.45, 0.3), 0.9))
	for i in 6:
		B.box(R, Vector3(0.03, 0.22, 0.02), Vector3(17.4 + i * 0.22, 1.35, 2.13), Mats.m("metal_dark"), false, Vector3(0, 0, randf_range(-10, 10)))
	B.box(R, Vector3(0.35, 0.18, 0.2), Vector3(18.5, 0.69, 2.45), Mats.color(Color(0.65, 0.12, 0.08), 0.5))
	_note("garage_note", "kitchen clock - new battery 10/2\nstill loses time.\n\nbuy a new one?", Vector3(17.6, 0.601, 2.5), Vector3(0, -6, 0), Vector2(0.12, 0.09))
	Props.shelf_unit(R, Vector3(22.2, -0.3, 5.0), -90, 1.4, 1.9, 0.45, true)
	Props.shelf_unit(R, Vector3(22.2, -0.3, 8.2), -90, 1.4, 1.9, 0.45, true)
	Props.boxes(R, Vector3(21.6, -0.3, 2.6), 3, 31)
	# lawnmower
	var lm := B.node(R, "Mower", Vector3(17.0, -0.3, 9.6), Vector3(0, 30, 0))
	B.box(lm, Vector3(0.5, 0.25, 0.6), Vector3(0, 0.2, 0), Mats.color(Color(0.6, 0.12, 0.08), 0.5), true)
	B.cyl(lm, 0.012, 0.012, 1.0, Vector3(0, 0.6, -0.5), Mats.m("metal_dark"), false, Vector3(-40, 0, 0), 6)
	for p: Vector3 in [Vector3(-0.27, 0.09, 0.22), Vector3(0.27, 0.09, 0.22), Vector3(-0.27, 0.09, -0.22), Vector3(0.27, 0.09, -0.22)]:
		B.cyl(lm, 0.09, 0.09, 0.04, p, Mats.m("rubber"), false, Vector3(0, 0, 90), 10)
	var gd := GarageDoor.new()
	gd.name = "GarageDoor"
	R.add_child(gd)
	gd.position = Vector3(19.25, -0.3, 11.0)
	gd.setup("garage_door", 5.3, 2.4, Mats.m("siding_white"))


const FRIDGE_LETTER := "Dana -\n\nSaw Dad on Sunday. He's the same.\nStill spells everything out loud instead of\njust saying it. Asked the nurse for W-A-T-E-R.\nTold the TV to O-F-F.\n\nYou remember how he'd stand at the microwave\nand spell S-T-A-R-T at it, like machines only\nlisten if you spell it out for them.\n\nHe asked if you still have the old computer.\nI told him I didn't know.\n\nCall me. The phone at your place never picks up.\n\n- Ruth"


# ================================================================== event data
func _points() -> void:
	house.points = {
		"front_door_out": Vector3(5.9, 1.2, 11.25),
		"front_porch": Vector3(5.9, -0.02, 11.75),
		"back_door_out": Vector3(13.6, 1.2, -0.3),
		"living_center": Vector3(12.5, 1.2, 8.6),
		"kitchen_center": Vector3(13.5, 1.2, 3.0),
		"hall_center": Vector3(4.9, 1.2, 5.0),
		"spawn": Vector3(1.35, 0.05, 1.3),
		"garage_inside": Vector3(19.0, 0.5, 9.0),
	}
	house.paths = {
		"hall": [Vector3(2.0, 0, 8.2), Vector3(3.6, 0, 6.2), Vector3(4.9, 0, 6.0), Vector3(4.9, 0, 4.5), Vector3(4.9, 0, 3.0), Vector3(4.9, 0, 2.0)],
		"living": [Vector3(8.4, 0, 9.6), Vector3(10.1, 0, 8.0), Vector3(9.5, 0, 6.4), Vector3(9.7, 0, 4.9), Vector3(11.6, 0, 3.6), Vector3(13.6, 0, 2.6)],
		"patio": [Vector3(17.0, -0.3, -1.4), Vector3(14.5, -0.02, -1.6), Vector3(12.0, -0.02, -1.5), Vector3(9.0, -0.3, -2.0), Vector3(5.0, -0.3, -2.4), Vector3(1.5, -0.3, -2.2)],
		"to_bedroom": [Vector3(5.9, 0, 9.8), Vector3(4.9, 0, 8.4), Vector3(4.9, 0, 6.4), Vector3(4.85, 0, 4.6), Vector3(4.45, 0, 4.2)],
		"garage": [Vector3(21.5, -0.3, 9.6), Vector3(19.4, -0.3, 9.2), Vector3(17.2, -0.3, 6.0), Vector3(16.4, 0.0, 4.8)],
		"kitchen": [Vector3(14.6, 0, 1.6), Vector3(13.2, 0, 2.0), Vector3(11.8, 0, 2.9), Vector3(10.0, 0, 3.2), Vector3(8.4, 0, 4.8)],
	}
	house.set_meta("path_surfaces", {"patio": "concrete", "garage": "concrete", "kitchen": "tile"})


func _acoustics() -> void:
	var a := Area3D.new()
	a.name = "RoomReverb"
	a.collision_layer = B.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = "Room"
	a.reverb_bus_amount = 0.35
	a.reverb_bus_uniformity = 0.2
	house.add_child(a)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(16.0, 2.6, 11.0)
	cs.shape = sh
	cs.position = Vector3(8.0, 1.3, 5.5)
	a.add_child(cs)
