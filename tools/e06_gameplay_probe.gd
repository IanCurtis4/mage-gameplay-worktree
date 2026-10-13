extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var controller: RunController
func _initialize() -> void:
	_run.call_deferred()
func freeze_actors() -> void:
	controller.set_process(false)
	controller.player.set_process(false)
	controller._update_hud()
	for actor: CombatActor in controller.enemies: actor.set_process(false)
func clear_actors() -> void:
	for actor: CombatActor in controller.enemies.duplicate(): actor.free()
	controller.enemies.clear()
func capture(name: String, size: Vector2i) -> void:
	root.size = size
	freeze_actors()
	controller.route_camera.reset_smoothing()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://.godot/verification/e06_gameplay_extension/native"
	DirAccess.make_dir_recursive_absolute(directory)
	assert(root.get_texture().get_image().save_png(directory.path_join(name + ".png"))==OK)
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_gameplay_extension/native_profile_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(F.FaultStore.new(directory,ProfileCatalog.pilot()),ProfileRewardResolver.pilot_progression())
	assert(not FileAccess.file_exists(directory.path_join(ProfileStore.PRIMARY_FILE)), "Probe profile must start isolated")
	assert(facade.create_character("create",0,"Visão isolada",&"mage")["ok"])
	var started := facade.start_run("start",facade.current_profile().revision)
	assert(started["ok"])
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = true
	controller = RunController.new()
	root.add_child(controller)
	controller.player.global_position = Vector2(1000,850)
	await capture("campina_1280",Vector2i(1280,720))
	clear_actors()
	controller._spawn_encounter(3)
	controller.player.global_position = Vector2(1000,850)
	await capture("bosque_1280",Vector2i(1280,720))
	clear_actors()
	controller._spawn_encounter(6)
	clear_actors()
	controller.player.global_position = Vector2(1700,1280)
	for index: int in 5:
		controller._spawn_route_enemy({"species":&"test_gel","category":MobCatalog.CATEGORIES[index],"position":Vector2(1130+index*215,1300)},6)
	var master := controller._spawn_route_enemy({"species":&"test_beast_master","category":&"boss","position":Vector2(1700,1190)},6)
	freeze_actors()
	await process_frame
	freeze_actors()
	var pets := 0
	for actor: CombatActor in controller.enemies:
		if actor is EnemyActor and actor.is_summoned:
			pets += 1
			assert(actor.occurrence.category_id == &"rare_elite", "boss companion is one tier lower")
		if actor is EnemyActor and actor._mob_definition.visual_kind != &"humanoid": assert(actor.body_drawer.is_valid(), "native mock drawer must remain alive")
	assert(master.summon_used and pets==1,"native master has actual finite companion")
	controller.status_label.text = "Ruínas · cinco categorias de Gel (Nv.15) · Mestre e companheiro de tier inferior"
	await capture("ruinas_tiers_1280",Vector2i(1280,720))
	await capture("ruinas_tiers_1920",Vector2i(1920,1080))
	print("E06_GAMEPLAY_NATIVE_OK three areas, five gel tiers, actual companion,1280/1920")
	quit(0)
