extends MysteryEvent
## EVENT 4 — The phone rings exactly four times. If nobody answers, that's it.

var call_type := ""
var answered := false
var phone: Phone


func _init() -> void:
	id = "phone"
	title = "The phone"
	resources = ["phone"]
	kinds = ["temporary", "reactive"]


func can_start() -> bool:
	var p := WorldState.get_obj("phone") as Phone
	return p != null and not p.in_call and not p.ringing


func _start() -> void:
	phone = WorldState.get_obj("phone") as Phone
	answered = false
	call_type = pick_weighted({"silence": 0.3, "time": 0.25, "wrong": 0.25, "distant": 0.2})
	phone.missed.connect(_on_missed, CONNECT_ONE_SHOT)
	phone.ring(4, _on_answer)


func _on_missed() -> void:
	if answered:
		return
	record("missed", {"call": call_type})
	finish()


func _on_answer(_p: Phone) -> void:
	answered = true
	if phone.missed.is_connected(_on_missed):
		phone.missed.disconnect(_on_missed)
	record("answered", {"call": call_type})
	phone.hung_up.connect(_on_hung_up, CONNECT_ONE_SHOT)
	# whatever happens on the line, the event itself lets go after a while
	get_tree().create_timer(45.0, false).timeout.connect(_on_hung_up)
	match call_type:
		"silence":
			# nothing but the line. then the other side hangs up.
			await wait(rng.randf_range(9.0, 15.0))
			if phone.in_call:
				phone.play_line("phone_hangup", [], true)
		"time":
			phone.play_line("voice_time", [[0.1, "Hi."], [2.6, "Sorry. What time do you have?"], [9.2, "...Okay."], [10.9, "Thank you."]], true, 0.6)
		"wrong":
			phone.play_line("voice_wrong", [[0.05, "Hey. Is Dana there?"], [4.8, "...Oh."], [6.3, "Sorry. I think I have the wrong number."]], true, 0.5)
		"distant":
			# an open line somewhere outside: crickets, wind. A dog barks on the
			# line — and a dog barks in the neighbourhood at the same moment.
			phone.play_extra("crickets", -20.0)
			phone.play_extra("wind", -24.0)
			await wait(rng.randf_range(3.0, 5.0))
			if phone.in_call:
				var bark := "dog_bark_%d" % rng.randi_range(0, 3)
				phone.play_extra(bark, -10.0)
				var nh := WorldState.get_obj("neighbor_whitcomb") as Node3D
				if nh:
					AudioManager.play_3d(bark, nh.global_position + nh.global_basis.z * -14.0 + Vector3(0, 0.6, 0), -2.0, 1.0, 10.0, 120.0)
			await wait(rng.randf_range(6.0, 9.0))
			if phone.in_call:
				phone.play_line("phone_hangup", [], true)


func _on_hung_up() -> void:
	if running:
		finish()
