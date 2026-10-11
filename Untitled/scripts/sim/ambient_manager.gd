class_name AmbientActivityManager
extends Node
## Ordinary life. None of this is mysterious, and that is the point:
## neighbours' lights, dogs, wind, the fridge, the house settling, traffic.
## Every activity runs on its own randomised timer, whether or not anyone hears.

var rng := RandomNumberGenerator.new()
var _next: Dictionary = {}
var _fridge_on := true
var _arrivals := 0
var _bed: AudioStreamPlayer
var _traffic: AudioStreamPlayer

const SCHEDULE := {
	"neighbor_window": Vector2(20, 75),
	"neighbor_porch": Vector2(150, 360),
	"dog": Vector2(45, 170),
	"owl": Vector2(160, 420),
	"gust": Vector2(35, 100),
	"chime": Vector2(60, 220),
	"distant_car": Vector2(70, 220),
	"arrival": Vector2(260, 560),
	"fridge": Vector2(150, 300),
	"creak": Vector2(50, 150),
	"pipes": Vector2(240, 560),
	"flicker": Vector2(120, 320),
	# layer A additions: the street is alive, the house is old
	"neighbor_home": Vector2(200, 420),
	"outside_steps": Vector2(160, 380),
	"wind_door": Vector2(150, 360),
	"tv_crackle": Vector2(180, 420),
}


func _ready() -> void:
	name = "AmbientActivityManager"
	rng.randomize()
	for k in SCHEDULE:
		_next[k] = rng.randf_range(SCHEDULE[k].x * 0.3, SCHEDULE[k].y)
	_next["arrival"] = rng.randf_range(240, 540)
	_beds.call_deferred()


func _beds() -> void:
	# wind bed and far traffic: non-positional, on the Outdoor bus (muffled inside)
	_bed = AudioStreamPlayer.new()
	_bed.stream = AudioManager.stream("wind")
	_bed.volume_db = AudioManager.db("wind")
	_bed.bus = "AmbOut"
	add_child(_bed)
	_bed.play(rng.randf() * 10.0)
	_traffic = AudioStreamPlayer.new()
	_traffic.stream = AudioManager.stream("distant_traffic")
	_traffic.volume_db = AudioManager.db("distant_traffic")
	_traffic.bus = "AmbOut"
	add_child(_traffic)
	_traffic.play()
	# crickets live in the grass around the court
	var root := get_tree().current_scene as Node3D
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.3
		var r := rng.randf_range(20.0, 40.0)
		var holder := B.node(root, "Crickets", Vector3(sin(a) * r, 0.2, cos(a) * r))
		var e := AudioManager.make_emitter(holder, "crickets", Vector3.ZERO, 0.0, -1.0, -1.0, true, "AmbOut")
		e.pitch_scale = rng.randf_range(0.92, 1.08)
	for p: Vector3 in [Vector3(-4, 0.2, -46), Vector3(8, 0.2, -44), Vector3(-9, 0.2, -22)]:
		var holder2 := B.node(root, "Crickets", p)
		AudioManager.make_emitter(holder2, "crickets", Vector3.ZERO, -3.0, -1.0, -1.0, true, "AmbOut")


func _process(delta: float) -> void:
	if GameManager.ending != "":
		return
	for k in _next.keys():
		_next[k] -= delta
		if _next[k] <= 0.0:
			var span: Vector2 = SCHEDULE[k]
			_next[k] = rng.randf_range(span.x, span.y)
			call("_do_" + k)


func _houses() -> Array:
	var nb = WorldState.get_obj("neighborhood")
	if nb == null:
		return []
	var out := []
	for fam in nb.houses:
		if not WorldState.is_locked("house_" + String(fam).to_lower()):
			out.append(nb.houses[fam])
	return out


func _do_neighbor_window() -> void:
	var hs := _houses()
	if hs.is_empty():
		return
	var h: NeighborHouse = hs[rng.randi() % hs.size()]
	var i := rng.randi() % h.window_count()
	# as the night goes on, lights tend to go out
	var hour := WorldState.clock_minutes() / 60.0
	var p_on := 0.45 if hour > 20.0 else 0.3
	h.set_window(i, rng.randf() < p_on)


