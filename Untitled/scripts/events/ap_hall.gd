extends MysteryEvent
## Someone standing at the far end of the hallway, by the bathroom door, half in
## the dark. It does not attack. Sometimes being there is enough.

var f: ShadowFigure
var _t := 0.0
var _seen := 0.0
var _mode := ""
var _restore_light := false


func _init() -> void:
	id = "ap_hall"
	title = "Figure at the end of the hall"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	resources = ["figure_inside"]
	kinds = ["temporary"]


func can_start() -> bool:
	var h := house()
	if h == null or WorldState.player == null:
		return false
	var spot := h.to_global(Vector3(4.9, 0, 3.15))
	# never pop in while the spot is in view
	return not Perception.sees(spot + Vector3(0, 1.4, 0), 70.0) and Perception.dist(spot) > 3.0


func _start() -> void:
	f = figure()
	if f == null:
		finish()
		return
	var h := house()
	var hall := WorldState.get_obj("hall_ceiling") as LightFixture
	_restore_light = false
	if hall and hall.is_on and rng.randf() < 0.6:
		hall.set_on(false, true)
		_restore_light = rng.randf() < 0.5
	f.appear(h.to_global(Vector3(4.9, 0, 3.15)), h.global_basis * Vector3(0, 0, 1))
	f.look_target = null
	f.head_tilt = rng.randf_range(-8, 8)
	_mode = pick_weighted({"wait_unseen": 0.55, "step_back": 0.25, "turn_and_go": 0.2})
	_t = 0.0
	_seen = 0.0
	record(_mode, {"light_off": hall != null and not hall.is_on})


func _process(delta: float) -> void:
	if not running or f == null:
		return
	_t += delta
	var seen := Perception.sees_figure(f)
	if seen:
		_seen += delta
	if f.state == ShadowFigure.State.HIDDEN:
		_end()
		return
	if _t > 45.0 and not seen:
		f.vanish("instant")
		return
	if _seen > 1.2 or Perception.dist(f.global_position) < 2.5:
		match _mode:
			"wait_unseen":
				if not seen:
					f.vanish("instant")
			"step_back":
				if f.state == ShadowFigure.State.WATCHING:
					f.walk_path(PackedVector3Array([house().to_global(Vector3(4.95, 0, 1.9))]), 0.7, true)
					f.finished_path.connect(func(): f.vanish("instant"), CONNECT_ONE_SHOT)
			"turn_and_go":
				if f.state == ShadowFigure.State.WATCHING:
					f.look_target = WorldState.player.camera
					f.twitch()
					await wait(0.9)
					if f.state != ShadowFigure.State.HIDDEN:
						f.vanish("instant")


func _end() -> void:
	if _restore_light:
		var hall := WorldState.get_obj("hall_ceiling") as LightFixture
		if hall:
			hall.set_on(true, true)
	finish()
