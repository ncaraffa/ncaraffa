class_name Vehicles
## Car geometry (front faces local +Z) shared by parked and moving cars.


static func car_model(parent: Node, paint: Color, wagon := false) -> Node3D:
	var r := Node3D.new()
	r.name = "Car"
	parent.add_child(r)
	var body := Mats.color(paint, 0.35, 0.4)
	var glass := Mats.color(Color(0.03, 0.04, 0.05), 0.05, 0.4)
	var dark := Mats.color(Color(0.05, 0.05, 0.05), 0.6)
	var chrome := Mats.m("chrome")
	var L := 4.6
	B.box(r, Vector3(1.78, 0.55, L), Vector3(0, 0.55, 0), body)
	B.box(r, Vector3(1.8, 0.12, L * 0.98), Vector3(0, 0.33, 0), dark)
	# hood slope + trunk
	B.box(r, Vector3(1.74, 0.08, 1.2), Vector3(0, 0.85, 1.6), body, false, Vector3(4, 0, 0))
	var cab_len := 2.9 if wagon else 2.2
	var cab_z := -0.45 if wagon else -0.15
	B.box(r, Vector3(1.6, 0.52, cab_len), Vector3(0, 1.08, cab_z), glass)
	B.box(r, Vector3(1.62, 0.06, cab_len + 0.05), Vector3(0, 1.36, cab_z), body)
	# pillars
	for x: float in [-0.8, 0.8]:
		for zz: float in [cab_z + cab_len / 2 - 0.05, cab_z - cab_len / 2 + 0.05, cab_z + 0.15]:
			B.box(r, Vector3(0.05, 0.52, 0.08), Vector3(x, 1.08, zz), body)
	# bumpers
	B.box(r, Vector3(1.82, 0.16, 0.12), Vector3(0, 0.42, L / 2 + 0.03), chrome)
	B.box(r, Vector3(1.82, 0.16, 0.12), Vector3(0, 0.42, -L / 2 - 0.03), chrome)
	B.box(r, Vector3(0.7, 0.18, 0.02), Vector3(0, 0.62, L / 2 + 0.005), Mats.color(Color(0.1, 0.1, 0.1), 0.3, 0.6))
	# wheels
	for x: float in [-0.84, 0.84]:
		for z: float in [1.4, -1.45]:
			var w := B.cyl(r, 0.33, 0.33, 0.24, Vector3(x, 0.33, z), Mats.m("rubber"), false, Vector3(0, 0, 90), 16)
			w.name = "Wheel"
			B.cyl(r, 0.18, 0.18, 0.25, Vector3(x, 0.33, z), Mats.color(Color(0.6, 0.6, 0.6), 0.3, 0.8), false, Vector3(0, 0, 90), 12)
	# lamps
	var hl: Array = []
	var tl: Array = []
	for x: float in [-0.65, 0.65]:
		hl.append(B.box(r, Vector3(0.32, 0.14, 0.03), Vector3(x, 0.68, L / 2 + 0.005), Mats.color(Color(0.85, 0.85, 0.8), 0.2)))
		tl.append(B.box(r, Vector3(0.3, 0.14, 0.03), Vector3(x, 0.7, -L / 2 - 0.005), Mats.color(Color(0.35, 0.05, 0.04), 0.3)))
	r.set_meta("headlights", hl)
	r.set_meta("taillights", tl)
	# license plate
	B.box(r, Vector3(0.32, 0.16, 0.01), Vector3(0, 0.5, -L / 2 - 0.1), Mats.color(Color(0.85, 0.85, 0.8), 0.6))
	return r


static func set_lamps(model: Node3D, on: bool) -> void:
	for m in model.get_meta("headlights", []):
		m.material_override = Mats.emissive(Color(1.0, 0.95, 0.82), 4.0) if on else Mats.color(Color(0.85, 0.85, 0.8), 0.2)
	for m in model.get_meta("taillights", []):
		m.material_override = Mats.emissive(Color(0.9, 0.06, 0.04), 2.5) if on else Mats.color(Color(0.35, 0.05, 0.04), 0.3)
