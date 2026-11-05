extends SceneTree
## F10 Q4 (contracts/f10_first_phase.md): the published forest phase. Three
## published maps prepare and compose into one expedition; the Q2 rules hold on
## the real manifest (first play by clearing, replay by guardian then objective).
const PhaseRelease = preload("res://scripts/map_authoring/release/phase_release.gd")
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_FOREST_PHASE_CHECK "+id+" "+str(ok)+" "+str(detail))
func run() -> void:
	check("phase_is_listed",PhaseRelease.phases().any(func(item: Dictionary) -> bool: return item.phase_id == "forest_sanctuary"),PhaseRelease.phases())
	var started := Time.get_ticks_usec()
	var prepared := PhaseRelease.prepare("forest_sanctuary")
	var prepare_ms := (Time.get_ticks_usec()-started)/1000.0
	check("phase_prepares",prepared.ok,prepared.get("code",""))
	if not prepared.ok:
		for item: Dictionary in PhaseRelease.definition("forest_sanctuary").definition.maps:
			var map := MapRelease.prepare(item.package_id)
			print("F10_FOREST_PHASE_MAP "+item.package_id+" "+JSON.stringify({"ok":map.ok,"code":map.get("code",""),"entity":map.get("entity",""),"diagnostics":map.get("diagnostics",[])}).substr(0,1500))
		finish(); return
	var data: Dictionary = (prepared.manifest as ExpeditionManifest).to_data()
	check("three_stages",prepared.stages == ["forest_sanctuary_1","forest_sanctuary_2","forest_sanctuary_3"])
	var per_stage := {}; var guardians := {}
	for slot: Dictionary in data.population.slots:
		per_stage[slot.stage_id] = per_stage.get(slot.stage_id,0)+1
		if slot.get("guardian",false): guardians[slot.stage_id] = guardians.get(slot.stage_id,0)+1
	check("fields_hold_40_to_70",per_stage.get("forest_sanctuary_1",0) >= 40 and per_stage.get("forest_sanctuary_1",0) <= 70 and per_stage.get("forest_sanctuary_2",0) >= 40 and per_stage.get("forest_sanctuary_2",0) <= 70,per_stage)
	check("one_guardian_per_map",guardians == {"forest_sanctuary_1":1,"forest_sanctuary_2":1,"forest_sanctuary_3":1},guardians)
	var travel: Array = data.portals.filter(func(portal: Dictionary) -> bool: return portal.kind == "travel")
	var unlocks: Array = data.objectives.filter(func(objective: Dictionary) -> bool: return objective.outcome == "stage_unlock")
	var completion: Array = data.objectives.filter(func(objective: Dictionary) -> bool: return objective.outcome == "phase_completion")
	check("portals_and_objectives",travel.size() == 4 and unlocks.size() == 2 and completion.size() == 1 and completion[0].stage_id == "forest_sanctuary_3",[travel.size(),unlocks.size(),completion.size()])
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(),true)
	var first := ExpeditionCampaignState.create("forest_first","forest_character",prepared.manifest,loaded.catalog.mob_catalog(),prepared.rules)
	var replay := ExpeditionCampaignState.create("forest_replay","forest_character",prepared.manifest,loaded.catalog.mob_catalog(),prepared.rules,true)
	check("campaign_accepts_the_phase",first.ok and replay.ok and first.worlds.size() == 3,first.get("error_code",""))
	if not first.ok or not replay.ok: finish(); return
	var forward: String = travel[0].portal_id
	var state: ExpeditionCampaignState = first.state
	var closed: bool = not state.portal_view(forward).open
	state.stages["forest_sanctuary_1"].cleared_once = true
	check("first_play_opens_by_clearing",closed and state.portal_view(forward).open)
	var again: ExpeditionCampaignState = replay.state
	var before_guardian: bool = not again.portal_view(forward).open
	for slot: Dictionary in again.slots.values():
		if slot.stage_id == "forest_sanctuary_1" and slot.get("guardian",false): slot.initial_resolved = true
	var before_shrine: bool = not again.portal_view(forward).open
	for objective: Dictionary in unlocks:
		if objective.stage_id == "forest_sanctuary_1": again.objectives[objective.objective_id] = true
	check("replay_opens_by_guardian_then_shrine",before_guardian and before_shrine and again.portal_view(forward).open and not again.stages["forest_sanctuary_1"].cleared_once)
	print("F10_FOREST_PHASE_TIMING "+JSON.stringify({"prepare_ms":snappedf(prepare_ms,1.0),"maps":prepared.metrics,"manifest_bytes":var_to_bytes(data).size(),"manifest_hash":ExpeditionCanonical.digest(data)}))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_FOREST_PHASE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
