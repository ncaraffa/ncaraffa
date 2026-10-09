extends MysteryEvent
## EVENT 5 — A car comes into the court, goes around and leaves. It may come
## back a few minutes later. Nobody gets out.

const PAINT := Color(0.13, 0.14, 0.16)
const LOOP_R := 10.5

var returned := false


func _init() -> void:
	id = "car"
	title = "The car"
	resources = ["street_traffic"]
	kinds = ["temporary"]


static func loop_points(from_deg: float, to_deg: float, step := 20.0) -> Array:
	var pts := []
	var a := from_deg
	while a <= to_deg + 0.01:
		pts.append(Neighborhood.polar(a, LOOP_R) + Vector3(0, 0.02, 0))
		a += step
	return pts


static func route(laps := 1) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var y := 0.02
	pts.append(Vector3(-70, y, 152.0))
	pts.append(Vector3(-12, y, 152.0))
	pts.append(Vector3(2.0, y, 140.0))
	pts.append(Vector3(2.0, y, 60.0))
	pts.append(Vector3(2.0, y, 20.0))
	for p in loop_points(14.0, 346.0 + 360.0 * (laps - 1)):
		pts.append(p)
	pts.append(Vector3(-2.0, y, 20.0))
	pts.append(Vector3(-2.0, y, 60.0))
	pts.append(Vector3(-2.0, y, 145.0))
	pts.append(Vector3(10.0, y, 156.0))
	pts.append(Vector3(70.0, y, 156.0))
	return pts


func _spawn_car() -> Car:
	var car := Car.new()
	car.name = "PassingCar"
	get_tree().current_scene.add_child(car)
	car.setup(PAINT)
	return car


func _start() -> void:
	var variant := pick_weighted({"pass": 0.4, "linger": 0.4, "twice": 0.2})
	var car := _spawn_car()
	car.start_route(route(2 if variant == "twice" else 1), rng.randf_range(6.0, 7.5))
	if variant == "linger":
		var front := Neighborhood.polar(180.0, LOOP_R)
		car.stops.append({"d": car.curve.get_closest_offset(front), "t": rng.randf_range(14.0, 28.0), "done": false})
	record(variant)
	car.route_finished.connect(_on_first_pass.bind(car), CONNECT_ONE_SHOT)


func _on_first_pass(car: Car) -> void:
	car.queue_free()
	finish()
	if not returned and rng.randf() < 0.5:
		returned = true
		after(rng.randf_range(180.0, 360.0), _come_back)


func _come_back() -> void:
	if not WorldState.try_lock("street_traffic", id + "_return"):
		after(30.0, _come_back)
		return
	var car := _spawn_car()
	car.start_route(route(1), rng.randf_range(5.0, 6.0))
	WorldState.log_event(id, "returned")
	car.route_finished.connect(_on_return_done.bind(car), CONNECT_ONE_SHOT)


func _on_return_done(car: Car) -> void:
	car.queue_free()
	WorldState.unlock("street_traffic", id + "_return")
