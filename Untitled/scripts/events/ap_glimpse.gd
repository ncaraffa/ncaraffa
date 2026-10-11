extends MysteryEvent
## A figure crosses a doorway at the far side of the room you are in.
## Two seconds. Did you see that?

# house-local start/end points of short walks across openings
const PATHS := [
	[Vector3(10.4, 0, 1.4), Vector3(12.2, 0, 1.4)],    # dining -> kitchen
	[Vector3(12.6, 0, 5.4), Vector3(12.6, 0, 7.4)],    # kitchen -> living
	[Vector3(8.6, 0, 7.4), Vector3(6.6, 0, 9.4)],      # living -> foyer
	[Vector3(4.9, 0, 7.6), Vector3(4.9, 0, 9.4)],      # hall -> foyer
	[Vector3(9.0, 0, 5.6), Vector3(9.4, 0, 7.4)],      # dining -> living
]

var f: ShadowFigure


func _init() -> void:
	id = "ap_glimpse"
	title = "Someone crossing a doorway"
	track = "side"
	intensity = 2
	min_night = 3
	max_per_night = 1
	resources = ["figure_inside"]
	kinds = ["temporary"]


func _pick() -> Array:
	var h := house()
	var opts := PATHS.duplicate()
	opts.shuffle()
	for pth in opts:
		var a: Vector3 = h.to_global(pth[0])
		var b: Vector3 = h.to_global(pth[1])
		var mid := (a + b) / 2.0
		var d := Perception.dist(mid)
		if d > 3.5 and d < 11.0 and Perception.view_angle(mid + Vector3(0, 1.4, 0)) < 55.0 and not Perception.sees(a + Vector3(0, 1.4, 0), 70.0):
			return [a, b]
	return []


func can_start() -> bool:
	return WorldState.player_inside and not _pick().is_empty()


func _start() -> void:
	var pth := _pick()
	f = figure()
	if pth.is_empty() or f == null:
		finish()
		return
	f.appear(pth[0], pth[1] - pth[0])
	f.look_target = null
	f.stiff = true
	f.walk_path(PackedVector3Array([pth[1]]), 1.5)
	f.finished_path.connect(_on_done, CONNECT_ONE_SHOT)
	record("crossing")


func _on_done() -> void:
	f.vanish("instant")
	finish()
