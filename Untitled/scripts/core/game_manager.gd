extends Node
## Global game state: settings, input map, scene flow and development mode.
##
## Development tools are only reachable when `dev_mode` is true: running from the
## editor, or launching the game with the `--dev` user argument
## (e.g. `godot --path . -- --dev`). A normal exported build never shows them.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"

var settings := {
	"mouse_sensitivity": 0.0022,
	"master_volume": 0.85,
	"ambience_volume": 1.0,
	"sfx_volume": 1.0,
	"horror_volume": 1.0,
	"vhs": false,
	"grain": true,
	"subtitles": true,
	"fullscreen": false,
	"fov": 72.0,
	"invert_y": false,
}

var dev_mode := false
var in_game := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	dev_mode = OS.has_feature("editor") or args.has("--dev")
	_setup_input()
	load_settings()
	apply_settings()


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
		"interact": [KEY_E],
		"pause": [KEY_ESCAPE],
		"crouch": [KEY_CTRL, KEY_C],
		"debug_panel": [KEY_F1],
		"notes": [KEY_TAB, KEY_N],
	}
	for action in keys:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Left mouse also interacts / drops held objects.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", mb)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cfg.get_value("settings", k, settings[k])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(0.0001, float(settings.master_volume))))
	# per-category trims live on the category buses' own effects-free gain
	for pair in [["Ambience", "ambience_volume"], ["SFX", "sfx_volume"], ["Horror", "horror_volume"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(max(0.0001, float(settings[pair[1]]))))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	settings_changed.emit()


func start_game() -> void:
	WorldState.reset()
	in_game = true
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


func return_to_menu() -> void:
	in_game = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_all()
	get_tree().change_scene_to_file(MENU_SCENE)


func restart_world() -> void:
	## Development helper: rebuilds the whole world with a fresh state.
	AudioManager.stop_all()
	start_game()
