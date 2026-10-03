extends SceneTree
## Integrated legal builds and dense combat; fixtures never touch persistent saves.

const POINTS := [Vector2(300, 300), Vector2(700, 300), Vector2(500, 650)]
var checks := 0
var failures := 0
var arena: RunController
var casting: GeometerCasting
var hits: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(ProfileCatalog.pilot().evolution_is_ready(&"mg_ar", &"mage"), "completed G7 production catalog exposes Geometer to legal Mage runs")
	_production_entry()
	for recipe: Array in [[&"fire", &"fire", &"fire"], [&"ice", &"ice", &"ice"], [&"lightning", &"lightning", &"lightning"], [&"fire", &"ice", &"fire"], [&"fire", &"ice", &"lightning"]]:
		await _dense(recipe)
	for rate: int in [30, 60, 144]:
		await _wall_contact(rate)
	await _mobile_pause_cleanup()
	print("Geometer G7 integrated: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _legal_build(triangle_rank: int = 5) -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot({}, {}, {&"mg_ar": {"content_ready": true}})
	var character := CharacterState.new("geometer-g7-fixture", "Geômetra G7", &"mage")
	character.evolution_id = &"mg_ar"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var purchases := {&"lightning": 5, &"fireball": 5, &"fire_spear": 5, &"mage_mana_regeneration": 3, &"teleport": 1, &"geometer_trace": 2, &"geometer_incidence": 3, &"geometer_triangulation": triangle_rank, &"geometer_vector_memory": 3, &"geometer_collapse": 2, &"geometer_rewrite": 5}
	for skill: StringName in purchases:
		for index: int in int(purchases[skill]):
			_check(CharacterProgression.learn_skill(character, catalog, skill)["ok"], "legal purchase %s #%d" % [skill, index + 1])
	var summary := CharacterProgression.summary(character, catalog)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 15 + triangle_rank, "job40 legal 19 base / <=20 evolution wallet")
	character.presets[0]["active_slots"] = [&"geometer_trace", &"geometer_triangulation", &"geometer_rewrite", &"geometer_collapse", &"fireball"]
	character.presets[0]["passive_slots"] = [&"geometer_incidence", &"geometer_vector_memory"]
	return BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(&"mage", &"mg_ar"))

func _fixture(triangle_rank: int = 5) -> void:
	RunController.pending_run_state = RunState.from_build("", _legal_build(triangle_rank))
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
	arena.player.global_position = Vector2(150, 450)
	arena.player.health.max_hp = 100000
	arena.player.health.current_hp = 100000
	arena.training_boss.global_position = Vector2(500, 430)
	arena.training_boss.set_process(false)
	for index: int in 19:
		var enemy := arena._spawn_enemy(&"archer" if index % 4 == 0 else &"chaser", Vector2(390 + index % 5 * 48, 345 + index / 5 * 48))
		enemy.set_process(false)
		enemy.health.max_hp = 10000
		enemy.health.current_hp = 10000
	casting = arena.geometer_casting
	casting.targets = arena.enemies.duplicate()
	hits.clear()
	casting.hit.connect(func(request: DamageRequest, _actor: CombatActor) -> void: hits.append(request.copy()))
	_check(arena.enemies.size() == 20 and arena.training_boss.hard_controls.boss, "dense fixture has19 enemies plus boss within total20 cap")
	_check(arena.enemies.all(func(actor: CombatActor) -> bool: return actor.compact_control_visuals), "dense Geometer uses compact control markers only")

func _paid_shape(elements: Array, mobile: bool = false) -> void:
	casting.clear_construction()
	for index: int in 3:
		var command := GeometerCastCommand.new()
		command.skill_id = &"geometer_triangulation" if index == 2 else &"geometer_trace"
		command.element = elements[index]
		command.point = POINTS[index]
		if index == 2 and mobile:
			arena.training_boss.global_position = POINTS[index]
			command.actor_id = arena.training_boss.get_instance_id()
		arena.player.mage_cooldowns[command.skill_id] = 0
		var before := arena.player.current_sp
		casting.launch(command)
		_check(arena.player.current_sp == before - (16 if index == 2 else 8), "paid launch spends exact one skill cost")
		for child: Node in casting.get_children():
			if child is GeometerTraceProjectile and not child.is_queued_for_deletion():
				child.set_process(false)
				child._process(2.0)
		await process_frame
	_check(casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE and casting.construction.elements() == elements, "paid ordered launch forms expected recipe")

func _dense(recipe: Array) -> void:
	var rank := 1 if recipe[0] == recipe[1] and recipe[1] == recipe[2] else (3 if recipe[0] == recipe[2] else 5)
	_fixture(rank)
	await _paid_shape(recipe)
	var identity := casting.construction.construction_id
	var before := arena.player.current_sp
	var closure_count := hits.size()
	var eligible := 0
	for actor: CombatActor in arena.enemies:
		if GeometerGeometry.triangle_contains(casting.construction.positions(), actor.global_position, actor.collision_radius): eligible += 1
	_check(closure_count <= 3 if recipe[2] == &"lightning" else closure_count == eligible, "C respects dense unique current occupants / bounded lightning three")
	for request: DamageRequest in hits:
		_check(request.is_secondary and request.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not request.can_crit, "dense closure canonical secondary geometry request")
	casting.advance(1.0)
	_check(casting._wall_reactions.size() <= 12 and casting.construction.construction_id == identity and arena.player.current_sp == before, "dense maintenance bounded effects no extra charge/identity change")
	var arrows := 0
	for enemy: CombatActor in arena.enemies:
		if enemy is EnemyActor and (enemy as EnemyActor).archetype == &"archer":
			(enemy as EnemyActor)._try_attack(true)
	for child: Node in arena.get_children():
		if child is ArrowProjectile:
			arrows += 1
			child.set_process(false)
			child._process(0.1)
	_check(arrows == 5, "five real enemy attack emissions create hostile arrows")
	arena.player.target = arena.training_boss
	arena.player.global_position = Vector2(420, 430)
	arena.player._try_basic_attack()
	var autos := 0
	for child: Node in arena.get_children():
		if child is MageProjectile and not child.is_queued_for_deletion():
			autos += 1
			child.set_process(false)
			child._process(0.5)
	_check(autos == 1 and casting.construction.vertices.size() == 3, "real Mage auto remains distinct from Trace and cannot add vertex")
	casting.advance(12.0)
	_check(casting.construction.vertices.is_empty() and casting._wall_reactions.is_empty() and casting._shot_triangle_snapshots.is_empty(), "dense expiration leaves no figure/reactions/reservation snapshots")
	await _finish()

