class_name PauseMenu
extends CanvasLayer
## Esc: the world stops, the cursor is freed. Resume / settings / leave.

var root: Control
var box: VBoxContainer
var settings: SettingsPanel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-80, -70)
	box.custom_minimum_size = Vector2(160, 140)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	for item in [["resume", _resume], ["settings", _settings], ["leave", _leave]]:
		var b := Button.new()
		b.text = item[0]
		b.flat = true
		SettingsPanel._style_button(b)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(item[1])
		box.add_child(b)
	settings = SettingsPanel.new()
	settings.set_anchors_preset(Control.PRESET_CENTER)
	settings.position = Vector2(-220, -200)
	settings.visible = false
	settings.closed.connect(func():
		settings.visible = false
		box.visible = true)
	root.add_child(settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if root.visible:
			_resume()
		else:
			var p = WorldState.player
			if p and p.is_busy():
				return
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	root.visible = true
	box.visible = true
	settings.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _settings() -> void:
	box.visible = false
	settings.visible = true


func _leave() -> void:
	GameManager.return_to_menu()
