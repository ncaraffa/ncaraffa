extends Node
## AudioManager — bus layout, central mix table, sound library, spatial sounds.
##
## Bus graph (all built at runtime):
##   Master  [compressor -> hard limiter at -1 dB: protects ears/headphones]
##     Ambience <- AmbIn / AmbOut      (room tone, crickets, wind, traffic)
##     SFX      <- SFXIn / SFXOut, Room (reverb send), Phone (handset band-pass)
##     Horror   [own compressor: impact without clipping]
##     Music, UI
## *In buses are low-passed while the player is outside the house, *Out buses
## while the player is inside, so every sound is heard "through the walls".
##
## All audio files are peak-normalised (tools/gen_audio.py). Levels live here,
## in MIX: [gain_db, unit_size_m, max_distance_m, category]. Call sites only pass
## small relative offsets.

const MIX := {
	# foley
	"step_wood": [-8.0, 3.0, 25.0, "sfx"], "step_tile": [-5.0, 3.0, 25.0, "sfx"],
	"step_grass": [-5.0, 3.0, 25.0, "sfx"], "step_concrete": [-5.0, 3.0, 25.0, "sfx"],
	"step_heavy": [-2.0, 4.0, 35.0, "sfx"],
	"door_open": [9.0, 4.5, 35.0, "sfx"], "door_close": [-1.0, 5.0, 40.0, "sfx"], "door_creak": [-3.0, 4.0, 30.0, "sfx"],
	"door_rattle": [0.0, 4.0, 30.0, "sfx"], "lock_click": [-1.0, 3.0, 20.0, "sfx"],
	"knock": [2.0, 8.0, 70.0, "sfx"], "switch_click": [-2.0, 3.0, 20.0, "sfx"],
	"phone_ring": [-4.0, 9.0, 90.0, "sfx"], "phone_pickup": [-3.0, 3.0, 20.0, "sfx"], "phone_hangup": [-3.0, 3.0, 20.0, "sfx"],
	"dial_tone": [-14.0, 1.0, 5.0, "sfx"], "line_hiss": [-18.0, 1.0, 5.0, "sfx"],
	"voice_time": [-2.0, 1.0, 5.0, "sfx"], "voice_wrong": [-2.0, 1.0, 5.0, "sfx"], "voice_hello": [-2.0, 1.0, 5.0, "sfx"],
	"voice_spell": [3.0, 14.0, 160.0, "horror"],
	"tv_static": [-6.0, 4.0, 35.0, "sfx"], "tv_tone": [-22.0, 3.0, 25.0, "sfx"],
	"crt_on": [-5.0, 3.0, 20.0, "sfx"], "crt_off": [-5.0, 3.0, 20.0, "sfx"], "computer_hum": [-18.0, 1.5, 8.0, "sfx"],
	"key": [-6.0, 1.0, 5.0, "ui"], "paper": [-4.0, 2.0, 10.0, "ui"],
	"fridge_hum": [-19.0, 2.0, 12.0, "ambience"], "fridge_clunk": [-5.0, 3.0, 20.0, "sfx"],
	"fridge_open": [-4.0, 3.0, 20.0, "sfx"], "fridge_close": [-4.0, 3.0, 20.0, "sfx"],
	"water": [-6.0, 2.5, 15.0, "sfx"], "clock_tick": [-11.0, 1.5, 7.0, "ambience"], "tick": [-8.0, 2.0, 10.0, "sfx"],
	"garage_door": [-2.0, 6.0, 50.0, "sfx"], "thud": [-3.0, 4.0, 30.0, "sfx"],
	"car_engine": [-1.0, 8.0, 170.0, "sfx"], "car_idle": [-3.0, 6.0, 90.0, "sfx"], "car_pass": [3.0, 30.0, 300.0, "ambience"],
	"car_door": [0.0, 8.0, 90.0, "sfx"],
	# ambience
	"crickets": [-6.0, 7.0, 50.0, "ambience"], "wind": [-12.0, 1.0, 1.0, "ambience"], "wind_gust": [-3.0, 16.0, 90.0, "ambience"],
	"leaves": [-10.0, 9.0, 60.0, "ambience"], "distant_traffic": [-19.0, 1.0, 1.0, "ambience"], "lamp_buzz": [-22.0, 1.5, 9.0, "ambience"],
	"owl": [-3.0, 20.0, 170.0, "ambience"], "dog_bark": [0.0, 14.0, 160.0, "ambience"], "wind_chime": [-4.0, 6.0, 60.0, "ambience"],
	"house_creak": [-3.0, 4.0, 30.0, "sfx"], "pipes": [-4.0, 4.0, 30.0, "sfx"], "elec_buzz": [-6.0, 2.0, 10.0, "ambience"],
	# chores
	"dish": [-4.0, 2.0, 15.0, "sfx"], "scrub": [-7.0, 2.0, 12.0, "sfx"], "trash_bag": [-4.0, 2.0, 12.0, "sfx"],
	"bin_lid": [-3.0, 4.0, 30.0, "sfx"], "mailbox": [2.0, 3.0, 20.0, "sfx"], "window_slide": [-3.0, 3.0, 20.0, "sfx"],
	"stove_knob": [1.0, 2.0, 12.0, "sfx"], "gas_hiss": [-12.0, 2.0, 10.0, "sfx"], "object_fall": [2.0, 6.0, 40.0, "sfx"],
	# horror
	"stinger": [1.0, 6.0, 40.0, "horror"], "shriek": [-1.0, 5.0, 40.0, "horror"], "tv_scare": [-1.0, 5.0, 40.0, "horror"],
	"breath_close": [3.0, 1.2, 6.0, "horror"], "whisper": [1.0, 1.5, 8.0, "horror"], "window_bang": [4.0, 6.0, 40.0, "horror"],
	"bang_door": [4.0, 9.0, 70.0, "horror"], "chant_far": [-5.0, 25.0, 140.0, "horror"], "drone_swell": [-11.0, 1.0, 1.0, "horror"],
	"run_steps": [2.0, 5.0, 40.0, "horror"], "heartbeat": [-8.0, 1.0, 1.0, "horror"],
	"glass_tap": [2.0, 4.0, 25.0, "horror"], "furniture_drag": [-1.0, 5.0, 35.0, "sfx"], "whoosh": [0.0, 4.0, 30.0, "horror"],
	"mattress_creak": [0.0, 2.0, 10.0, "horror"],
	# the tape and the endings (own buses, never faded with the world)
	"vhs_hiss": [-15.0, 1.0, 1.0, "music"], "vhs_insert": [-2.0, 2.0, 12.0, "sfx"],
	"tape_scare": [2.0, 1.0, 1.0, "music"], "final_scare": [2.0, 1.0, 1.0, "music"], "whisper_tape": [2.0, 1.0, 1.0, "music"],
}

