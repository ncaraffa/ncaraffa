class_name CultEvidence
extends Node
## Traces of the Larkspur Court Association, placed quietly around the house.
## Some are there from the start. Others appear (or change) while you sleep.
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
const MAIL_LATER := [
	"VALU-MART\nThis week only: canned soup 3 for $1.\nCoupons inside.",
	"LARKSPUR ELECTRIC & GAS\nAccount: R. HALLOWAY\nAmount due: $68.12",
	"(a postcard of a lake. the back is blank except for the number 14, written many times)",
]

var stage := 0
var root: Node3D
var _candle_lights: Array = []
var _t := 0.0


func _ready() -> void:
	name = "CultEvidence"
	WorldState.register("cult", self)


func _house() -> House:
	return WorldState.get_obj("house") as House


func _decal(tex: String, local_pos: Vector3, rot: Vector3, size: float, alpha := 0.85) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mats.tex(tex)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, alpha)
	m.roughness = 1.0
	return B.quad(_house(), Vector2(size, size), local_pos, m, rot)


## Things that were always there.
func setup_initial() -> void:
	var h := _house()
	# a mark scratched low inside the closet, on the door frame
	_decal("sigil", Vector3(5.67, 0.42, 6.38), Vector3(0, 90, 0), 0.11, 0.7)
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
	# three burnt-out candle stubs at the corner of the back patio
	for i in 3:
		var p := Vector3(15.6 + i * 0.09, 0.0, -2.45 + (i % 2) * 0.08)
		B.cyl(h, 0.02, 0.02, 0.04 + i * 0.015, p + Vector3(0, 0.02 + i * 0.007, 0), Mats.color(Color(0.86, 0.82, 0.7), 0.8), false, Vector3.ZERO, 8)
	B.box(h, Vector3(0.3, 0.003, 0.2), Vector3(15.7, 0.002, -2.42), Mats.color(Color(0.1, 0.09, 0.08), 1.0))
	stage = 1


func _candle(parent: Node3D, p: Vector3, h := 0.12, lit := true, light := false) -> void:
	B.cyl(parent, 0.022, 0.024, h, p + Vector3(0, h / 2.0, 0), Mats.color(Color(0.12, 0.09, 0.08), 0.7), false, Vector3.ZERO, 8)
	if lit:
		B.sphere(parent, 0.012, p + Vector3(0, h + 0.016, 0), Mats.emissive(Color(1.0, 0.65, 0.28), 6.0, true), Vector3(1, 1.9, 1))
	if light:
		_candle_lights.append(B.omni(parent, p + Vector3(0, h + 0.15, 0), Color(1.0, 0.58, 0.28), 0.9, 4.0, true))


const CIRCLE_TXT := "THE CIRCLE OF LARKSPUR COURT\n\n 6  LELAND      present\n 9  WHITCOMB    present\n12  PRUITT      present\n16  OCAMPO      present\n 3  HAINES      present\n 5  BAPTISTE    present\n 7  KOWALSKI    present\n11  FERRARO     present\n14  HALLOWAY    ---- pending ----\n\nthe chair is kept.\nthe circle closes when fourteen answers."


