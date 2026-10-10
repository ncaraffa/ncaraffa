class_name CultEvidence
extends Node
## Traces of the Larkspur Court Association.
##
## Two very different kinds of things live here:
##
## PERMANENT CLUES — the history book, the association photo, the letters in the
##   mailbox, the file on the computer, the altered hall photograph, an old
##   scratch in the closet, burnt-out stubs on the patio. Ordinary objects with
##   a story. They stay.
##
## MANIFESTATIONS — altars, candle rings, chalk circles, symbols, writing.
##   They are never part of the decoration. Each one has its own lifetime:
##     "night"   stays through the night, gone by the next one
##     "timed"   lasts a few minutes, then goes the next time nobody is looking
##     "return"  once you've seen it and left the room, it is gone when you come back
##     "glance"  gone the moment you look away
##   Every one of them is cleared at the transition between nights
##   (clear_temporary), whatever its lifetime.
##
## Nothing here says what the Association is, or whether it has anything to do
## with what walks around at night.

const BOOK := "LARKSPUR COURT\nA Neighborhood History (1981)\n\n...the court was laid out in 1958 on what had been the Halloway orchard. The founding families formed the Larkspur Court Association that same year, and its evening gatherings, held in turn at each home, were a fixture of the street for decades.\n\nOlder residents recall the singing on summer nights, and the custom of leaving one chair empty at every gathering \"for whoever had not yet arrived.\"\n\nThe fire at no. 6 in the autumn of 1979 ended the gatherings for a time.\n\n(the next pages have been cut out)"
const PHOTO_BACK := "on the back, in pencil:\n\nLarkspur Ct. Assn. — midsummer '74\nWhitcomb, Halloway, Leland, Pruitt, Baptiste, Kowalski, Haines\n\n\"everyone came\""

const MAIL := {
	1: "LARKSPUR ELECTRIC & GAS\nAccount: R. HALLOWAY - 14 Larkspur Ct.\n\nAmount due: $71.40\nThis is a reminder. If you have already paid, thank you.",
	2: "LARKSPUR COURT ASSOCIATION\n\nDear neighbor at number 14,\n\nWe meet on Thursdays, after dark, as we always have. We have kept your chair.\nThe circle has been incomplete for a long time.\n\nPlease don't be alarmed by the singing.\n\n- M. Leland, no. 6",
	3: "(no stamp. torn from a notebook, pencil)\n\ndon't say it out loud.\nspell it.\nthey only listen to words.\n\n- W.",
	4: "COUNTY RECORD - photocopy\n\nOct. 30, 1979. A fire at a home on Larkspur Court was ruled accidental. Residents described \"a gathering\" held that evening. No one was injured. The family at no. 6 declined to comment.\n\n(someone circled \"No one was injured\")",
	5: "(an envelope with nothing inside.\non the back someone drew a broken circle,\na line through it, splitting at the bottom,\nand three short marks.)",
}

const CIRCLE_TXT := "THE CIRCLE OF LARKSPUR COURT\n\n 6  LELAND      present\n 9  WHITCOMB    present\n12  PRUITT      present\n16  OCAMPO      present\n 3  HAINES      present\n 5  BAPTISTE    present\n 7  KOWALSKI    present\n11  FERRARO     present\n14  HALLOWAY    ---- pending ----\n\nthe chair is kept.\nthe circle closes when fourteen answers."

## Rooms (house-local x/z) used by the "return" lifetime.
const ROOMS := {
	"b1": Rect2(0.0, 0.0, 4.2, 5.0), "b2": Rect2(0.0, 5.0, 4.2, 6.0), "hall": Rect2(4.2, 2.8, 1.4, 5.4),
	"bath": Rect2(4.2, 0.0, 3.4, 2.8), "dining": Rect2(7.6, 0.0, 3.4, 6.2), "kitchen": Rect2(11.0, 0.0, 5.0, 6.2),
	"living": Rect2(7.6, 6.2, 8.4, 4.8), "foyer": Rect2(4.2, 8.2, 3.4, 2.8), "garage": Rect2(16.0, 2.0, 6.5, 9.0),
}

