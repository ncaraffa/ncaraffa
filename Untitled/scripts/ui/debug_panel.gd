class_name DebugEventPanel
extends CanvasLayer
## Development-only tools (F1). Never created unless GameManager.dev_mode
## (running from the editor, or launched with `-- --dev`).
##
## Tabs: Events (main + side tracks), Horror (scares, figures), Nights (chores,
## sleep), Audio (every sound, bus meters), World (state, teleports, door test).

var root: PanelContainer
var status: Label
var info: TextEdit
var log_box: TextEdit
var director: EventDirector
var scares: ScareDirector
var sound_pick: OptionButton
var _t := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.02, 0.93)
	sb.set_content_margin_all(10)
	root.add_theme_stylebox_override("panel", sb)
	root.position = Vector2(10, 10)
	root.custom_minimum_size = Vector2(780, 0)
	root.visible = false
	add_child(root)
	var v := VBoxContainer.new()
	root.add_child(v)
	var title := Label.new()
	title.text = "DEV — F1 to close"
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	v.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	v.add_child(status)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(760, 150)
	v.add_child(tabs)
	info = TextEdit.new()
	info.custom_minimum_size = Vector2(760, 230)
	info.editable = false
	v.add_child(info)
	log_box = TextEdit.new()
	log_box.custom_minimum_size = Vector2(760, 110)
	log_box.editable = false
	v.add_child(log_box)
	WorldState.event_logged.connect(func(e): log_box.text += "[%s %5.0fs] %s : %s %s\n" % [e.clock, e.time, e.id, e.variant, str(e.data)])
	_build_tabs.call_deferred(tabs)