func _do_neighbor_porch() -> void:
	var hs := _houses()
	if hs.is_empty():
		return
	var h: NeighborHouse = hs[rng.randi() % hs.size()]
	h.set_porch(not h.porch_on)


func _yard_point(h: Node3D) -> Vector3:
	return h.global_position - h.global_basis.z * rng.randf_range(12.0, 18.0) + h.global_basis.x * rng.randf_range(-5.0, 5.0) + Vector3(0, 0.5, 0)


func _do_dog() -> void:
	var nb = WorldState.get_obj("neighborhood")
	if nb == null:
		return
	var keys: Array = nb.houses.keys()
	var h: Node3D = nb.houses[keys[rng.randi() % keys.size()]]
	var pos := _yard_point(h)
	AudioManager.play_3d("dog_bark_%d" % rng.randi_range(0, 3), pos, rng.randf_range(-4.0, 0.0), rng.randf_range(0.9, 1.1), -1.0, -1.0, "Outdoor")
	if rng.randf() < 0.3:
		var h2: Node3D = nb.houses[keys[rng.randi() % keys.size()]]
		var pos2 := _yard_point(h2)
		get_tree().create_timer(rng.randf_range(2.0, 5.0), false).timeout.connect(func():
			AudioManager.play_3d("dog_bark_%d" % rng.randi_range(0, 3), pos2, -4.0, rng.randf_range(0.8, 1.2), -1.0, -1.0, "Outdoor"))


func _do_owl() -> void:
	var a := rng.randf() * TAU
	AudioManager.play_3d("owl", Vector3(sin(a) * 60.0, 9.0, cos(a) * 60.0), 0.0, rng.randf_range(0.95, 1.05), -1.0, -1.0, "Outdoor")


func _do_gust() -> void:
	var p := WorldState.player
	if p == null:
		return
	var a := rng.randf() * TAU
	AudioManager.play_3d("wind_gust", p.global_position + Vector3(sin(a) * 18.0, 6.0, cos(a) * 18.0), 0.0, rng.randf_range(0.85, 1.1), -1.0, -1.0, "Outdoor")
	if _bed:
		var t := create_tween()
		t.tween_property(_bed, "volume_db", AudioManager.db("wind") + 5.0, 2.0)
		t.tween_property(_bed, "volume_db", AudioManager.db("wind"), 3.0)


func _do_chime() -> void:
	var h := WorldState.get_obj("neighbor_pruitt") as Node3D
	if h:
		AudioManager.play_3d("wind_chime", h.global_position + h.global_basis.z * 1.0 + Vector3(0, 2.2, 0), 0.0, 1.0, -1.0, -1.0, "Outdoor")


func _do_distant_car() -> void:
	var x := rng.randf_range(-50.0, 50.0)
	AudioManager.play_3d("car_pass", Vector3(x, 1.0, 154.0), 0.0, rng.randf_range(0.85, 1.15), -1.0, -1.0, "Outdoor")


## A neighbour comes home: drives in, parks in a driveway, the lights go off.
func _do_arrival() -> void:
	if _arrivals >= 2:
		return
	if not WorldState.try_lock("street_traffic", "ambient_arrival"):
		_next["arrival"] = 45.0
		return
	var targets := ["Pruitt", "Leland"]
	var fam: String = targets[rng.randi() % targets.size()]
	var nb = WorldState.get_obj("neighborhood")
	var h: NeighborHouse = null
	if nb:
		h = nb.houses.get(fam)
	if h == null:
		WorldState.unlock("street_traffic", "ambient_arrival")
		return
	_arrivals += 1
	var car := Car.new()
	car.name = "NeighborCar"
	get_tree().current_scene.add_child(car)
	var cols := [Color(0.55, 0.52, 0.45), Color(0.35, 0.08, 0.06), Color(0.6, 0.62, 0.65)]
	car.setup(cols[rng.randi() % cols.size()], rng.randf() < 0.4)
	var fwd := h.global_basis.z
	var garage := h.global_position + h.global_basis.x * 9.5
	var approach := garage + fwd * 11.0
	var phi := rad_to_deg(atan2(approach.x, approach.z))
	if phi < 0.0:
		phi += 360.0
	var pts := PackedVector3Array([Vector3(-70, 0.02, 152), Vector3(-12, 0.02, 152), Vector3(2, 0.02, 140), Vector3(2, 0.02, 20)])
	var a := 14.0
	while a < phi - 12.0:
		pts.append(Neighborhood.polar(a, 10.5) + Vector3(0, 0.02, 0))
		a += 20.0
	pts.append(Neighborhood.polar(phi - 4.0, 12.0) + Vector3(0, 0.02, 0))
	pts.append(approach + Vector3(0, 0.03, 0))
	pts.append(garage + fwd * 4.6 + Vector3(0, 0.03, 0))
	var t := [fam]
	car.start_route(pts, 6.5, [], true)
	WorldState.set_state("ambient/arrival_%d" % _arrivals, t[0])
	car.route_finished.connect(func(): WorldState.unlock("street_traffic", "ambient_arrival"), CONNECT_ONE_SHOT)