## What appears later in the night (night -> [[kind, delay_min, delay_max]]).
const LATER := {
	2: [["mirror_sigil", 240.0, 480.0]],
	3: [["inverted_cross", 300.0, 540.0], ["kitchen_circle", 420.0, 700.0]],
	4: [["dining_ritual", 240.0, 420.0], ["wardrobe_sigil", 480.0, 760.0]],
	5: [["mirror_sigil", 200.0, 380.0], ["kitchen_circle", 360.0, 560.0], ["dining_ritual", 520.0, 800.0]],
}

var stage := 0
var temps: Array = []        # [{node, kind, mode, until, room, center, seen, seen_at, away}]
var _later: Array = []       # [{at, kind}]
var _candle_lights: Array = []
var _t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "CultEvidence"
	rng.randomize()
	WorldState.register("cult", self)


func _house() -> House:
	return WorldState.get_obj("house") as House


func _decal(parent: Node3D, tex: String, local_pos: Vector3, rot: Vector3, size: float, alpha := 0.85, tint := Color.WHITE) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mats.tex(tex)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.roughness = 1.0
	return B.quad(parent, Vector2(size, size), local_pos, m, rot)


# ================================================================== permanent clues
## Things that were always there.
func setup_initial() -> void:
	var h := _house()
	# an old mark scratched low inside the closet, on the door frame
	_decal(h, "sigil", Vector3(5.67, 0.42, 6.38), Vector3(0, 90, 0), 0.11, 0.7)
	# the association photo on the garage wall above the workbench
	var ph := Readable.new()
	ph.name = "AssociationPhoto"
	h.add_child(ph)
	ph.position = Vector3(18.9, 1.55, 2.12)
	ph.setup("assoc_photo", PHOTO_BACK, Vector2(0.32, 0.24), Mats.picture("photo_cult"), false)
	B.box(ph, Vector3(0.36, 0.28, 0.015), Vector3(0, 0, -0.01), Mats.m("wood_dark"))
	# local history book lying on the living-room bookshelf
	var bk := Readable.new()
	bk.name = "HistoryBook"
	h.add_child(bk)
	bk.position = Vector3(14.6, 1.825, 6.43)
	bk.rotation_degrees.y = 8
	bk.setup("history_book", BOOK, Vector2(0.17, 0.24), Mats.color(Color(0.28, 0.12, 0.1), 0.7))
	# three burnt-out candle stubs at the corner of the back patio (old, cold)
	for i in 3:
		var p := Vector3(15.6 + i * 0.09, 0.0, -2.45 + (i % 2) * 0.08)
		B.cyl(h, 0.02, 0.02, 0.04 + i * 0.015, p + Vector3(0, 0.02 + i * 0.007, 0), Mats.color(Color(0.86, 0.82, 0.7), 0.8), false, Vector3.ZERO, 8)
	B.box(h, Vector3(0.3, 0.003, 0.2), Vector3(15.7, 0.002, -2.42), Mats.color(Color(0.1, 0.09, 0.08), 1.0))
	stage = 1
	WorldState.set_state("cult/stage", stage)
	_schedule(1)


## Called while the player sleeps, before night `n` begins (after clear_temporary).
func advance(n: int) -> void:
	stage = n
	WorldState.set_state("cult/stage", stage)
	# permanent: the story keeps arriving
	if n >= 3:
		var comp = WorldState.get_obj("computer")
		if comp:
			comp.terminal.files["CIRCLE.TXT"] = CIRCLE_TXT
	if n >= 4:
		# the hall photograph: someone at the back who wasn't there
		var ph := WorldState.get_obj("photo_hall") as PictureFrame
		if ph and not ph.get_meta("altered", false):
			ph.set_meta("altered", true)
			for c in ph.frame.get_children():
				if c is MeshInstance3D and c.mesh is QuadMesh:
					c.material_override = Mats.picture("photo_5b")
	# tonight's manifestations, waiting when you wake up
	match n:
		2:
			spawn("altar_b2", "night")
		3:
			spawn("chalk_back_door", "night")
		4:
			spawn("garage_candles", "night")
			spawn("porch_candles", "timed", rng.randf_range(300.0, 520.0))
		5:
			spawn("island_ring", "night")
			spawn("wall_writing", "return")
	_schedule(n)


