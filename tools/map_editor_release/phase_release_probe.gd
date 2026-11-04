extends Node
## Q5: actual game presentation from an exe/PCK-only installation. Synthetic
## profile, same lobby/service/renderer; never reads an authoring source JSON.
const PhaseRelease = preload("res://scripts/map_authoring/release/phase_release.gd")
var checks: Array[Dictionary] = []
var host: RunController
var timings: Dictionary = {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)})
	print("M8_PHASE_RELEASE_CHECK "+id+" "+str(ok))
func rich(candidate: RunController) -> bool:
	return candidate != null and candidate.expedition_view != null and candidate.expedition_view.get_script().resource_path == "res://scripts/world/authored_expedition_view.gd"
func frames(count: int) -> void:
	for _i: int in count: await get_tree().process_frame
func run() -> void:
	get_tree().root.size = Vector2i(1280,720)
	check("release_process",not OS.has_feature("editor") and not OS.is_debug_build())
	var folder := OS.get_executable_path().get_base_dir()
	var files := Array(DirAccess.get_files_at(folder)); files.sort()
	var expected := [OS.get_executable_path().get_file(),OS.get_executable_path().get_file().get_basename()+".pck"]; expected.sort()
	var profile_root := OS.get_environment("APPDATA").replace("\\","/")
	check("clean_install",files == expected and DirAccess.get_directories_at(folder).is_empty() and not profile_root.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(profile_root))
	check("packaged_phase_definition",PhaseRelease.definition("forest_sanctuary").ok)
	if profile_root.is_empty() or not checks.all(func(item: Dictionary) -> bool: return item.ok): finish(); return
	var facade := ProfileFacade.new(ProfileStore.new(profile_root.path_join("forest_profile")),ProfileRewardResolver.pilot_progression())
	var opened := facade.open_profile()
	var created := facade.create_character("forest_release_create",facade.current_profile().revision,"Prova da floresta",&"mage") if opened.get("ok",false) else {"ok":false}
	check("synthetic_character",created.get("ok",false))
	if not created.get("ok",false): finish(); return
	var menu := CharacterMenu.new(); menu.set_profile_facade(facade); get_tree().root.add_child(menu); get_tree().current_scene = menu
	var panel := PhaseSelectionPanel.new(); menu.add_child(panel); panel.configure(menu,facade.current_profile().selected_character_id)
	var index := -1
	for k: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(k) == "Floresta do Santuário": index = k
	check("phase_listed_in_lobby",index > 0)
	if index <= 0: finish(); return
	panel.phase_choice.select(index); panel.phase_choice.item_selected.emit(index)
	var started := Time.get_ticks_usec()
	var entered: Dictionary = await panel.start()
	timings["entry_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("enters_from_lobby",entered.get("ok",false),entered.get("error_code",""))
	if not entered.get("ok",false): finish(); return
	host = entered["root"]
	await frames(3)
	var state := host.campaign_runtime.state
	check("three_stages_and_population",state.stages.size() == 3 and state.slots.size() == 126 and host.enemies.size() == 62)
	check("authored_game_presentation",rich(host))
	var props: int = host.expedition_view.get("skin").object_sprites.size() if rich(host) else 0
	check("authored_props_present",props >= 196,props)
	var origin := host.player.world_point()
	var world := host.player.world_motion.geometry
	var goal: Dictionary = {"ok":false}
	for offset: Vector2 in [Vector2(400,0),Vector2(0,-400),Vector2(-300,-300)]:
		var probe := world.support_at(origin.surface_id,Vector2(origin.position.x,origin.position.z)+offset,world.geometry_revision)
		if probe.ok: goal = probe; break
	if goal.ok: host.spatial_pointer_move(ExpeditionGeometryView.project(goal.data.point.position))
	var walk_start := Time.get_ticks_usec()
	while Time.get_ticks_usec()-walk_start < 4000000: await get_tree().process_frame
	check("player_walks",host.player.world_point().position.distance_to(origin.position) > 100.0)
	var picture := OS.get_environment("M8_EVIDENCE").path_join("release_forest.png")
	var saved := get_viewport().get_texture().get_image().save_png(picture)
	check("native_game_draws",DisplayServer.get_name() != "headless" and saved == OK and RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) > 0)
	var character_id := host.run_state.character_id
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	started = Time.get_ticks_usec()
	var suspended: Dictionary = await status.run_action({"kind":"suspend"})
	timings["suspend_ms"] = (Time.get_ticks_usec()-started)/1000.0
	check("suspends",suspended.get("ok",false) and get_tree().current_scene is CharacterMenu,suspended.get("error_code",""))
	if not suspended.get("ok",false): finish(); return
	var lobby := get_tree().current_scene as CharacterMenu
	var again := PhaseSelectionPanel.new(); lobby.add_child(again); again.configure(lobby,character_id)
	started = Time.get_ticks_usec()
	var resumed: Dictionary = await again.start()
	timings["resume_ms"] = (Time.get_ticks_usec()-started)/1000.0
	if resumed.get("ok",false): host = resumed["root"]
	check("resume_keeps_authored_presentation",resumed.get("ok",false) and rich(host) and host.campaign_runtime.state.current_stage_id == "forest_sanctuary_1",resumed.get("error_code",""))
	check("no_source_checkout_in_install",not DirAccess.dir_exists_absolute(folder.path_join("scripts")) and not DirAccess.dir_exists_absolute(folder.path_join("data")))
	finish()
func finish() -> void:
	var ok := checks.size() == 14 and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M8_PHASE_RELEASE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"timings":timings,"engine":Engine.get_version_info().string}))
	get_tree().paused = false
	get_tree().quit(0 if ok else 1)
