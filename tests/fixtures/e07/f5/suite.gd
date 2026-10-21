extends SceneTree
const Fault = preload("res://tests/e06_tx_fixture.gd")
const Campaign = preload("res://tests/fixtures/e07/f5/campaign_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void: pass
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func make(label: String, with_card: bool = false) -> Dictionary:
	var catalog := ProfileCatalog.pilot()
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e07_f5/profiles/%s_%d" % [label, Time.get_ticks_usec()])
	var store := Fault.FaultStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	check(facade.create_character("create", 0, "Teste F5", &"mage")["ok"], "fixture character")
	if with_card:
		var seed_profile := facade.current_profile()
		check(seed_profile.card_inventory.grant(&"bulwark_card", BuildContentLoader.pilot(), "f5_card_fixture", seed_profile.selected_character_id)["ok"], "explicit owned card fixture before expedition")
		check(store.commit(seed_profile)["ok"], "card fixture through canonical writer")
		facade = ProfileFacade.new(store)
		check(facade.open_profile()["ok"], "read explicit card fixture")
	var started := facade.start_run("start", facade.current_profile().revision)
	check(started["ok"], "fixture session")
	var loaded := BuildContentLoader.load_catalog_for_profile(catalog, true)
	check(loaded["ok"] and started["run_state"].set_effect_catalog(loaded["catalog"])["ok"], "canonical gameplay content")
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	var host := RunController.new()
	host.expedition_entry_mode = true
	root.add_child(host)
	check(host.enemies.is_empty(), "explicit expedition startup does not create a pilot encounter")
	var loot := host.reward_service.configure_mob_loot(EquipmentLootProfiles.production(host.run_state.effect_catalog()))
	check(loot["ok"], "canonical loot profiles")
	disable(host)
	paused = true
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(host)["ok"], "coherent fixture barrier")
	var generated := ExpeditionAssembler.build(Campaign.input())
	check(generated["ok"], "four-stage generated fixture")
	return {"controller": host, "facade": facade, "store": store, "directory": directory, "barrier": barrier, "manifest": generated["data"]["manifest"], "service": ExpeditionService.new(facade)}
func disable(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): disable(child)
func enter(f: Dictionary) -> Dictionary:
	var result: Dictionary = f["service"].enter(f["controller"], f["barrier"], "f5_expedition", f["manifest"], Campaign.rules(f["manifest"]), "enter", f["facade"].current_profile().revision)
	check(result.get("ok", false), "entry persists before publication: " + str(result.get("error_code")))
	if result.get("ok", false): adopt(f, result)
	return result
func adopt(f: Dictionary, result: Dictionary) -> void:
	f["barrier"].release()
	var old: RunController = f["controller"]
	if old.is_inside_tree(): old.get_parent().remove_child(old)
	old.free()
	var host: RunController = result["root"]
	# Off-tree fixtures execute no frame. The native consumer installs explicitly.
	for id: String in result["snapshot"]["objects"]:
		var object: Object = result["entities"].resolve(id)
		if object is Node: object.process_mode = result["snapshot"]["objects"][id]["node"]["mode"]
	f["controller"] = host
	f["barrier"] = SnapshotTickBarrier.new()
	check(f["barrier"].acquire(host)["ok"], "next off-tree coherent barrier")
func command(f: Dictionary, payload: Dictionary, request: String, adopt_result: bool = true) -> Dictionary:
	var result: Dictionary = f["service"].campaign_command(f["controller"], f["barrier"], payload, request, f["facade"].current_profile().revision)
	if result.get("ok", false) and result.has("root") and adopt_result: adopt(f, result)
	return result
func kill(f: Dictionary, id: String, request: String) -> Dictionary:
	var host: RunController = f["controller"]
	var actor: EnemyActor = host.campaign_runtime.actors[id]
	# Real HealthState terminal state and the same actor callback consumed in game.
	actor.health.current_hp = 0.0
	actor.health._death_emitted = true
	host._on_enemy_died(actor)
	var events := host.campaign_runtime.pending_events.duplicate(true)
	return command(f, {"kind": "events", "events": events}, request)
func relocate(f: Dictionary, record: Dictionary) -> void:
	var host: RunController = f["controller"]
	var motion := host.player.world_motion
	motion._point = ExpeditionPopulationPlanner.point(record)
	motion.geometry.set_occupant(motion._occupant_id, motion._point, motion.profile(), motion.geometry.geometry_revision)
	host.player.global_position = Vector2(motion._point.position.x, motion._point.position.z)
func travel_to(f: Dictionary, id: String, request: String) -> Dictionary:
	var host: RunController = f["controller"]
	var portal := host.campaign_runtime.state.portal_view(id)
	relocate(f, portal["from_anchor"])
	return command(f, {"kind": "travel", "portal_id": id, "stage_id": portal["from_stage"]}, request)
func dispose(f: Dictionary) -> void:
	f["barrier"].release()
	f["controller"].free()
	paused = false
func finish_test() -> void:
	print("E07 F5 %s: %d checks, %d failures" % [get_script().resource_path.get_file(), checks, failures])
	quit(1 if failures else 0)