func _schedule(n: int) -> void:
	_later.clear()
	for e in LATER.get(n, []):
		_later.append({"at": WorldState.sim_time + rng.randf_range(e[1], e[2]), "kind": e[0]})


func mail_for(n: int) -> String:
	return MAIL.get(clampi(n, 1, 5), "")


# ================================================================== manifestations
## Every manifestation goes away by the next night, whatever its lifetime.
func clear_temporary() -> void:
	for t in temps:
		if is_instance_valid(t.node):
			t.node.queue_free()
	temps.clear()
	_later.clear()
	_candle_lights = _candle_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
	WorldState.set_state("cult/temps", 0)
	WorldState.log_event("cult", "cleared", {"intensity": 0})


## Register something temporary that another system created (the pillow note).
func add_temp(node: Node3D, mode: String, secs := 0.0, room := "") -> void:
	var h := _house()
	var r = null
	if room != "" and ROOMS.has(room):
		r = ROOMS[room]
	elif h:
		var lp := h.to_local(node.global_position)
		for k in ROOMS:
			if ROOMS[k].has_point(Vector2(lp.x, lp.z)):
				r = ROOMS[k]
				break
	temps.append({"node": node, "kind": node.name, "mode": mode, "until": WorldState.sim_time + secs, "room": r,
		"center": node.global_position + Vector3(0, 0.1, 0), "seen": false, "seen_at": -1.0, "away": 0.0})
	WorldState.set_state("cult/temps", temps.size())


func active_kinds() -> Array:
	var out := []
	for t in temps:
		if is_instance_valid(t.node):
			out.append(t.kind)
	return out


## Builds a manifestation of `kind` and registers it with a lifetime.
func spawn(kind: String, mode: String, secs := 0.0) -> Node3D:
	if not has_method("_m_" + kind):
		WorldState.warn("unknown manifestation " + kind)
		return null
	var info: Array = call("_m_" + kind)
	var node: Node3D = info[0]
	if node == null:
		return null
	node.name = kind
	add_temp(node, mode, secs, info[1])
	if info.size() > 2:
		temps[-1].center = info[2]
	WorldState.log_event("manifest", kind, {"mode": mode, "intensity": 1})
	return node


## Where a manifestation of `kind` would be (global), to avoid spawning it in plain view.
func _spot_of(kind: String) -> Vector3:
	var h := _house()
	var local := {"mirror_sigil": Vector3(7.5, 1.55, 1.9), "inverted_cross": Vector3(4.12, 1.55, 7.6),
		"kitchen_circle": Vector3(13.6, 0.2, 3.3), "dining_ritual": Vector3(9.3, 0.9, 3.1),
		"wardrobe_sigil": Vector3(3.24, 1.1, 1.8), "wall_writing": Vector3(4.13, 1.5, 8.0)}
	return h.to_global(local.get(kind, Vector3(8, 1, 5)))


func _room_of(kind: String) -> String:
	return {"mirror_sigil": "bath", "inverted_cross": "b2", "kitchen_circle": "kitchen", "dining_ritual": "dining",
		"wardrobe_sigil": "b1", "wall_writing": "b2"}.get(kind, "")


func _player_in(room: String) -> bool:
	if room == "" or not ROOMS.has(room) or WorldState.player == null:
		return false
	var lp := _house().to_local(WorldState.player.global_position)
	return ROOMS[room].has_point(Vector2(lp.x, lp.z))


func _candle(parent: Node3D, p: Vector3, h := 0.12, lit := true, light := false, col := Color(0.12, 0.09, 0.08)) -> void:
	B.cyl(parent, 0.022, 0.024, h, p + Vector3(0, h / 2.0, 0), Mats.color(col, 0.7), false, Vector3.ZERO, 8)
	if lit:
		B.sphere(parent, 0.012, p + Vector3(0, h + 0.016, 0), Mats.emissive(Color(1.0, 0.65, 0.28), 6.0, true), Vector3(1, 1.9, 1))
	if light:
		_candle_lights.append(B.omni(parent, p + Vector3(0, h + 0.15, 0), Color(1.0, 0.58, 0.28), 0.9, 4.0, true))


