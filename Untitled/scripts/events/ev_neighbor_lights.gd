extends MysteryEvent
## EVENT 2 — A house across the street lights up all at once. Later some go out.
## Maybe somebody just came home.

var family := ""


func _init() -> void:
	intensity = 0
	id = "neighbor_lights"
	title = "The house across the street"
	resources = ["neighbor_lights"]
	kinds = ["temporary"]


func _start() -> void:
	family = "Whitcomb" if rng.randf() < 0.7 else "Leland"
	var h := WorldState.get_obj("neighbor_" + family.to_lower()) as NeighborHouse
	if h == null or not WorldState.try_lock("house_" + family.to_lower(), id):
		finish()
		return
	var n := h.window_count()
	var lit := []
	for i in n:
		if rng.randf() < 0.85:
			lit.append(i)
	# all at once (a few milliseconds apart, like one breaker)
	for i in lit:
		h.set_window(i, true)
	if rng.randf() < 0.6:
		h.set_porch(true)
	record(family, {"windows": lit.size()})
	after(rng.randf_range(50.0, 150.0), func(): _dim(h, rng.randi_range(1, 3)))
	after(rng.randf_range(220.0, 420.0), func(): _settle(h))


func _dim(h: NeighborHouse, count: int) -> void:
	var on := []
	for i in h.window_count():
		if h.windows[i].on:
			on.append(i)
	on.shuffle()
	for k in min(count, on.size()):
		h.set_window(on[k], false)


func _settle(h: NeighborHouse) -> void:
	if rng.randf() < 0.65:
		var on := []
		for i in h.window_count():
			if h.windows[i].on:
				on.append(i)
		on.shuffle()
		for k in max(0, on.size() - rng.randi_range(1, 2)):
			h.set_window(on[k], false)
	if rng.randf() < 0.5:
		h.set_porch(false)
	WorldState.unlock("house_" + family.to_lower(), id)
	finish()
