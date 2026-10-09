class_name Terminal
extends Control
## The bedroom computer's text interface. It runs inside a SubViewport and is
## shown on the CRT. Keyboard input is real: the player types while focused.
##
## Modes: NORMAL (a small DOS-like shell), PRESS_ENTER (the anomaly), OFF.

signal spelled_enter
signal power_changed(on: bool)

enum Mode { NORMAL, PRESS_ENTER, MESSAGE, OFF }

const COLS := 58
const ROWS := 21
const FG := Color(0.70, 0.86, 0.68)

var mode := Mode.NORMAL
var lines: Array = []
var input := ""
var typed_letters := ""   # every letter typed in PRESS_ENTER mode
var _blink := 0.0
var _label: Label
var _bg: ColorRect
var _big: Label
var _flash := 0.0

var files := {
	"GROCERY.TXT": "milk\neggs\nAA batteries (kitchen clock)\nlightbulbs 60W x4\ncoffee filters\ncall phone co. about the line",
	"NOTES.TXT": "Phone rang again around midnight. Nobody there.\nPhone company says there are no calls on record.\n\nWhitcombs' lights on again. Ruth says they're still\nin Tucson until November.\n\nAsk someone about the car that keeps coming around\nthe court. Probably just someone lost.",
	"JOURNAL.TXT": "oct 3\nDad called. Spelled my name out like I was six.\nD-A-N-A. Then he hung up.\n\noct 6\nMoved the kitchen chairs back under the table.\nI don't remember pulling them out.\n\noct 8\nNobody has slept in the front room since spring.\nI keep that door closed.",
	"LETTER.DOC": "",
	"BUDGET.TXT": "rent      640\nphone      38\nelectric   71  (high again?)\ngas        22\ngroceries 160",
}


func _ready() -> void:
	# lives inside a SubViewport (no Control parent): size everything explicitly
	position = Vector2.ZERO
	size = Vector2(640, 480)
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.035, 0.03)
	_bg.position = Vector2.ZERO
	_bg.size = size
	add_child(_bg)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_label = Label.new()
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", FG)
	_label.position = Vector2(26, 20)
	_label.size = Vector2(600, 440)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	_big = Label.new()
	_big.add_theme_font_override("font", font)
	_big.add_theme_font_size_override("font_size", 58)
	_big.add_theme_color_override("font_color", FG)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.position = Vector2.ZERO
	_big.size = size
	_big.visible = false
	add_child(_big)
	boot()


func boot() -> void:
	lines.clear()
	_print("HOMEDOS 6.2  (C) 1994")
	_print("640K OK")
	_print("")
	_print("C:\\>DIR /W")
	_print("GROCERY.TXT   NOTES.TXT   JOURNAL.TXT")
	_print("LETTER.DOC    BUDGET.TXT")
	_print("")
	mode = Mode.NORMAL
	_refresh()


func _print(s: String) -> void:
	for part in s.split("\n"):
		while part.length() > COLS:
			lines.append(part.substr(0, COLS))
			part = part.substr(COLS)
		lines.append(part)
	while lines.size() > ROWS:
		lines.pop_front()


func _refresh() -> void:
	if mode == Mode.OFF:
		_label.text = ""
		_big.visible = false
		_bg.color = Color(0.01, 0.012, 0.012)
		return
	_bg.color = Color(0.02, 0.035, 0.03)
	var cursor := "_" if fmod(_blink, 1.0) < 0.5 else " "
	match mode:
		Mode.NORMAL:
			_big.visible = false
			_label.text = "\n".join(lines) + "\nC:\\>" + input + cursor
		Mode.PRESS_ENTER:
			_big.visible = fmod(_blink, 1.6) < 1.1 or _flash > 0.0
			_big.text = "PRESS ENTER"
			var pad := "\n".repeat(ROWS)
			_label.text = pad + input + cursor
		Mode.MESSAGE:
			_big.visible = false
			_label.text = "\n".join(lines) + "\n" + cursor


func _process(delta: float) -> void:
	_blink += delta
	if _flash > 0.0:
		_flash -= delta
		_bg.color = Color(0.08, 0.1, 0.09) if _flash > 0.0 else Color(0.02, 0.035, 0.03)
	_refresh()


