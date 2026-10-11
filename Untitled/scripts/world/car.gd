class_name Car
extends Node3D
## A driven car following a waypoint route with headlights and a positional
## engine (with doppler). Runs on its own: nobody needs to be watching.

signal route_finished

var model: Node3D
var engine: AudioStreamPlayer3D
var head_l: SpotLight3D
var head_r: SpotLight3D
var tail: OmniLight3D
var curve: Curve3D
var progress := 0.0
var speed := 0.0
var cruise := 7.0
var stops: Array = []            # [{d: distance, t: seconds, done: false}]
var _stop_timer := 0.0
var driving := false
var park_at_end := false
var lights_on := true
var parked := false


func setup(paint: Color, wagon := false) -> void:
	model = Vehicles.car_model(self, paint, wagon)
	head_l = B.spot(self, Vector3(-0.65, 0.7, 2.4), Vector3(-6, 180, 0), Color(1.0, 0.94, 0.8), 6.0, 32.0, 28.0, true)
	head_r = B.spot(self, Vector3(0.65, 0.7, 2.4), Vector3(-6, 180, 0), Color(1.0, 0.94, 0.8), 6.0, 32.0, 28.0, false)
	tail = B.omni(self, Vector3(0, 0.7, -2.6), Color(1.0, 0.1, 0.05), 0.6, 3.5, false)
	engine = AudioStreamPlayer3D.new()
	engine.stream = AudioManager.stream("car_engine")
	engine.unit_size = AudioManager.mix_entry("car_engine")[1]
	engine.max_distance = 160.0
	engine.volume_db = AudioManager.db("car_engine")
	engine.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	engine.area_mask = B.LAYER_AUDIO
	engine.bus = "SFXOut"
	engine.attenuation_filter_db = -8.0
	add_child(engine)
	set_lights(true)


func set_lights(on: bool) -> void:
	lights_on = on
	head_l.visible = on
	head_r.visible = on
	tail.visible = on
	Vehicles.set_lamps(model, on)


func start_route(points: PackedVector3Array, cruise_speed := 7.0, route_stops: Array = [], park := false) -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.5
	for p in points:
		curve.add_point(p)
	# smooth corners with handles
	for i in range(1, curve.point_count - 1):
		var prev := curve.get_point_position(i - 1)
		var nxt := curve.get_point_position(i + 1)
		var tangent := (nxt - prev) * 0.22
		curve.set_point_in(i, -tangent)
		curve.set_point_out(i, tangent)
	cruise = cruise_speed
	stops = route_stops.duplicate(true)
	park_at_end = park
	progress = 0.0
	speed = cruise
	driving = true
	parked = false
	global_position = curve.sample_baked(0.0)
	_orient(0.0, 1.0)
	engine.stream = AudioManager.stream("car_engine")
	engine.play()
	set_lights(true)


func _orient(at: float, blend: float) -> void:
	var p := curve.sample_baked(at)
	var ahead := curve.sample_baked(min(at + 2.0, curve.get_baked_length()))
	if ahead.distance_to(p) < 0.05:
		return
	var target_basis := Basis.looking_at(-(ahead - p).normalized(), Vector3.UP)
	global_basis = global_basis.slerp(target_basis, blend).orthonormalized()


func _physics_process(delta: float) -> void:
	if not driving:
		return
	var total := curve.get_baked_length()
	if _stop_timer > 0.0:
		_stop_timer -= delta
		speed = 0.0
		if _stop_timer <= 0.0:
			engine.stream = AudioManager.stream("car_engine")
			engine.play()
		return
	var target := cruise
	for s in stops:
		if not s.done:
			var dist: float = s.d - progress
			if dist < 0.3:
				s.done = true
				_stop_timer = s.t
				engine.stream = AudioManager.stream("car_idle")
				engine.play()
				return
			if dist < 12.0:
				target = min(target, max(1.0, dist * 0.6))
	if park_at_end and total - progress < 12.0:
		target = min(target, max(0.8, (total - progress) * 0.5))
	speed = move_toward(speed, target, delta * 2.5)
	progress += speed * delta
	engine.pitch_scale = clamp(0.75 + speed / 14.0, 0.75, 1.4)
	if progress >= total:
		progress = total
		driving = false
		if park_at_end:
			park()
		else:
			engine.stop()
		route_finished.emit()
		return
	global_position = curve.sample_baked(progress)
	_orient(progress, clamp(delta * 6.0, 0.0, 1.0))


## Stop for good: engine off, lights off, door closes. A new parked car exists.
func park() -> void:
	parked = true
	engine.stop()
	set_lights(false)
	AudioManager.play_3d("car_door", global_position + Vector3(0, 1, 0), 0.0, randf_range(0.9, 1.05))
	B.collider(self, Vector3(1.8, 1.4, 4.6), Vector3(0, 0.7, 0))
