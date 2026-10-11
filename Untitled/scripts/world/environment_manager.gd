class_name EnvironmentManager
extends Node
## Night sky, moonlight, fog, tonemapping and the subtle post-processing layer.

var env: Environment
var world_env: WorldEnvironment
var moon: DirectionalLight3D
var post: ColorRect
var post_mat: ShaderMaterial
var _t := 0.0
var _fade := 1.0


var _fade_target := 0.0
var _fade_speed := 0.35


func setup(parent: Node) -> void:
	name = "EnvironmentManager"
	WorldState.register("environment", self)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_tex", Mats.tex("cloud_noise"))
	var moon_dir := Vector3(0.45, 0.42, -0.78).normalized()
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.21, 0.3)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 5.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.09, 0.15)
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.25
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.82
	world_env = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.7, 0.95)
	moon.light_energy = 0.28
	moon.light_specular = 0.2
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 70.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP)

	var layer := CanvasLayer.new()
	layer.layer = 5
	parent.add_child(layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post.material = post_mat
	layer.add_child(post)
	GameManager.settings_changed.connect(_apply_settings)
	_apply_settings()


## Fade the picture to black (1.0) or back (0.0) over `secs`.
func fade_to(v: float, secs: float) -> void:
	_fade_target = v
	_fade_speed = absf(v - _fade) / max(0.05, secs)


func _apply_settings() -> void:
	post_mat.set_shader_parameter("grain", 0.045 if GameManager.settings.grain else 0.0)
	post_mat.set_shader_parameter("vhs", 1.0 if GameManager.settings.vhs else 0.0)


func _process(delta: float) -> void:
	_t += delta
	if _fade != _fade_target:
		_fade = move_toward(_fade, _fade_target, delta * _fade_speed)
		post_mat.set_shader_parameter("fade", _fade)
	# clouds drifting over the moon: tiny variations of moonlight
	if moon:
		moon.light_energy = 0.26 + 0.04 * sin(_t * 0.031) + 0.02 * sin(_t * 0.17)
