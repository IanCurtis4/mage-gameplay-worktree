extends SceneTree
## F10 Q4 (contracts/f10_first_phase.md): the published forest phase in the real
## game flow. The Expedicoes panel prepares the phase off the main frame, enters
## through the expedition service, installs the first field and walks it; then
## suspends to the lobby and resumes. Measures the checkpoint the profile keeps.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_FOREST_PLAY_CHECK "+id+" "+str(ok)+" "+str(detail))
func frames(count: int) -> void:
	for _index: int in count: await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	var f := F.make("f10_forest_play")
	var facade: ProfileFacade = f["facade"]
	var menu := CharacterMenu.new(); menu.set_profile_facade(facade); root.add_child(menu); current_scene = menu
	var panel := PhaseSelectionPanel.new(); menu.add_child(panel); panel.configure(menu,f["a"])
	var index := -1
	for k: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(k) == "Floresta do Santuário": index = k
	check("panel_lists_the_phase",index > 0,index)
	if index <= 0: finish(); return
	panel.phase_choice.select(index); panel.phase_choice.item_selected.emit(index)
	var started := Time.get_ticks_usec()
	# Frames keep flowing while the maps prepare in the panel's worker thread.
	var timing := {"longest":0.0,"last":Time.get_ticks_usec()}
	var tick := func() -> void:
		var now := Time.get_ticks_usec(); timing.longest = maxf(timing.longest,(now-timing.last)/1000.0); timing.last = now
	process_frame.connect(tick)
	var entered: Dictionary = await panel.start()
	process_frame.disconnect(tick)
	var longest: float = timing.longest; var last := Time.get_ticks_usec()
	var enter_ms := (Time.get_ticks_usec()-started)/1000.0
	check("phase_enters_through_the_panel",entered.get("ok",false),entered.get("error_code",""))
	if not entered.get("ok",false):
		print("F10_FOREST_PLAY_FAILURE "+JSON.stringify(entered.get("snapshot_metrics",entered.get("detail",{}))).substr(0,4000))
		finish(); return
	var host := entered["root"] as RunController
	await frames(10)
	var state := host.campaign_runtime.state
	check("first_field_is_installed",current_scene == host and state.current_stage_id == "forest_sanctuary_1" and host.expedition_view != null and not state.replay)
	var forward := ""
	for portal: Dictionary in state.manifest_data.portals:
		if portal.kind == "travel" and portal.from_stage == "forest_sanctuary_1": forward = portal.portal_id
	check("first_play_portal_starts_closed",not forward.is_empty() and not state.portal_view(forward).open)
	var lock := facade.current_profile().expedition_for_character(f["a"])
	var checkpoint_bytes := var_to_bytes(lock.checkpoint).size() if lock != null else -1
	var profile_bytes := JSON.stringify(ProfileCodec.owned_dictionary(facade.current_profile())).to_utf8_buffer().size()
	check("profile_fits_its_ceiling",lock != null and profile_bytes < ProfileCodec.MAX_FILE_BYTES,[checkpoint_bytes,profile_bytes])
	# Walk the field for a few seconds and measure the frames.
	var origin: ExpeditionWorldPoint = host.player.world_point()
	var geometry: WorldGeometry = host.player.world_motion.geometry
	var goal := geometry.support_at(origin.surface_id,Vector2(origin.position.x+400.0,origin.position.z-300.0),geometry.geometry_revision)
	var moved := false; var worst := 0.0; var count := 0; var total := 0.0
	if goal.ok:
		host.spatial_pointer_move(host.get_canvas_transform().affine_inverse()*(host.get_canvas_transform()*ExpeditionGeometryView.project(goal.data.point.position)))
		var begin := Time.get_ticks_usec(); last = begin
		while Time.get_ticks_usec()-begin < 4000000:
			await process_frame
			var now := Time.get_ticks_usec(); var ms := (now-last)/1000.0; last = now
			worst = maxf(worst,ms); total += ms; count += 1
		moved = host.player.world_point().position.distance_to(origin.position) > 100.0
	check("player_walks_the_field",moved,[goal.ok,host.player.world_point().position.distance_to(origin.position)])
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	var suspended: Dictionary = await status.run_action({"kind":"suspend"})
	check("suspends_to_the_lobby",suspended.get("ok",false) and current_scene is CharacterMenu,suspended.get("error_code",""))
	if not suspended.get("ok",false): finish(); return
	var lobby := current_scene as CharacterMenu
	var again := PhaseSelectionPanel.new(); lobby.add_child(again); again.configure(lobby,f["a"])
	var resumed: Dictionary = await again.start()
	var resumed_ok: bool = resumed.get("ok",false) and (resumed["root"] as RunController).campaign_runtime.state.current_stage_id == "forest_sanctuary_1"
	check("resumes_the_phase",resumed_ok,resumed.get("error_code",""))
	print("F10_FOREST_PLAY_TIMING "+JSON.stringify({"enter_ms":snappedf(enter_ms,1.0),"longest_frame_while_preparing_ms":snappedf(longest,0.1),"walk_frames":count,"walk_mean_ms":snappedf(total/maxf(1,count),0.1),"walk_worst_ms":snappedf(worst,0.1),"checkpoint_bytes":checkpoint_bytes,"profile_bytes":profile_bytes,"slots_field_1":state.slots.values().filter(func(slot: Dictionary) -> bool: return slot.stage_id == "forest_sanctuary_1").size()}))
	if resumed.get("ok",false): (resumed["root"] as Node).queue_free()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_FOREST_PLAY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