func _wall_contact(rate: int) -> void:
	_fixture()
	casting.clear_construction()
	casting.construction.add_vertex(&"fire", Vector2(300, 400), 0, 5, arena.navigation)
	casting.construction.add_vertex(&"ice", Vector2(700, 400), 0, 5, arena.navigation)
	casting.wall_field.capture_construction()
	casting.advance(0.001)
	hits.clear()
	var actor := arena.enemies[1] as EnemyActor
	var begin := Vector2(500, 330)
	actor.global_position = begin
	for index: int in rate:
		var next := Vector2(500, 330 + 140.0 * float(index + 1) / rate)
		var prior := actor.global_position
		actor.global_position = next
		actor.ground_walked.emit(prior, next)
		casting.advance(1.0 / rate)
	_check(hits.size() == 1 and hits[0].target_id == actor.get_instance_id(), "30/60/144Hz actual walked wall contact exactly once at%d" % rate)
	_check(casting._wall_reactions.size() <= 12, "contact reaction budget independent of frame rate")
	await _finish()

func _mobile_pause_cleanup() -> void:
	_fixture()
	await _paid_shape([&"fire", &"ice", &"lightning"], true)
	var identity := casting.construction.construction_id
	var clock := casting.construction.figure_remaining
	var count := hits.size()
	paused = true
	casting.advance(3.0)
	_check(casting.construction.figure_remaining == clock and hits.size() == count, "pause freezes clocks and effects in dense mobile field")
	paused = false
	arena.training_boss.global_position = Vector2(1350, 950)
	casting.advance(0.2)
	_check(casting.construction.suspended and casting.construction.figure_remaining < clock and hits.size() == count, "mobile invalid geometry suspends effects but ages deadline")
	arena.training_boss.global_position = POINTS[2]
	casting.advance(0.2)
	_check(casting.construction.has_active_figure() and casting.construction.construction_id == identity and hits.size() == count, "mobile resume same identity without replaying C")
	for index: int in 40:
		casting.show_wall_reaction(Vector2(450 + index, 400), &"fire")
	_check(casting._wall_reactions.size() == 12, "hard reaction limit12 under burst pressure")
	arena.player.health.current_hp = 0
	arena._on_player_died(arena.player)
	_check(casting.construction.vertices.is_empty() and casting._wall_reactions.is_empty() and casting._shot_wall_snapshots.is_empty() and casting._shot_triangle_snapshots.is_empty() and casting.construction.grammar.pending_count() == 0, "death/result synchronously clears every construction owned runtime")
	paused = false
	arena._restart_run()
	await process_frame
	await process_frame
	arena = current_scene as RunController
	casting = arena.geometer_casting
	_check(casting.construction.vertices.is_empty() and casting._wall_reactions.is_empty() and casting.interaction_ledger._victim_ready.is_empty(), "fresh run has no orphan effects/ledger")
	await _finish()

func _production_entry() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/geometer_g7_production_entry")
	_cleanup_profile(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174207"
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Entrada Geômetra G7", &"mage")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "isolated production Mage profile saves")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(facade.open_profile()["ok"], "production Mage profile opens")
	var evolved := facade.change_evolution("g7-evolve", facade.current_profile().revision, character.character_id, &"mg_ar")
	_check(evolved["ok"], "real default catalog permits eligible Mage becoming Geometer")
	var summary := facade.progression_summary(character.character_id)
	_check(summary["job_level"] == 20 and summary["effective_skill_ranks"] == {&"geometer_trace": 1}, "new Geometer gets only free TraceR1 atjob20")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(reloaded.open_profile()["ok"] and reloaded.current_profile().character_by_id(character.character_id).evolution_id == &"mg_ar", "production Geometer reload preserves evolution without fixture overrides")
	_check(reloaded.update_preset("g7-equip-entry", reloaded.current_profile().revision, character.character_id, 0, [&"geometer_trace", null, null, null, null], [null, null], character.equipped)["ok"], "free Trace entry legally equips without purchasing a rank")
	var started := reloaded.start_run("g7-start", reloaded.current_profile().revision)
	_check(started["ok"] and started["run_state"].build_snapshot.active_slots[0] == &"geometer_trace", "new production Geometer starts run with free entry skill")
	var ordinary_enemy := EnemyActor.new()
	_check(not ordinary_enemy.compact_control_visuals, "ordinary actors retain prior presentation default")
	ordinary_enemy.free()
	_cleanup_profile(directory)

func _cleanup_profile(directory: String) -> void:
	assert(directory == ProjectSettings.globalize_path("res://.godot/verification/geometer_g7_production_entry"))
	# Only this named, flat, disposable fixture directory; never user profile paths.
	if DirAccess.dir_exists_absolute(directory):
		for file: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)

func _finish() -> void:
	paused = false
	arena.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
