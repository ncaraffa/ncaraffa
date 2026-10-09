class_name WallClock
extends Node3D
## Analog or digital clock reading the shared world clock plus its own offset
## (state "clock/<id>/offset", in minutes).

var obj_id := ""
var digital := false
var hour_hand: Node3D
var min_hand: Node3D
var sec_hand: Node3D
var label: Label3D
var twelve_hour := true
var blink_noon := false   # VCR-style "12:00"
var _tick: AudioStreamPlayer3D
var _t := 0.0


func setup_analog(id: String, radius := 0.15, face_col := Color(0.92, 0.9, 0.84), tick := true) -> void:
	obj_id = id
	WorldState.register(id, self)
	B.cyl(self, radius, radius, 0.04, Vector3(0, 0, 0.02), Mats.color(Color(0.3, 0.24, 0.18), 0.5), false, Vector3(90, 0, 0), 24)
	B.cyl(self, radius * 0.9, radius * 0.9, 0.01, Vector3(0, 0, 0.041), Mats.color(face_col, 0.6), false, Vector3(90, 0, 0), 24)
	var ink := Mats.color(Color(0.08, 0.08, 0.08), 0.5)
	for i in 12:
		var a := i * TAU / 12.0
		var r := radius * 0.78
		var big := i % 3 == 0
		B.box(self, Vector3(0.008 if big else 0.005, radius * (0.14 if big else 0.08), 0.004), Vector3(sin(a) * r, cos(a) * r, 0.048), ink, false, Vector3(0, 0, -rad_to_deg(a)))
	hour_hand = _hand(radius * 0.5, 0.012, ink, 0.05)
	min_hand = _hand(radius * 0.75, 0.008, ink, 0.054)
	sec_hand = _hand(radius * 0.8, 0.003, Mats.color(Color(0.6, 0.1, 0.08)), 0.058)
	B.cyl(self, 0.01, 0.01, 0.01, Vector3(0, 0, 0.06), ink, false, Vector3(90, 0, 0), 8)
	if tick:
		_tick = AudioManager.make_emitter(self, "clock_tick", Vector3(0, 0, 0.05), -22.0, 1.2, 6.0)
	_update()


func _hand(length: float, width: float, mat: Material, z: float) -> Node3D:
	var pivot := B.node(self, "Hand")
	pivot.position.z = z
	B.box(pivot, Vector3(width, length, 0.003), Vector3(0, length / 2 - length * 0.12, 0), mat)
	return pivot


func setup_digital(id: String, col := Color(1.0, 0.15, 0.1), px := 0.0016, h12 := true) -> void:
	obj_id = id
	digital = true
	twelve_hour = h12
	WorldState.register(id, self)
	label = B.label(self, "00:00", Vector3.ZERO, px, col, Vector3.ZERO, 40, true)
	_update()


func offset_minutes() -> float:
	return float(WorldState.get_state("clock/" + obj_id + "/offset", 0.0))


func set_offset(minutes: float) -> void:
	WorldState.set_state("clock/" + obj_id + "/offset", minutes)
	_update()


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.2:
		_t = 0.0
		_update()


func _update() -> void:
	var m := WorldState.clock_minutes(offset_minutes())
	if digital:
		if blink_noon:
			label.text = "12:00" if fmod(WorldState.sim_time, 1.0) < 0.5 else ""
		else:
			label.text = WorldState.format_clock(m, twelve_hour)
		return
	var secs := fmod(WorldState.sim_time + 17.0, 60.0)
	sec_hand.rotation.z = -floor(secs) / 60.0 * TAU
	min_hand.rotation.z = -fmod(m, 60.0) / 60.0 * TAU
	hour_hand.rotation.z = -fmod(m / 60.0, 12.0) / 12.0 * TAU
