class_name NeighborHouse
extends Node3D
## Exterior-only neighbour house. Front centre at local origin, facing +Z.
## Its windows can be lit or dark; that is how the neighbourhood "lives".

var family := ""
var windows: Array = []   # [{glow: MeshInstance3D, light: OmniLight3D, on: bool}]
var porch: OmniLight3D
var porch_glow: MeshInstance3D
var porch_on := false
var _lit_mat: Material
var _dark_mat: Material


func build(params: Dictionary) -> void:
	family = params.get("family", "")
	set_process(false)
	var w: float = params.get("w", 13.0)
	var d: float = params.get("d", 9.5)
	var h := 2.8
	var siding := Mats.m(params.get("siding", "siding_gray"))
	var trim := Mats.m("trim")
	var rng := RandomNumberGenerator.new()
	rng.seed = params.get("seed", 1)
	_lit_mat = Mats.emissive(Color(1.0, 0.72, 0.42), 1.6)
	var dm := Mats.m("dark_window")
	_dark_mat = dm
	var garage_side: int = params.get("garage", 1)   # -1 left, 1 right, 0 none
	var gw := 6.0
	var body_x0 := -w / 2.0
	var body_x1 := w / 2.0
	# body
	B.box(self, Vector3(w, h, d), Vector3(0, h / 2 + 0.3, -d / 2), siding, true)
	B.box(self, Vector3(w + 0.04, 0.32, d + 0.04), Vector3(0, 0.16, -d / 2), Mats.m("concrete"))
	if params.get("brick", false):
		B.box(self, Vector3(w + 0.03, 1.0, d + 0.03), Vector3(0, 0.8, -d / 2), Mats.m("brick"))
	var roof_mat := Mats.m("shingles")
	var ridge_x: bool = params.get("ridge_x", true)
	B.roof(self, body_x0, body_x1, -d, 0.0, h + 0.3, params.get("rise", 2.0), roof_mat, siding, ridge_x, 0.45)
	# garage
	if garage_side != 0:
		var gx := (w / 2.0 + gw / 2.0) * garage_side
		B.box(self, Vector3(gw, h - 0.2, 7.0), Vector3(gx, (h - 0.2) / 2 + 0.05, -3.6), siding, true)
		B.box(self, Vector3(gw - 0.8, 2.2, 0.06), Vector3(gx, 1.15, -0.08), Mats.textured("siding_white", 2.0, 0.8, "", true, Color(0.9, 0.9, 0.86)))
		for i in 4:
			B.box(self, Vector3(gw - 0.8, 0.02, 0.08), Vector3(gx, 0.5 + i * 0.45, -0.06), Mats.color(Color(0.7, 0.7, 0.68), 0.6))
		B.roof(self, gx - gw / 2.0, gx + gw / 2.0, -7.1, -0.1, h - 0.15, 1.3, roof_mat, siding, false, 0.35)
		_add_window(Vector3(gx + garage_side * (gw / 2.0 + 0.0), 1.6, -3.6), 90.0 * garage_side, Vector2(0.8, 0.7), rng.randf() < 0.1)
	# front door + porch light
	var door_x: float = params.get("door_x", -1.5)
	set_meta("door_x", door_x)
	var door_col: Color = params.get("door_col", Color(0.35, 0.12, 0.1))
	B.box(self, Vector3(1.0, 2.1, 0.06), Vector3(door_x, 1.35, 0.01), Mats.color(door_col, 0.5))
	B.box(self, Vector3(1.16, 2.2, 0.04), Vector3(door_x, 1.4, 0.0), trim)
	B.sphere(self, 0.03, Vector3(door_x + 0.35, 1.3, 0.06), Mats.m("chrome"))
	B.box(self, Vector3(2.4, 0.16, 1.5), Vector3(door_x, 0.08, 0.75), Mats.m("concrete"), true, Vector3.ZERO, "concrete")
	if params.has("number"):
		B.label(self, str(params.number), Vector3(door_x - 0.85, 1.85, 0.03), 0.005, Color(0.85, 0.82, 0.75), Vector3.ZERO, 40)
	porch_glow = B.cyl(self, 0.06, 0.08, 0.16, Vector3(door_x + 0.8, 2.05, 0.12), Mats.m("plastic_white"), false, Vector3.ZERO, 10)
	porch = B.omni(self, Vector3(door_x + 0.8, 2.0, 0.45), Color(1.0, 0.78, 0.5), 0.9, 7.0, false)
	set_porch(params.get("porch", true))
	# windows: front
	var n_front: int = params.get("front_windows", 3)
	var xs := []
	for i in n_front:
		var x := body_x0 + (i + 1) * w / (n_front + 1)
		if absf(x - door_x) < 1.3:
			x += 1.5 * signf(x - door_x + 0.01)
		xs.append(x)
	for x in xs:
		_add_window(Vector3(x, 1.75, 0.0), 0.0, Vector2(1.2, 1.25), rng.randf() < 0.35)
		if params.get("shutters", false):
			for s: float in [-1.0, 1.0]:
				B.box(self, Vector3(0.45, 1.35, 0.04), Vector3(x + s * 0.85, 1.75, 0.03), Mats.color(params.get("shutter_col", Color(0.15, 0.18, 0.2)), 0.7))
	# sides and back
	for s: float in [-1.0, 1.0]:
		if garage_side != 0 and s == garage_side:
			continue
		_add_window(Vector3(s * w / 2.0, 1.75, -d * 0.35), 90.0 * s, Vector2(1.0, 1.2), rng.randf() < 0.3)
		_add_window(Vector3(s * w / 2.0, 1.75, -d * 0.75), 90.0 * s, Vector2(1.0, 1.2), rng.randf() < 0.2)
	for i in 3:
		_add_window(Vector3(body_x0 + (i + 1) * w / 4.0, 1.75, -d), 180.0, Vector2(1.1, 1.2), rng.randf() < 0.25)
	# mailbox at the curb
	if params.has("mailbox"):
		var mb_pos: Vector3 = params.mailbox
		var mb := B.node(self, "Mailbox", mb_pos)
		B.box(mb, Vector3(0.08, 1.05, 0.08), Vector3(0, 0.52, 0), Mats.m("wood_dark"), true)
		B.box(mb, Vector3(0.24, 0.22, 0.48), Vector3(0, 1.15, 0), Mats.color(params.get("mailbox_col", Color(0.15, 0.15, 0.16)), 0.4, 0.5))
		B.box(mb, Vector3(0.02, 0.15, 0.04), Vector3(0.13, 1.25, -0.1), Mats.color(Color(0.7, 0.1, 0.08), 0.5))
		for side: float in [-1.0, 1.0]:
			B.label(mb, family.to_upper(), Vector3(side * 0.123, 1.15, 0), 0.0017, Color(0.92, 0.9, 0.85), Vector3(0, 90 * side, 0), 32)


