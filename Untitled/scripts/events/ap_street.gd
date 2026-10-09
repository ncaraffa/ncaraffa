extends MysteryEvent
## Someone stands across the street, still, facing the house. Then they are not
## there anymore — or they walk off behind a house. Silent. Easy to miss.

const SPOTS := [
	# world position, where it walks to when it leaves
	[Vector3(7.6, 0.08, 13.4), Vector3(16.0, 0.0, 26.0)],
	[Vector3(-7.6, 0.08, 13.4), Vector3(-17.0, 0.0, 26.0)],
	[Vector3(5.6, 0.08, 34.0), Vector3(14.0, 0.0, 40.0)],
	[Vector3(-5.6, 0.08, 40.0), Vector3(-14.0, 0.0, 46.0)],
	[Vector3(16.2, 0.08, 4.5), Vector3(26.0, 0.0, 2.0)],
	[Vector3(-16.4, 0.08, 4.0), Vector3(-27.0, 0.0, 0.0)],
	[Vector3(0.6, 0.2, 1.2), Vector3(0.0, 0.0, 20.0)],
]

var f: ShadowFigure
var _t := 0.0
var _stay := 10.0
var _seen := 0.0
var _leaving := false


func _init() -> void:
	id = "ap_street"
	title = "Figure across the street"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 2
	resources = ["figure_outside"]
	kinds = ["temporary"]


func _start() -> void:
	f = figure()
	if f == null:
		finish()
		return
	var options := SPOTS.duplicate()
	options.shuffle()
	var spot: Array = options[0]
	for o in options:
		# prefer a spot that is not being looked at right now
		if not Perception.sees(o[0] + Vector3(0, 1.4, 0), 50.0):
			spot = o
			break
	var house_front := Vector3(0, 0, -27)
	f.appear(spot[0], house_front - spot[0], 1.5)
	f.set_rim(0.9)
	f.look_target = WorldState.player.camera if not WorldState.player_inside else null
	f.set_meta("exit", spot[1])
	_t = 0.0
	_seen = 0.0
	_leaving = false
	_stay = rng.randf_range(8.0, 25.0)
	record("stand", {"at": spot[0]})


func _process(delta: float) -> void:
	if not running or f == null:
		return
	_t += delta
	var seen := Perception.sees_figure(f)
	if seen:
		_seen += delta
	if _leaving:
		if not seen and f.state != ShadowFigure.State.VANISHING:
			f.vanish("instant")
		if f.state == ShadowFigure.State.HIDDEN:
			_end()
		return
	if _t > _stay or (_seen > 4.0 and Perception.dist(f.global_position) < 12.0):
		_leaving = true
		if rng.randf() < 0.5:
			var exit_p: Vector3 = f.get_meta("exit")
			f.stiff = rng.randf() < 0.5
			f.walk_path(PackedVector3Array([exit_p]), 1.1)
			f.finished_path.connect(func(): f.vanish("fade", 1.0), CONNECT_ONE_SHOT)
		elif seen:
			f.vanish("fade", 2.5)
		else:
			f.vanish("instant")
	if _t > 70.0:
		f.vanish("instant")
		_end()


func _end() -> void:
	if f and f.state != ShadowFigure.State.HIDDEN:
		f.vanish("instant")
	WorldState.set_state("apparition/last_street_seen", _seen > 0.3)
	finish()