func _chalk_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mats.tex("sigil_chalk")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, alpha)
	m.roughness = 1.0
	return m


# --- the builders: each returns [node, room, (center)] ----------------------
func _m_altar_b2() -> Array:
	var h := _house()
	var alt := B.node(h, "Altar", Vector3(3.55, 0, 7.15))
	B.box(alt, Vector3(0.9, 0.42, 0.45), Vector3(0, 0.21, 0), Mats.color(Color(0.05, 0.04, 0.04), 0.9), true)
	B.box(alt, Vector3(0.96, 0.02, 0.5), Vector3(0, 0.425, 0), Mats.color(Color(0.18, 0.03, 0.03), 0.9))
	for x: float in [-0.32, 0.0, 0.32]:
		_candle(alt, Vector3(x, 0.435, -0.1), 0.14 + absf(x) * 0.1, true, x == 0.0)
	B.cyl(alt, 0.08, 0.06, 0.05, Vector3(0, 0.46, 0.1), Mats.color(Color(0.3, 0.28, 0.25), 0.4), false, Vector3.ZERO, 14)
	B.cyl(alt, 0.065, 0.065, 0.005, Vector3(0, 0.483, 0.1), Mats.color(Color(0.15, 0.02, 0.02), 0.2), false, Vector3.ZERO, 14)
	_decal(alt, "sigil", Vector3(0.58, 1.25, 0.0), Vector3(0, -90, 0), 0.55, 0.85)
	_decal(alt, "sigil_chalk", Vector3(0, 0.004, 0), Vector3(-90, 0, 0), 1.6, 0.35)
	return [alt, "b2"]


func _m_chalk_back_door() -> Array:
	var d := WorldState.get_obj("door_back") as Door
	var h := _house()
	var n := B.node(h, "ChalkBack", Vector3.ZERO)
	if d:
		# outside face of the back door is local +Z of its panel (node rotated 180)
		var on_door := B.node(d.body, "ChalkDoor", Vector3.ZERO)
		B.quad(on_door, Vector2(0.3, 0.3), Vector3(0.44, 1.35, 0.03), _chalk_mat(1.0))
		# the door part lives on the panel; free it together with the rest
		n.tree_exiting.connect(func():
			if is_instance_valid(on_door):
				on_door.queue_free())
	_decal(n, "sigil_chalk", Vector3(13.6, 0.004, -1.1), Vector3(-90, 0, 0), 0.7, 0.6)
	return [n, "", h.to_global(Vector3(13.6, 0.5, -1.0))]


func _m_kitchen_circle() -> Array:
	var h := _house()
	var n := B.node(h, "KitchenCircle", Vector3(13.6, 0, 3.3))
	B.quad(n, Vector2(1.5, 1.5), Vector3(0, 0.004, 0), _chalk_mat(0.75), Vector3(-90, 0, 0))
	for i in 5:
		var a := TAU * i / 5.0
		_candle(n, Vector3(sin(a) * 0.68, 0.0, cos(a) * 0.68), 0.1, true, i == 0, Color(0.9, 0.87, 0.78))
	return [n, "kitchen"]


func _m_garage_candles() -> Array:
	var h := _house()
	var n := B.node(h, "GarageCandles", Vector3(18.0, 0.6, 2.45))
	for i in 7:
		var a := TAU * i / 7.0
		_candle(n, Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.18), 0.12, true, i == 0, Color(0.9, 0.87, 0.78))
	return [n, "garage"]


