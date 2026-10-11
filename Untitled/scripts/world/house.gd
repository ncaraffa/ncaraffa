class_name House
extends Node3D
## The player's house. Knows its own volume (for indoor/outdoor audio) and a
## set of named local points used by events (paths for footsteps, etc).

var points: Dictionary = {}
var paths: Dictionary = {}
var volumes: Array = [
	AABB(Vector3(-0.15, -0.4, -0.15), Vector3(16.3, 3.2, 11.3)),
	AABB(Vector3(16.0, -0.5, 1.9), Vector3(6.6, 3.3, 9.2)),
]


func contains_point(p: Vector3) -> bool:
	var l := to_local(p)
	for v in volumes:
		if v.has_point(l):
			return true
	return false


func gp(point_name: String) -> Vector3:
	return to_global(points.get(point_name, Vector3.ZERO))


func global_path(path_name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in paths.get(path_name, []):
		out.append(to_global(p))
	return out
