extends MysteryEvent
## A silhouette in a neighbour's lit window. It does not react to anything.


func _init() -> void:
	id = "ap_window"
	title = "Silhouette in a neighbour's window"
	track = "side"
	intensity = 1
	min_night = 2
	max_per_night = 2
	kinds = ["temporary"]


func _start() -> void:
	var nb = WorldState.get_obj("neighborhood")
	var fams := ["Leland", "Whitcomb", "Pruitt", "Ocampo"]
	if night() >= 4:
		fams.append("Leland")
	var fam: String = fams[rng.randi() % fams.size()]
	var h: NeighborHouse = nb.houses.get(fam)
	if h == null or WorldState.is_locked("house_" + fam.to_lower()):
		finish()
		return
	var i: int = rng.randi() % maxi(1, mini(4, h.window_count()))
	var dur := rng.randf_range(6.0, 22.0)
	h.show_silhouette(i, dur)
	record(fam, {"window": i, "secs": snappedf(dur, 1)})
	await wait(dur)
	finish()