func _do_fridge() -> void:
	var hum := WorldState.get_obj("fridge_hum") as AudioStreamPlayer3D
	if hum == null:
		return
	_fridge_on = not _fridge_on
	AudioManager.play_3d("fridge_clunk", hum.global_position, 0.0, rng.randf_range(0.9, 1.1))
	var t := create_tween()
	t.tween_property(hum, "volume_db", AudioManager.db("fridge_hum") if _fridge_on else -60.0, 0.6)
	WorldState.set_state("ambient/fridge_running", _fridge_on)


func _do_creak() -> void:
	var h := WorldState.get_obj("house") as House
	if h == null:
		return
	var local := Vector3(rng.randf_range(0.5, 15.5), rng.randf_range(1.8, 2.7), rng.randf_range(0.5, 10.5))
	AudioManager.play_3d("house_creak_%d" % rng.randi_range(0, 3), h.to_global(local), rng.randf_range(-6.0, 0.0), rng.randf_range(0.85, 1.15), -1.0, -1.0, "Indoor")


func _do_pipes() -> void:
	var h := WorldState.get_obj("house") as House
	if h == null:
		return
	var spots := [Vector3(6.8, 0.6, 1.2), Vector3(12.0, 0.4, 0.3), Vector3(7.0, 1.0, 4.5)]
	AudioManager.play_3d("pipes", h.to_global(spots[rng.randi() % spots.size()]), 0.0, rng.randf_range(0.85, 1.1), -1.0, -1.0, "Indoor")


func _do_flicker() -> void:
	if rng.randf() < 0.6:
		var nb = WorldState.get_obj("neighborhood")
		if nb and not nb.lamps.is_empty():
			var l: Dictionary = nb.lamps[rng.randi() % nb.lamps.size()]
			_flicker_lamp(l)
	else:
		var ids := ["hall_ceiling", "kitchen_sink", "porch_front", "living_floorlamp", "b1_lamp"]
		var f := WorldState.get_obj(ids[rng.randi() % ids.size()]) as LightFixture
		if f:
			f.flicker(rng.randf_range(0.2, 0.6))


func _flicker_lamp(l: Dictionary) -> void:
	var light: Light3D = l.light
	var base: float = l.energy
	for i in rng.randi_range(3, 8):
		light.light_energy = base * (0.15 if rng.randf() < 0.5 else 0.7)
		await get_tree().create_timer(rng.randf_range(0.04, 0.18), false).timeout
		light.light_energy = base
		await get_tree().create_timer(rng.randf_range(0.05, 0.4), false).timeout
	light.light_energy = base