const LOOPS := [
	"crickets", "wind", "distant_traffic", "leaves", "fridge_hum", "computer_hum",
	"tv_static", "tv_tone", "water", "vhs_hiss", "lamp_buzz", "clock_tick", "car_engine",
	"car_idle", "line_hiss", "garage_door", "chant_far", "elec_buzz", "gas_hiss",
]

const BUSES := ["Ambience", "AmbIn", "AmbOut", "SFX", "SFXIn", "SFXOut", "Room", "Phone", "Horror", "Music", "UI", "Tape", "Ending"]

var _cache: Dictionary = {}
var _oneshots: Array = []
var _rng := RandomNumberGenerator.new()
var _lpf: Dictionary = {}       # bus name -> AudioEffectLowPassFilter
var _muffle := 1.0              # 1 = player inside


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_setup_buses()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	var comp := AudioEffectCompressor.new()
	comp.threshold = -12.0
	comp.ratio = 3.0
	comp.attack_us = 3000.0
	comp.release_ms = 180.0
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.0
	lim.release = 0.1
	AudioServer.add_bus_effect(0, comp)
	AudioServer.add_bus_effect(0, lim)
	_add_bus("Ambience", "Master")
	_add_bus("AmbIn", "Ambience", [_new_lpf("AmbIn")])
	_add_bus("AmbOut", "Ambience", [_new_lpf("AmbOut")])
	_add_bus("SFX", "Master")
	_add_bus("SFXIn", "SFX", [_new_lpf("SFXIn")])
	_add_bus("SFXOut", "SFX", [_new_lpf("SFXOut")])
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.35
	rev.damping = 0.55
	rev.dry = 0.0
	rev.wet = 0.3
	rev.spread = 0.8
	_add_bus("Room", "SFX", [rev])
	var bpf := AudioEffectBandPassFilter.new()
	bpf.cutoff_hz = 1600
	_add_bus("Phone", "SFX", [bpf])
	var hcomp := AudioEffectCompressor.new()
	hcomp.threshold = -10.0
	hcomp.ratio = 4.0
	hcomp.attack_us = 500.0
	hcomp.release_ms = 250.0
	_add_bus("Horror", "Master", [hcomp])
	_add_bus("Music", "Master")
	_add_bus("UI", "Master")
	# what was recorded on the tape: band-limited, a little saturated, mono-ish
	var tlp := AudioEffectLowPassFilter.new()
	tlp.cutoff_hz = 3400
	var thp := AudioEffectHighPassFilter.new()
	thp.cutoff_hz = 160
	var tdist := AudioEffectDistortion.new()
	tdist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	tdist.drive = 0.18
	tdist.post_gain = -2.0
	_add_bus("Tape", "Master", [thp, tlp, tdist])
	# the last seconds of both endings: loud, but always under the master limiter
	var ecomp := AudioEffectCompressor.new()
	ecomp.threshold = -8.0
	ecomp.ratio = 6.0
	ecomp.attack_us = 200.0
	ecomp.release_ms = 200.0
	_add_bus("Ending", "Master", [ecomp])
	GameManager.apply_settings.call_deferred()


