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
			# in a house without light, a pure black shape would be invisible
			if WorldState.get_state("power/out", false):
				f.set_rim(1.3)
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