## A neighbour walks up to their front door and goes in. A light comes on.
func _do_neighbor_home() -> void:
	var hs := _houses()
	if hs.is_empty():
		return
	var h: NeighborHouse = hs[rng.randi() % hs.size()]
	var dx: float = h.get_meta("door_x", -1.5)
	var start := h.to_global(Vector3(dx + rng.randf_range(-1.0, 1.0), 0.02, 9.0))
	if Perception.dist(start) < 7.0:
		return
	var who := ShadowFigure.new()
	who.name = "Neighbor"
	get_tree().current_scene.add_child(who)
	var shirts := [Color(0.3, 0.35, 0.45), Color(0.5, 0.2, 0.18), Color(0.6, 0.58, 0.5), Color(0.2, 0.3, 0.22)]
	who.make_person(shirts[rng.randi() % shirts.size()], Color(0.18, 0.18, 0.2), Color(0.75, 0.58, 0.47).darkened(rng.randf() * 0.4))
	who.look_target = null
	who.set_rim(0.0)
	who.appear(start, h.global_basis * Vector3(0, 0, -1))
	who.walk_path(PackedVector3Array([h.to_global(Vector3(dx, 0.02, 2.2)), h.to_global(Vector3(dx, 0.16, 0.7))]), 1.05)
	WorldState.log_event("ambient", "neighbor_home", {"family": h.family, "intensity": 0})
	await who.finished_path
	AudioManager.play_3d("door_close", h.to_global(Vector3(dx, 1.0, 0.0)), -2.0, 1.05, -1.0, -1.0, "Outdoor")
	who.vanish("instant")
	who.queue_free()
	if h.window_count() > 0:
		h.set_window(rng.randi() % h.window_count(), true)


## Someone walks past outside, close to the wall of the room you are in.
func _do_outside_steps() -> void:
	var p = WorldState.player
	var house = WorldState.get_obj("house")
	if p == null or house == null or not WorldState.player_inside:
		return
	var lp: Vector3 = house.to_local(p.global_position)
	# the nearest outside wall
	var walls := [[lp.z, Vector3(0, 0, -1.2)], [11.0 - lp.z, Vector3(0, 0, 12.2)], [lp.x, Vector3(-1.2, 0, 0)], [16.0 - lp.x, Vector3(17.2, 0, 0)]]
	walls.sort_custom(func(a, b): return a[0] < b[0])
	var w: Vector3 = walls[0][1]
	var along := Vector3(1, 0, 0) if w.x == 0.0 else Vector3(0, 0, 1)
	var base := Vector3(lp.x if w.x == 0.0 else w.x, 0.0, lp.z if w.z == 0.0 else w.z)
	var dir := 1.0 if rng.randf() < 0.5 else -1.0
	WorldState.log_event("ambient", "outside_steps", {"intensity": 0})
	for i in 8:
		var at: Vector3 = base + along * dir * (-3.0 + i * 0.8)
		AudioManager.play_3d("step_grass_%d" % rng.randi_range(0, 3), house.to_global(at + Vector3(0, 0.1, 0)), 3.0, rng.randf_range(0.85, 0.95), -1.0, -1.0, "Outdoor")
		await get_tree().create_timer(0.62, false).timeout


## A gust; somewhere in the house a door shifts in its frame.
func _do_wind_door() -> void:
	var ids := ["door_b2", "door_closet", "door_laundry", "door_bath", "door_b1"]
	var d := WorldState.get_obj(ids[rng.randi() % ids.size()]) as Door
	if d == null or WorldState.is_locked(d.obj_id):
		return
	var house = WorldState.get_obj("house")
	AudioManager.play_3d("wind_gust", house.global_position + Vector3(rng.randf_range(-6, 18), 3.0, rng.randf_range(-3, 12)), 2.0)
	var c := d.global_transform * Vector3(d.width / 2.0, 1.1, 0)
	AudioManager.play_3d("door_rattle", c, -6.0, rng.randf_range(0.9, 1.1))
	if d.is_open and rng.randf() < 0.4:
		d.drift(d.open_angle - rng.randf_range(10.0, 25.0))
	WorldState.log_event("ambient", "wind_door", {"door": d.obj_id, "intensity": 0})


## The old television ticks and pops as it cools, or its static swells.
func _do_tv_crackle() -> void:
	var tv := WorldState.get_obj("tv") as TV
	if tv == null:
		return
	AudioManager.play_3d("tick" if not tv.power else "elec_buzz", tv.global_position + Vector3(0, 0.3, 0), -4.0, rng.randf_range(0.7, 1.1))
	WorldState.log_event("ambient", "tv_crackle", {"intensity": 0})
