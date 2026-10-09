class_name B
## Small geometry toolkit used by every builder. Keeps scene construction terse.
##
## Physics layers: 1 = world (player collides), 2 = interaction-only areas,
## 3 = loose props (player walks through them, ray still hits).

const LAYER_WORLD := 1
const LAYER_INTERACT := 2
const LAYER_PROPS := 4
const LAYER_AUDIO := 1 << 15

static var _meshes: Dictionary = {}


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _meshes[key]


static func _set_rot(n: Node3D, rot_deg: Vector3) -> void:
	if rot_deg != Vector3.ZERO:
		n.rotation_degrees = rot_deg


## A box mesh. With `collide` the mesh is wrapped in a StaticBody3D.
static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide := false,
		rot_deg := Vector3.ZERO, surface := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		if surface != "":
			body.set_meta("surface", surface)
		parent.add_child(body)
		body.position = pos
		_set_rot(body, rot_deg)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
	else:
		parent.add_child(mi)
		mi.position = pos
		_set_rot(mi, rot_deg)
	return mi


## Invisible collision box.
static func collider(parent: Node, size: Vector3, pos: Vector3, rot_deg := Vector3.ZERO, surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	if surface != "":
		body.set_meta("surface", surface)
	parent.add_child(body)
	body.position = pos
	_set_rot(body, rot_deg)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	return body


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material,
		collide := false, rot_deg := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var key := "c%s|%s|%s|%s" % [r_top, r_bot, h, segs]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = segs
		cm.rings = 1
		_meshes[key] = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		parent.add_child(body)
		body.position = pos
		_set_rot(body, rot_deg)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = max(r_top, r_bot)
		sh.height = h
		cs.shape = sh
		body.add_child(cs)
		body.add_child(mi)
	else:
		parent.add_child(mi)
		mi.position = pos
		_set_rot(mi, rot_deg)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE, segs := 16) -> MeshInstance3D:
	var key := "s%s|%s" % [r, segs]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2
		sm.radial_segments = segs
		sm.rings = segs / 2
		_meshes[key] = sm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	mi.scale = scale
	return mi


static func quad(parent: Node, size: Vector2, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	_set_rot(mi, rot_deg)
	return mi


static func label(parent: Node, text: String, pos: Vector3, px := 0.004, col := Color.WHITE, rot_deg := Vector3.ZERO,
		font_size := 32, emissive := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.modulate = col
	l.font_size = font_size
	l.outline_size = 0
	l.shaded = not emissive
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	l.position = pos
	_set_rot(l, rot_deg)
	return l


static func node(parent: Node, node_name: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	parent.add_child(n)
	n.position = pos
	_set_rot(n, rot_deg)
	return n


## Area used only by the interaction ray (player does not collide with it).
static func interact_area(parent: Node, size: Vector3, pos := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = LAYER_INTERACT
	a.collision_mask = 0
	a.monitoring = false
	parent.add_child(a)
	a.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	return a


static func omni(parent: Node, pos: Vector3, col: Color, energy: float, rng: float, shadow := false,
		attenuation := 1.4) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = attenuation
	l.shadow_enabled = shadow
	l.shadow_bias = 0.06
	l.shadow_normal_bias = 1.5
	l.light_specular = 0.35
	parent.add_child(l)
	l.position = pos
	return l


static func spot(parent: Node, pos: Vector3, rot_deg: Vector3, col: Color, energy: float, rng: float,
		angle := 45.0, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.spot_attenuation = 1.2
	l.spot_angle_attenuation = 1.5
	l.shadow_enabled = shadow
	l.shadow_bias = 0.05
	l.light_specular = 0.3
	parent.add_child(l)
	l.position = pos
	l.rotation_degrees = rot_deg
	return l


## Triangular prism mesh (used for gable ends). Points in the XY plane, extruded along Z.
static func gable(parent: Node, width: float, height: float, depth: float, pos: Vector3, mat: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width / 2.0
	var hd := depth / 2.0
	var a := Vector3(-hw, 0, 0)
	var b := Vector3(hw, 0, 0)
	var c := Vector3(0, height, 0)
	for side: float in [-1.0, 1.0]:
		var z := Vector3(0, 0, hd * side)
		if side > 0:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(a + z); st.add_vertex(b + z); st.add_vertex(c + z)
		else:
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(a + z); st.add_vertex(c + z); st.add_vertex(b + z)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.two_sided(mat)
	parent.add_child(mi)
	mi.position = pos
	_set_rot(mi, rot_deg)
	return mi


## Gable roof over a rectangle. Ridge runs along local X if `ridge_x`, else along Z.
static func roof(parent: Node, x0: float, x1: float, z0: float, z1: float, eave_y: float, rise: float,
		roof_mat: Material, gable_mat: Material, ridge_x := true, overhang := 0.45, thick := 0.14) -> Node3D:
	var root := node(parent, "Roof")
	var span: float = (z1 - z0) if ridge_x else (x1 - x0)
	var length: float = (x1 - x0) if ridge_x else (z1 - z0)
	var half := span / 2.0
	var slope_len := sqrt(half * half + rise * rise) + overhang
	var ang := rad_to_deg(atan2(rise, half))
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var mid_out := (sqrt(half * half + rise * rise) - overhang) / 2.0
	for side: float in [-1.0, 1.0]:
		# centre of the slab measured from the ridge going down the slope
		var d := (slope_len / 2.0)
		var horiz: float = cos(deg_to_rad(ang)) * d
		var vert: float = sin(deg_to_rad(ang)) * d
		var top_y := eave_y + rise
		if ridge_x:
			var p := Vector3(cx, top_y - vert + thick * 0.5, cz + side * horiz)
			box(root, Vector3(length + overhang * 2, thick, slope_len), p, roof_mat, false, Vector3(side * ang, 0, 0))
		else:
			var p := Vector3(cx + side * horiz, top_y - vert + thick * 0.5, cz)
			box(root, Vector3(slope_len, thick, length + overhang * 2), p, roof_mat, false, Vector3(0, 0, -side * ang))
	# gable triangles at both ends
	if ridge_x:
		gable(root, span, rise, 0.2, Vector3(x0 + 0.1, eave_y, cz), gable_mat, Vector3(0, 90, 0))
		gable(root, span, rise, 0.2, Vector3(x1 - 0.1, eave_y, cz), gable_mat, Vector3(0, 90, 0))
	else:
		gable(root, span, rise, 0.2, Vector3(cx, eave_y, z0 + 0.1), gable_mat)
		gable(root, span, rise, 0.2, Vector3(cx, eave_y, z1 - 0.1), gable_mat)
	return root
