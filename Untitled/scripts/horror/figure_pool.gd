class_name FigurePool
extends Node3D
## Owns the shadow figures. Systems borrow one, use it, and it returns itself
## to the pool when it vanishes.

var figures: Array = []


func _ready() -> void:
	name = "Figures"
	WorldState.register("figures", self)
	for i in 4:
		var f := ShadowFigure.new()
		f.name = "Figure%d" % i
		add_child(f)
		figures.append(f)


func borrow() -> ShadowFigure:
	for f in figures:
		if f.state == ShadowFigure.State.HIDDEN and not f.get_meta("busy", false):
			f.set_meta("busy", true)
			f.vanished.connect(func(): f.set_meta("busy", false), CONNECT_ONE_SHOT)
			f.look_target = WorldState.player.camera if WorldState.player else null
			return f
	return null


func any_visible() -> bool:
	for f in figures:
		if f.is_visible_figure():
			return true
	return false


func hide_all() -> void:
	for f in figures:
		if f.state != ShadowFigure.State.HIDDEN:
			f.vanish("instant")