func _add_window(pos: Vector3, rot_y: float, size: Vector2, lit: bool) -> void:
	var r := B.node(self, "Win", pos, Vector3(0, rot_y, 0))
	var trim := Mats.m("trim")
	B.box(r, Vector3(size.x + 0.14, size.y + 0.14, 0.05), Vector3(0, 0, 0.02), trim)
	B.box(r, Vector3(size.x + 0.25, 0.05, 0.12), Vector3(0, -size.y / 2 - 0.08, 0.06), trim)
	var glow := B.box(r, Vector3(size.x, size.y, 0.01), Vector3(0, 0, 0.05), _dark_mat)
	B.box(r, Vector3(0.04, size.y, 0.02), Vector3(0, 0, 0.058), trim)
	B.box(r, Vector3(size.x, 0.04, 0.02), Vector3(0, 0, 0.058), trim)
	var l := B.omni(r, Vector3(0, -0.2, 0.9), Color(1.0, 0.72, 0.45), 0.55, 5.0, false)
	var sil := B.quad(r, Vector2(size.x * 0.55, size.y * 0.95), Vector3(randf_range(-0.15, 0.15) * size.x, -0.03, 0.056), _sil_mat())
	sil.visible = false
	var entry := {"glow": glow, "light": l, "on": false, "sil": sil}
	windows.append(entry)
	_set_entry(entry, lit)


func _set_entry(e: Dictionary, on: bool) -> void:
	e.on = on
	var gm: MeshInstance3D = e.glow
	if on:
		var m := StandardMaterial3D.new()
		m.albedo_texture = Mats.tex("window_glow")
		m.emission_enabled = true
		m.emission_texture = Mats.tex("window_glow")
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = randf_range(0.9, 1.6)
		m.albedo_color = Color(1, 1, 1)
		gm.material_override = m
	else:
		gm.material_override = _dark_mat
	e.light.visible = on


static var _silm: StandardMaterial3D


static func _sil_mat() -> StandardMaterial3D:
	if _silm == null:
		_silm = StandardMaterial3D.new()
		_silm.albedo_texture = Mats.tex("silhouette")
		_silm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_silm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_silm.albedo_color = Color(1, 1, 1, 0.92)
	return _silm


## A shape stands behind the curtain of window i for `secs` seconds.
func show_silhouette(i: int, secs: float) -> void:
	if i < 0 or i >= windows.size():
		return
	var e: Dictionary = windows[i]
	if not e.on:
		set_window(i, true)
	e.sil.visible = true
	WorldState.set_state("neighbor/%s/silhouette" % family, i)
	await get_tree().create_timer(secs, false).timeout
	e.sil.visible = false
	WorldState.set_state("neighbor/%s/silhouette" % family, -1)


var _candle_t := 0.0
var _candles := false


## Candlelight: front windows lit with a warm, unsteady flicker.
func candles(on: bool) -> void:
	_candles = on
	for i in min(4, windows.size()):
		set_window(i, on)
	set_process(on)


func _process(delta: float) -> void:
	if not _candles:
		return
	_candle_t += delta
	for i in min(4, windows.size()):
		var e: Dictionary = windows[i]
		e.light.light_energy = 0.4 + 0.25 * sin(_candle_t * (7.0 + i)) * sin(_candle_t * (3.1 + i * 0.7)) + randf() * 0.1
		e.light.light_color = Color(1.0, 0.55, 0.25)


func set_window(i: int, on: bool) -> void:
	if i >= 0 and i < windows.size():
		_set_entry(windows[i], on)
		WorldState.set_state("neighbor/%s/window%d" % [family, i], on)


func window_count() -> int:
	return windows.size()


func lit_count() -> int:
	var n := 0
	for w in windows:
		if w.on:
			n += 1
	return n


func set_porch(on: bool) -> void:
	porch_on = on
	porch.visible = on
	porch_glow.material_override = Mats.emissive(Color(1.0, 0.8, 0.55), 3.0) if on else Mats.m("plastic_white")
	WorldState.set_state("neighbor/%s/porch" % family, on)
