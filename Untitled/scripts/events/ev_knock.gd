extends MysteryEvent
## EVENT 3 — Three knocks. Opening the door is optional.

const FLYER := "LARKSPUR COURT\nNEIGHBORHOOD WATCH\n\nMeeting Thursday 7 PM\nat the Pruitts' (no. 9)\n\nReminder: please lock your doors\nand leave a porch light on at night.\n\nCoffee & pie."


func _init() -> void:
	id = "knock"
	title = "The knocking"
	resources = ["front_door"]
	kinds = ["temporary", "reactive"]


func _start() -> void:
	var h := house()
	var variant := pick_weighted({"empty": 0.4, "package": 0.18, "flyer": 0.18, "neighbor_porch": 0.14, "back_door": 0.1})
	if variant == "package" and WorldState.get_obj("package") != null:
		variant = "empty"
	if variant == "flyer" and WorldState.get_obj("flyer") != null:
		variant = "empty"
	var pos := h.gp("back_door_out" if variant == "back_door" else "front_door_out")
	record(variant, {"door_open": WorldState.get_state("door/door_front", false)})
	var gap := rng.randf_range(0.38, 0.55)
	for i in 3:
		AudioManager.play_3d("knock", pos, -i * 0.8, rng.randf_range(0.95, 1.04), -1.0, -1.0, "World")
		await wait(gap + rng.randf_range(-0.03, 0.05))
	match variant:
		"package":
			_package(h)
		"flyer":
			_flyer(h)
		"neighbor_porch":
			await wait(rng.randf_range(3.0, 6.0))
			var nh := WorldState.get_obj("neighbor_pruitt") as NeighborHouse
			if nh:
				nh.set_porch(true)
				after(rng.randf_range(30.0, 90.0), func(): nh.set_porch(false))
	await wait(8.0)
	finish()


func _package(h: House) -> void:
	var p := Props.pickup_box(h, Vector3(6.6, 0.0, 11.65), "package", Vector3(0.34, 0.22, 0.28), Mats.color(Color(0.62, 0.48, 0.32), 0.95), 1.2)
	p.rotation_degrees.y = rng.randf_range(-20, 20)
	B.box(p, Vector3(0.36, 0.002, 0.06), Vector3(0, 0.221, 0), Mats.color(Color(0.75, 0.7, 0.55), 0.4))
	B.box(p, Vector3(0.12, 0.002, 0.08), Vector3(0.08, 0.222, 0.06), Mats.m("paper"))
	B.label(p, "D. WHITCOMB\n9 LARKSPUR CT", Vector3(0.08, 0.224, 0.06), 0.0006, Color(0.1, 0.1, 0.12), Vector3(-90, 0, 0), 32)
	WorldState.set_state("porch/package", true)


func _flyer(h: House) -> void:
	var r := Readable.new()
	r.name = "Flyer"
	h.add_child(r)
	r.position = Vector3(5.75, 0.014, 11.45)
	r.rotation_degrees.y = rng.randf_range(-25, 25)
	r.setup("flyer", FLYER, Vector2(0.21, 0.28), Mats.color(Color(0.95, 0.9, 0.6), 0.9))
	WorldState.set_state("porch/flyer", true)