func _new_lpf(bus_name: String) -> AudioEffectLowPassFilter:
	var f := AudioEffectLowPassFilter.new()
	f.cutoff_hz = 20000
	_lpf[bus_name] = f
	return f


func _add_bus(bus_name: String, send: String, effects: Array = []) -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	for e in effects:
		AudioServer.add_bus_effect(idx, e)


func _process(delta: float) -> void:
	var target := 1.0 if WorldState.player_inside else 0.0
	_muffle = move_toward(_muffle, target, delta * 1.5)
	if not _lpf.is_empty():
		# heard through a wall: dull, quieter, but never gone
		var in_cut: float = lerp(900.0, 20000.0, ease(_muffle, 0.4))
		var out_cut: float = lerp(20000.0, 1400.0, ease(_muffle, 2.5))
		_lpf["SFXIn"].cutoff_hz = in_cut
		_lpf["AmbIn"].cutoff_hz = in_cut
		_lpf["SFXOut"].cutoff_hz = out_cut
		_lpf["AmbOut"].cutoff_hz = out_cut
		for b in ["SFXIn", "AmbIn"]:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), lerp(-6.0, 0.0, _muffle))
		for b in ["SFXOut", "AmbOut"]:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), lerp(0.0, -5.0, _muffle))
	for i in range(_oneshots.size() - 1, -1, -1):
		if not is_instance_valid(_oneshots[i]):
			_oneshots.remove_at(i)


# ------------------------------------------------------------------ mix table
func mix_entry(sound_name: String) -> Array:
	if MIX.has(sound_name):
		return MIX[sound_name]
	# variants: "step_wood_2" -> "step_wood", "stinger_1" -> "stinger"
	var base := sound_name
	while base.contains("_"):
		base = base.substr(0, base.rfind("_"))
		if MIX.has(base):
			return MIX[base]
	return [0.0, 4.0, 40.0, "sfx"]


func db(sound_name: String) -> float:
	return float(mix_entry(sound_name)[0])


## Resolve a bus from a category ("sfx", "ambience", "horror", "ui", "music"),
## an explicit bus name, or legacy names ("Indoor", "Outdoor", "World").
func resolve_bus(sound_name: String, pos: Vector3, hint := "") -> String:
	match hint:
		"Indoor":
			return "AmbIn" if mix_entry(sound_name)[3] == "ambience" else "SFXIn"
		"Outdoor":
			return "AmbOut" if mix_entry(sound_name)[3] == "ambience" else "SFXOut"
		"World":
			return "SFX"
	if hint in BUSES or hint == "Master":
		return hint
	var cat: String = hint if hint != "" else String(mix_entry(sound_name)[3])
	var inside := is_indoor(pos)
	match cat:
		"ambience":
			return "AmbIn" if inside else "AmbOut"
		"horror":
			return "Horror"
		"ui":
			return "UI"
		"music":
			return "Music"
	return "SFXIn" if inside else "SFXOut"


