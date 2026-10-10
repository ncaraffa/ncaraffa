extends Node3D
## World bootstrap: builds the house and the neighbourhood procedurally, then
## starts the player, the HUD and the simulation systems.

const HOUSE_ORIGIN := Vector3(-11.25, 0.3, -38.0)

var player: Player
var director: EventDirector


func _ready() -> void:
	GameManager.ending = ""
	if not GameManager.in_game:
		# launched directly (editor "Run Current Scene" or tests)
		WorldState.reset()
		GameManager.in_game = true
	var envm := EnvironmentManager.new()
	add_child(envm)
	envm.setup(self)
	var house := HouseBuilder.new().build(self, HOUSE_ORIGIN)
	var nb := Neighborhood.new()
	nb.name = "Neighborhood"
	add_child(nb)
	nb.build()
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = house.gp("spawn")
	player.set_look(-133.0, -6.0)
	add_child(Hud.new())
	add_child(PauseMenu.new())
	add_child(AmbientActivityManager.new())
	add_child(FigurePool.new())
	add_child(CultEvidence.new())
	add_child(TaskManager.new())
	director = EventDirector.new()
	add_child(director)
	add_child(ScareDirector.new())
	add_child(HallScene.new())
	var nights := NightManager.new()
	add_child(nights)
	nights.begin()
	if GameManager.dev_mode:
		add_child(DebugEventPanel.new())


func _exit_tree() -> void:
	# static resource caches must not outlive the world (and the renderer)
	B._meshes.clear()
	Mats._cache.clear()
	Mats._tex.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY and GameManager.dev_mode:
		print("[dev] world ready: %d objects registered, first event in %.0fs" % [WorldState.objects.size(), director.next_at])
