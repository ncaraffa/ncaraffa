extends Node
## AudioManager — bus layout, sound library and spatial one-shots.
##
## Buses:
##   Master <- World <- Indoor  (low-passed while the player is outside)
##                   <- Outdoor (low-passed while the player is inside)
##                   <- Room    (reverb send used by the house Area3D)
##   Master <- Phone (the handset), UI
## Every positional sound picks Indoor/Outdoor from where it is emitted, so a
## phone ringing inside sounds muffled from the street and vice versa.

const LOOPS := [
	"crickets", "wind", "distant_traffic", "leaves", "fridge_hum", "computer_hum",
	"tv_static", "tv_tone", "water", "lamp_buzz", "clock_tick", "car_engine",
	"car_idle", "line_hiss", "garage_door",
]

var _cache: Dictionary = {}
var _oneshots: Array = []
var _rng := RandomNumberGenerator.new()
var _lpf_in: AudioEffectLowPassFilter
var _lpf_out: AudioEffectLowPassFilter
var _muffle := 1.0  # 1 = player inside


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_setup_buses()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("World") != -1:
		return
	_add_bus("World", "Master")
	_lpf_in = AudioEffectLowPassFilter.new()
	_lpf_in.cutoff_hz = 20000
	_add_bus("Indoor", "World", [_lpf_in])
	_lpf_out = AudioEffectLowPassFilter.new()
	_lpf_out.cutoff_hz = 1000
	_add_bus("Outdoor", "World", [_lpf_out])
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.35
	rev.damping = 0.6
	rev.dry = 0.0
	rev.wet = 0.25
	rev.spread = 0.8
	_add_bus("Room", "World", [rev])
	var phone_lpf := AudioEffectBandPassFilter.new()
	phone_lpf.cutoff_hz = 1600
	_add_bus("Phone", "Master", [phone_lpf])
	_add_bus("UI", "Master")


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
	if _lpf_in:
		# Inside sounds get muffled when the player is outside, and the reverse.
		_lpf_in.cutoff_hz = lerp(650.0, 20000.0, ease(_muffle, 0.4))
		_lpf_out.cutoff_hz = lerp(20000.0, 1100.0, ease(_muffle, 2.5))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Indoor"), lerp(-9.0, 0.0, _muffle))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Outdoor"), lerp(0.0, -7.0, _muffle))
	# Cleanup finished one-shots.
	for i in range(_oneshots.size() - 1, -1, -1):
		var p = _oneshots[i]
		if not is_instance_valid(p):
			_oneshots.remove_at(i)


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
	return "Indoor" if is_indoor(pos) else "Outdoor"


## Fire-and-forget positional sound. Returns the player so callers may tweak it.
func play_3d(sound_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 6.0,
		max_distance := 60.0, bus := "") -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	if s == null:
		return null
	var root := get_tree().current_scene
	if root == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 6000
	p.attenuation_filter_db = -12
	p.area_mask = B.LAYER_AUDIO
	p.bus = bus if bus != "" else bus_for(pos)
	root.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	_oneshots.append(p)
	return p


## A persistent (usually looping) positional emitter attached to `parent`.
func make_emitter(parent: Node3D, sound_name: String, local_pos := Vector3.ZERO, volume_db := 0.0,
		unit_size := 4.0, max_distance := 30.0, autoplay := true) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound_name)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 7000
	p.area_mask = B.LAYER_AUDIO
	parent.add_child(p)
	p.position = local_pos
	p.bus = bus_for(p.global_position) if p.is_inside_tree() else "World"
	if autoplay and p.stream:
		# Random start offset so loops never sound synchronised.
		p.play(randf() * max(0.0, p.stream.get_length() - 0.1))
	return p


func play_ui(sound_name: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound_name)
	p.volume_db = volume_db
	p.bus = "UI"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func stop_all() -> void:
	for p in _oneshots:
		if is_instance_valid(p):
			p.queue_free()
	_oneshots.clear()
