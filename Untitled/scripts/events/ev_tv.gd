extends MysteryEvent
## EVENT 6 — The living room TV turns itself on. Static, a rolling picture, or a
## blue screen that just stays.


func _init() -> void:
	intensity = 1
	id = "tv"
	title = "The television"
	resources = ["tv"]
	kinds = ["temporary", "persistent"]


func _start() -> void:
	var tv := WorldState.get_obj("tv") as TV
	if tv == null:
		finish()
		return
	if tv.power:
		var prev := tv.mode
		record("channel_glitch")
		tv.set_mode(1)
		await wait(rng.randf_range(3.0, 7.0))
		if tv.power and tv.mode == 1:
			tv.set_mode(prev)
		finish()
		return
	var variant := pick_weighted({"static": 0.4, "rolling": 0.35, "stays_on": 0.25})
	record(variant)
	match variant:
		"static":
			tv.set_power(true, 1)
		"rolling":
			tv.set_power(true, 2)
		"stays_on":
			tv.set_power(true, 3)
			finish()
			return
	await wait(rng.randf_range(5.0, 14.0))
	if tv.power and (tv.mode == 1 or tv.mode == 2):
		tv.set_power(false)
	finish()
