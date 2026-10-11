class_name Scare
extends Node
## Base class for an intense scare managed by the ScareDirector.
## A scare is first ARMED (it waits for its moment: the player looking down a
## hallway, opening a door...). If the moment never comes it quietly disarms.

var id := ""
var min_night := 3
var weight := 1.0
var timeout := 200.0
var armed := false
var firing := false
var director: Node
var rng := RandomNumberGenerator.new()
var _armed_t := 0.0


func can_arm() -> bool:
	return true


func arm() -> void:
	armed = true
	firing = false
	_armed_t = 0.0
	_on_arm()


func _on_arm() -> void:
	pass


func disarm(reason := "timeout") -> void:
	if not armed:
		return
	armed = false
	_on_disarm()
	director.on_scare_done(self, false, reason)


func _on_disarm() -> void:
	pass


func _process(delta: float) -> void:
	if not armed or firing:
		return
	_armed_t += delta
	if _armed_t > timeout:
		disarm("timeout")
		return
	_watch(delta)


## Override: check the trigger condition every frame while armed.
func _watch(_delta: float) -> void:
	pass


## Override: the scare itself. Must end with done().
func fire() -> void:
	done(true)


func done(happened: bool) -> void:
	armed = false
	firing = false
	director.on_scare_done(self, happened, "fired" if happened else "aborted")


func house() -> House:
	return WorldState.get_obj("house") as House


func player() -> Node:
	return WorldState.player


func figure() -> ShadowFigure:
	var pool = WorldState.get_obj("figures")
	return pool.borrow() if pool else null


func wait(s: float) -> Signal:
	return get_tree().create_timer(s, false).timeout


func shake(amount: float, dur := 0.35) -> void:
	var p = player()
	if p and p.has_method("shake"):
		p.shake(amount, dur)


func stinger(pos: Vector3, offset := 0.0) -> void:
	AudioManager.play_3d("stinger_%d" % rng.randi_range(0, 2), pos, offset, rng.randf_range(0.92, 1.06))
