class_name Hud
extends CanvasLayer
## Minimal HUD: a faint dot, a whispered interaction hint, subtitles for voices
## heard on the phone, and the sheet used to read notes. Nothing else, ever.

var dot: Panel
var prompt: Label
var subtitle: Label
var note_root: Control
var note_text: Label
var note_rich: RichTextLabel
var thought_label: Label
var title_label: Label
var _thought_t := 0.0
var _reading := false
var _sub_t := 0.0
var _prompt_alpha := 0.0
var _prompt_target := ""


func _ready() -> void:
	layer = 10
	WorldState.register("hud", self)
	dot = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.42)
	sb.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", sb)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 24)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)
	_build_note()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_note() -> void:
	note_root = Control.new()
	note_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	note_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_root.visible = false
	add_child(note_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_root.add_child(dim)
	var paper := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.9, 0.87, 0.79)
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 18
	ps.set_corner_radius_all(2)
	paper.add_theme_stylebox_override("panel", ps)
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_root.add_child(paper)
	note_text = Label.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Comic Sans MS", "Georgia", "Times New Roman", "serif"])
	note_text.add_theme_font_override("font", f)
	note_text.add_theme_font_size_override("font_size", 22)
	note_text.add_theme_color_override("font_color", Color(0.16, 0.15, 0.22))
	note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(note_text)
	note_rich = RichTextLabel.new()
	note_rich.bbcode_enabled = true
	note_rich.fit_content = false
	note_rich.scroll_active = false
	note_rich.add_theme_font_override("normal_font", f)
	var fi := SystemFont.new()
	fi.font_names = PackedStringArray(["Segoe Script", "Brush Script MT", "Georgia", "Times New Roman", "serif"])
	fi.font_italic = true
	note_rich.add_theme_font_override("italics_font", fi)
	note_rich.add_theme_font_size_override("normal_font_size", 23)
	note_rich.add_theme_font_size_override("italics_font_size", 22)
	note_rich.add_theme_color_override("default_color", Color(0.16, 0.18, 0.4))
	note_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_rich.visible = false
	paper.add_child(note_rich)
	thought_label = Label.new()
	thought_label.add_theme_font_size_override("font_size", 19)
	thought_label.add_theme_color_override("font_color", Color(0.85, 0.84, 0.8, 0.9))
	thought_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(thought_label)
	title_label = Label.new()
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	title_label.add_theme_font_override("font", tf)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.modulate.a = 0.0
	add_child(title_label)


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	dot.position = s / 2.0 - Vector2(2, 2)
	prompt.position = Vector2(s.x / 2.0 - 200, s.y / 2.0 + 22)
	subtitle.position = Vector2(s.x * 0.15, s.y - 120)
	subtitle.size = Vector2(s.x * 0.7, 80)
	var paper: Panel = note_root.get_node("Paper")
	var pw: float = min(560.0, s.x - 60.0)
	var ph: float = min(700.0, s.y - 60.0)
	paper.size = Vector2(pw, ph)
	paper.position = (s - paper.size) / 2.0
	paper.rotation = deg_to_rad(-0.8)
	note_text.position = Vector2(46, 50)
	note_text.size = Vector2(pw - 92, ph - 100)
	note_rich.position = Vector2(46, 50)
	note_rich.size = Vector2(pw - 92, ph - 100)
	thought_label.position = Vector2(0, s.y - 170)
	thought_label.size = Vector2(s.x, 30)
	title_label.position = Vector2(0, 0)
	title_label.size = s


func _process(delta: float) -> void:
	# the prompt fades in/out softly instead of popping
	var want := 0.0 if _prompt_target == "" or _reading else 0.75
	_prompt_alpha = move_toward(_prompt_alpha, want, delta * 4.0)
	prompt.modulate.a = _prompt_alpha
	if _thought_t > 0.0:
		_thought_t -= delta
		thought_label.modulate.a = clampf(_thought_t, 0.0, 1.0)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			subtitle.text = ""


func set_prompt(text: String) -> void:
	if text != "":
		_prompt_target = text
		prompt.text = "E   " + text
	else:
		_prompt_target = ""


func set_crosshair_visible(v: bool) -> void:
	dot.visible = v


func show_subtitle(text: String, dur := 3.0) -> void:
	if not GameManager.settings.subtitles:
		return
	subtitle.text = text
	_sub_t = dur


func clear_subtitle() -> void:
	subtitle.text = ""
	_sub_t = 0.0


func thought(text: String, dur := 2.6) -> void:
	thought_label.text = text
	_thought_t = dur


func title_card(text: String) -> void:
	title_label.text = text
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 0.85, 1.0)
	tw.tween_interval(1.4)
	tw.tween_property(title_label, "modulate:a", 0.0, 1.2)


func show_list(bbcode: String) -> void:
	note_rich.text = bbcode
	note_rich.visible = true
	note_text.visible = false
	note_root.visible = true
	_reading = true
	dot.visible = false


func show_note(text: String) -> void:
	note_rich.visible = false
	note_text.visible = true
	note_text.text = text
	note_root.visible = true
	_reading = true
	dot.visible = false


func close_note() -> void:
	note_root.visible = false
	_reading = false
	dot.visible = true


func is_reading() -> bool:
	return _reading
