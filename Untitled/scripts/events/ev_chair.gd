extends MysteryEvent
## EVENT 1 — A kitchen chair is no longer where it was. Persistent.


func _init() -> void:
	intensity = 1
	id = "chair"
	title = "The chair"
	resources = ["kitchen_chairs"]
	kinds = ["persistent"]


func _start() -> void:
	var cid := "kitchen_chair_a" if rng.randf() < 0.6 else "kitchen_chair_b"
	var chair := WorldState.get_obj(cid) as MovableChair
	if chair == null:
		finish()
		return
	var variant := pick_weighted({"pulled": 0.4, "turned": 0.35, "both": 0.25})
	var t: Transform3D = chair.transform
	if variant != "turned":
		t = t.translated_local(Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(0.26, 0.45)))
	if variant != "pulled":
		var ang := deg_to_rad(rng.randf_range(16.0, 38.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		t = Transform3D(t.basis.rotated(Vector3.UP, ang), t.origin)
	var silent := rng.randf() < 0.55
	if silent:
		chair.transform = t
		chair.displaced = true
		chair._store()
	else:
		chair.slide_to(t, 1.1, true)
	record(variant, {"chair": cid, "silent": silent})
	await wait(1.5)
	finish()
