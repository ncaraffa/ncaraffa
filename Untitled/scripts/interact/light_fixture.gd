class_name LightFixture
extends Interactable
## A light source (ceiling dome, lamp, porch light...). Lamps are directly
## interactive; ceiling lights are driven by a LightSwitch.

var lights: Array = []          # Light3D nodes
var energies: Array = []
var glow_meshes: Array = []     # MeshInstance3D swapped between on/off materials
var mat_on: Material
var mat_off: Material
var is_on := false
var interactive := false
var click_sound := true
var _flicker_t := 0.0


func setup(id: String, start_on: bool, glow_color := Color(1.0, 0.82, 0.6), glow_energy := 3.0,
		is_interactive := false) -> void:
	register(id)
	interactive = is_interactive
	mat_on = Mats.emissive(glow_color, glow_energy)
	mat_off = Mats.color(glow_color.darkened(0.45), 0.4)
	for l in lights:
		energies.append(l.light_energy)
	set_on(start_on, true)


func add_light(l: Light3D) -> void:
	lights.append(l)


func add_glow(mi: MeshInstance3D) -> void:
	glow_meshes.append(mi)


func get_prompt() -> String:
	if not interactive:
		return ""
	return "Turn off" if is_on else "Turn on"


func interact(_player: Node) -> void:
	if not interactive:
		return
	set_on(not is_on)
	WorldState.log_interaction("lamp", obj_id)


## Part of the player's house? (On the last night the house has no power.)
func _in_house() -> bool:
	if not has_meta("in_house"):
		var h = WorldState.get_obj("house")
		set_meta("in_house", h != null and h.is_ancestor_of(self))
	return get_meta("in_house")


## `force` is only for the endings' cinematics.
func set_on(value: bool, silent := false, force := false) -> void:
	if value and not force and WorldState.get_state("power/out", false) and _in_house():
		value = false
	is_on = value
	for i in lights.size():
		lights[i].visible = value
		if i < energies.size():
			lights[i].light_energy = energies[i]
	for mi in glow_meshes:
		mi.material_override = mat_on if value else mat_off
	if not silent and interactive and click_sound:
		AudioManager.play_3d("switch_click", global_position, -2.0, randf_range(0.9, 1.1))
	if obj_id != "":
		WorldState.set_state("light/" + obj_id, value)


## Brief irregular flicker (bulbs do that). Does not change on/off state.
func flicker(duration := 0.8) -> void:
	if not is_on:
		return
	_flicker_t = duration


func _process(delta: float) -> void:
	if _flicker_t <= 0.0:
		return
	_flicker_t -= delta
	var k := 1.0 if _flicker_t <= 0.0 else (0.25 if randf() < 0.35 else randf_range(0.6, 1.0))
	for i in lights.size():
		if i < energies.size():
			lights[i].light_energy = energies[i] * k
