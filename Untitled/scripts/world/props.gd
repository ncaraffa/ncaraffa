class_name Props
## Furniture and household object builders. Every prop is built facing +Z
## (its front) around its own origin on the floor, then rotated by `rot_y`.

const WARM := Color(1.0, 0.76, 0.5)
const WARM2 := Color(1.0, 0.82, 0.62)
const COOL := Color(0.86, 0.92, 1.0)


static func root(parent: Node, n: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	return B.node(parent, n, pos, Vector3(0, rot_y, 0))


# ------------------------------------------------------------------ bedroom
static func bed(parent: Node, pos: Vector3, rot_y: float, w := 1.4, l := 2.0, blanket := "fabric_red") -> Node3D:
	var r := root(parent, "Bed", pos, rot_y)
	var wood := Mats.m("wood_light")
	B.collider(r, Vector3(w, 0.55, l), Vector3(0, 0.275, l / 2))
	B.box(r, Vector3(w, 0.22, l), Vector3(0, 0.25, l / 2), wood)
	for x: float in [-w / 2 + 0.04, w / 2 - 0.04]:
		for z: float in [0.04, l - 0.04]:
			B.box(r, Vector3(0.07, 0.3, 0.07), Vector3(x, 0.15, z), wood)
	# headboard with slats (as in an old guest bed)
	B.box(r, Vector3(w + 0.06, 0.08, 0.06), Vector3(0, 1.0, 0.0), wood)
	for x: float in [-w / 2, w / 2]:
		B.box(r, Vector3(0.07, 1.04, 0.07), Vector3(x, 0.52, 0.0), wood)
	for i in 9:
		B.box(r, Vector3(0.05, 0.55, 0.02), Vector3(-w / 2 + 0.15 + i * (w - 0.3) / 8.0, 0.68, 0.0), wood)
	B.box(r, Vector3(w + 0.04, 0.06, 0.05), Vector3(0, 0.55, l), wood)
	B.box(r, Vector3(w - 0.04, 0.18, l - 0.08), Vector3(0, 0.44, l / 2 + 0.02), Mats.m("fabric_white"))
	B.box(r, Vector3(w + 0.02, 0.06, l * 0.62), Vector3(0, 0.55, l * 0.64), Mats.m(blanket))
	B.box(r, Vector3(w + 0.04, 0.24, l * 0.62), Vector3(0, 0.44, l * 0.64), Mats.m(blanket))
	B.box(r, Vector3(w * 0.9, 0.1, 0.4), Vector3(0, 0.58, l * 0.38), Mats.m("fabric_stripe"), false, Vector3(-4, 0, 0))
	var pw := w * 0.4 if w > 1.1 else w * 0.8
	for x in ([-w * 0.22, w * 0.22] if w > 1.1 else [0.0]):
		B.box(r, Vector3(pw, 0.12, 0.38), Vector3(x, 0.6, 0.25), Mats.m("fabric_stripe"), false, Vector3(-12, 0, 0))
	return r


static func nightstand(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := root(parent, "Nightstand", pos, rot_y)
	var wood := Mats.m("wood_dark")
	B.box(r, Vector3(0.45, 0.55, 0.4), Vector3(0, 0.275, 0), wood, true)
	B.box(r, Vector3(0.4, 0.14, 0.01), Vector3(0, 0.42, 0.2), wood)
	B.sphere(r, 0.015, Vector3(0, 0.42, 0.215), Mats.m("chrome"))
	return r


static func table_lamp(parent: Node, pos: Vector3, id: String, on: bool, shade := Color(0.95, 0.88, 0.72), energy := 1.3, shadow := true) -> LightFixture:
	var f := LightFixture.new()
	f.name = "Lamp_" + id
	parent.add_child(f)
	f.position = pos
	B.cyl(f, 0.06, 0.08, 0.04, Vector3(0, 0.02, 0), Mats.m("metal_dark"))
	B.cyl(f, 0.012, 0.012, 0.32, Vector3(0, 0.18, 0), Mats.m("metal"))
	var sh := B.cyl(f, 0.1, 0.17, 0.2, Vector3(0, 0.38, 0), Mats.emissive(shade, 0.0), false, Vector3.ZERO, 20)
	f.add_glow(sh)
	f.add_light(B.omni(f, Vector3(0, 0.36, 0), WARM, energy, 5.5, shadow))
	B.interact_area(f, Vector3(0.36, 0.5, 0.36), Vector3(0, 0.25, 0))
	f.setup(id, on, shade.lerp(WARM, 0.3), 1.6, true)
	return f


static func floor_lamp(parent: Node, pos: Vector3, id: String, on: bool, energy := 1.6) -> LightFixture:
	var f := LightFixture.new()
	f.name = "FloorLamp_" + id
	parent.add_child(f)
	f.position = pos
	B.cyl(f, 0.14, 0.16, 0.03, Vector3(0, 0.015, 0), Mats.m("metal_dark"))
	B.cyl(f, 0.012, 0.012, 1.45, Vector3(0, 0.74, 0), Mats.m("metal_dark"))
	var sh := B.cyl(f, 0.13, 0.2, 0.26, Vector3(0, 1.52, 0), Mats.emissive(Color(0.96, 0.9, 0.76), 0.0), false, Vector3.ZERO, 20)
	f.add_glow(sh)
	f.add_light(B.omni(f, Vector3(0, 1.45, 0), WARM, energy, 6.5, true))
	B.interact_area(f, Vector3(0.4, 1.7, 0.4), Vector3(0, 0.85, 0))
	f.setup(id, on, Color(1.0, 0.86, 0.66), 1.8, true)
	return f


## Ceiling dome light (driven by a wall switch).
static func ceiling_light(parent: Node, pos: Vector3, id: String, on: bool, energy := 1.4, rng := 6.0, shadow := true, style := 0) -> LightFixture:
	var f := LightFixture.new()
	f.name = "Ceiling_" + id
	parent.add_child(f)
	f.position = pos
	var g: MeshInstance3D
	match style:
		0:  # flush dome
			B.cyl(f, 0.14, 0.14, 0.02, Vector3(0, -0.01, 0), Mats.m("trim"))
			g = B.sphere(f, 0.17, Vector3(0, -0.03, 0), Mats.m("plastic_white"), Vector3(1, 0.42, 1), 20)
		1:  # bare bulb
			B.cyl(f, 0.03, 0.03, 0.08, Vector3(0, -0.04, 0), Mats.m("plastic_white"))
			g = B.sphere(f, 0.04, Vector3(0, -0.11, 0), Mats.m("plastic_white"), Vector3(1, 1.2, 1))
			B.cyl(f, 0.002, 0.002, 0.5, Vector3(0.03, -0.3, 0), Mats.m("metal"), false, Vector3.ZERO, 4)
		2:  # small chandelier
			B.cyl(f, 0.008, 0.008, 0.4, Vector3(0, -0.2, 0), Mats.m("metal_dark"))
			B.cyl(f, 0.18, 0.05, 0.06, Vector3(0, -0.42, 0), Mats.m("metal_dark"))
			g = B.cyl(f, 0.09, 0.16, 0.14, Vector3(0, -0.5, 0), Mats.m("plastic_white"), false, Vector3.ZERO, 16)
		3:  # fluorescent tube
			B.box(f, Vector3(1.2, 0.05, 0.14), Vector3(0, -0.03, 0), Mats.m("metal"))
			g = B.box(f, Vector3(1.15, 0.03, 0.06), Vector3(0, -0.07, 0), Mats.m("plastic_white"))
	f.add_glow(g)
	var col := COOL if style == 3 else WARM2
	f.add_light(B.omni(f, Vector3(0, -0.25 if style != 2 else -0.6, 0), col, energy, rng, shadow, 1.2))
	f.setup(id, on, col, 2.2)
	return f


static func wall_sconce(parent: Node, pos: Vector3, rot_y: float, id: String, on: bool, energy := 0.8, shadow := false, col := WARM) -> LightFixture:
	var f := LightFixture.new()
	f.name = "Sconce_" + id
	parent.add_child(f)
	f.position = pos
	f.rotation_degrees.y = rot_y
	B.box(f, Vector3(0.08, 0.14, 0.03), Vector3(0, 0, 0.015), Mats.m("metal_dark"))
	B.box(f, Vector3(0.02, 0.02, 0.1), Vector3(0, 0, 0.07), Mats.m("metal_dark"))
	var g := B.cyl(f, 0.05, 0.08, 0.13, Vector3(0, 0.05, 0.14), Mats.m("plastic_white"), false, Vector3.ZERO, 16)
	f.add_glow(g)
	f.add_light(B.omni(f, Vector3(0, 0.05, 0.22), col, energy, 5.0, shadow))
	f.setup(id, on, col, 2.0)
	return f


static func wardrobe(parent: Node, pos: Vector3, rot_y := 0.0, w := 1.2, h := 2.0) -> Node3D:
	var r := root(parent, "Wardrobe", pos, rot_y)
	var wm := Mats.m("wood_painted")
	B.box(r, Vector3(w, h, 0.6), Vector3(0, h / 2, 0), wm, true)
	B.box(r, Vector3(w + 0.04, 0.05, 0.64), Vector3(0, h + 0.025, 0), wm)
	var dark := Mats.color(Color(0.55, 0.52, 0.46), 0.8)
	for s: float in [-1.0, 1.0]:
		var cx := s * w / 4
		B.box(r, Vector3(w / 2 - 0.04, h - 0.1, 0.02), Vector3(cx, h / 2 + 0.03, 0.305), wm)
		# louvers
		for i in 16:
			B.box(r, Vector3(w / 2 - 0.14, 0.035, 0.012), Vector3(cx, 0.35 + i * (h - 0.6) / 16.0, 0.318), dark, false, Vector3(-30, 0, 0))
		B.box(r, Vector3(0.015, 0.12, 0.02), Vector3(cx - s * (w / 4 - 0.07), h / 2, 0.33), Mats.m("chrome"))
	return r


static func dresser(parent: Node, pos: Vector3, rot_y := 0.0, w := 1.1, h := 0.85) -> Node3D:
	var r := root(parent, "Dresser", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.box(r, Vector3(w, h, 0.48), Vector3(0, h / 2, 0), wm, true)
	for i in 3:
		var y := 0.15 + i * (h - 0.2) / 3.0 + 0.1
		B.box(r, Vector3(w - 0.08, (h - 0.2) / 3.0 - 0.03, 0.015), Vector3(0, y, 0.245), wm)
		for x: float in [-w / 4, w / 4]:
			B.box(r, Vector3(0.1, 0.015, 0.02), Vector3(x, y, 0.26), Mats.m("chrome"))
	return r


static func desk(parent: Node, pos: Vector3, rot_y := 0.0, w := 1.1, d := 0.6) -> Node3D:
	var r := root(parent, "Desk", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.collider(r, Vector3(w, 0.76, d), Vector3(0, 0.38, 0))
	B.box(r, Vector3(w, 0.035, d), Vector3(0, 0.74, 0), wm)
	B.box(r, Vector3(0.4, 0.7, d - 0.04), Vector3(w / 2 - 0.2, 0.36, 0), wm)
	for i in 3:
		B.box(r, Vector3(0.36, 0.18, 0.012), Vector3(w / 2 - 0.2, 0.15 + i * 0.22, d / 2 - 0.01), wm)
		B.box(r, Vector3(0.08, 0.012, 0.02), Vector3(w / 2 - 0.2, 0.15 + i * 0.22, d / 2 + 0.005), Mats.m("chrome"))
	B.box(r, Vector3(0.04, 0.72, 0.04), Vector3(-w / 2 + 0.03, 0.36, d / 2 - 0.03), wm)
	B.box(r, Vector3(0.04, 0.72, 0.04), Vector3(-w / 2 + 0.03, 0.36, -d / 2 + 0.03), wm)
	B.box(r, Vector3(w - 0.4, 0.3, 0.015), Vector3(-0.2, 0.55, -d / 2 + 0.02), wm)
	return r


static func simple_chair(parent: Node, pos: Vector3, rot_y: float, mat: Material, cushion: Material = null) -> Node3D:
	var r := root(parent, "Chair", pos, rot_y)
	_chair_geo(r, mat, cushion)
	B.collider(r, Vector3(0.44, 0.46, 0.44), Vector3(0, 0.23, 0))
	return r


static func _chair_geo(r: Node3D, mat: Material, cushion: Material = null) -> void:
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			B.box(r, Vector3(0.035, 0.45, 0.035), Vector3(x, 0.225, z), mat)
		B.box(r, Vector3(0.035, 0.5, 0.035), Vector3(x, 0.7, -0.19), mat)
	B.box(r, Vector3(0.44, 0.04, 0.44), Vector3(0, 0.46, 0), mat)
	if cushion:
		B.box(r, Vector3(0.4, 0.04, 0.4), Vector3(0, 0.495, 0.01), cushion)
	for i in 3:
		B.box(r, Vector3(0.38, 0.05, 0.02), Vector3(0, 0.65 + i * 0.13, -0.19), mat)


## A chair that the world (or the player) can move. Front faces +Z.
static func movable_chair(parent: Node, pos: Vector3, rot_y: float, id: String, mat: Material, cushion: Material = null) -> MovableChair:
	var c := MovableChair.new()
	c.name = "Chair_" + id
	parent.add_child(c)
	c.position = pos
	c.rotation_degrees.y = rot_y
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = B.LAYER_WORLD
	c.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.42, 0.9, 0.42)
	cs.shape = sh
	cs.position = Vector3(0, 0.45, 0)
	body.add_child(cs)
	_chair_geo(c, mat, cushion)
	c.setup(id)
	return c


static func office_chair(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := root(parent, "OfficeChair", pos, rot_y)
	var fab := Mats.m("fabric_blue")
	for i in 5:
		var a := i * TAU / 5.0
		B.box(r, Vector3(0.04, 0.03, 0.3), Vector3(sin(a) * 0.15, 0.05, cos(a) * 0.15), Mats.m("plastic_black"), false, Vector3(0, rad_to_deg(a), 0))
	B.cyl(r, 0.025, 0.025, 0.38, Vector3(0, 0.24, 0), Mats.m("chrome"))
	B.box(r, Vector3(0.46, 0.08, 0.44), Vector3(0, 0.46, 0), fab)
	B.box(r, Vector3(0.42, 0.5, 0.07), Vector3(0, 0.78, -0.22), fab, false, Vector3(-8, 0, 0))
	B.collider(r, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0))
	return r


static func bookshelf(parent: Node, pos: Vector3, rot_y := 0.0, w := 0.9, h := 1.8, d := 0.32) -> Node3D:
	var r := root(parent, "Bookshelf", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.collider(r, Vector3(w, h, d), Vector3(0, h / 2, 0))
	B.box(r, Vector3(0.02, h, d), Vector3(-w / 2 + 0.01, h / 2, 0), wm)
	B.box(r, Vector3(0.02, h, d), Vector3(w / 2 - 0.01, h / 2, 0), wm)
	B.box(r, Vector3(w, h, 0.01), Vector3(0, h / 2, -d / 2 + 0.005), wm)
	var shelves := int(h / 0.36)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 100 + pos.z * 7)
	var cols := [Color(0.45, 0.12, 0.1), Color(0.15, 0.22, 0.35), Color(0.2, 0.3, 0.2), Color(0.6, 0.55, 0.42), Color(0.3, 0.25, 0.2), Color(0.7, 0.68, 0.6)]
	for i in shelves + 1:
		var y := 0.04 + i * (h - 0.06) / shelves
		B.box(r, Vector3(w - 0.02, 0.02, d - 0.02), Vector3(0, y, 0), wm)
		if i == shelves:
			break
		var x := -w / 2 + 0.04
		while x < w / 2 - 0.08:
			var bw := rng.randf_range(0.025, 0.05)
			var bh := rng.randf_range(0.18, 0.28)
			if rng.randf() < 0.12:
				x += 0.08
				continue
			var lean := 0.0 if rng.randf() < 0.9 else 12.0
			B.box(r, Vector3(bw, bh, d * 0.7), Vector3(x + bw / 2, y + 0.01 + bh / 2, 0.01), Mats.color(cols[rng.randi() % cols.size()] * rng.randf_range(0.7, 1.1), 0.8), false, Vector3(0, 0, lean))
			x += bw + 0.003
	return r


static func rug(parent: Node, pos: Vector3, size: Vector2, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	return B.box(parent, Vector3(size.x, 0.012, size.y), pos + Vector3(0, 0.006, 0), mat, false, Vector3(0, rot_y, 0))


# ------------------------------------------------------------------ living
static func sofa(parent: Node, pos: Vector3, rot_y: float, w := 2.0, fab := "fabric_sofa") -> Node3D:
	var r := root(parent, "Sofa", pos, rot_y)
	var f := Mats.m(fab)
	B.collider(r, Vector3(w, 0.8, 0.9), Vector3(0, 0.4, 0))
	B.box(r, Vector3(w, 0.22, 0.86), Vector3(0, 0.2, 0), f)
	B.box(r, Vector3(w, 0.55, 0.22), Vector3(0, 0.55, -0.33), f, false, Vector3(-6, 0, 0))
	for s: float in [-1.0, 1.0]:
		B.box(r, Vector3(0.2, 0.36, 0.86), Vector3(s * (w / 2 - 0.1), 0.45, 0), f)
	var n := int(w / 0.65)
	for i in n:
		var cw := (w - 0.4) / n
		B.box(r, Vector3(cw - 0.02, 0.14, 0.62), Vector3(-w / 2 + 0.2 + cw * (i + 0.5), 0.38, 0.08), f)
	for x: float in [-w / 2 + 0.1, w / 2 - 0.1]:
		B.box(r, Vector3(0.05, 0.08, 0.05), Vector3(x, 0.04, 0.35), Mats.m("wood_dark"))
	B.box(r, Vector3(0.42, 0.36, 0.12), Vector3(-w / 2 + 0.45, 0.6, -0.12), Mats.m("fabric_red"), false, Vector3(-15, 20, 8))
	return r


static func armchair(parent: Node, pos: Vector3, rot_y: float, fab := "fabric_green") -> Node3D:
	var r := root(parent, "Armchair", pos, rot_y)
	var f := Mats.m(fab)
	B.collider(r, Vector3(0.85, 0.9, 0.85), Vector3(0, 0.45, 0))
	B.box(r, Vector3(0.85, 0.25, 0.8), Vector3(0, 0.22, 0), f)
	B.box(r, Vector3(0.85, 0.65, 0.2), Vector3(0, 0.62, -0.3), f, false, Vector3(-8, 0, 0))
	for s: float in [-1.0, 1.0]:
		B.box(r, Vector3(0.16, 0.34, 0.8), Vector3(s * 0.345, 0.47, 0), f)
	B.box(r, Vector3(0.55, 0.12, 0.58), Vector3(0, 0.4, 0.07), f)
	return r


static func coffee_table(parent: Node, pos: Vector3, rot_y := 0.0, w := 1.1, d := 0.55) -> Node3D:
	var r := root(parent, "CoffeeTable", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.collider(r, Vector3(w, 0.42, d), Vector3(0, 0.21, 0))
	B.box(r, Vector3(w, 0.04, d), Vector3(0, 0.4, 0), wm)
	B.box(r, Vector3(w - 0.1, 0.02, d - 0.1), Vector3(0, 0.12, 0), wm)
	for x: float in [-w / 2 + 0.05, w / 2 - 0.05]:
		for z: float in [-d / 2 + 0.05, d / 2 - 0.05]:
			B.box(r, Vector3(0.045, 0.38, 0.045), Vector3(x, 0.19, z), wm)
	return r


static func side_table(parent: Node, pos: Vector3, rot_y := 0.0, h := 0.58) -> Node3D:
	var r := root(parent, "SideTable", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.collider(r, Vector3(0.45, h, 0.45), Vector3(0, h / 2, 0))
	B.box(r, Vector3(0.45, 0.03, 0.45), Vector3(0, h - 0.015, 0), wm)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			B.box(r, Vector3(0.035, h - 0.03, 0.035), Vector3(x, (h - 0.03) / 2, z), wm)
	return r


static func tv_stand(parent: Node, pos: Vector3, rot_y := 0.0) -> Node3D:
	var r := root(parent, "TVStand", pos, rot_y)
	var wm := Mats.m("wood_dark")
	B.box(r, Vector3(1.1, 0.5, 0.5), Vector3(0, 0.25, 0), wm, true)
	B.box(r, Vector3(1.0, 0.18, 0.02), Vector3(0, 0.2, 0.25), Mats.color(Color(0.04, 0.04, 0.04), 0.2))
	# VCR
	B.box(r, Vector3(0.42, 0.09, 0.3), Vector3(-0.2, 0.17, 0.08), Mats.m("plastic_black"))
	return r


static func plant(parent: Node, pos: Vector3, h := 0.9) -> Node3D:
	var r := root(parent, "Plant", pos)
	B.cyl(r, 0.16, 0.12, 0.3, Vector3(0, 0.15, 0), Mats.color(Color(0.55, 0.3, 0.2), 0.8))
	var leaf := Mats.color(Color(0.16, 0.25, 0.12), 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31 + pos.z * 17)
	for i in 9:
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(15, 45)
		B.box(r, Vector3(0.08, h * rng.randf_range(0.5, 0.9), 0.01), Vector3(cos(a) * 0.05, 0.3 + h * 0.3, sin(a) * 0.05), leaf, false, Vector3(tilt * cos(a), rad_to_deg(a), tilt * sin(a)))
	return r


# ------------------------------------------------------------------ dining / kitchen
static func table(parent: Node, pos: Vector3, rot_y: float, w: float, d: float, h := 0.76, mat: Material = null, round_top := false) -> Node3D:
	var r := root(parent, "Table", pos, rot_y)
	var wm: Material = mat if mat else Mats.m("wood_light")
	if round_top:
		B.cyl(r, w / 2, w / 2, 0.04, Vector3(0, h - 0.02, 0), wm, false, Vector3.ZERO, 28)
		B.cyl(r, 0.04, 0.04, h - 0.04, Vector3(0, (h - 0.04) / 2, 0), wm)
		B.cyl(r, 0.25, 0.28, 0.04, Vector3(0, 0.02, 0), wm)
		B.collider(r, Vector3(w * 0.7, h, w * 0.7), Vector3(0, h / 2, 0))
	else:
		B.box(r, Vector3(w, 0.04, d), Vector3(0, h - 0.02, 0), wm)
		B.box(r, Vector3(w - 0.12, 0.08, d - 0.12), Vector3(0, h - 0.08, 0), wm)
		for x: float in [-w / 2 + 0.06, w / 2 - 0.06]:
			for z: float in [-d / 2 + 0.06, d / 2 - 0.06]:
				B.box(r, Vector3(0.06, h - 0.04, 0.06), Vector3(x, (h - 0.04) / 2, z), wm)
		B.collider(r, Vector3(w, h, d), Vector3(0, h / 2, 0))
	return r


static func counter(parent: Node, pos: Vector3, rot_y: float, w: float, top_mat: Material = null, with_doors := true) -> Node3D:
	var r := root(parent, "Counter", pos, rot_y)
	var cab := Mats.m("wood_light")
	var top: Material = top_mat if top_mat else Mats.color(Color(0.72, 0.68, 0.6), 0.35)
	B.box(r, Vector3(w, 0.86, 0.58), Vector3(0, 0.43, 0), cab, true)
	B.box(r, Vector3(w + 0.02, 0.04, 0.63), Vector3(0, 0.88, 0.02), top)
	B.box(r, Vector3(w, 0.1, 0.02), Vector3(0, 0.05, 0.27), Mats.color(Color(0.15, 0.12, 0.1)))
	if with_doors:
		var n: int = max(1, int(round(w / 0.5)))
		var dw := w / n
		for i in n:
			var x := -w / 2 + dw * (i + 0.5)
			B.box(r, Vector3(dw - 0.03, 0.14, 0.015), Vector3(x, 0.74, 0.295), cab)
			B.box(r, Vector3(dw - 0.03, 0.52, 0.015), Vector3(x, 0.38, 0.295), cab)
			B.box(r, Vector3(0.08, 0.012, 0.02), Vector3(x, 0.74, 0.31), Mats.m("chrome"))
			B.box(r, Vector3(0.012, 0.08, 0.02), Vector3(x + dw / 2 - 0.06, 0.55, 0.31), Mats.m("chrome"))
	return r


static func upper_cabinet(parent: Node, pos: Vector3, rot_y: float, w: float) -> Node3D:
	var r := root(parent, "Upper", pos, rot_y)
	var cab := Mats.m("wood_light")
	B.box(r, Vector3(w, 0.7, 0.34), Vector3(0, 0.35, 0), cab)
	var n: int = max(1, int(round(w / 0.45)))
	var dw := w / n
	for i in n:
		var x := -w / 2 + dw * (i + 0.5)
		B.box(r, Vector3(dw - 0.03, 0.66, 0.015), Vector3(x, 0.35, 0.175), cab)
		B.box(r, Vector3(0.012, 0.08, 0.02), Vector3(x + dw / 2 - 0.06, 0.1, 0.19), Mats.m("chrome"))
	return r


static func sink_basin(parent: Node, pos: Vector3, rot_y: float, w := 0.7) -> Node3D:
	var r := root(parent, "Sink", pos, rot_y)
	var st := Mats.m("chrome")
	B.box(r, Vector3(w, 0.02, 0.45), Vector3(0, -0.15, 0), st)
	B.box(r, Vector3(w, 0.16, 0.02), Vector3(0, -0.07, 0.22), st)
	B.box(r, Vector3(w, 0.16, 0.02), Vector3(0, -0.07, -0.22), st)
	B.box(r, Vector3(0.02, 0.16, 0.45), Vector3(w / 2, -0.07, 0), st)
	B.box(r, Vector3(0.02, 0.16, 0.45), Vector3(-w / 2, -0.07, 0), st)
	B.box(r, Vector3(0.02, 0.15, 0.43), Vector3(0, -0.07, 0), st)
	return r


static func stove(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	## The oven window glows orange while the stove is on (see StoveKnob).
	var r := root(parent, "Stove", pos, rot_y)
	var body := Mats.color(Color(0.86, 0.84, 0.78), 0.35)
	B.box(r, Vector3(0.76, 0.9, 0.62), Vector3(0, 0.45, 0), body, true)
	var ov := B.box(r, Vector3(0.6, 0.38, 0.02), Vector3(0, 0.38, 0.31), Mats.color(Color(0.08, 0.08, 0.08), 0.15))
	ov.name = "OvenWindow"
	r.set_meta("oven_window", ov)
	B.box(r, Vector3(0.5, 0.02, 0.03), Vector3(0, 0.62, 0.33), Mats.m("chrome"))
	B.box(r, Vector3(0.76, 0.2, 0.06), Vector3(0, 1.0, -0.28), body)
	for x: float in [-0.18, 0.18]:
		for z: float in [-0.14, 0.12]:
			B.cyl(r, 0.09, 0.09, 0.012, Vector3(x, 0.906, z), Mats.color(Color(0.1, 0.1, 0.1), 0.4), false, Vector3.ZERO, 16)
	for i in 4:
		B.cyl(r, 0.022, 0.022, 0.03, Vector3(-0.27 + i * 0.18, 0.84, 0.32), Mats.m("plastic_black"), false, Vector3(90, 0, 0), 10)
	return r


static func fridge_body(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	## Fridge cabinet without its door (the door is a Door node added by the builder).
	var r := root(parent, "Fridge", pos, rot_y)
	var body := Mats.color(Color(0.86, 0.85, 0.8), 0.3)
	B.collider(r, Vector3(0.74, 1.72, 0.7), Vector3(0, 0.86, 0))
	B.box(r, Vector3(0.74, 1.72, 0.02), Vector3(0, 0.86, -0.34), body)
	B.box(r, Vector3(0.02, 1.72, 0.7), Vector3(-0.36, 0.86, 0), body)
	B.box(r, Vector3(0.02, 1.72, 0.7), Vector3(0.36, 0.86, 0), body)
	B.box(r, Vector3(0.74, 0.02, 0.7), Vector3(0, 1.71, 0), body)
	B.box(r, Vector3(0.74, 0.08, 0.7), Vector3(0, 0.04, 0), body)
	var inner := Mats.color(Color(0.92, 0.92, 0.9), 0.5)
	B.box(r, Vector3(0.7, 1.6, 0.01), Vector3(0, 0.88, -0.32), inner)
	for i in 3:
		B.box(r, Vector3(0.68, 0.01, 0.6), Vector3(0, 0.45 + i * 0.38, 0), Mats.glass())
	# contents
	B.cyl(r, 0.05, 0.05, 0.25, Vector3(-0.2, 0.585, -0.1), Mats.color(Color(0.95, 0.95, 0.92), 0.4))
	B.box(r, Vector3(0.18, 0.12, 0.14), Vector3(0.12, 0.89, -0.05), Mats.color(Color(0.8, 0.6, 0.2), 0.6))
	B.box(r, Vector3(0.12, 0.2, 0.08), Vector3(-0.15, 1.31, 0.0), Mats.color(Color(0.3, 0.5, 0.7), 0.5))
	B.cyl(r, 0.04, 0.04, 0.18, Vector3(0.2, 1.27, 0.05), Mats.color(Color(0.6, 0.2, 0.15), 0.4))
	return r


static func microwave(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := root(parent, "Microwave", pos, rot_y)
	B.box(r, Vector3(0.48, 0.28, 0.36), Vector3(0, 0.14, 0), Mats.color(Color(0.82, 0.8, 0.76), 0.4))
	B.box(r, Vector3(0.3, 0.2, 0.01), Vector3(-0.06, 0.14, 0.181), Mats.color(Color(0.05, 0.05, 0.05), 0.15))
	B.box(r, Vector3(0.1, 0.22, 0.01), Vector3(0.17, 0.14, 0.181), Mats.color(Color(0.2, 0.2, 0.2), 0.5))
	return r


static func toaster(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := root(parent, "Toaster", pos, rot_y)
	B.box(r, Vector3(0.26, 0.18, 0.16), Vector3(0, 0.09, 0), Mats.m("chrome"))
	B.box(r, Vector3(0.2, 0.01, 0.03), Vector3(0, 0.18, 0.03), Mats.m("black"))
	B.box(r, Vector3(0.2, 0.01, 0.03), Vector3(0, 0.18, -0.03), Mats.m("black"))
	return r


# ------------------------------------------------------------------ bathroom / laundry
static func toilet(parent: Node, pos: Vector3, rot_y: float) -> Node3D:
	var r := root(parent, "Toilet", pos, rot_y)
	var p := Mats.m("porcelain")
	B.collider(r, Vector3(0.4, 0.75, 0.7), Vector3(0, 0.375, 0.1))
	B.box(r, Vector3(0.44, 0.38, 0.18), Vector3(0, 0.6, -0.15), p)
	B.cyl(r, 0.12, 0.15, 0.38, Vector3(0, 0.19, 0.1), p, false, Vector3.ZERO, 16)
	B.cyl(r, 0.19, 0.19, 0.04, Vector3(0, 0.41, 0.15), p, false, Vector3.ZERO, 20)
	B.cyl(r, 0.19, 0.19, 0.02, Vector3(0, 0.44, 0.15), Mats.color(Color(0.95, 0.94, 0.9), 0.3), false, Vector3.ZERO, 20)
	return r


static func bathtub(parent: Node, pos: Vector3, rot_y: float, l := 1.6) -> Node3D:
	var r := root(parent, "Bathtub", pos, rot_y)
	var p := Mats.m("porcelain")
	B.box(r, Vector3(l, 0.08, 0.75), Vector3(0, 0.04, 0), p, true)
	B.box(r, Vector3(l, 0.55, 0.06), Vector3(0, 0.275, 0.345), p, true)
	B.box(r, Vector3(l, 0.55, 0.06), Vector3(0, 0.275, -0.345), p, true)
	B.box(r, Vector3(0.06, 0.55, 0.75), Vector3(l / 2 - 0.03, 0.275, 0), p, true)
	B.box(r, Vector3(0.06, 0.55, 0.75), Vector3(-l / 2 + 0.03, 0.275, 0), p, true)
	# shower curtain + rod
	B.cyl(r, 0.012, 0.012, l, Vector3(0, 1.95, 0.36), Mats.m("chrome"), false, Vector3(0, 0, 90), 8)
	var cm := Mats.color(Color(0.75, 0.82, 0.8), 0.6)
	for i in 8:
		B.box(r, Vector3(l * 0.6 / 8.0 * 1.1, 1.35, 0.02), Vector3(l / 2 - 0.06 - i * l * 0.6 / 8.0, 1.25, 0.37 + (0.015 if i % 2 == 0 else -0.015)), cm)
	# faucet
	B.cyl(r, 0.02, 0.02, 0.15, Vector3(-l / 2 + 0.1, 0.62, 0), Mats.m("chrome"), false, Vector3(0, 0, 90), 8)
	return r


static func vanity(parent: Node, pos: Vector3, rot_y: float, w := 0.9) -> Node3D:
	var r := root(parent, "Vanity", pos, rot_y)
	B.box(r, Vector3(w, 0.8, 0.5), Vector3(0, 0.4, 0), Mats.m("wood_painted"), true)
	B.box(r, Vector3(w + 0.02, 0.04, 0.53), Vector3(0, 0.82, 0.01), Mats.color(Color(0.85, 0.83, 0.78), 0.2))
	B.cyl(r, 0.18, 0.15, 0.03, Vector3(0, 0.84, 0.03), Mats.m("porcelain"), false, Vector3.ZERO, 20)
	for x: float in [-w / 4, w / 4]:
		B.box(r, Vector3(w / 2 - 0.04, 0.6, 0.015), Vector3(x, 0.38, 0.255), Mats.m("wood_painted"))
	return r


static func mirror(parent: Node, pos: Vector3, rot_y: float, size := Vector2(0.6, 0.8)) -> Node3D:
	var r := root(parent, "Mirror", pos, rot_y)
	B.box(r, Vector3(size.x + 0.05, size.y + 0.05, 0.02), Vector3(0, 0, 0.01), Mats.m("trim"))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.55, 0.55)
	m.metallic = 1.0
	m.roughness = 0.04
	B.box(r, Vector3(size.x, size.y, 0.005), Vector3(0, 0, 0.023), m)
	return r


static func washer(parent: Node, pos: Vector3, rot_y: float, dryer := false) -> Node3D:
	var r := root(parent, "Dryer" if dryer else "Washer", pos, rot_y)
	var w := Mats.color(Color(0.9, 0.9, 0.87), 0.3)
	B.box(r, Vector3(0.68, 0.9, 0.66), Vector3(0, 0.45, 0), w, true)
	B.box(r, Vector3(0.68, 0.14, 0.08), Vector3(0, 0.97, -0.29), w)
	if dryer:
		B.box(r, Vector3(0.5, 0.35, 0.015), Vector3(0, 0.55, 0.335), Mats.color(Color(0.8, 0.8, 0.77), 0.4))
	else:
		B.box(r, Vector3(0.5, 0.01, 0.5), Vector3(0, 0.905, 0.02), Mats.color(Color(0.8, 0.8, 0.77), 0.4))
	B.cyl(r, 0.03, 0.03, 0.03, Vector3(0.2, 0.97, -0.24), Mats.m("plastic_black"), false, Vector3(90, 0, 0), 10)
	return r


static func water_heater(parent: Node, pos: Vector3) -> Node3D:
	var r := root(parent, "WaterHeater", pos)
	B.cyl(r, 0.28, 0.28, 1.5, Vector3(0, 0.75, 0), Mats.color(Color(0.75, 0.74, 0.68), 0.5), true, Vector3.ZERO, 20)
	B.cyl(r, 0.03, 0.03, 0.9, Vector3(0.12, 1.95, 0), Mats.m("metal"))
	B.cyl(r, 0.03, 0.03, 0.9, Vector3(-0.12, 1.95, 0), Mats.m("metal"))
	return r


static func shelf_unit(parent: Node, pos: Vector3, rot_y: float, w := 1.0, h := 1.8, d := 0.4, metal := false) -> Node3D:
	var r := root(parent, "Shelves", pos, rot_y)
	var m := Mats.m("metal") if metal else Mats.m("wood_light")
	B.collider(r, Vector3(w, h, d), Vector3(0, h / 2, 0))
	for x: float in [-w / 2 + 0.02, w / 2 - 0.02]:
		for z: float in [-d / 2 + 0.02, d / 2 - 0.02]:
			B.box(r, Vector3(0.03, h, 0.03), Vector3(x, h / 2, z), m)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 13 + pos.z * 29)
	for i in 4:
		var y := 0.1 + i * (h - 0.15) / 3.0
		B.box(r, Vector3(w, 0.02, d), Vector3(0, y, 0), m)
		if i < 3:
			var x := -w / 2 + 0.06
			while x < w / 2 - 0.15:
				var bw := rng.randf_range(0.15, 0.32)
				var bh := rng.randf_range(0.12, 0.35)
				if x + bw > w / 2 - 0.03:
					break
				B.box(r, Vector3(bw, bh, d * rng.randf_range(0.6, 0.9)), Vector3(x + bw / 2, y + 0.01 + bh / 2, 0), Mats.color(Color(0.6, 0.48, 0.32).lerp(Color(0.8, 0.78, 0.7), rng.randf()) , 0.9), false, Vector3(0, rng.randf_range(-6, 6), 0))
				x += bw + rng.randf_range(0.02, 0.1)
	return r


static func boxes(parent: Node, pos: Vector3, count := 3, seed := 1) -> Node3D:
	var r := root(parent, "Boxes", pos)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var y := 0.0
	var card := Mats.color(Color(0.62, 0.48, 0.32), 0.95)
	for i in count:
		var s := Vector3(rng.randf_range(0.4, 0.6), rng.randf_range(0.28, 0.42), rng.randf_range(0.35, 0.5))
		B.box(r, s, Vector3(rng.randf_range(-0.05, 0.05), y + s.y / 2, rng.randf_range(-0.05, 0.05)), card, i == 0, Vector3(0, rng.randf_range(-12, 12), 0))
		B.box(r, Vector3(s.x * 0.98, 0.002, 0.06), Vector3(0, y + s.y + 0.001, 0), Mats.color(Color(0.75, 0.7, 0.55), 0.4))
		y += s.y
	if count > 0:
		B.collider(r, Vector3(0.6, y, 0.5), Vector3(0, y / 2, 0))
	return r


static func coats(parent: Node, pos: Vector3, rot_y: float, w := 1.6) -> Node3D:
	var r := root(parent, "Coats", pos, rot_y)
	B.cyl(r, 0.012, 0.012, w, Vector3(0, 1.7, 0), Mats.m("chrome"), false, Vector3(0, 0, 90), 8)
	var cols := ["fabric_blue", "fabric_sofa", "fabric_red", "fabric_green", "fabric_stripe"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x := -w / 2 + 0.15
	var i := 0
	while x < w / 2 - 0.15:
		var h := rng.randf_range(0.7, 1.05)
		B.box(r, Vector3(0.08, h, 0.42), Vector3(x, 1.68 - h / 2, 0), Mats.m(cols[i % cols.size()]), false, Vector3(0, rng.randf_range(-8, 8), 0))
		x += rng.randf_range(0.1, 0.18)
		i += 1
	B.box(r, Vector3(w, 0.02, 0.4), Vector3(0, 1.9, 0), Mats.m("wood_light"))
	return r


static func smoke_detector(parent: Node, pos: Vector3) -> void:
	B.cyl(parent, 0.07, 0.07, 0.035, pos + Vector3(0, -0.018, 0), Mats.m("plastic_white"), false, Vector3.ZERO, 16)
	var led := B.sphere(parent, 0.005, pos + Vector3(0.03, -0.037, 0), Mats.emissive(Color(1, 0.1, 0.05), 3.0, true))
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	led.add_child(t)
	var on := [true]
	t.timeout.connect(func():
		on[0] = not on[0]
		led.visible = on[0] or randf() < 0.1)


static func thermostat(parent: Node, pos: Vector3, rot_y: float) -> void:
	var r := root(parent, "Thermostat", pos, rot_y)
	B.cyl(r, 0.055, 0.055, 0.03, Vector3(0, 0, 0.015), Mats.color(Color(0.8, 0.78, 0.72), 0.5), false, Vector3(90, 0, 0), 20)
	B.cyl(r, 0.035, 0.035, 0.006, Vector3(0, 0, 0.032), Mats.color(Color(0.9, 0.85, 0.6), 0.3), false, Vector3(90, 0, 0), 20)


static func towel(parent: Node, pos: Vector3, rot_y: float, col := "fabric_blue") -> void:
	var r := root(parent, "Towel", pos, rot_y)
	B.cyl(r, 0.01, 0.01, 0.6, Vector3(0, 0, 0.04), Mats.m("chrome"), false, Vector3(0, 0, 90), 6)
	B.box(r, Vector3(0.45, 0.6, 0.03), Vector3(0, -0.28, 0.05), Mats.m(col))


static func mug(parent: Node, pos: Vector3, id: String, col := Color(0.8, 0.75, 0.65)) -> Pickup:
	var p := Pickup.new()
	p.name = "Mug_" + id
	parent.add_child(p)
	p.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.045
	sh.height = 0.1
	cs.shape = sh
	cs.position.y = 0.05
	p.add_child(cs)
	B.cyl(p, 0.045, 0.04, 0.1, Vector3(0, 0.05, 0), Mats.color(col, 0.3), false, Vector3.ZERO, 14)
	B.box(p, Vector3(0.012, 0.06, 0.04), Vector3(0.055, 0.05, 0), Mats.color(col, 0.3))
	B.cyl(p, 0.038, 0.038, 0.005, Vector3(0, 0.09, 0), Mats.color(Color(0.18, 0.1, 0.05), 0.2), false, Vector3.ZERO, 12)
	p.setup(id, 0.3)
	return p


static func pickup_box(parent: Node, pos: Vector3, id: String, size: Vector3, mat: Material, mass := 0.5) -> Pickup:
	var p := Pickup.new()
	p.name = "Item_" + id
	parent.add_child(p)
	p.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y / 2
	p.add_child(cs)
	B.box(p, size, Vector3(0, size.y / 2, 0), mat)
	p.setup(id, mass)
	return p


static func can(parent: Node, pos: Vector3, id: String, col: Color) -> Pickup:
	var p := Pickup.new()
	p.name = "Can_" + id
	parent.add_child(p)
	p.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.033
	sh.height = 0.12
	cs.shape = sh
	cs.position.y = 0.06
	p.add_child(cs)
	B.cyl(p, 0.033, 0.033, 0.12, Vector3(0, 0.06, 0), Mats.color(col, 0.3, 0.6), false, Vector3.ZERO, 12)
	p.setup(id, 0.2)
	return p
