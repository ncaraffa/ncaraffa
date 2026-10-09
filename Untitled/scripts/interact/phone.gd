class_name Phone
extends Interactable
## Landline telephone. Rings a given number of times; may be answered while
## ringing. Calls are played through the "Phone" bus (handset to the ear).

signal answered
signal missed
signal hung_up

const RING_PERIOD := 6.0   # 2 s bell + 4 s silence (North American cadence)
const MAX_DISTANCE := 2.6

var ringing := false
var in_call := false
var rings_done := 0
var rings_total := 0
var handset: Node3D
var handset_home: Transform3D
var line: AudioStreamPlayer
var hiss: AudioStreamPlayer
var _ring_player: AudioStreamPlayer3D
var _ring_t := 0.0
var _on_answer: Callable
var _call_id := 0


func setup(id: String) -> void:
	register(id)
	var body_mat := Mats.color(Color(0.55, 0.47, 0.38), 0.45)
	B.box(self, Vector3(0.2, 0.07, 0.22), Vector3(0, 0.035, 0), body_mat)
	B.box(self, Vector3(0.12, 0.012, 0.12), Vector3(0, 0.072, 0.03), Mats.color(Color(0.85, 0.83, 0.78), 0.4))
	for i in 12:
		var a := i * TAU / 12.0
		B.cyl(self, 0.008, 0.008, 0.004, Vector3(cos(a) * 0.04, 0.08, 0.03 + sin(a) * 0.04), Mats.m("black"), false, Vector3.ZERO, 6)
	handset = B.node(self, "Handset", Vector3(0, 0.085, -0.055))
	B.box(handset, Vector3(0.22, 0.035, 0.05), Vector3.ZERO, body_mat)
	B.box(handset, Vector3(0.06, 0.04, 0.06), Vector3(-0.09, -0.01, 0), body_mat)
	B.box(handset, Vector3(0.06, 0.04, 0.06), Vector3(0.09, -0.01, 0), body_mat)
	handset_home = handset.transform
	# cord
	B.cyl(self, 0.006, 0.006, 0.25, Vector3(-0.13, 0.05, -0.02), Mats.m("black"), false, Vector3(0, 0, 70), 6)
	B.interact_area(self, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.08, 0))
	line = AudioStreamPlayer.new()
	line.bus = "Phone"
	add_child(line)
	hiss = AudioStreamPlayer.new()
	hiss.bus = "Phone"
	hiss.volume_db = -18
	hiss.stream = AudioManager.stream("line_hiss")
	add_child(hiss)


func get_prompt() -> String:
	if ringing:
		return "Answer"
	if in_call:
		return "Hang up"
	return "Pick up"


func ring(count: int, on_answer: Callable = Callable()) -> void:
	ringing = true
	rings_total = count
	rings_done = 0
	_on_answer = on_answer
	_ring_t = 0.0
	_ring_once()


func _ring_once() -> void:
	rings_done += 1
	_ring_player = AudioManager.play_3d("phone_ring", global_position + Vector3(0, 0.1, 0), 2.0, 1.0, 7.0, 70.0)
	WorldState.set_state("phone/rings_heard", rings_done)


func _process(delta: float) -> void:
	if ringing:
		_ring_t += delta
		if _ring_t >= RING_PERIOD:
			_ring_t = 0.0
			if rings_done >= rings_total:
				_stop_ringing()
				missed.emit()
			else:
				_ring_once()
		elif rings_done >= rings_total and _ring_t >= 3.0:
			# after the last bell, give it a moment then stop for good
			_stop_ringing()
			missed.emit()
	if in_call and WorldState.player:
		if WorldState.player.global_position.distance_to(global_position) > MAX_DISTANCE:
			hang_up()


func _stop_ringing() -> void:
	ringing = false
	if is_instance_valid(_ring_player):
		_ring_player.stop()
		_ring_player.queue_free()


func interact(_player: Node) -> void:
	if ringing:
		_stop_ringing()
		_lift()
		WorldState.log_interaction("phone_answer", obj_id)
		answered.emit()
		if _on_answer.is_valid():
			_on_answer.call(self)
	elif in_call:
		hang_up()
	else:
		_lift()
		WorldState.log_interaction("phone_pickup", obj_id)
		play_line("dial_tone", [], false)


func _lift() -> void:
	in_call = true
	_call_id += 1
	AudioManager.play_3d("phone_pickup", global_position, -6.0, 1.0, 2.0)
	var t := create_tween()
	t.tween_property(handset, "position", handset_home.origin + Vector3(0, 0.25, 0.05), 0.25)
	hiss.play()


func hang_up() -> void:
	if not in_call:
		return
	in_call = false
	_call_id += 1
	_clear_extras()
	line.stop()
	hiss.stop()
	var hud = WorldState.get_obj("hud")
	if hud:
		hud.clear_subtitle()
	AudioManager.play_3d("phone_hangup", global_position, -4.0, 1.0, 3.0)
	var t := create_tween()
	t.tween_property(handset, "transform", handset_home, 0.2)
	hung_up.emit()


## Plays a sound through the handset. `subs` = [[seconds, text], ...].
func play_line(sound_name: String, subs: Array = [], dial_after := true, delay := 0.0) -> void:
	var my_call := _call_id
	if sound_name == "phone_hangup":
		_clear_extras()
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if my_call != _call_id or not in_call:
			return
	line.stream = AudioManager.stream(sound_name)
	line.volume_db = -2.0
	line.play()
	var hud = WorldState.get_obj("hud")
	for s in subs:
		_subtitle_later(my_call, float(s[0]), String(s[1]), hud)
	if dial_after:
		await line.finished
		if my_call != _call_id or not in_call:
			return
		AudioManager.play_ui("phone_hangup", -20.0)
		await get_tree().create_timer(1.2).timeout
		if my_call != _call_id or not in_call:
			return
		hiss.stop()
		line.stream = AudioManager.stream("dial_tone")
		line.volume_db = -10.0
		line.play()


func _subtitle_later(call_id: int, at: float, text: String, hud) -> void:
	await get_tree().create_timer(at).timeout
	if call_id == _call_id and in_call and hud:
		hud.show_subtitle(text, 3.5)


## An extra sound mixed into the handset (background of the caller's line).
func play_extra(sound_name: String, volume_db := -12.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Phone"
	p.stream = AudioManager.stream(sound_name)
	p.volume_db = volume_db
	add_child(p)
	p.add_to_group("phone_extra")
	p.play()
	p.finished.connect(p.queue_free)
	return p


func _clear_extras() -> void:
	for p in get_children():
		if p is AudioStreamPlayer and p.is_in_group("phone_extra"):
			p.queue_free()