# ------------------------------------------------------------------ input
func handle_key(ev: InputEventKey) -> void:
	if not ev.pressed or mode == Mode.OFF or mode == Mode.MESSAGE:
		return
	AudioManager.play_ui("key_%d" % (randi() % 3))
	var kc := ev.keycode
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_on_enter()
		return
	if kc == KEY_BACKSPACE:
		if input.length() > 0:
			input = input.substr(0, input.length() - 1)
		return
	var ch := ""
	if ev.unicode > 31 and ev.unicode < 127:
		ch = char(ev.unicode).to_upper()
	if ch == "":
		return
	if input.length() < COLS - 5:
		input += ch
	if mode == Mode.PRESS_ENTER and ch >= "A" and ch <= "Z":
		typed_letters += ch
		if typed_letters.length() > 32:
			typed_letters = typed_letters.substr(typed_letters.length() - 32)
		if typed_letters.ends_with("ENTER"):
			spelled_enter.emit()


func _on_enter() -> void:
	if mode == Mode.PRESS_ENTER:
		# Pressing the key itself does nothing. The screen only blinks.
		input = ""
		_flash = 0.12
		WorldState.set_state("computer/enter_key_presses", int(WorldState.get_state("computer/enter_key_presses", 0)) + 1)
		return
	var cmd := input.strip_edges()
	input = ""
	_print("C:\\>" + cmd)
	_run(cmd)


func _run(cmd: String) -> void:
	if cmd == "":
		return
	var parts := cmd.split(" ", false)
	var c := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	WorldState.log_interaction("terminal_cmd", c)
	match c:
		"DIR":
			_print(" Volume in drive C has no label")
			_print(" Directory of C:\\")
			_print("")
			var names := files.keys()
			for n in names:
				var fsize := 0 if files[n] == "" else String(files[n]).length()
				_print("%-14s %6d  10-0%d-98" % [n, fsize if fsize > 0 else 18432, 1 + (n.length() % 8)])
			_print("        %d file(s)" % names.size())
		"TYPE", "OPEN", "EDIT", "MORE", "CAT":
			_type_file(arg)
		"CLS":
			lines.clear()
		"TIME":
			_print("Current time is " + WorldState.format_clock(WorldState.clock_minutes()) + ":%02d" % (int(WorldState.sim_time) % 60))
		"DATE":
			_print("Current date is Fri 10-09-1998")
		"VER":
			_print("HOMEDOS Version 6.2")
		"HELP", "?":
			_print("DIR  TYPE  CLS  TIME  DATE  VER  EXIT")
		"EXIT":
			power_off()
		_:
			if files.has(c):
				_type_file(c)
			else:
				_print("Bad command or file name")


func _type_file(arg: String) -> void:
	if arg == "":
		_print("Required parameter missing")
		return
	if not files.has(arg):
		_print("File not found - " + arg)
		return
	WorldState.log_interaction("terminal_read", arg)
	if files[arg] == "":
		_print("#|@@  ^^ }{%%  ~~ ;8   ((  ##%  @  ")
		_print("Read fault reading drive C")
		return
	_print(files[arg])


# ------------------------------------------------------------------ anomaly
func show_press_enter() -> void:
	if mode == Mode.OFF:
		power_on(true)
	mode = Mode.PRESS_ENTER
	input = ""
	typed_letters = ""


## The response after ENTER is spelled. Slow, quiet, unexplained.
func play_message(message_lines: Array) -> void:
	mode = Mode.MESSAGE
	lines.clear()
	input = ""
	_refresh()
	await get_tree().create_timer(1.6).timeout
	for msg in message_lines:
		var s := ""
		_print("")
		for ch in String(msg):
			s += ch
			lines[lines.size() - 1] = s
			await get_tree().create_timer(0.11).timeout
		await get_tree().create_timer(1.4).timeout
	await get_tree().create_timer(5.0).timeout
	_print("")
	mode = Mode.NORMAL


func power_off() -> void:
	mode = Mode.OFF
	input = ""
	power_changed.emit(false)


func power_on(keep_text := false) -> void:
	if not keep_text:
		boot()
	else:
		mode = Mode.NORMAL
	power_changed.emit(true)
