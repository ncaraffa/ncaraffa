class_name DebugEventPanel
extends CanvasLayer
## Development-only tools (F1). Never created unless GameManager.dev_mode.
## Accelerate the event clock, fire events, inspect world state and the player,
## test random orders, reset the world, see conflicts/warnings.

var root: PanelContainer
var status: Label
var log_box: TextEdit
var info: TextEdit
var director: EventDirector
var _t := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.02, 0.92)
	sb.set_content_margin_all(10)
	root.add_theme_stylebox_override("panel", sb)
	root.position = Vector2(10, 10)
	root.custom_minimum_size = Vector2(720, 0)
	root.visible = false
	add_child(root)
	var v := VBoxContainer.new()
	root.add_child(v)
	var title := Label.new()
	title.text = "DEV — EventDirector / WorldState  (F1 to close)"
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	v.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	v.add_child(status)
	var speed := HBoxContainer.new()
	v.add_child(speed)
	_lbl(speed, "event clock:")
	for s: float in [1.0, 10.0, 60.0, 300.0]:
		_btn(speed, "%dx" % int(s), func(): director.time_scale = s)
	_btn(speed, "next event now", func(): director.skip_to_next())
	var evs := HFlowContainer.new()
	v.add_child(evs)
	_lbl(evs, "fire:")
	var tools := HFlowContainer.new()
	v.add_child(tools)
	_btn(tools, "world state", func(): info.text = WorldState.dump())
	_btn(tools, "event log", func(): info.text = _event_log())
	_btn(tools, "warnings", func(): info.text = "\n".join(WorldState.warnings) if not WorldState.warnings.is_empty() else "(no warnings)")
	_btn(tools, "simulate orders", func(): info.text = _sim())
	_btn(tools, "interactions", func(): info.text = _interactions())
	_btn(tools, "reset world", func(): GameManager.restart_world())
	var tp := HFlowContainer.new()
	v.add_child(tp)
	_lbl(tp, "teleport:")
	for t in [["bedroom", "h", Vector3(2.7, 0.05, 2.9)], ["kitchen", "h", Vector3(13.0, 0.05, 2.5)], ["living", "h", Vector3(10.0, 0.05, 8.0)],
			["porch", "h", Vector3(5.9, -0.1, 12.5)], ["court", "w", Vector3(0, 0.1, 0)], ["road end", "w", Vector3(0, 0.1, 140)], ["backyard", "w", Vector3(0, 0.1, -44)]]:
		var item: Array = t
		_btn(tp, item[0], func(): _teleport(item[1], item[2]))
	info = TextEdit.new()
	info.custom_minimum_size = Vector2(700, 260)
	info.editable = false
	v.add_child(info)
	log_box = TextEdit.new()
	log_box.custom_minimum_size = Vector2(700, 120)
	log_box.editable = false
	v.add_child(log_box)
	WorldState.event_logged.connect(func(e): log_box.text += "[%s %5.0fs] %s : %s %s\n" % [e.clock, e.time, e.id, e.variant, str(e.data)])
	_fill_events.call_deferred(evs)


func _fill_events(container: Container) -> void:
	director = WorldState.get_obj("director") as EventDirector
	if director == null:
		return
	for ev in director.events:
		var eid: String = ev.id
		_btn(container, eid, func(): info.text = director.force(eid))


func _lbl(p: Node, t: String) -> void:
	var l := Label.new()
	l.text = t
	p.add_child(l)


func _btn(p: Node, t: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(fn)
	p.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		root.visible = not root.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if root.visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not root.visible or director == null:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	var p := WorldState.player
	var pos: Vector3 = p.global_position if p else Vector3.ZERO
	var running := []
	for ev in director.events:
		if ev.running:
			running.append(ev.id)
	status.text = "real %.0fs | world clock %s | director %.0fs x%.0f | next in %.0fs | fired %d/%d %s\nplayer %s inside=%s | running %s | locks %s" % [
		WorldState.sim_time, WorldState.format_clock(WorldState.clock_minutes()), director.clock, director.time_scale,
		director.time_to_next(), director.fired.size(), director.events.size(), "(after-phase)" if director.main_done() else "",
		str(pos.snapped(Vector3.ONE * 0.1)), WorldState.player_inside, str(running), str(WorldState.locks)]


func _event_log() -> String:
	var lines := PackedStringArray(["seed %d  order: %s" % [director.seed_used, " > ".join(director.order)]])
	for e in WorldState.event_log:
		lines.append("[%s %5.0fs] %-16s %-14s inside=%s %s" % [e.clock, e.time, e.id, e.variant, e.player_inside, str(e.data)])
	return "\n".join(lines)


func _interactions() -> String:
	var lines := PackedStringArray()
	for i in WorldState.interaction_log:
		lines.append("%6.1fs %s %s" % [i.time, i.what, i.id])
	return "\n".join(lines)


func _sim() -> String:
	var lines := PackedStringArray()
	for seq in director.simulate_orders(6):
		lines.append(" > ".join(seq))
	return "\n".join(lines)


func _teleport(space: String, pos: Vector3) -> void:
	var p := WorldState.player
	if p == null:
		return
	if space == "h":
		var h := WorldState.get_obj("house") as House
		p.global_position = h.to_global(pos)
	else:
		p.global_position = pos
	p.velocity = Vector3.ZERO