func _tab(tabs: TabContainer, n: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = n
	tabs.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	return box


func _row(parent: Node, label := "") -> HFlowContainer:
	var r := HFlowContainer.new()
	parent.add_child(r)
	if label != "":
		_lbl(r, label)
	return r


func _build_tabs(tabs: TabContainer) -> void:
	director = WorldState.get_obj("director") as EventDirector
	scares = WorldState.get_obj("scare_director") as ScareDirector
	# ---------------- events
	var ev := _tab(tabs, "Events")
	var sp := _row(ev, "event clock:")
	for s in [1.0, 10.0, 60.0, 300.0]:
		var spd: float = s
		_btn(sp, "%dx" % int(spd), func(): director.time_scale = spd)
	_btn(sp, "next main event now", func(): director.skip_to_next())
	_btn(sp, "next side event now", func(): director.side_next_at = director.clock)
	var m := _row(ev, "main:")
	var s2 := _row(ev, "side:")
	for e in director.events:
		var eid: String = e.id
		_btn(m if e.track == "main" else s2, eid, func(): info.text = director.force(eid))
	var tools := _row(ev)
	_btn(tools, "event log", func(): info.text = _event_log())
	_btn(tools, "simulate orders", func(): info.text = _sim())
	_btn(tools, "warnings", func(): info.text = "\n".join(WorldState.warnings) if not WorldState.warnings.is_empty() else "(no warnings)")
	# ---------------- horror
	var hz := _tab(tabs, "Horror")
	var fire := _row(hz, "fire scare now:")
	var arm := _row(hz, "arm (waits for its trigger):")
	for s in scares.scares:
		var sid: String = s.id
		_btn(fire, sid, func(): info.text = scares.force(sid))
		_btn(arm, sid, func(): info.text = scares.try_arm(sid))
	var sc2 := _row(hz)
	_btn(sc2, "end recovery", func(): scares.recover_until = 0.0)
	_btn(sc2, "toggle ScareDirector", func():
		scares.enabled = not scares.enabled
		info.text = "ScareDirector enabled: %s" % scares.enabled)
	var fig := _row(hz, "figure at:")
	for f in [["3 m ahead", "ahead"], ["behind me", "behind"], ["hall end", "hall"], ["back fence", "fence"], ["across street", "street"], ["kitchen window (outside)", "kwin"]]:
		var where: String = f[1]
		_btn(fig, f[0], func(): _spawn_figure(where))
	_btn(fig, "hide all", func(): WorldState.get_obj("figures").hide_all())
	var fb := _row(hz, "figure does:")
	_btn(fb, "walk away", func(): _figure_do("walk"))
	_btn(fb, "lunge", func(): _figure_do("lunge"))
	_btn(fb, "twitch", func(): _figure_do("twitch"))
	_btn(fb, "fade out", func(): _figure_do("fade"))
	_btn(fb, "flicker out", func(): _figure_do("flicker"))
	# ---------------- nights
	var nt := _tab(tabs, "Nights")
	var nr := _row(nt)
	_btn(nr, "show tonight's list", func(): info.text = WorldState.get_obj("tasks").list_bbcode())
	_btn(nr, "complete chores", func(): WorldState.get_obj("tasks").debug_complete())
	_btn(nr, "sleep now (next night)", func(): WorldState.get_obj("night_manager").sleep())
	_btn(nr, "add late list line", func(): WorldState.get_obj("tasks")._add_late_line())
	_btn(nr, "3 am awakening now", func(): WorldState.get_obj("night_manager")._night_waking())
	# ---------------- audio
	var au := _tab(tabs, "Audio")
	var ar := _row(au, "sound:")
	sound_pick = OptionButton.new()
	var names := []
	for f in DirAccess.get_files_at("res://assets/audio"):
		var n := String(f).replace(".import", "")
		if n.ends_with(".wav") and not names.has(n.get_basename()):
			names.append(n.get_basename())
	names.sort()
	for n in names:
		sound_pick.add_item(n)
	ar.add_child(sound_pick)
	_btn(ar, "play at 1 m", func(): _play_test(1.0))
	_btn(ar, "at 5 m", func(): _play_test(5.0))
	_btn(ar, "at 15 m", func(): _play_test(15.0))
	_btn(ar, "at 40 m", func(): _play_test(40.0))
	_btn(au, "bus layout", func(): info.text = _buses())
	# ---------------- world
	var wd := _tab(tabs, "World")
	var wr := _row(wd)
	_btn(wr, "world state", func(): info.text = WorldState.dump())
	_btn(wr, "interactions", func(): info.text = _interactions())
	_btn(wr, "reset world", func(): GameManager.restart_world())
	var tp := _row(wd, "teleport:")
	for t in [["bedroom", "h", Vector3(2.4, 0.05, 1.9)], ["kitchen", "h", Vector3(13.0, 0.05, 2.5)], ["living", "h", Vector3(10.0, 0.05, 8.0)],
			["hall", "h", Vector3(4.9, 0.05, 7.8)], ["porch", "h", Vector3(5.9, 0.05, 12.3)], ["court", "w", Vector3(0, 0.1, 0)],
			["road end", "w", Vector3(0, 0.1, 140)], ["backyard", "w", Vector3(0, 0.1, -44)], ["mailbox", "w", Vector3(-7.2, 0.1, -18.6)]]:
		var item: Array = t
		_btn(tp, item[0], func(): _teleport(item[1], item[2]))
	var dt := _row(wd, "back door test:")
	_btn(dt, "outside, facing door", func():
		_teleport("h", Vector3(13.6, 0.05, -1.4))
		WorldState.player.set_look(180.0, -8.0))
	_btn(dt, "inside, facing door", func():
		_teleport("h", Vector3(13.6, 0.05, 1.4))
		WorldState.player.set_look(0.0, -8.0))


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
	var meters := ""
	for b in ["Master", "SFX", "Ambience", "Horror"]:
		var idx := AudioServer.get_bus_index(b)
		meters += "%s %.0f  " % [b, max(-80.0, AudioServer.get_bus_peak_volume_left_db(idx, 0))]
	status.text = "night %d | real %.0fs | clock %s | main next %.0fs (%d/10) | side next %.0fs\nscares: armed=%s tonight %d/%d recovering %.0fs tension %.2f | running %s\nplayer %s inside=%s | peaks dB: %s" % [
		int(WorldState.get_state("night", 1)), WorldState.sim_time, WorldState.format_clock(WorldState.clock_minutes()),
		director.time_to_next(), director.main_events().filter(func(e): return director.fired.has(e.id)).size(),
		max(0.0, director.side_next_at - director.clock),
		scares.armed.id if scares.armed else "-", scares.fired_tonight, scares.quota(), max(0.0, scares.recover_until - WorldState.sim_time), scares.tension,
		str(running), str(pos.snapped(Vector3.ONE * 0.1)), WorldState.player_inside, meters]


func _spawn_figure(where: String) -> void:
	var pool = WorldState.get_obj("figures")
	var f: ShadowFigure = pool.borrow()
	if f == null:
		info.text = "no free figure"
		return
	var p := WorldState.player
	var h := WorldState.get_obj("house") as House
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var pos := p.global_position + fwd * 3.0
	match where:
		"behind":
			pos = p.global_position - fwd * 1.2
		"hall":
			pos = h.to_global(Vector3(4.9, 0, 3.15))
		"fence":
			pos = Vector3(0, 0, -51.2)
		"street":
			pos = Vector3(9.5, 0.08, 13.2)
		"kwin":
			pos = h.to_global(Vector3(12.0, -0.3, -0.45))
	f.appear(pos, p.global_position - pos, 0.4)
	info.text = "figure %s at %s" % [f.name, str(pos.snapped(Vector3.ONE * 0.1))]


func _figure_do(what: String) -> void:
	var pool = WorldState.get_obj("figures")
	for f in pool.figures:
		if not f.is_visible_figure():
			continue
		match what:
			"walk":
				f.walk_path(PackedVector3Array([f.global_position + f.global_basis.z * -4.0]), 1.2)
			"lunge":
				f.lunge(f.global_position.lerp(WorldState.player.global_position, 0.5), 0.2)
			"twitch":
				f.twitch()
			"fade":
				f.vanish("fade", 1.5)
			"flicker":
				f.vanish("flicker")


func _play_test(dist: float) -> void:
	var n := sound_pick.get_item_text(sound_pick.selected)
	var p := WorldState.player
	var fwd: Vector3 = -p.camera.global_transform.basis.z
	var pos: Vector3 = p.camera.global_position + fwd * dist
	var pl := AudioManager.play_3d(n, pos)
	var e := AudioManager.mix_entry(n)
	info.text = "%s  gain %+.1f dB  unit %.1f m  max %.0f m  bus %s" % [n, e[0], e[1], e[2], pl.bus if pl else "?"]


func _buses() -> String:
	var lines := PackedStringArray()
	for i in AudioServer.bus_count:
		var fx := []
		for k in AudioServer.get_bus_effect_count(i):
			fx.append(AudioServer.get_bus_effect(i, k).get_class().replace("AudioEffect", ""))
		lines.append("%-9s -> %-9s vol %+.1f dB  %s" % [AudioServer.get_bus_name(i), AudioServer.get_bus_send(i), AudioServer.get_bus_volume_db(i), ", ".join(fx)])
	return "\n".join(lines)


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
