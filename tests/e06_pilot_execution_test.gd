extends SceneTree
## Real launches through the production scene. No fabricated primary requests.
const Pilot = preload("res://tools/content/pilot_bundle.gd")
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var text: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/pilot_texts.json"))
	if not text is Dictionary: push_error("editorial missing"); quit(1); return
	var compiled := ContentAuthoring.compile_bundle(Pilot.entries(), text)
	if not compiled["ok"]: push_error(str(compiled)); quit(1); return
	var catalog: BuildEffectCatalog = compiled["catalog"]
	for identity: String in Pilot.EXCLUSIVE_PROCS:
		for branch: int in 2:
			var baseline: Dictionary = await _case(identity, branch, false, false, catalog)
			var selected: Dictionary = await _case(identity, branch, true, false, catalog)
			_check(baseline["launched"] and selected["launched"], "real launch with and without selected recipe")
			_check(baseline["selected_emissions"] == 0 and selected["selected_emissions"] == 1, "actual skill launches exact selected proc once %s/%d" % [identity, branch])
			_check(is_equal_approx(float(selected["damage"]) - float(baseline["damage"]), 6.0), "same real action gains exactly first stack after defenses %s/%d" % [identity, branch])
			if identity == "defender" and branch == 0:
				_check(selected["weapon_emissions"] == 1, "real Contraforte carries weapon use and fires owned blade proc")
			observations.append({"identity": identity, "branch": "A" if branch == 0 else "B", "skill_id": Pilot.EXCLUSIVE_PROCS[identity][branch], "baseline": baseline, "selected": selected, "real_launch": true, "tactical_validated": false})
			if identity == "sentinel":
				var removed: Dictionary = await _case(identity, branch, true, true, catalog)
				_check(removed["selected_emissions"] == 1 and is_equal_approx(float(removed["damage"]), float(selected["damage"])), "real in-flight projectile retains selected recipe after removal")
	var path := "res://content/authoring/pilot_execution.json"
	if failures == 0:
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "execution report writable")
		if file != null:
			file.store_string(JSON.stringify({"mechanical_digest": compiled["mechanical_digest"], "scope": "real_launch_proof_only", "production_published": false, "tactical_validated": false, "observations": observations}, "\t", true) + "\n")
			file.close()
	print("E06 pilot real execution: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _scene(identity: String, branch: int, enabled: bool, catalog: BuildEffectCatalog) -> RunController:
	var comparison: Dictionary = Pilot.comparison(identity, branch, catalog)
	if not comparison["ok"]: push_error(str(comparison)); return null
	var state := RunState.from_build("pilot-real-launch", comparison["snapshot"])
	state.augment_stacks.assign(comparison["run_effects"]["augment_stacks"])
	if not enabled: state.augment_stacks.erase(Pilot.exclusive_id(identity, branch))
	state.card_instances = comparison["run_effects"]["card_instances"].duplicate()
	state.card_sockets = comparison["run_effects"]["card_sockets"].duplicate(true)
	_check(state.set_effect_catalog(catalog)["ok"], "real comparison catalog injects")
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena.training_boss.position = Vector2(1400, 850)
	arena._training_add_elapsed = -1000
	arena.enemies.clear()
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 20)
	arena.player.position = Vector2(400, 350)
	arena.player.sentinel_combat_active = true
	arena.player.sentinel_state.gain(100)
	arena.rng.seed = 349
	_check(arena.persistent_facade == null, "fixture has no persistence facade")
	return arena
func _case(identity: String, branch: int, enabled: bool, remove_in_flight: bool, catalog: BuildEffectCatalog) -> Dictionary:
	var arena := _scene(identity, branch, enabled, catalog)
	if arena == null: return {"launched": false, "selected_emissions": 0, "weapon_emissions": 0, "damage": 0}
	var player := arena.player
	var victim := CombatActor.new()
	victim.setup("Alvo de prova", Color.WHITE, StatCalculator.calculate({}))
	victim.position = player.position + Vector2(60, 0)
	victim.health.max_hp = 5000
	victim.health.current_hp = 5000
	victim.health.physical_defense = 0
	victim.health.magic_defense = 0
	victim.health.flee_rating = 0
	victim.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	arena.add_child(victim)
	victim.set_process(false)
	arena.enemies.append(victim)
	var emissions: Array[DamageRequest] = []
	var skill := StringName(Pilot.EXCLUSIVE_PROCS[identity][branch])
	var family := StringName(String(Pilot.exclusive_id(identity, branch)) + "_effect")
	player.status_damage_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: emissions.append(request.copy()))
	_check(player.weapon_ids_for_skill(&"teleport").is_empty() and player.weapon_ids_for_skill(&"fire_spear").is_empty(), "item spell adapters do not claim equipped weapon")
	var sp_before := player.current_sp
	var launched := false
	match skill:
		&"defender_counterstroke": launched = player.use_defender_counterstroke(Vector2.RIGHT, [victim])
		&"defender_line_lock": launched = player.use_defender_line_lock(Vector2.RIGHT, [victim])
		&"berserker_rupture": launched = player.use_berserker_rupture(victim)
		&"berserker_execution": launched = player.use_berserker_execution(victim)
		&"elementalist_flame_burst": launched = player.use_elementalist_flame_burst(victim.position)
		&"elementalist_glacial_ring": launched = player.use_elementalist_glacial_ring()
		&"sentinel_headshot": launched = player.use_sentinel_reset(skill, victim.position, victim)
		&"sentinel_net_shot": launched = player.use_sentinel_net(victim.position)
	_check(launched and player.current_sp < sp_before and player.skill_cooldown(skill) > 0, "real action pays SP and shared cooldown %s" % skill)
	if identity == "sentinel":
		var projectiles := get_nodes_in_group("player_projectiles")
		_check(projectiles.size() == 1 and projectiles[0] is PlayerProjectile, "real production projectile spawned")
		if remove_in_flight:
			player.run_state.augment_stacks.erase(Pilot.exclusive_id(identity, branch))
			player.run_state.runtime_revision += 1
			player.apply_run_modifiers(player.run_state)
			_check(not player.run_state.augment_stacks.has(Pilot.exclusive_id(identity, branch)), "selected recipe removed before collision")
		for projectile: Node in projectiles:
			projectile.set_process(false)
			projectile._process(1.0)
	var selected_emissions := 0
	var weapon_emissions := 0
	for request: DamageRequest in emissions:
		if request.skill_id == family:
			selected_emissions += 1
			_check(request.is_secondary and not request.can_crit and request.context != null and request.context.secondary, "real proc preserves secondary causal contract")
			_check(is_equal_approx(request.physical_damage + request.magic_damage, 6), "real proc carries first curve value")
		if request.skill_id == &"pilot_blade_hit": weapon_emissions += 1
	var observation := {"launched": launched, "selected_emissions": selected_emissions, "weapon_emissions": weapon_emissions, "damage": 5000 - victim.health.current_hp, "sp_paid": sp_before - player.current_sp, "cooldown": player.skill_cooldown(skill), "removed_before_impact": remove_in_flight}
	arena.queue_free()
	await process_frame
	return observation
