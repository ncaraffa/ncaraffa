extends Scare
## A — THE FIGURE IN THE HALLWAY. Look down the hall and it is suddenly there,
## much too close, and it comes at you. Then it is gone.

const HALL := Rect2(4.25, 2.9, 1.3, 5.3)   # local x/z of the hallway floor


func _init() -> void:
	id = "hallway"
	min_night = 3
	weight = 1.2


func can_arm() -> bool:
	return WorldState.player_inside and not WorldState.is_locked("figure_inside")


func _watch(_d: float) -> void:
	var h := house()
	var p = player()
	if h == null or p == null:
		return
	var lp := h.to_local(p.global_position)
	var in_hall := HALL.has_point(Vector2(lp.x, lp.z))
	var at_mouth := Rect2(4.2, 8.2, 2.0, 1.6).has_point(Vector2(lp.x, lp.z))
	if not (in_hall or at_mouth):
		return
	var fwd: Vector3 = h.global_basis.inverse() * (-p.camera.global_transform.basis.z)
	if absf(fwd.z) < 0.88:
		return
	var dist := rng.randf_range(1.7, 2.3)
	var spot := lp + Vector3(fwd.x, 0, fwd.z).normalized() * dist
	spot.x = clamp(spot.x, 4.65, 5.15)
	if not HALL.has_point(Vector2(spot.x, spot.z)) or absf(spot.z - lp.z) < 1.3:
		return
	var g := h.to_global(Vector3(spot.x, 0.0, spot.z))
	if not Perception.sees(g + Vector3(0, 1.3, 0), 30.0):
		return
	firing = true
	_fire_at(g)


func fire() -> void:
	# forced from the debug panel: put it in front of the player wherever they are
	var p = player()
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	firing = true
	_fire_at(p.global_position + fwd.normalized() * 2.0)


func _fire_at(g: Vector3) -> void:
	var f := figure()
	if f == null:
		done(false)
		return
	var p = player()
	var hall := WorldState.get_obj("hall_ceiling") as LightFixture
	var was_on := hall != null and hall.is_on
	if was_on:
		hall.set_on(false, true)
	f.appear(g, p.global_position - g)
	f.head_tilt = rng.randf_range(-20, 20)
	stinger(g + Vector3(0, 1.6, 0), 2.0)
	shake(0.06, 0.4)
	await wait(0.12)
	var toward: Vector3 = p.global_position - g
	toward.y = 0
	var stop: float = max(0.0, toward.length() - 0.75)
	f.lunge(g + toward.normalized() * min(0.8, stop), 0.2)
	if was_on:
		await wait(0.12)
		hall.set_on(true, true)
		hall.flicker(0.5)
	await wait(0.35)
	f.vanish("instant")
	if was_on:
		hall.flicker(0.3)
	done(true)