## Called while the player sleeps, before night `n` begins.
func advance(n: int) -> void:
	var h := _house()
	if n >= 2 and stage < 2:
		# the unused front room: someone has made a small altar in the corner
		var alt := B.node(h, "Altar", Vector3(3.55, 0, 7.15))
		B.box(alt, Vector3(0.9, 0.42, 0.45), Vector3(0, 0.21, 0), Mats.color(Color(0.05, 0.04, 0.04), 0.9), true)
		B.box(alt, Vector3(0.96, 0.02, 0.5), Vector3(0, 0.425, 0), Mats.color(Color(0.18, 0.03, 0.03), 0.9))
		for x: float in [-0.32, 0.0, 0.32]:
			_candle(alt, Vector3(x, 0.435, -0.1), 0.14 + absf(x) * 0.1, true, x == 0.0)
		B.cyl(alt, 0.08, 0.06, 0.05, Vector3(0, 0.46, 0.1), Mats.color(Color(0.3, 0.28, 0.25), 0.4), false, Vector3.ZERO, 14)
		B.cyl(alt, 0.065, 0.065, 0.005, Vector3(0, 0.483, 0.1), Mats.color(Color(0.15, 0.02, 0.02), 0.2), false, Vector3.ZERO, 14)
		_decal("sigil", Vector3(4.13, 1.25, 7.15), Vector3(0, -90, 0), 0.55, 0.85)
		_decal("sigil_chalk", Vector3(3.55, 0.004, 7.15), Vector3(-90, 0, 0), 1.6, 0.35)
		stage = 2
	if n >= 3 and stage < 3:
		# an inverted cross above the altar, and the computer has a new file
		var cr := B.node(h, "InvertedCross", Vector3(4.12, 1.55, 6.55), Vector3(0, -90, 0))
		B.box(cr, Vector3(0.05, 0.5, 0.03), Vector3(0, 0, 0), Mats.m("wood_dark"))
		B.box(cr, Vector3(0.28, 0.05, 0.03), Vector3(0, -0.11, 0), Mats.m("wood_dark"))
		var comp = WorldState.get_obj("computer")
		if comp:
			comp.terminal.files["CIRCLE.TXT"] = CIRCLE_TXT
	if n >= 3 and stage < 3:
		# chalk on the outside of the back door and on the patio
		var d := WorldState.get_obj("door_back") as Door
		if d:
			var m := StandardMaterial3D.new()
			m.albedo_texture = Mats.tex("sigil_chalk")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 1.0
			# outside face of the back door is local +Z of its panel (node rotated 180)
			B.quad(d.body, Vector2(0.3, 0.3), Vector3(0.44, 1.35, 0.03), m)
		_decal("sigil_chalk", Vector3(13.6, 0.004, -1.1), Vector3(-90, 0, 0), 0.7, 0.55)
		stage = 3
	if n >= 4 and stage < 4:
		# the hall photograph: someone at the back who wasn't there
		var ph := WorldState.get_obj("photo_hall") as PictureFrame
		if ph:
			for c in ph.frame.get_children():
				if c is MeshInstance3D and c.mesh is QuadMesh:
					c.material_override = Mats.picture("photo_5b")
		# a ring of candles on the garage workbench, lit
		for i in 7:
			var a := TAU * i / 7.0
			var p := Vector3(18.0 + cos(a) * 0.32, 0.6, 2.45 + sin(a) * 0.18)
			B.cyl(h, 0.022, 0.022, 0.12, p + Vector3(0, 0.06, 0), Mats.color(Color(0.9, 0.87, 0.78), 0.8), false, Vector3.ZERO, 8)
			B.sphere(h, 0.012, p + Vector3(0, 0.135, 0), Mats.emissive(Color(1.0, 0.7, 0.3), 6.0, true), Vector3(1, 1.8, 1))
		var l := B.omni(h, Vector3(18.0, 0.95, 2.5), Color(1.0, 0.62, 0.3), 0.9, 4.0, true)
		_candle_lights.append(l)
		stage = 4
	if n >= 4 and not WorldState.get_state("cult/porch_candles", false):
		# candles burning on the front steps of no. 6 and no. 9
		WorldState.set_state("cult/porch_candles", true)
		for pair in [["neighbor_leland", -2.0], ["neighbor_whitcomb", 1.6]]:
			var nh := WorldState.get_obj(pair[0]) as Node3D
			if nh:
				for i in 3:
					var lp := Vector3(float(pair[1]) - 0.3 + i * 0.3, 0.16, 1.2)
					_candle(nh, lp, 0.13, true, i == 1)
	if n >= 5 and stage < 5:
		_decal("sigil", Vector3(3.24, 1.1, 1.799), Vector3(0, -90, 0), 0.08, 0.6)   # inside of the wardrobe door
		# a ring of candles on the island in the middle of the court, chalk on the asphalt
		var nb := WorldState.get_obj("neighborhood") as Node3D
		if nb:
			for i in 9:
				var a := TAU * i / 9.0
				_candle(nb, Vector3(sin(a) * 2.4, 0.15, cos(a) * 2.4), 0.14, true, i % 3 == 0)
			var m := StandardMaterial3D.new()
			m.albedo_texture = Mats.tex("sigil_chalk")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, 0.7)
			B.quad(nb, Vector2(3.0, 3.0), Vector3(0, 0.032, -8.5), m, Vector3(-90, 0, 0))
		stage = 5
	WorldState.set_state("cult/stage", stage)


func mail_for(n: int) -> String:
	if MAIL.has(n):
		return MAIL[n]
	return MAIL_LATER[n % MAIL_LATER.size()]


func _process(delta: float) -> void:
	if _candle_lights.is_empty():
		return
	_t += delta
	for l in _candle_lights:
		l.light_energy = 0.8 + 0.2 * sin(_t * 9.0) * sin(_t * 3.7) + randf() * 0.08
