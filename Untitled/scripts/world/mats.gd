class_name Mats
## Material library. Materials are cached and use world-space triplanar mapping so
## textures keep a realistic scale on procedurally built geometry.

static var _cache: Dictionary = {}
static var _tex: Dictionary = {}


static func tex(tex_name: String) -> Texture2D:
	if _tex.has(tex_name):
		return _tex[tex_name]
	var path := "res://assets/textures/%s.png" % tex_name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[tex_name] = t
	return t


static func textured(tex_name: String, tile_m := 1.0, rough := 0.85, normal := "", world := true,
		tint := Color.WHITE, metallic := 0.0, normal_scale := 0.6) -> StandardMaterial3D:
	var key := "t|%s|%s|%s|%s|%s|%s|%s" % [tex_name, tile_m, rough, normal, world, tint, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile_m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = tex(normal)
		m.normal_scale = normal_scale
	_cache[key] = m
	return m


static func color(c: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var key := "c|%s|%s|%s" % [c, rough, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	_cache[key] = m
	return m


static func emissive(c: Color, energy := 1.0, unshaded := false) -> StandardMaterial3D:
	var key := "e|%s|%s|%s" % [c, energy, unshaded]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m


static func picture(tex_name: String) -> StandardMaterial3D:
	var key := "p|" + tex_name
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.62, 0.68, 0.16)
	m.roughness = 0.05
	m.metallic = 0.2
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = m
	return m


static func two_sided(mat: Material) -> Material:
	var key := "2s|%d" % mat.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var m: Material = mat.duplicate()
	if m is BaseMaterial3D:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Named presets used by the builders.
static func m(key: String) -> Material:
	match key:
		"wallpaper": return textured("wallpaper_damask", 1.4, 0.92)
		"wallpaper_stripe": return textured("wallpaper_stripe", 1.6, 0.92)
		"paint_cream": return textured("paint_cream", 2.0, 0.9)
		"paint_yellow": return textured("paint_yellow", 2.0, 0.85)
		"paint_blue": return textured("paint_blue", 2.0, 0.9)
		"paint_white": return textured("paint_white", 2.0, 0.9)
		"paint_garage": return textured("paint_garage", 2.0, 0.95)
		"tile_bath": return textured("tile_bath", 1.2, 0.35, "tile_bath_n")
		"tile_kitchen": return textured("tile_kitchen", 1.8, 0.45, "tile_kitchen_n")
		"backsplash": return textured("tile_backsplash", 0.9, 0.35, "tile_backsplash_n")
		"ceiling": return textured("ceiling", 1.5, 0.95, "ceiling_n")
		"wood_floor": return textured("wood_floor", 1.6, 0.55, "wood_floor_n")
		"carpet": return textured("carpet", 1.0, 1.0)
		"wood_dark": return textured("wood_dark", 1.0, 0.6, "", false)
		"wood_light": return textured("wood_light", 1.0, 0.6, "", false)
		"wood_painted": return textured("wood_painted", 1.2, 0.7, "", false)
		"fabric_sofa": return textured("fabric_sofa", 0.6, 1.0, "", false)
		"fabric_green": return textured("fabric_green", 0.6, 1.0, "", false)
		"fabric_red": return textured("fabric_red", 0.6, 1.0, "", false)
		"fabric_blue": return textured("fabric_blue", 0.6, 1.0, "", false)
		"fabric_white": return textured("fabric_white", 0.6, 1.0, "", false)
		"fabric_stripe": return textured("fabric_stripe", 0.6, 1.0, "", false)
		"siding_white": return textured("siding_white", 2.0, 0.8, "siding_white_n")
		"siding_blue": return textured("siding_blue", 2.0, 0.8, "siding_blue_n")
		"siding_yellow": return textured("siding_yellow", 2.0, 0.8, "siding_yellow_n")
		"siding_green": return textured("siding_green", 2.0, 0.8, "siding_green_n")
		"siding_gray": return textured("siding_gray", 2.0, 0.8, "siding_gray_n")
		"shingles": return textured("shingles", 2.5, 0.9, "shingles_n")
		"brick": return textured("brick", 2.2, 0.9, "brick_n")
		"grass": return textured("grass", 3.0, 0.95)
		"asphalt": return textured("asphalt", 4.0, 0.85)
		"concrete": return textured("concrete", 2.0, 0.9)
		"concrete_dark": return textured("concrete_dark", 2.5, 0.9)
		"fence": return textured("fence", 2.0, 0.9, "", true)
		"mulch": return textured("mulch", 1.5, 1.0)
		"bark": return textured("bark", 1.0, 0.95, "bark_n", false)
		"trim": return color(Color(0.86, 0.84, 0.78), 0.6)
		"trim_dark": return color(Color(0.25, 0.2, 0.16), 0.6)
		"door_white": return textured("wood_painted", 1.0, 0.6, "", false, Color(0.95, 0.93, 0.88))
		"metal": return color(Color(0.6, 0.6, 0.62), 0.35, 0.8)
		"metal_dark": return color(Color(0.18, 0.18, 0.19), 0.4, 0.7)
		"chrome": return color(Color(0.8, 0.8, 0.82), 0.15, 1.0)
		"plastic_white": return color(Color(0.85, 0.84, 0.8), 0.45)
		"plastic_beige": return color(Color(0.78, 0.74, 0.64), 0.5)
		"plastic_black": return color(Color(0.06, 0.06, 0.06), 0.4)
		"porcelain": return color(Color(0.92, 0.92, 0.9), 0.15)
		"rubber": return color(Color(0.05, 0.05, 0.05), 0.9)
		"black": return color(Color(0.02, 0.02, 0.02), 0.6)
		"paper": return color(Color(0.92, 0.9, 0.84), 0.9)
		"leaves": return textured("leaves", 1.5, 0.95)
		"dark_window": return color(Color(0.04, 0.05, 0.07), 0.08, 0.3)
	push_warning("Unknown material preset " + key)
	return color(Color.MAGENTA)