func _m_porch_candles() -> Array:
	var n := B.node(self, "PorchCandles", Vector3.ZERO)
	# the candles themselves stand on the steps of no. 6 and no. 9
	var parts := []
	for pair in [["neighbor_leland", -2.0], ["neighbor_whitcomb", 1.6]]:
		var nh := WorldState.get_obj(pair[0]) as Node3D
		if nh:
			var grp := B.node(nh, "Candles", Vector3.ZERO)
			for i in 3:
				_candle(grp, Vector3(float(pair[1]) - 0.3 + i * 0.3, 0.16, 1.2), 0.13, true, i == 1)
			parts.append(grp)
	n.tree_exiting.connect(func():
		for g in parts:
			if is_instance_valid(g):
				g.queue_free())
	var center := Vector3.ZERO
	if not parts.is_empty():
		center = parts[0].global_position
	return [n, "", center]


func _m_island_ring() -> Array:
	var nb := WorldState.get_obj("neighborhood") as Node3D
	if nb == null:
		return [null, ""]
	var n := B.node(nb, "IslandRing", Vector3.ZERO)
	for i in 9:
		var a := TAU * i / 9.0
		_candle(n, Vector3(sin(a) * 2.4, 0.15, cos(a) * 2.4), 0.14, true, i % 3 == 0)
	B.quad(n, Vector2(3.0, 3.0), Vector3(0, 0.032, -8.5), _chalk_mat(0.92), Vector3(-90, 0, 0))
	return [n, "", nb.global_position]


func _m_wall_writing() -> Array:
	var h := _house()
	var n := B.node(h, "WallWriting", Vector3(4.132, 1.5, 8.0), Vector3(0, -90, 0))
	var l := B.label(n, "QVATTVORDECIM", Vector3.ZERO, 0.0016, Color(0.55, 0.07, 0.05, 0.92), Vector3.ZERO, 96)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe Script", "Brush Script MT", "URW Chancery L", "Georgia", "serif"])
	l.font = f
	l.rotation_degrees.z = -3.0
	B.label(n, "XIV", Vector3(0.05, -0.32, 0.0), 0.0022, Color(0.55, 0.07, 0.05, 0.85), Vector3.ZERO, 96).font = f
	return [n, "b2"]


func _m_mirror_sigil() -> Array:
	var h := _house()
	var n := B.node(h, "MirrorSigil", Vector3(7.505, 1.58, 1.9))
	# drawn on the glass in something red
	_decal(n, "sigil_chalk", Vector3.ZERO, Vector3(0, -90, 0), 0.4, 0.95, Color(0.78, 0.07, 0.05))
	return [n, "bath"]


func _m_inverted_cross() -> Array:
	var h := _house()
	var cr := B.node(h, "InvertedCross", Vector3(4.12, 1.55, 7.6), Vector3(0, -90, 0))
	B.box(cr, Vector3(0.05, 0.5, 0.03), Vector3(0, 0, 0), Mats.m("wood_dark"))
	B.box(cr, Vector3(0.28, 0.05, 0.03), Vector3(0, -0.11, 0), Mats.m("wood_dark"))
	return [cr, "b2"]


func _m_dining_ritual() -> Array:
	var h := _house()
	var n := B.node(h, "DiningRitual", Vector3(9.3, 0.77, 3.1))
	B.quad(n, Vector2(0.7, 0.7), Vector3(0, 0.003, 0), _chalk_mat(0.85), Vector3(-90, 0, 0))
	for x: float in [-0.5, 0.5]:
		_candle(n, Vector3(x, 0.005, 0.0), 0.16, true, x < 0.0)
	_candle(n, Vector3(0, 0.005, -0.3), 0.12, true, false)
	B.cyl(n, 0.075, 0.055, 0.045, Vector3(0, 0.03, 0.18), Mats.color(Color(0.3, 0.28, 0.25), 0.4), false, Vector3.ZERO, 14)
	B.cyl(n, 0.06, 0.06, 0.004, Vector3(0, 0.05, 0.18), Mats.color(Color(0.15, 0.02, 0.02), 0.2), false, Vector3.ZERO, 14)
	# the empty chair pulled out, facing the table
	return [n, "dining"]


