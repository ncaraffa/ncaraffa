class_name Perception
## What the player can see / hear. Used by apparitions and scares so they can
## happen while being watched, or deliberately while not.


static func camera() -> Camera3D:
	var p = WorldState.player
	return p.camera if p else null


## Angle (degrees) between the view direction and the direction to `point`.
static func view_angle(point: Vector3) -> float:
	var cam := camera()
	if cam == null:
		return 180.0
	var fwd := -cam.global_transform.basis.z
	var to := (point - cam.global_position).normalized()
	return rad_to_deg(acos(clamp(fwd.dot(to), -1.0, 1.0)))


## True if `point` is inside the view cone and not hidden behind world geometry.
static func sees(point: Vector3, max_angle := 38.0, max_dist := 80.0) -> bool:
	var cam := camera()
	if cam == null:
		return false
	if cam.global_position.distance_to(point) > max_dist:
		return false
	if view_angle(point) > max_angle:
		return false
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, point, B.LAYER_WORLD)
	q.exclude = [WorldState.player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(point) < 0.4


## A figure is "seen" if its head or chest is visible.
static func sees_figure(f: Node3D) -> bool:
	return sees(f.global_position + Vector3(0, 1.65, 0)) or sees(f.global_position + Vector3(0, 1.2, 0))


static func player_pos() -> Vector3:
	var p = WorldState.player
	return p.global_position if p else Vector3.ZERO


static func dist(point: Vector3) -> float:
	return player_pos().distance_to(point)
