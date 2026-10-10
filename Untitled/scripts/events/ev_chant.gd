extends MysteryEvent
## Low voices from the backyard of number 6, for half a minute. The windows of
## that house flicker like candlelight. Then nothing.

var p: AudioStreamPlayer3D


func _init() -> void:
	id = "chant"
	title = "Chanting from number 6"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 3
	resources = ["house_leland_chant"]
	kinds = ["temporary"]


func can_start() -> bool:
	# once on night 2, twice on night 3, up to three times later
	var allowed: int = clampi(night() - 1, 1, 3)
	return int(director.tonight.get(id, 0)) < allowed


func _start() -> void:
	var h := WorldState.get_obj("neighbor_leland") as NeighborHouse
	if h == null:
		finish()
		return
	var pos := h.global_position - h.global_basis.z * 14.0 + Vector3(0, 1.2, 0)
	p = AudioManager.play_3d("chant_far", pos, -2.0 + min(night(), 5) * 1.2)
	if p:
		p.volume_db -= 20.0
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", p.volume_db + 20.0, 6.0)
	h.candles(true)
	var dur := rng.randf_range(25.0, 45.0)
	record("leland", {"secs": int(dur)})
	await wait(dur)
	if is_instance_valid(p):
		var tw2 := p.create_tween()
		tw2.tween_property(p, "volume_db", -60.0, 5.0)
		tw2.tween_callback(p.queue_free)
	await wait(5.0)
	h.candles(false)
	finish()