func _m_wardrobe_sigil() -> Array:
	var h := _house()
	var n := B.node(h, "WardrobeSigil", Vector3(3.24, 1.1, 1.799))
	_decal(n, "sigil", Vector3.ZERO, Vector3(0, -90, 0), 0.16, 0.75)
	return [n, "b1"]


## A small symbol somewhere you are not looking (used by an event).
func small_sigil() -> Node3D:
	var h := _house()
	var spots := [
		[Vector3(4.265, 0.55, 6.6), Vector3(0, 90, 0), "hall"],
		[Vector3(7.535, 0.6, 9.6), Vector3(0, -90, 0), "foyer"],
		[Vector3(11.06, 1.85, 2.2), Vector3(0, 90, 0), "kitchen"],
		[Vector3(9.3, 1.7, 0.135), Vector3(0, 0, 0), "dining"],
		[Vector3(15.88, 1.4, 9.3), Vector3(0, -90, 0), "living"],
		[Vector3(0.135, 1.75, 4.2), Vector3(0, 90, 0), "b1"],
	]
	spots.shuffle()
	for s in spots:
		var g: Vector3 = h.to_global(s[0])
		if Perception.sees(g, 60.0) or _player_in(s[2]):
			continue
		var n := B.node(h, "SmallSigil", s[0])
		_decal(n, "sigil" if rng.randf() < 0.5 else "sigil_chalk", Vector3.ZERO, s[1], rng.randf_range(0.14, 0.24), 0.8,
			Color(0.45, 0.08, 0.06) if rng.randf() < 0.4 else Color.WHITE)
		add_temp(n, "glance" if rng.randf() < 0.5 else "timed", rng.randf_range(90.0, 240.0), s[2])
		temps[-1].kind = "small_sigil"
		WorldState.log_event("manifest", "small_sigil", {"room": s[2], "intensity": 1})
		return n
	return null


# ================================================================== lifetimes
func _remove(t: Dictionary, why: String) -> void:
	if is_instance_valid(t.node):
		t.node.queue_free()
	temps.erase(t)
	WorldState.set_state("cult/temps", temps.size())
	WorldState.log_event("manifest_gone", String(t.kind), {"why": why, "intensity": 0})


func _process(delta: float) -> void:
	_t += delta
	for l in _candle_lights:
		if is_instance_valid(l):
			l.light_energy = 0.8 + 0.2 * sin(_t * 9.0) * sin(_t * 3.7) + randf() * 0.08
	if GameManager.ending != "" or WorldState.player == null:
		return
	var now := WorldState.sim_time
	# manifestations that arrive later in the night, never in plain view
	for e in _later.duplicate():
		if now < e.at:
			continue
		var room := _room_of(e.kind)
		if _player_in(room) or Perception.sees(_spot_of(e.kind), 65.0):
			e.at = now + 20.0
			continue
		_later.erase(e)
		var mode: String = {"mirror_sigil": "glance", "inverted_cross": "return", "kitchen_circle": "timed",
			"dining_ritual": "return", "wardrobe_sigil": "timed"}.get(e.kind, "timed")
		spawn(e.kind, mode, rng.randf_range(240.0, 480.0))
	var h := _house()
	for t in temps.duplicate():
		if not is_instance_valid(t.node):
			temps.erase(t)
			continue
		var visible := Perception.sees(t.center, 55.0, 30.0)
		if visible:
			if not t.seen:
				t.seen = true
				WorldState.set_state("manifest/seen/" + String(t.kind), true)
			t.seen_at = now
		match t.mode:
			"timed":
				if now > t.until and not visible:
					_remove(t, "time")
			"glance":
				if t.seen and not visible and now - t.seen_at > 0.4:
					_remove(t, "glance")
				elif not t.seen and now > t.until + 300.0 and not visible:
					_remove(t, "unseen")
			"return":
				var inside := false
				if t.room != null and h:
					var lp := h.to_local(WorldState.player.global_position)
					inside = t.room.has_point(Vector2(lp.x, lp.z))
				if t.seen and not inside and not visible:
					t.away += delta
					if t.away > 6.0:
						_remove(t, "return")
				else:
					t.away = 0.0
