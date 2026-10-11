class_name Neighborhood
extends Node3D
## The cul-de-sac: bulb, access road, sidewalks, neighbour houses, lamps,
## trees, fences and a believable edge (closed road + woods).
##
## World layout: bulb centre at the origin. The access road leaves the bulb
## towards +Z and ends at a T junction (z = 150) closed by road works.
## The player's house sits north of the bulb (front facing +Z).

const BULB_R := 15.0
const WALK_IN := 15.25
const WALK_OUT := 17.0
const ROAD_HALF := 4.0
const ROAD_END := 150.0
const HOUSE_R := 27.0

var houses: Dictionary = {}       # family -> NeighborHouse
var lamps: Array = []             # [{light, glow, buzz}]
var flat_zones: Array = []        # [{type, data, surface}] for footstep surfaces
var rng := RandomNumberGenerator.new()
var _tree_spots: Array = []       # [Vector3, radius]
var _keepout: Array = []          # Rect2 in XZ that trees must avoid


func build() -> void:
	rng.seed = 1998
	WorldState.register("neighborhood", self)
	_ground()
	_bulb_and_road()
	_player_lot()
	_neighbors()
	_street_lamps()
	_edge()
	_trees()
	_boundary()


# ------------------------------------------------------------------ surfaces
func surface_at(p: Vector3) -> String:
	var r := Vector2(p.x, p.z).length()
	if r < BULB_R:
		return "asphalt"
	if r < WALK_OUT + 0.1:
		return "concrete"
	for z in flat_zones:
		var inside: bool = _in_rot(z, p)
		if inside:
			return z.surface
	return "grass"


func _in_rot(z: Dictionary, p: Vector3) -> bool:
	var c: Vector2 = z.center
	var lp := (Vector2(p.x, p.z) - c).rotated(-z.rot)
	return absf(lp.x) <= z.half.x and absf(lp.y) <= z.half.y


