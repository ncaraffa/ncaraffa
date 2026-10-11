extends Control
## Dark screen. PLAY. Nothing else is explained.

var settings: SettingsPanel
var play: Button
var grain: ColorRect
## The logo: an eye that watches the cursor.
var eye: ColorRect
var eye_mat: ShaderMaterial
var _open := 0.0
var _open_target := 1.0
var _blink_t := 2.5


func _ready() -> void:
	GameManager.in_game = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.012, 0.014)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	eye = ColorRect.new()
	eye_mat = ShaderMaterial.new()
	eye_mat.shader = load("res://shaders/eye_ui.gdshader")
	eye_mat.set_shader_parameter("open", 0.0)
	eye_mat.set_shader_parameter("surround", 0.9)
	eye.material = eye_mat
	eye.set_anchors_preset(Control.PRESET_CENTER)
	eye.size = Vector2(360, 360)
	eye.position = Vector2(-180, -330)
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eye)
	play = Button.new()
	play.text = "PLAY"
	play.flat = true
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_font_size_override("font_size", 30)
	play.add_theme_color_override("font_color", Color(0.72, 0.7, 0.66))
	play.add_theme_color_override("font_hover_color", Color(0.97, 0.95, 0.9))
	play.add_theme_color_override("font_pressed_color", Color(0.5, 0.48, 0.45))
	play.set_anchors_preset(Control.PRESET_CENTER)
	play.custom_minimum_size = Vector2(180, 60)
	play.position = Vector2(-90, 40)
	play.pressed.connect(_on_play)
	add_child(play)
	var corner := HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.position = Vector2(-190, -52)
	corner.add_theme_constant_override("separation", 18)
	add_child(corner)
	var sbtn := Button.new()
	sbtn.text = "settings"
	sbtn.flat = true
	SettingsPanel._style_button(sbtn)
	sbtn.add_theme_color_override("font_color", Color(0.3, 0.29, 0.27))
	sbtn.pressed.connect(func():
		settings.visible = true
		play.visible = false)
	corner.add_child(sbtn)
	var q := Button.new()
	q.text = "quit"
	q.flat = true
	SettingsPanel._style_button(q)
	q.add_theme_color_override("font_color", Color(0.3, 0.29, 0.27))
	q.pressed.connect(func(): get_tree().quit())
	corner.add_child(q)
	settings = SettingsPanel.new()
	settings.set_anchors_preset(Control.PRESET_CENTER)
	settings.position = Vector2(-220, -200)
	settings.visible = false
	settings.closed.connect(func():
		settings.visible = false
		play.visible = true)
	add_child(settings)
	grain = ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	m.set_shader_parameter("grain", 0.03)
	m.set_shader_parameter("vignette", 0.6)
	grain.material = m
	add_child(grain)
	if "--autoplay" in OS.get_cmdline_user_args():
		_on_play.call_deferred()


func _process(delta: float) -> void:
	if eye == null:
		return
	var c := eye.global_position + eye.size / 2.0
	var d := (get_viewport().get_mouse_position() - c) / 420.0
	eye_mat.set_shader_parameter("look", Vector2(clampf(d.x, -1.0, 1.0), clampf(-d.y * 1.4, -1.0, 1.0)))
	_blink_t -= delta
	if play.disabled:
		_open_target = 0.0
	elif _blink_t <= 0.0:
		_blink_t = randf_range(3.0, 7.0)
		_open_target = 0.0
	elif _open <= 0.02 and _open_target == 0.0:
		_open_target = 1.0
	_open = move_toward(_open, _open_target, delta * (9.0 if _open_target == 0.0 else 2.5))
	eye_mat.set_shader_parameter("open", _open)


func _on_play() -> void:
	play.disabled = true
	_open_target = 0.0
	_blink_t = 99.0
	var t := create_tween()
	t.tween_property(play, "modulate:a", 0.0, 0.6)
	t.tween_interval(0.4)
	t.tween_callback(GameManager.start_game)
