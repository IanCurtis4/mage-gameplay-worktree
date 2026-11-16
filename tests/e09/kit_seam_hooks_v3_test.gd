extends SceneTree
## E09 T1.2 (A13) — kit hooks over origin skills:
## - ClassKit.skill_cost: single effective SP cost (payment check, debit, UI), floor 0;
## - ClassKit.on_base_skill_committed: once per paid commit of a non-kit skill, flat
##   and world, with target, point, world, rank and element.
## Uses the fixture kit (scripts/classes/fixture/fixture_kit.gd); no profile or save.
const FixtureKit = preload("res://scripts/classes/fixture/fixture_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const F1Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")

const EXPLOSIVE := &"sentinel_explosive_shot"

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _close(a: float, b: float, label: String) -> void:
	_check(absf(a - b) <= 0.0001, "%s (%s vs %s)" % [label, a, b])

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassKitRegistry.install_fixture(&"sp_ac", FixtureKit.new(&"sp_ac")) and ClassKitRegistry.install_fixture(&"mg_ac", FixtureKit.new(&"mg_ac")), "fixture kits install over sp_ac and mg_ac")
	_check_defaults()
	_check_swordsman_flat()
	await _check_mage_controller()
	await _check_sentinel_reservation()
	await _check_world_commits()
	ClassKitRegistry.clear_fixtures()
	print("E09 kit seam hooks v3: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Builders ----------------------------------------------------------------------

func _snapshot(origin: StringName, evolution: StringName, base_skills: Array[StringName]) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "kit-v3-" + String(evolution)
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = origin
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(origin, evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in base_skills: snapshot.skill_ranks[skill] = 1
	for skill: StringName in ClassKitRegistry.skill_ids(evolution): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	var slots: Array = []
	for skill: StringName in base_skills: slots.append(skill)
	if ClassKitRegistry.is_kit(evolution): slots.append(ClassKitRegistry.skill_ids(evolution)[0])
	while slots.size() < 5: slots.append(null)
	snapshot.active_slots = slots
	return snapshot

func _player(snapshot: BuildSnapshot) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build(snapshot.character_id, snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _enemy(at: Vector2, stats: StatBreakdown) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, stats, 18.0)
	enemy.global_position = at
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _commits(player: PlayerActor) -> Array[Dictionary]:
	return player.kit.get("base_commits")

# --- Defaults: a kit without the hooks keeps the current behaviour ------------------

func _check_defaults() -> void:
	var plain := ClassKit.new()
	_check(is_equal_approx(plain.skill_cost(null, &"slash", 7.0), 7.0), "default ClassKit.skill_cost returns the base cost")
	plain.on_base_skill_committed(null, &"slash", {})
	_check(true, "default on_base_skill_committed is a no-op")
	var without_kit := _player(_snapshot(&"swordsman", &"defender", [&"slash", &"dash"] as Array[StringName]))
	_check(without_kit.kit == null, "an existing identity has no kit")
	var same := true
	for skill: StringName in without_kit.available_skill_ids():
		same = same and is_equal_approx(without_kit.skill_cost(skill), without_kit.base_skill_cost(skill))
	_check(same, "without kit skill_cost is the base cost for every skill")
	var sp := without_kit.current_sp
	_check(without_kit.use_slash(Vector2.RIGHT, [] as Array[CombatActor]), "slash commits without kit")
	_close(sp - without_kit.current_sp, without_kit.base_skill_cost(&"slash"), "without kit the debit is the base cost")
	without_kit.free()
	# A fixture kit with identity cost (scale 1, offset 0) charges exactly the base cost.
	var identity := _player(_snapshot(&"swordsman", &"sp_ac", [&"slash", &"dash"] as Array[StringName]))
	same = true
	for skill: StringName in identity.available_skill_ids():
		same = same and is_equal_approx(identity.skill_cost(skill), identity.base_skill_cost(skill))
	_check(identity.has_kit() and same, "identity kit cost leaves every cost unchanged")
	sp = identity.current_sp
	_check(identity.use_slash(Vector2.RIGHT, [] as Array[CombatActor]), "slash commits with the identity kit")
	_close(sp - identity.current_sp, identity.base_skill_cost(&"slash"), "identity kit debit is the base cost")
	identity.free()

# --- Swordsman, flat entries -------------------------------------------------------

func _check_swordsman_flat() -> void:
	var player := _player(_snapshot(&"swordsman", &"sp_ac", [&"slash", &"dash"] as Array[StringName]))
	var kit := player.kit
	var base := player.base_skill_cost(&"slash")
	_check(base > 0.0, "slash has a base SP cost")
	kit.set("cost_scale", 0.5)
	_close(player.skill_cost(&"slash"), base * 0.5, "kit halves an origin skill cost")
	# Payment check reads the kit cost: SP between half and full cost is enough.
	player.current_sp = base * 0.75
	_check(player._can_pay_skill(&"slash"), "_can_pay_skill reads the kit cost")
	var deficit := player.sp_deficit()
	_check(player.use_slash(Vector2.RIGHT, [] as Array[CombatActor]), "slash commits with SP below its base cost")
	_close(player.sp_deficit() - deficit, base * 0.5, "debit is the kit cost")
	var commits := _commits(player)
	_check(commits.size() == 1 and commits[0]["skill_id"] == &"slash", "one base commit for one slash")
	_check(not bool(commits[0]["world"]) and int(commits[0]["rank"]) == player.skill_rank(&"slash") and StringName(commits[0]["element"]) == &"" and int(commits[0]["target_id"]) == 0, "flat slash context: world false, rank, empty element, no target")
	_check((commits[0]["point"] as Vector2).is_equal_approx(player.global_position), "without an entry note the point is the player position")
	# Refused casts never call the hook.
	var sp := player.current_sp
	_check(not player.use_slash(Vector2.RIGHT, [] as Array[CombatActor]) and commits.size() == 1 and is_equal_approx(player.current_sp, sp), "refused on cooldown: no hook, no SP")
	player.slash_cooldown = 0.0
	player.current_sp = base * 0.25
	_check(not player._can_pay_skill(&"slash") and not player.use_slash(Vector2.RIGHT, [] as Array[CombatActor]) and commits.size() == 1, "refused below the kit cost: no hook")
	# Kit skills read the same cost but never reach the base hook.
	player.current_sp = player.max_sp
	var oath := ClassKitRegistry.skill_ids(&"sp_ac")[0]
	var oath_base := player.base_skill_cost(oath)
	_close(player.skill_cost(oath), oath_base * 0.5, "kit skills use the same kit cost")
	deficit = player.sp_deficit()
	_check(player.use_kit_skill(oath, player.global_position), "kit skill commits")
	_close(player.sp_deficit() - deficit, oath_base * 0.5, "kit skill debit is the kit cost")
	_check(commits.size() == 1, "a kit skill does not call on_base_skill_committed")
	# Floor at zero and non-finite answers.
	kit.set("cost_scale", 1.0)
	kit.set("cost_offset", -1000.0)
	_close(player.skill_cost(&"slash"), 0.0, "negative kit cost floors at 0")
	player.slash_cooldown = 0.0
	player.current_sp = 0.0
	deficit = player.sp_deficit()
	_check(player._can_pay_skill(&"slash") and player.use_slash(Vector2.RIGHT, [] as Array[CombatActor]), "zero cost commits with zero SP")
	_close(player.sp_deficit(), deficit, "zero cost debits nothing")
	_check(commits.size() == 2, "a free commit still calls the hook once")
	kit.set("cost_offset", 0.0)
	kit.set("cost_scale", NAN)
	_close(player.skill_cost(&"slash"), base, "non-finite kit cost falls back to the base")
	kit.set("cost_scale", INF)
	_close(player.skill_cost(&"slash"), base, "infinite kit cost falls back to the base")
	kit.set("cost_scale", 1.0)
	# Dash: the point is the planned endpoint.
	player.current_sp = player.max_sp
	var expected := player.dash_destination(Vector2.RIGHT)
	_check(player.use_dash(Vector2.RIGHT), "dash commits")
	_check(commits.size() == 3 and commits[2]["skill_id"] == &"dash" and (commits[2]["point"] as Vector2).is_equal_approx(expected), "dash context point is its endpoint")
	# The basic attack never calls the hook.
	var target := _enemy(player.global_position + Vector2(40, 0), player.stat_breakdown)
	player.target = target
	player.attack_cooldown = 0.0
	player._try_basic_attack()
	_check(commits.size() == 3, "the basic attack is not a base skill commit")
	player.target = null
	target.free()
	player.free()

# --- Mage through RunController (flat dispatch with point and target) ---------------

func _check_mage_controller() -> void:
	RunController.pending_run_state = RunState.from_build("kit-v3-mage", _snapshot(&"mage", &"mg_ac", [&"fireball", &"lightning", &"teleport"] as Array[StringName]))
	RunController.pending_run_facade = null
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.set_process(false)
	var player := controller.player
	player.set_process(false)
	for enemy: CombatActor in controller.enemies: enemy.set_process(false)
	_check(player.has_kit() and player.kit.get_script() == FixtureKit, "the controller player carries the mage fixture kit")
	var commits := _commits(player)
	var kit := player.kit
	# UI reads the effective cost.
	kit.set("cost_scale", 0.5)
	controller._update_hud()
	var half := player.skill_cost(&"fireball")
	_close(half, player.base_skill_cost(&"fireball") * 0.5, "mage origin spell uses the kit cost")
	var card: Button = controller.battle_controls.skill_buttons.get(&"fireball")
	_check(card != null and (card.text + card.tooltip_text).contains("%d SP" % int(half)), "HUD shows the effective cost")
	# Fireball: element fire, clicked point.
	player.current_sp = player.max_sp
	var aim := player.global_position + Vector2(200, 0)
	var deficit := player.sp_deficit()
	controller._execute_skill(&"fireball", aim)
	_check(commits.size() == 1 and commits[0]["skill_id"] == &"fireball" and StringName(commits[0]["element"]) == &"fire", "fireball commit carries the fire element")
	_check(commits.size() == 1 and (commits[0]["point"] as Vector2).is_equal_approx(aim) and not bool(commits[0]["world"]), "flat dispatch passes the clicked point")
	_close(player.sp_deficit() - deficit, half, "controller dispatch debits the kit cost")
	_check(player._base_commit_hint.is_empty(), "no entry note survives the dispatch")
	# Refused dispatch: on cooldown, no hook, no stale note.
	controller._execute_skill(&"fireball", aim)
	_check(commits.size() == 1 and player._base_commit_hint.is_empty(), "refused dispatch: no hook and no note left")
	# Lightning on a selected target.
	var victim := _enemy(player.global_position + Vector2(150, 0), player.stat_breakdown)
	controller.add_child(victim)
	victim.set_process(false)
	_check(player.can_target_skill(&"lightning", victim), "lightning can target the victim")
	controller._execute_skill(&"lightning", victim.global_position, victim)
	_check(commits.size() == 2 and commits[1]["skill_id"] == &"lightning" and int(commits[1]["target_id"]) == victim.get_instance_id() and StringName(commits[1]["element"]) == &"lightning", "lightning commit carries its target and element")
	# Teleport: the point is the destination.
	var far := player.global_position + Vector2(1000, 0)
	var destination := player.teleport_destination(far)
	controller._execute_skill(&"teleport", far)
	_check(commits.size() == 3 and commits[2]["skill_id"] == &"teleport" and (commits[2]["point"] as Vector2).is_equal_approx(destination) and StringName(commits[2]["element"]) == &"", "teleport commit point is the destination, no element")
	_check(player.global_position.is_equal_approx(destination), "teleport resolved after the hook")
	kit.set("cost_scale", 1.0)
	controller.queue_free()
	await process_frame

# --- Sentinel reservation: one commit, at the reserved price ------------------------

func _sentinel() -> PlayerActor:
	var build := BuildSnapshot.new()
	build.character_id = "kit-v3-sentinel"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel"
	build.base_level = 30
	build.job_level = 40
	build.attribute_allocations = {&"int": 35, &"dex": 20, &"luk": 15}
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", &"sentinel")
	build.skill_ranks = {EXPLOSIVE: 5, &"sentinel_headshot": 1, &"sentinel_piercing_shot": 1, &"sentinel_observe": 1, &"sentinel_opening_read": 3}
	E05DependencyFixture.complete_snapshot(build)
	build.active_slots = [EXPLOSIVE, &"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_observe", null]
	build.passive_slots = [&"sentinel_opening_read", null]
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 300)
	player.configure(navigation, RunState.from_build("", build))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	player.sentinel_state.gain(90.0)
	return player

func _check_sentinel_reservation() -> void:
	var player := _sentinel()
	player.attach_kit(FixtureKit.new(&"sp_ac"))
	var kit := player.kit
	var commits := _commits(player)
	var base := player.base_skill_cost(EXPLOSIVE)
	kit.set("cost_scale", 0.5)
	_check(player.prepare_sentinel_explosive(), "reservation prepares")
	_close(player.sentinel_state.reserved_sp, base * 0.5, "reservation locks the kit cost")
	_check(commits.is_empty(), "a reservation is not a commit")
	kit.set("cost_scale", 2.0)
	var enemy := CombatActor.new()
	enemy.setup("Alvo Explosivo", Color.WHITE, player.stat_breakdown)
	enemy.position = Vector2(480, 300)
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	var deficit := player.sp_deficit()
	_check(player._launch_sentinel_explosive(enemy), "reserved shot launches")
	_close(player.sp_deficit() - deficit, base * 0.5, "the launch charges the reserved price, not the new cost")
	_check(commits.size() == 1 and commits[0]["skill_id"] == EXPLOSIVE and int(commits[0]["target_id"]) == enemy.get_instance_id(), "exactly one commit with the shot target")
	_check(not player._launch_sentinel_explosive(enemy) and commits.size() == 1, "a retry without reservation adds no commit")
	player.queue_free()
	enemy.queue_free()
	await process_frame

# --- World entries: teleport, dash and a spatial command ----------------------------

func _check_world_commits() -> void:
	if not F1Fixture.sources_current():
		_check(false, "F1 world fixture is current")
		return
	var input := F1Fixture.make()
	var built := ExpeditionAssembler.build(input)
	_check(built["ok"], "world fixture builds")
	if not built["ok"]: return
	var geometry := WorldGeometry.new()
	geometry.configure(built["data"]["manifest"], "sample")
	var profile := input.traversal.to_data()
	var mage := _player(_snapshot(&"mage", &"mg_ac", [&"fireball", &"lightning", &"teleport"] as Array[StringName]))
	root.add_child(mage)
	mage.set_process(false)
	var lower := F1Fixture.point("root", Vector3(50, 0, 150))
	_check(mage.bind_world_geometry(geometry, lower, profile, "mage")["ok"], "mage kit player binds the world")
	var commits := _commits(mage)
	var destination := F1Fixture.point("root", Vector3(80, 0, 150))
	_check(mage.use_world_teleport(destination, geometry.geometry_revision), "world teleport commits")
	_check(commits.size() == 1 and commits[0]["skill_id"] == &"teleport" and bool(commits[0]["world"]) and (commits[0]["point"] as Vector2).is_equal_approx(Vector2(80, 150)), "world teleport context: world true, destination x/z")
	var sp := mage.current_sp
	_check(not mage.use_world_teleport(destination, geometry.geometry_revision) and commits.size() == 1 and is_equal_approx(mage.current_sp, sp), "refused world teleport: no hook")
	# Spatial command through the world cast pipeline.
	var actors: Array[CombatActor] = []
	var requested := mage.request_world_skill(&"fireball", null, Vector3.RIGHT, null, actors, geometry.geometry_revision)
	if requested.get("ok", false) and mage.active_cast_remaining > 0.0:
		mage._advance_world_cast(10.0)
	_check(requested.get("ok", false), "world fireball request: %s" % str(requested))
	_check(commits.size() == 2 and commits[1]["skill_id"] == &"fireball" and bool(commits[1]["world"]) and StringName(commits[1]["element"]) == &"fire", "world fireball commits once with world and element")
	mage._advance_world_cast(10.0)
	_check(commits.size() == 2, "advancing the finished cast adds no commit")
	# Swordsman world dash.
	var swordsman := _player(_snapshot(&"swordsman", &"sp_ac", [&"slash", &"dash"] as Array[StringName]))
	root.add_child(swordsman)
	swordsman.set_process(false)
	var start := F1Fixture.point("root", Vector3(50, 0, 50))
	_check(swordsman.bind_world_geometry(geometry, start, profile, "swordsman")["ok"], "swordsman kit player binds the world")
	var ramp_end := F1Fixture.point("landing", Vector3(220, 40, 50))
	_check(swordsman.use_world_dash(ramp_end, geometry.geometry_revision), "world dash commits")
	var dash_commits := _commits(swordsman)
	_check(dash_commits.size() == 1 and dash_commits[0]["skill_id"] == &"dash" and bool(dash_commits[0]["world"]) and (dash_commits[0]["point"] as Vector2).is_equal_approx(Vector2(220, 50)), "world dash context: destination x/z")
	mage.queue_free()
	swordsman.queue_free()
	await process_frame
