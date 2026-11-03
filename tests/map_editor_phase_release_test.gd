extends SceneTree
## F10 Q4 (contracts/f10_first_phase.md): an authored phase composes published
## maps into stages joined by travel portals, and the campaign accepts it. The
## published Bosque stands in for the phase maps (twice).
const PhaseRelease = preload("res://scripts/map_authoring/release/phase_release.gd")
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_PHASE_RELEASE_CHECK "+id+" "+str(ok)+" "+str(detail))
func phase(maps: Array) -> Dictionary:
	return {"registry_version":1,"phase_id":"woods_test","title":"Fase de teste","maps":maps}
func run() -> void:
	# 1. Registry shape.
	var good := phase([{"package_id":"sanctuary_woods","exit":"shrine_completion"},{"package_id":"sanctuary_woods"}])
	var single := phase([{"package_id":"sanctuary_woods"}])
	var no_exit := phase([{"package_id":"sanctuary_woods"},{"package_id":"sanctuary_woods"}])
	var extra := good.duplicate(true); extra["seed"] = 1
	check("registry_shape_is_closed",PhaseRelease.valid_definition(good) and not PhaseRelease.valid_definition(single) and not PhaseRelease.valid_definition(no_exit) and not PhaseRelease.valid_definition(extra))
	# 2. Compose the published map twice.
	var started := Time.get_ticks_usec()
	var map := MapRelease.prepare("sanctuary_woods")
	var prepare_ms := (Time.get_ticks_usec()-started)/1000.0
	check("published_map_prepares",map.ok,map.get("code",""))
	if not map.ok: finish(); return
	var composed := PhaseRelease.compose(good,[map,map])
	check("phase_composes",composed.ok,composed.get("code",""))
	if not composed.ok: finish(); return
	var data: Dictionary = (composed.manifest as ExpeditionManifest).to_data()
	check("two_stages_renamed",composed.stages == ["woods_test_1","woods_test_2"] and data.input.entry_stage_id == "woods_test_1" and data.input.phase_id == "woods_test")
	var ids: Dictionary = {}; var duplicated := false
	for slot: Dictionary in data.population.slots:
		if ids.has(slot.slot_id): duplicated = true
		ids[slot.slot_id] = true
	var single_count: int = (map.manifest as ExpeditionManifest).to_data().population.slots.size()
	check("slots_prefixed_and_unique",not duplicated and ids.size() == single_count*2 and composed.rules.size() == map.rules.size()*2 and composed.rules.has(data.population.slots[0].slot_id))
	var travel: Array = data.portals.filter(func(portal: Dictionary) -> bool: return portal.kind == "travel")
	check("exit_becomes_travel_both_ways",travel.size() == 2 and travel[0].from_stage == "woods_test_1" and travel[0].to_stage == "woods_test_2" and travel[1].from_stage == "woods_test_2" and travel[1].to_stage == "woods_test_1" and travel[0].to_anchor.stage_id == "woods_test_2" and travel[0].from_anchor.stage_id == "woods_test_1")
	var completions: Array = data.objectives.filter(func(objective: Dictionary) -> bool: return objective.outcome == "phase_completion")
	check("only_the_last_map_completes",completions.size() == 1 and completions[0].stage_id == "woods_test_2")
	var leaked := false
	for key: String in ["stage_id","from_stage","to_stage"]:
		if JSON.stringify(data).contains("\""+key+"\":\"map_preview\""): leaked = true
	check("no_single_map_stage_left",not leaked)
	check("phase_hash_is_stable",PhaseRelease.compose(good,[map,map]).phase_hash == composed.phase_hash)
	# 3. The campaign accepts the composed phase; the portal follows the Q2 rule.
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(),true)
	var created := ExpeditionCampaignState.create("phase_test","phase_character",composed.manifest,loaded.catalog.mob_catalog(),composed.rules) if loaded.ok else {"ok":false}
	var portal_ok := false
	if created.ok:
		var state: ExpeditionCampaignState = created.state
		var closed: bool = not state.portal_view(travel[0].portal_id).open
		state.stages["woods_test_1"].cleared_once = true
		portal_ok = closed and state.portal_view(travel[0].portal_id).open and created.worlds.size() == 2
	check("campaign_accepts_the_phase",created.ok and portal_ok,created.get("error_code",""))
	# 4. Refusals.
	var wrong_exit := phase([{"package_id":"sanctuary_woods","exit":"nowhere"},{"package_id":"sanctuary_woods"}])
	var refused := PhaseRelease.compose(wrong_exit,[map,map])
	check("missing_exit_is_refused",not refused.ok and refused.code == "phase_exit_missing")
	print("F10_PHASE_RELEASE_TIMING "+JSON.stringify({"prepare_ms":snappedf(prepare_ms,1.0)}))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_PHASE_RELEASE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
