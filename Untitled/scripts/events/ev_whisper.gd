extends MysteryEvent
## In a dark room, a whisper, close to one ear. Nothing more.


func _init() -> void:
	id = "whisper"
	title = "Whisper"
	track = "side"
	intensity = 2
	min_night = 4
	max_per_night = 1
	kinds = ["temporary"]


func can_start() -> bool:
	return WorldState.player_inside


func _start() -> void:
	var p = WorldState.player
	var side: Vector3 = p.camera.global_transform.basis.x * (1.0 if rng.randf() < 0.5 else -1.0)
	AudioManager.play_3d("whisper", p.camera.global_position + side * 0.45, -2.0, rng.randf_range(0.85, 1.0))
	record("ear")
	finish()
