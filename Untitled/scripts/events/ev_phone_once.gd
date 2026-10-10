extends MysteryEvent
## The phone rings once and stops. If you pick it up fast enough: an open line,
## somebody breathing, then the click.

var phone: Phone


func _init() -> void:
	id = "phone_once"
	title = "One ring"
	track = "side"
	intensity = 1
	min_night = 1
	max_per_night = 1
	resources = ["phone"]
	kinds = ["temporary"]


func can_start() -> bool:
	var p := WorldState.get_obj("phone") as Phone
	return p != null and not p.in_call and not p.ringing


func _start() -> void:
	phone = WorldState.get_obj("phone") as Phone
	phone.ring(1, _on_answer)
	record("ring")
	await wait(9.0)
	if not phone.in_call:
		finish()


func _on_answer(_p: Phone) -> void:
	record("answered")
	phone.play_extra("breath_close", -12.0)
	await wait(5.0)
	if phone.in_call:
		phone.play_line("phone_hangup", [], true)
	await wait(2.0)
	finish()
