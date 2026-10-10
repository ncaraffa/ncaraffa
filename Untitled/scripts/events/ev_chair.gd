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
	var variant := pick_weighted({"pulled": 0.3, "turned": 0.25, "both": 0.3, "fallen": 0.15})
	var t: Transform3D = chair.transform
	if variant == "fallen":
		# knocked over, lying on its back next to the table
		t = t.translated_local(Vector3(0, 0, 0.55))
		t = Transform3D(t.basis.rotated(t.basis.x.normalized(), deg_to_rad(-85.0)), t.origin + Vector3(0, 0.05, 0))
		chair.transform = t
		chair.displaced = true
		chair._store()
		AudioManager.play_3d("object_fall", chair.global_position + Vector3(0, 0.3, 0), 2.0, 0.8)
		record(variant, {"chair": cid, "silent": false})
		await wait(1.5)
		finish()
		return
	if variant != "turned":
		t = t.translated_local(Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(0.4, 0.65)))
	if variant != "pulled":
		var ang := deg_to_rad(rng.randf_range(28.0, 55.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
		t = Transform3D(t.basis.rotated(Vector3.UP, ang), t.origin)
	var silent := rng.randf() < 0.3
	if silent:
		chair.transform = t
		chair.displaced = true
		chair._store()
	else:
		chair.slide_to(t, 1.1, true)
	record(variant, {"chair": cid, "silent": silent})
	await wait(1.5)
	finish()