## Flat strip (road, driveway, walkway) rendered as a thin box. rot in radians around Y.
func flat(center: Vector3, size: Vector2, rot: float, mat: Material, surface: String, top := 0.02) -> void:
	var mi := B.box(self, Vector3(size.x, 0.04, size.y), Vector3(center.x, top - 0.02, center.z), mat, false, Vector3(0, rad_to_deg(rot), 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := size / 2.0
	flat_zones.append({"rect": Rect2(Vector2(center.x, center.z) - half, size), "rot": rot, "center": Vector2(center.x, center.z), "half": half, "surface": surface})
	_keepout.append({"center": Vector2(center.x, center.z), "half": half + Vector2(1.5, 1.5), "rot": rot})


func _ground() -> void:
	var g := B.box(self, Vector3(600, 1.0, 600), Vector3(0, -0.5, 60), Mats.m("grass"), true, Vector3.ZERO, "ground")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _annulus(r0: float, r1: float, y0: float, y1: float, mat: Material, segs := 96, gap_center := -1.0, gap_half := 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var am := (a0 + a1) / 2.0
		if gap_center >= 0.0 and absf(angle_difference(am, gap_center)) < gap_half:
			continue
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		var quads := [
			[d0 * r0 + Vector3(0, y1, 0), d1 * r0 + Vector3(0, y1, 0), d1 * r1 + Vector3(0, y1, 0), d0 * r1 + Vector3(0, y1, 0), Vector3.UP],
			[d0 * r0 + Vector3(0, y0, 0), d1 * r0 + Vector3(0, y0, 0), d1 * r0 + Vector3(0, y1, 0), d0 * r0 + Vector3(0, y1, 0), -(d0 + d1).normalized()],
		]
		for q in quads:
			st.set_normal(q[4])
			st.add_vertex(q[0])
			st.add_vertex(q[1])
			st.add_vertex(q[2])
			st.add_vertex(q[0])
			st.add_vertex(q[2])
			st.add_vertex(q[3])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.two_sided(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _bulb_and_road() -> void:
	var asphalt := Mats.m("asphalt")
	var concrete := Mats.m("concrete")
	var curb := Mats.color(Color(0.62, 0.6, 0.56), 0.9)
	var bulb := B.cyl(self, BULB_R, BULB_R, 0.04, Vector3(0, 0.006, 0), asphalt, false, Vector3.ZERO, 64)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_annulus(BULB_R, WALK_IN, 0.0, 0.12, curb, 96, 0.0, 0.29)
	_annulus(WALK_IN, WALK_OUT, 0.0, 0.08, concrete, 96, 0.0, 0.33)
	# little island in the middle of the bulb: a lone tree in a mulch bed
	B.cyl(self, 3.0, 3.0, 0.14, Vector3(0, 0.07, 0), curb, true, Vector3.ZERO, 32)
	B.cyl(self, 2.85, 2.85, 0.02, Vector3(0, 0.145, 0), Mats.m("mulch"), false, Vector3.ZERO, 32)
	_tree_spots.append([Vector3(0, 0.14, 0), 1.3])
	# access road
	var road_len := ROAD_END - BULB_R + 1.0
	flat(Vector3(0, 0, BULB_R - 1.0 + road_len / 2.0), Vector2(ROAD_HALF * 2, road_len), 0.0, asphalt, "asphalt")
	# centre line (faded, dashed)
	var paint := Mats.color(Color(0.75, 0.68, 0.4), 0.8)
	var z := 24.0
	while z < ROAD_END - 6.0:
		B.box(self, Vector3(0.12, 0.01, 2.5), Vector3(0, 0.022, z), paint)
		z += 7.0
	for s: float in [-1.0, 1.0]:
		B.box(self, Vector3(0.18, 0.12, road_len - 2.5), Vector3(s * (ROAD_HALF + 0.09), 0.06, BULB_R + road_len / 2.0 + 0.4), curb)
		flat(Vector3(s * (ROAD_HALF + 1.1), 0, BULB_R + 1.6 + (road_len - 1.5) / 2.0), Vector2(1.6, road_len - 1.5), 0.0, concrete, "concrete", 0.08)
	# cross road at the T junction
	flat(Vector3(0, 0, ROAD_END + 4.0), Vector2(110, 8.0), 0.0, asphalt, "asphalt")
	B.box(self, Vector3(110, 0.12, 0.18), Vector3(0, 0.06, ROAD_END + 8.1), curb)
	# stop sign at the end of the access road
	var ss := B.node(self, "StopSign", Vector3(-5.2, 0, ROAD_END - 1.0))
	B.cyl(ss, 0.03, 0.03, 2.3, Vector3(0, 1.15, 0), Mats.m("metal"), true)
	B.cyl(ss, 0.36, 0.36, 0.02, Vector3(0, 2.35, 0), Mats.color(Color(0.55, 0.06, 0.05), 0.5), false, Vector3(90, 180, 0), 8)
	B.label(ss, "STOP", Vector3(0, 2.35, -0.015), 0.006, Color(0.95, 0.95, 0.92), Vector3(0, 180, 0), 32)
	# street name sign
	var sn := B.node(self, "StreetSign", Vector3(5.3, 0, 18.5))
	B.cyl(sn, 0.03, 0.03, 2.6, Vector3(0, 1.3, 0), Mats.m("metal"), true)
	B.box(sn, Vector3(0.9, 0.18, 0.02), Vector3(0, 2.5, 0), Mats.color(Color(0.1, 0.3, 0.18), 0.5))
	B.label(sn, "LARKSPUR CT", Vector3(0, 2.5, 0.012), 0.0035, Color(0.9, 0.92, 0.88), Vector3.ZERO, 32)
	B.label(sn, "LARKSPUR CT", Vector3(0, 2.5, -0.012), 0.0035, Color(0.9, 0.92, 0.88), Vector3(0, 180, 0), 32)
	B.box(sn, Vector3(0.6, 0.45, 0.02), Vector3(0, 1.95, 0), Mats.color(Color(0.85, 0.75, 0.1), 0.5))
	B.label(sn, "NO\nOUTLET", Vector3(0, 1.95, 0.012), 0.003, Color(0.05, 0.05, 0.05), Vector3.ZERO, 32)


## Where a house's lot meets the street: polar position on the bulb.
static func polar(phi_deg: float, r: float) -> Vector3:
	var a := deg_to_rad(phi_deg)
	return Vector3(sin(a) * r, 0, cos(a) * r)


func _driveway_to_curb(start: Vector3, dir: Vector3, width: float, surface := "concrete", mat: Material = null) -> void:
	## Straight strip from `start` along `dir` until it reaches the sidewalk ring.
	var lo := 0.0
	var hi := 40.0
	for i in 30:
		var mid := (lo + hi) / 2.0
		var p := start + dir * mid
		if Vector2(p.x, p.z).length() > WALK_OUT - 0.3:
			lo = mid
		else:
			hi = mid
	var length := lo + 0.4
	var center := start + dir * (length / 2.0)
	flat(center, Vector2(width, length), atan2(dir.x, dir.z), mat if mat else Mats.m("concrete"), surface, 0.03)


func _player_lot() -> void:
	# player's house is built by HouseBuilder; front centre world (0, 0, -27)
	var concrete := Mats.m("concrete")
	# driveway from the garage door, walkway from the porch
	_driveway_to_curb(Vector3(8.0, 0, -26.6), Vector3(0, 0, 1), 5.4)
	_driveway_to_curb(Vector3(-5.35, 0, -25.3), Vector3(0, 0, 1), 1.2)
	# path lights along the walkway (as seen from the street at night)
	for i in 5:
		for s: float in [-1.0, 1.0]:
			var p := Vector3(-5.35 + s * 0.85, 0, -24.6 + i * 1.6)
			if Vector2(p.x, p.z).length() < WALK_OUT + 0.3:
				continue
			B.cyl(self, 0.02, 0.02, 0.32, p + Vector3(0, 0.16, 0), Mats.m("metal_dark"), false, Vector3.ZERO, 6)
			B.cyl(self, 0.06, 0.05, 0.06, p + Vector3(0, 0.34, 0), Mats.emissive(Color(1.0, 0.85, 0.6), 3.0), false, Vector3.ZERO, 8)
			if i % 2 == 0:
				B.omni(self, p + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.55), 0.25, 2.2, false)
	# mailbox (chore: the mail) and wheelie bins (chore: the trash)
	var mb := Mailbox.new()
	mb.name = "PlayerMailbox"
	add_child(mb)
	mb.position = Vector3(-7.2, 0, -17.4)
	mb.setup("mailbox")
	for i in 2:
		var bin := OutdoorBin.new()
		bin.name = "Bin%d" % i
		add_child(bin)
		bin.position = Vector3(11.6 + i * 0.75, 0, -26.2)
		bin.setup("bin_%d" % i, Color(0.12, 0.2, 0.14) if i == 0 else Color(0.15, 0.2, 0.32))
	# flower bed + bushes in front of the house
	B.box(self, Vector3(9.0, 0.06, 1.2), Vector3(-4.0, 0.03, -26.3), Mats.m("mulch"))
	for x: float in [-10.0, -8.5, -2.6, -1.0, 1.0, 2.6]:
		_bush(Vector3(x, 0, -26.3), rng.randf_range(0.5, 0.8))
	# backyard: fence with a gate gap, patio furniture, grill, shed, clothesline
	var fence_y0 := -38.0
	_fence(Vector3(-11.6, 0, fence_y0 + 0.3), Vector3(-11.6, 0, -52.0))
	_fence(Vector3(-11.6, 0, -52.0), Vector3(11.8, 0, -52.0))
	_fence(Vector3(11.8, 0, -52.0), Vector3(11.8, 0, -36.2))
	_fence(Vector3(-11.6, 0, -27.5), Vector3(-11.6, 0, -33.5))
	_fence_gate_posts(Vector3(-11.6, 0, -33.5), Vector3(-11.6, 0, -37.7))
	var g := B.node(self, "Grill", Vector3(5.5, 0.15, -40.6))
	B.sphere(g, 0.3, Vector3(0, 0.95, 0), Mats.color(Color(0.08, 0.08, 0.08), 0.4, 0.5), Vector3(1, 0.75, 1))
	for a in 3:
		B.cyl(g, 0.015, 0.015, 0.9, Vector3(cos(a * TAU / 3) * 0.2, 0.45, sin(a * TAU / 3) * 0.2), Mats.m("metal_dark"), false, Vector3.ZERO, 6)
	B.collider(g, Vector3(0.6, 1.2, 0.6), Vector3(0, 0.6, 0))
	for i in 2:
		var lc := B.node(self, "LawnChair", Vector3(1.0 + i * 1.3, 0.15, -40.2), Vector3(0, -20 + i * 35, 0))
		var w := Mats.color(Color(0.85, 0.85, 0.82), 0.5)
		B.box(lc, Vector3(0.6, 0.05, 0.55), Vector3(0, 0.4, 0), w, true)
		B.box(lc, Vector3(0.6, 0.6, 0.05), Vector3(0, 0.7, -0.28), w, false, Vector3(-15, 0, 0))
		for x: float in [-0.27, 0.27]:
			B.box(lc, Vector3(0.04, 0.4, 0.5), Vector3(x, 0.2, 0), w)
	var shed := B.node(self, "Shed", Vector3(-8.0, 0, -49.0))
	B.box(shed, Vector3(3.0, 2.2, 2.4), Vector3(0, 1.1, 0), Mats.m("siding_gray"), true)
	B.roof(shed, -1.5, 1.5, -1.2, 1.2, 2.2, 0.7, Mats.m("shingles"), Mats.m("siding_gray"), true, 0.25)
	B.box(shed, Vector3(1.2, 1.9, 0.04), Vector3(0, 0.95, 1.21), Mats.m("wood_painted"))
	var cl := B.node(self, "Clothesline", Vector3(2.0, 0, -46.0))
	for x: float in [-3.0, 3.0]:
		B.box(cl, Vector3(0.08, 2.0, 0.08), Vector3(x, 1.0, 0), Mats.m("metal"), true)
		B.box(cl, Vector3(0.06, 0.06, 1.0), Vector3(x, 1.95, 0), Mats.m("metal"))
	for zz: float in [-0.4, 0.0, 0.4]:
		B.box(cl, Vector3(6.0, 0.008, 0.008), Vector3(0, 1.93, zz), Mats.color(Color(0.8, 0.8, 0.78)))
	B.box(cl, Vector3(0.7, 0.9, 0.01), Vector3(-1.0, 1.5, 0.0), Mats.m("fabric_white"))
	B.box(cl, Vector3(0.5, 0.6, 0.01), Vector3(0.6, 1.62, 0.4), Mats.m("fabric_blue"))
	_tree_spots.append([Vector3(-3.0, 0, -47.5), 1.0])
	_tree_spots.append([Vector3(9.0, 0, -49.0), 1.1])
	_tree_spots.append([Vector3(-11.0, 0, -20.5), 1.0])
	_keepout.append({"center": Vector2(5.0, -32.0), "half": Vector2(13.0, 7.0), "rot": 0.0})


func _bush(p: Vector3, s: float) -> void:
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s
	sm.height = s * 1.5
	sm.radial_segments = 12
	sm.rings = 6
	b.mesh = sm
	b.material_override = _foliage_mat(Color(0.42, 0.5, 0.36))
	add_child(b)
	b.position = p + Vector3(0, s * 0.55, 0)


var _fol_cache: Dictionary = {}


func _foliage_mat(tint: Color) -> ShaderMaterial:
	var key := str(tint)
	if _fol_cache.has(key):
		return _fol_cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("leaf_tex", Mats.tex("leaves"))
	m.set_shader_parameter("tint", tint)
	_fol_cache[key] = m
	return m


func _fence(a: Vector3, b: Vector3, h := 1.8) -> void:
	var d := b - a
	var length := d.length()
	var center := (a + b) / 2.0
	var rot := rad_to_deg(atan2(d.x, d.z))
	B.box(self, Vector3(0.05, h, length), center + Vector3(0, h / 2.0, 0), Mats.m("fence"), true, Vector3(0, rot, 0))
	var n := int(length / 2.4)
	for i in n + 1:
		var p: Vector3 = a + d * (float(i) / maxf(n, 1))
		B.box(self, Vector3(0.1, h + 0.1, 0.1), p + Vector3(0, (h + 0.1) / 2.0, 0), Mats.m("wood_dark"), false, Vector3(0, rot, 0))
	B.box(self, Vector3(0.06, 0.08, length), center + Vector3(0, h - 0.3, 0) + Vector3(0, 0, 0), Mats.m("wood_dark"), false, Vector3(0, rot, 0))
	_keepout.append({"center": Vector2(center.x, center.z), "half": Vector2(1.2, length / 2.0 + 0.5), "rot": deg_to_rad(rot)})


func _fence_gate_posts(a: Vector3, b: Vector3) -> void:
	for p: Vector3 in [a, b]:
		B.box(self, Vector3(0.12, 1.95, 0.12), p + Vector3(0, 0.97, 0), Mats.m("wood_dark"), true)


# ------------------------------------------------------------------ neighbours
const FAMILIES := [
	# phi, family, params
	[56.0, "Whitcomb", {"number": 9, "siding": "siding_blue", "garage": -1, "w": 13.0, "d": 9.5, "door_x": 1.6, "door_col": Color(0.12, 0.18, 0.28), "shutters": true, "seed": 3, "front_windows": 3, "porch": false, "rise": 2.1, "ridge_x": true}],
	[118.0, "Pruitt", {"number": 12, "siding": "siding_yellow", "garage": 1, "w": 12.0, "d": 9.0, "door_x": -1.2, "door_col": Color(0.4, 0.1, 0.08), "seed": 4, "front_windows": 2, "porch": true, "rise": 1.8, "ridge_x": true}],
	[242.0, "Ocampo", {"number": 16, "siding": "siding_green", "garage": -1, "w": 13.5, "d": 9.5, "door_x": 0.5, "door_col": Color(0.25, 0.2, 0.15), "seed": 5, "front_windows": 3, "porch": true, "brick": true, "rise": 2.2, "ridge_x": true}],
	[304.0, "Leland", {"number": 6, "siding": "siding_gray", "garage": 1, "w": 12.5, "d": 9.0, "door_x": -2.0, "door_col": Color(0.6, 0.55, 0.45), "shutters": true, "shutter_col": Color(0.3, 0.1, 0.08), "seed": 6, "front_windows": 3, "porch": false, "rise": 2.6, "ridge_x": false}],
]
const ROAD_HOUSES := [
	# x side, z, family, params
	[-1, 48.0, "Baptiste", {"siding": "siding_white", "garage": 1, "w": 12.0, "d": 9.0, "door_x": -1.0, "seed": 7, "front_windows": 3, "porch": true, "shutters": true}],
	[1, 52.0, "Kowalski", {"siding": "siding_yellow", "garage": -1, "w": 13.0, "d": 9.5, "door_x": 1.0, "seed": 8, "front_windows": 3, "porch": false, "brick": true}],
	[-1, 88.0, "Haines", {"siding": "siding_gray", "garage": 0, "w": 11.0, "d": 8.5, "door_x": 0.0, "seed": 9, "front_windows": 2, "porch": true, "rise": 2.4}],
	[1, 92.0, "Ferraro", {"siding": "siding_green", "garage": 1, "w": 12.5, "d": 9.0, "door_x": -1.5, "seed": 10, "front_windows": 3, "porch": true, "shutters": true, "shutter_col": Color(0.9, 0.9, 0.85)}],
]
const CAR_COLORS := [Color(0.5, 0.08, 0.06), Color(0.7, 0.7, 0.68), Color(0.15, 0.2, 0.35), Color(0.55, 0.5, 0.38), Color(0.1, 0.1, 0.1)]


func _neighbors() -> void:
	var i := 0
	for f in FAMILIES:
		var phi: float = f[0]
		var pos := polar(phi, HOUSE_R)
		var to_c := -pos.normalized()
		var h := _place_house(f[1], f[2], pos, atan2(to_c.x, to_c.z))
		_lot_extras(h, f[2], i)
		i += 1
	for f in ROAD_HOUSES:
		var side: int = f[0]
		var pos := Vector3(side * 20.0, 0, f[1])
		var rot := atan2(-side, 0.0)
		var h := _place_house(f[2], f[3], pos, rot)
		_lot_extras(h, f[3], i)
		i += 1


func _place_house(family: String, params: Dictionary, pos: Vector3, rot: float) -> NeighborHouse:
	var h := NeighborHouse.new()
	h.name = "House_" + family
	add_child(h)
	h.position = pos
	h.rotation.y = rot
	var p := params.duplicate()
	p["family"] = family
	# mailbox near the curb, in local coordinates
	var curb_dist := _distance_to_walk(pos, Vector3(sin(rot), 0, cos(rot)))
	p["mailbox"] = Vector3(-float(p.get("w", 12.0)) / 2.0 + 1.0, 0, curb_dist - 0.6)
	h.build(p)
	houses[family] = h
	WorldState.register("neighbor_" + family.to_lower(), h)
	_keepout.append({"center": Vector2(pos.x, pos.z) - Vector2(sin(rot), cos(rot)) * 5.0, "half": Vector2(14.0, 8.0), "rot": rot})
	return h


func _distance_to_walk(from: Vector3, dir: Vector3) -> float:
	var lo := 0.0
	var hi := 40.0
	for i in 30:
		var mid := (lo + hi) / 2.0
		var p := from + dir * mid
		if surface_at(p) in ["concrete", "asphalt"] and (Vector2(p.x, p.z).length() < WALK_OUT or absf(p.x) < ROAD_HALF + 2.0):
			hi = mid
		else:
			lo = mid
	return lo


func _lot_extras(h: NeighborHouse, params: Dictionary, idx: int) -> void:
	var fwd := h.global_basis.z
	var right := h.global_basis.x
	var gside: int = params.get("garage", 1)
	var w: float = params.get("w", 12.0)
	var base := h.global_position
	var dist := _distance_to_walk(base, fwd)
	if gside != 0:
		var gpos := base + right * ((w / 2.0 + 3.0) * gside)
		var dd := _distance_to_walk(gpos, fwd)
		flat(gpos + fwd * (dd / 2.0 + 0.1), Vector2(4.6, dd + 0.4), atan2(fwd.x, fwd.z), Mats.m("concrete"), "concrete", 0.03)
		if idx % 2 == 0 or idx == 5:
			var car := Vehicles.car_model(self, CAR_COLORS[idx % CAR_COLORS.size()], idx == 2)
			car.global_position = gpos + fwd * 4.2
			car.rotation.y = atan2(fwd.x, fwd.z) + PI
			B.collider(car, Vector3(1.8, 1.4, 4.6), Vector3(0, 0.7, 0))
	var door_x: float = params.get("door_x", 0.0)
	var walk_start := base + right * door_x + fwd * 1.4
	flat(walk_start + fwd * ((dist - 1.4) / 2.0), Vector2(1.1, max(0.5, dist - 1.4)), atan2(fwd.x, fwd.z), Mats.m("concrete"), "concrete", 0.03)
	# bushes along the facade
	for k in 4:
		var off := -w / 2.0 + 1.0 + k * (w - 2.0) / 3.0
		if absf(off - door_x) < 1.2:
			continue
		_bush(base + right * off + fwd * 0.9, rng.randf_range(0.45, 0.75))
	# front yard tree
	if idx != 0:
		_tree_spots.append([base + right * (-w / 2.0 - 1.5 * gside) + fwd * (dist * 0.5), rng.randf_range(0.9, 1.2)])
	else:
		_tree_spots.append([base + right * (w / 2.0 + 2.0) + fwd * (dist * 0.55), 1.15])
	# trash bins at the curb for some
	if idx % 3 == 1:
		var t := B.node(self, "Bin", base + fwd * (dist - 0.8) + right * (w / 2.0 - 1.0))
		B.box(t, Vector3(0.6, 1.0, 0.7), Vector3(0, 0.5, 0), Mats.color(Color(0.15, 0.22, 0.15), 0.6), true)
	# backyard fence
	var back := base - fwd * 10.5
	var a := back - right * (w / 2.0 + 0.5)
	var b := back + right * (w / 2.0 + 0.5)
	_fence(a, b)
	_fence(a, a - fwd * 10.0)
	_fence(b, b - fwd * 10.0)
	_fence(a - fwd * 10.0, b - fwd * 10.0)


# ------------------------------------------------------------------ lamps
func _street_lamps() -> void:
	var spots := []
	for phi: float in [30.0, 95.0, 150.0, 210.0, 265.0, 330.0]:
		spots.append([polar(phi, WALK_OUT + 0.4), phi])
	var z := 32.0
	var side := 1.0
	while z < ROAD_END:
		spots.append([Vector3(side * (ROAD_HALF + 2.3), 0, z), 90.0 if side < 0 else 270.0])
		side = -side
		z += 24.0
	var idx := 0
	for s in spots:
		var p: Vector3 = s[0]
		var arm_dir := -Vector3(p.x, 0, p.z).normalized() if idx < 6 else Vector3(-signf(p.x), 0, 0)
		_lamp(p, arm_dir, idx < 4)
		idx += 1


func _lamp(p: Vector3, arm_dir: Vector3, shadow: bool) -> void:
	var n := B.node(self, "StreetLamp", p)
	n.rotation.y = atan2(arm_dir.x, arm_dir.z)
	var pole := Mats.color(Color(0.22, 0.2, 0.18), 0.7)
	B.cyl(n, 0.07, 0.1, 6.2, Vector3(0, 3.1, 0), pole, true, Vector3.ZERO, 10)
	B.box(n, Vector3(0.06, 0.06, 1.6), Vector3(0, 6.1, 0.8), pole)
	B.box(n, Vector3(0.3, 0.12, 0.55), Vector3(0, 6.05, 1.55), pole)
	var glow := B.box(n, Vector3(0.24, 0.02, 0.45), Vector3(0, 5.98, 1.55), Mats.emissive(Color(1.0, 0.72, 0.42), 5.0))
	var l := B.spot(n, Vector3(0, 5.9, 1.55), Vector3(-90, 0, 0), Color(1.0, 0.7, 0.42), 9.0, 15.0, 62.0, shadow)
	l.spot_attenuation = 1.0
	var halo := B.omni(n, Vector3(0, 5.6, 1.55), Color(1.0, 0.72, 0.45), 0.35, 7.0, false)
	AudioManager.make_emitter(n, "lamp_buzz", Vector3(0, 5.9, 1.55), 0.0, -1.0, -1.0, true, "AmbOut")
	lamps.append({"light": l, "halo": halo, "glow": glow, "energy": l.light_energy, "node": n})
	_keepout.append({"center": Vector2(p.x, p.z), "half": Vector2(1.0, 1.0), "rot": 0.0})


# ------------------------------------------------------------------ edge
func _edge() -> void:
	# road works closing the cross road on both sides, with blinking lamps
	for s: float in [-1.0, 1.0]:
		var x: float = s * 30.0
		for k in 3:
			var bar := B.node(self, "Barricade", Vector3(x, 0, ROAD_END + 1.5 + k * 2.4))
			_barricade(bar)
		var sign_n := B.node(self, "RoadClosed", Vector3(x + s * 1.5, 0, ROAD_END + 4.0), Vector3(0, 90 * s, 0))
		B.box(sign_n, Vector3(1.4, 0.7, 0.04), Vector3(0, 1.4, 0), Mats.color(Color(0.9, 0.88, 0.8), 0.6))
		B.label(sign_n, "ROAD\nCLOSED", Vector3(0, 1.4, 0.025), 0.004, Color(0.05, 0.05, 0.05), Vector3.ZERO, 32)
		B.label(sign_n, "ROAD\nCLOSED", Vector3(0, 1.4, -0.025), 0.004, Color(0.05, 0.05, 0.05), Vector3(0, 180, 0), 32)
		for leg: float in [-0.5, 0.5]:
			B.box(sign_n, Vector3(0.05, 1.1, 0.05), Vector3(leg, 0.55, 0), Mats.m("wood_light"))
	# far side of the cross road: a ditch line of woods; a guardrail
	for i in 20:
		var x := -55.0 + i * 5.8
		B.box(self, Vector3(0.12, 0.7, 0.12), Vector3(x, 0.35, ROAD_END + 9.2), Mats.m("metal"))
	B.box(self, Vector3(116, 0.3, 0.04), Vector3(0, 0.6, ROAD_END + 9.3), Mats.m("metal"), true)


func _barricade(n: Node3D) -> void:
	var w := Mats.color(Color(0.9, 0.88, 0.82), 0.6)
	var o := Mats.color(Color(0.85, 0.35, 0.05), 0.6)
	for x: float in [-0.8, 0.8]:
		B.box(n, Vector3(0.06, 1.1, 0.5), Vector3(x, 0.55, 0), Mats.m("wood_light"), false, Vector3(0, 90, 0))
	for k in 2:
		B.box(n, Vector3(2.0, 0.22, 0.04), Vector3(0, 0.55 + k * 0.4, 0), w if k == 0 else o)
	B.collider(n, Vector3(2.0, 1.2, 0.6), Vector3(0, 0.6, 0))
	var lamp := B.sphere(n, 0.06, Vector3(0.8, 1.25, 0), Mats.emissive(Color(1.0, 0.6, 0.1), 4.0))
	var l := B.omni(n, Vector3(0.8, 1.3, 0.2), Color(1.0, 0.6, 0.15), 0.6, 4.0, false)
	var t := Timer.new()
	t.wait_time = 0.9 + randf() * 0.2
	t.autostart = true
	n.add_child(t)
	t.timeout.connect(func():
		lamp.visible = not lamp.visible
		l.visible = lamp.visible)


# ------------------------------------------------------------------ trees
func _blocked(p: Vector3, margin := 0.0) -> bool:
	var v := Vector2(p.x, p.z)
	if v.length() < WALK_OUT + 2.5 + margin:
		return true
	if absf(p.x) < ROAD_HALF + 3.0 + margin and p.z > 0 and p.z < ROAD_END + 10:
		return true
	if p.z > ROAD_END - 3.0 and p.z < ROAD_END + 10.5 and absf(p.x) < 60:
		return true
	# player house + garage footprint
	if p.x > -13.0 and p.x < 13.5 and p.z > -39.5 and p.z < -25.0:
		return true
	for k in _keepout:
		var lp: Vector2 = (v - k.center).rotated(-k.rot)
		if absf(lp.x) < k.half.x + margin and absf(lp.y) < k.half.y + margin:
			return true
	return false


func _trees() -> void:
	# scattered woods around the neighbourhood (outside lots), plus yard trees
	var forest := []
	var tries := 0
	while forest.size() < 330 and tries < 9000:
		tries += 1
		var p: Vector3
		var zone := rng.randi() % 4
		if zone <= 1:
			var a := rng.randf() * TAU
			var r := rng.randf_range(46.0, 82.0)
			p = Vector3(sin(a) * r, 0, cos(a) * r)
		elif zone == 2:
			p = Vector3(rng.randf_range(26.0, 60.0) * (1 if rng.randf() < 0.5 else -1), 0, rng.randf_range(30.0, ROAD_END))
		else:
			p = Vector3(rng.randf_range(-75.0, 75.0), 0, rng.randf_range(ROAD_END + 11.0, ROAD_END + 40.0))
		if _blocked(p, 0.5):
			continue
		var ok := true
		for q in forest:
			if q[0].distance_to(p) < 3.2:
				ok = false
				break
		if ok:
			forest.append([p, rng.randf_range(0.85, 1.45)])
	for t in _tree_spots:
		forest.append(t)
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.22
	cm.height = 5.0
	cm.radial_segments = 8
	trunk_mm.mesh = cm
	trunk_mm.instance_count = forest.size()
	var crown_mm := MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 14
	sm.rings = 8
	crown_mm.mesh = sm
	crown_mm.instance_count = forest.size() * 6
	var ci := 0
	for i in forest.size():
		var p: Vector3 = forest[i][0]
		var s: float = forest[i][1]
		var trunk_h := 5.0 * s
		trunk_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p + Vector3(0, trunk_h / 2.0 - 0.1, 0)))
		var tr := RandomNumberGenerator.new()
		tr.seed = int(p.x * 1000 + p.z)
		for k in 6:
			var off := Vector3(tr.randf_range(-1.9, 1.9), tr.randf_range(-0.9, 1.8), tr.randf_range(-1.9, 1.9)) * s
			if k == 0:
				off = Vector3(0, 0.9 * s, 0)
			var cs := tr.randf_range(1.2, 2.0) * s
			var basis := Basis(Vector3.UP, tr.randf() * TAU).scaled(Vector3(cs, cs * tr.randf_range(0.75, 1.0), cs))
			crown_mm.set_instance_transform(ci, Transform3D(basis, p + Vector3(0, trunk_h * 0.82, 0) + off))
			ci += 1
		# trunks the player can reach need collision
		if Vector2(p.x, p.z).length() < 90.0:
			var body := StaticBody3D.new()
			add_child(body)
			body.position = p + Vector3(0, 1.5, 0)
			var shape := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.25 * s
			cyl.height = 3.0
			shape.shape = cyl
			body.add_child(shape)
	var tmi := MultiMeshInstance3D.new()
	tmi.multimesh = trunk_mm
	tmi.material_override = Mats.m("bark")
	add_child(tmi)
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = crown_mm
	cmi.material_override = _foliage_mat(Color(0.5, 0.56, 0.42))
	add_child(cmi)
	# leaves rustling in a few places around the court
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		AudioManager.make_emitter(self, "leaves", polar(rad_to_deg(a), 40.0) + Vector3(0, 5, 0), 0.0, -1.0, -1.0, true, "AmbOut")


# ------------------------------------------------------------------ boundary
func _boundary() -> void:
	## Invisible limits hidden inside the woods / behind the road works.
	var R := 66.0
	var segs := 40
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var am := (a0 + a1) / 2.0
		if absf(angle_difference(am, 0.0)) < deg_to_rad(30.0):
			continue
		var p0 := Vector3(sin(a0) * R, 0, cos(a0) * R)
		var p1 := Vector3(sin(a1) * R, 0, cos(a1) * R)
		var c := (p0 + p1) / 2.0
		B.collider(self, Vector3(1.0, 8.0, p0.distance_to(p1) + 0.6), c + Vector3(0, 4, 0), Vector3(0, rad_to_deg(atan2(p1.x - p0.x, p1.z - p0.z)), 0))
	var zc := R * cos(deg_to_rad(30.0))
	var xw := R * sin(deg_to_rad(30.0))
	var z_end := ROAD_END + 10.5
	for s in [-1.0, 1.0]:
		B.collider(self, Vector3(1.0, 8.0, z_end - zc + 2.0), Vector3(s * xw, 4, (zc + z_end) / 2.0))
	B.collider(self, Vector3(xw * 2.0 + 2.0, 8.0, 1.0), Vector3(0, 4, z_end))
