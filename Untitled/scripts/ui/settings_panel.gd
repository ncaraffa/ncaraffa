class_name SettingsPanel
extends PanelContainer
## Volume, mouse sensitivity, field of view and a few visual toggles.

signal closed


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.96)
	sb.border_color = Color(0.25, 0.24, 0.22)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(26)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	_slider(v, "volume", "master_volume", 0.0, 1.0, 0.01)
	_slider(v, "ambience", "ambience_volume", 0.0, 1.5, 0.01)
	_slider(v, "effects", "sfx_volume", 0.0, 1.5, 0.01)
	_slider(v, "scares", "horror_volume", 0.0, 1.0, 0.01)
	_slider(v, "mouse sensitivity", "mouse_sensitivity", 0.0005, 0.006, 0.0001)
	_slider(v, "field of view", "fov", 60.0, 95.0, 1.0)
	_check(v, "film grain", "grain")
	_check(v, "vhs", "vhs")
	_check(v, "subtitles", "subtitles")
	_check(v, "invert mouse", "invert_y")
	_check(v, "fullscreen", "fullscreen")
	var back := Button.new()
	back.text = "back"
	back.flat = true
	_style_button(back)
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)


static func _style_button(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(0.62, 0.6, 0.56))
	b.add_theme_color_override("font_hover_color", Color(0.95, 0.93, 0.88))
	b.add_theme_color_override("font_focus_color", Color(0.95, 0.93, 0.88))
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
	l.add_theme_font_size_override("font_size", 15)
	return l


func _slider(parent: Control, title: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	h.add_child(_label(title))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameManager.settings[key])
	s.custom_minimum_size = Vector2(220, 20)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(val): GameManager.set_setting(key, val))
	h.add_child(s)
	parent.add_child(h)


func _check(parent: Control, title: String, key: String) -> void:
	var h := HBoxContainer.new()
	h.add_child(_label(title))
	var c := CheckBox.new()
	c.button_pressed = bool(GameManager.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on): GameManager.set_setting(key, on))
	h.add_child(c)
	parent.add_child(h)
