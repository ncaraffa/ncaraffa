extends MysteryEvent
## A light you left on, in a room you are not in, is off now. A switch clicked.


func _init() -> void:
	id = "lights_out"
	title = "A light goes out"
	track = "side"
	intensity = 1
	min_night = 3
	max_per_night = 1
	kinds = ["persistent"]


func _start() -> void:
	var ids := ["living_ceiling", "kitchen_ceiling", "dining_chandelier", "foyer_ceiling", "b2_ceiling", "living_floorlamp", "garage_tube", "hall_ceiling"]
	ids.shuffle()
	for lid in ids:
		var l := WorldState.get_obj(lid) as LightFixture
		if l and l.is_on and Perception.dist(l.global_position) > 5.0 and not Perception.sees(l.global_position, 60.0):
			l.set_on(false, true)
			AudioManager.play_3d("switch_click", l.global_position + Vector3(0, -1.3, 0), 2.0)
			record(lid)
			break
	finish()