# ------------------------------------------------------------------ library
func stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := "res://assets/audio/%s.wav" % sound_name
	if not ResourceLoader.exists(path):
		WorldState.warn("Missing sound: " + sound_name)
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and sound_name in LOOPS:
		var w: AudioStreamWAV = s.duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	_cache[sound_name] = s
	return s


func variant(prefix: String, count: int) -> AudioStream:
	return stream("%s_%d" % [prefix, _rng.randi_range(0, count - 1)])


func is_indoor(pos: Vector3) -> bool:
	var house = WorldState.get_obj("house")
	if house and house.has_method("contains_point"):
		return house.contains_point(pos)
	return false


func bus_for(pos: Vector3) -> String:
	return "SFXIn" if is_indoor(pos) else "SFXOut"


func _configure(p: AudioStreamPlayer3D, sound_name: String, offset_db: float, unit_size: float, max_distance: float) -> void:
	var e := mix_entry(sound_name)
	p.volume_db = float(e[0]) + offset_db
	# never let a call site make a sound vanish because of a tiny unit size
	p.unit_size = max(unit_size, float(e[1])) if unit_size > 0.0 else float(e[1])
	p.max_distance = max(max_distance, float(e[2])) if max_distance > 0.0 else float(e[2])
	p.max_db = p.volume_db + 3.0   # closeness adds at most +3 dB over the mix level
	p.attenuation_filter_cutoff_hz = 7000
	p.attenuation_filter_db = -8.0
	p.area_mask = B.LAYER_AUDIO
	p.panning_strength = 1.0


## Fire-and-forget positional sound.
func play_3d(sound_name: String, pos: Vector3, offset_db := 0.0, pitch := 1.0, unit_size := -1.0,
		max_distance := -1.0, bus := "") -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	if s == null:
		return null
	var root := get_tree().current_scene
	if root == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.pitch_scale = pitch
	_configure(p, sound_name, offset_db, unit_size, max_distance)
	p.bus = resolve_bus(sound_name, pos, bus)
	root.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	_oneshots.append(p)
	return p


## Persistent (usually looping) positional emitter attached to `parent`.
func make_emitter(parent: Node3D, sound_name: String, local_pos := Vector3.ZERO, offset_db := 0.0,
		unit_size := -1.0, max_distance := -1.0, autoplay := true, bus := "") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound_name)
	_configure(p, sound_name, offset_db, unit_size, max_distance)
	parent.add_child(p)
	p.position = local_pos
	p.bus = resolve_bus(sound_name, p.global_position if p.is_inside_tree() else Vector3.ZERO, bus)
	if autoplay and p.stream:
		p.play(randf() * max(0.0, p.stream.get_length() - 0.1))
	return p


## Non-positional sound (inside the player's head: UI, the handset, beds).
func play_flat(sound_name: String, offset_db := 0.0, bus := "", pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound_name)
	p.volume_db = db(sound_name) + offset_db
	p.pitch_scale = pitch
	p.bus = bus if bus != "" else resolve_bus(sound_name, Vector3.ZERO, "")
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


func play_ui(sound_name: String, offset_db := 0.0) -> void:
	play_flat(sound_name, offset_db, "UI")


func stop_all() -> void:
	for b in ["Tape", "Ending"]:
		var bi := AudioServer.get_bus_index(b)
		if bi != -1:
			AudioServer.set_bus_volume_db(bi, 0.0)
	for p in _oneshots:
		if is_instance_valid(p):
			p.queue_free()
	_oneshots.clear()
	for c in get_children():
		if c is AudioStreamPlayer:
			c.queue_free()


## Smoothly fade the world mix (sleep transition). Master stays the user's.
func fade_world(to_db: float, secs: float) -> void:
	var trims := {"Ambience": "ambience_volume", "SFX": "sfx_volume", "Horror": "horror_volume"}
	for b in ["Ambience", "SFX", "Horror", "Music"]:
		var idx := AudioServer.get_bus_index(b)
		var from := AudioServer.get_bus_volume_db(idx)
		var target := to_db
		if to_db >= 0.0 and trims.has(b):
			target = linear_to_db(max(0.0001, float(GameManager.settings[trims[b]])))
		var tw := create_tween()
		tw.tween_method(func(v): AudioServer.set_bus_volume_db(idx, v), from, target, secs)
