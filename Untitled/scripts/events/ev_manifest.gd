extends MysteryEvent
## A symbol, drawn where you were not looking. Small. Then, often, it isn't there.


func _init() -> void:
	id = "manifest"
	title = "A symbol appears"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 2
	kinds = ["temporary"]


func can_start() -> bool:
	return WorldState.get_obj("cult") != null and WorldState.player_inside


func _start() -> void:
	var cult = WorldState.get_obj("cult")
	var n = cult.small_sigil()
	record("sigil" if n else "none")
	finish()
