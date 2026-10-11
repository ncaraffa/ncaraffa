extends MysteryEvent
## A figure by the back fence, facing the house. It may leave while you go
## inside. It may still be there.

var f: ShadowFigure
var _t := 0.0
var _limit := 40.0
var _was_inside := true


func _init() -> void:
	id = "ap_backyard"
	title = "Figure by the back fence"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	resources = ["figure_outside"]
	kinds = ["temporary"]


func _start() -> void:
	f = figure()
	if f == null:
		finish()
		return
	var x := rng.randf_range(-8.5, 9.0)
	var pos := Vector3(x, 0.0, -51.2)
	f.appear(pos, Vector3(0, 0, -38) - pos, 2.0 if Perception.sees(pos + Vector3(0, 1.4, 0)) else 0.0)
	f.look_target = null
	f.set_rim(0.9)
	_t = 0.0
	_limit = rng.randf_range(20.0, 60.0)
	_was_inside = WorldState.player_inside
	record("fence", {"x": snappedf(x, 0.1)})


func _process(delta: float) -> void:
	if not running or f == null:
		return
	_t += delta
	var seen := Perception.sees_figure(f)
	# goes inside -> when you look out again it may be gone
	if WorldState.player_inside and not _was_inside and rng.randf() < 0.7:
		if not seen:
			f.vanish("instant")
	_was_inside = WorldState.player_inside
	if Perception.dist(f.global_position) < 7.0:
		f.vanish("instant" if not seen else "flicker")
	elif _t > _limit:
		f.vanish("fade" if seen else "instant", 3.0)
	if f.state == ShadowFigure.State.HIDDEN:
		finish()
