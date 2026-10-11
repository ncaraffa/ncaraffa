extends MysteryEvent
## EVENT 8 — The kitchen clock now disagrees with every other clock. It stays so.


func _init() -> void:
	intensity = 1
	id = "clock"
	title = "The kitchen clock"
	resources = ["clock_kitchen"]
	kinds = ["persistent"]
	repeatable = false


func _start() -> void:
	var c := WorldState.get_obj("clock_kitchen") as WallClock
	if c == null:
		finish()
		return
	var minutes := -9.0 if rng.randf() < 0.85 else -11.0
	c.set_offset(c.offset_minutes() + minutes)
	record("%+d min" % int(minutes))
	finish()
