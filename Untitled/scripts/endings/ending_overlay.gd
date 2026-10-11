class_name EndingOverlay
extends CanvasLayer
## The last thing either ending shows: total black, then, slowly, the name.

var black: ColorRect
var title: Label


func _ready() -> void:
	layer = 120
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	title = Label.new()
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	title.add_theme_font_override("font", tf)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.78, 0.76, 0.72))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "Untitled..."
	title.modulate.a = 0.0
	add_child(title)


## Instant, total black.
func blackout() -> void:
	black.color.a = 1.0


func show_title(fade_in := 3.5) -> Signal:
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE)
	return tw.finished


func hide_title(fade_out := 2.0) -> Signal:
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 0.0, fade_out)
	return tw.finished
