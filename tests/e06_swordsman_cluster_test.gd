extends SceneTree
## Approved cluster gates, historical refunds and four new skill behaviors.
const TX = preload("res://tests/e06_tx_fixture.gd")
const H = preload("res://tests/fixtures/e07/f2/confirmed_history.gd")
class FailingMigrationStore:
	extends ProfileStore
	var failure_stage: StringName = &""
	func _should_fail(stage: StringName) -> bool: return stage == failure_stage

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174336"
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_gates_and_builds()
	_migration()
	_item_previews()
	await _skills()
	print("E06 swordsman clusters: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _character(evolution: StringName) -> CharacterState:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Cachos", &"swordsman")
	character.evolution_id = evolution
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	return character

func _buy(character: CharacterState, catalog: ProfileCatalog, id: StringName, rank: int) -> void:
	while int(catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks, character.granted_skill_ranks).get(id, 0)) < rank:
		var result := CharacterProgression.learn_skill(character, catalog, id)
		_check(result["ok"], "legal build buys %s" % id)
		if not result["ok"]: break

func _gates_and_builds() -> void:
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "cluster catalog is valid and acyclic")
	var requirements := {
		&"defender_anchor": {&"shield_wall": 2}, &"defender_line_lock": {&"defender_anchor": 2}, &"defender_guard_return": {&"defender_counterstroke": 2}, &"defender_wall_advance": {&"dash": 2}, &"defender_reprisal_wave": {&"defender_counterstroke": 3}, &"defender_riposte": {&"defender_guard_return": 2},
		&"berserker_obstinacy": {&"fury": 3}, &"berserker_wound_leap": {&"dash": 2}, &"berserker_execution": {&"berserker_rupture": 3}, &"berserker_pursuit": {&"berserker_rupture": 2}, &"berserker_breath_steal": {&"berserker_pursuit": 2}, &"berserker_pursuit_cut": {&"berserker_wound_leap": 2}, &"berserker_deep_bleeding": {&"berserker_blood_rift": 3},
	}
	for id: StringName in requirements:
		var metadata := catalog.skill_metadata(id)
		var maximum := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		for rank: int in range(1, maximum + 1):
			_check(metadata["rank_requirements"][rank]["skill_ranks"] == requirements[id], "%s prerequisites persist at rank%d" % [id,rank])
		var empty: Dictionary[StringName,int] = {}
		_check(not catalog.check_rank_requirements(id, 1, 40, empty)["ok"], "%s high Job cannot replace investment" % id)
		var invested: Dictionary[StringName,int] = {}
		for prerequisite: StringName in requirements[id]: invested[prerequisite] = requirements[id][prerequisite]
		_check(catalog.check_rank_requirements(id, 1, 40, invested)["ok"], "%s minimal antecedents suffice without maxing" % id)
		_check(not catalog.check_rank_requirements(id, 1, 1, invested)["ok"], "%s investment does not replace Job" % id)
	var defender := _character(&"defender")
	_buy(defender,catalog,&"shield_wall",3)
	_buy(defender,catalog,&"perseverance",3)
	_buy(defender,catalog,&"swordsman_resistance",3)
	_buy(defender,catalog,&"defender_counterstroke",3)
	_buy(defender,catalog,&"defender_anchor",4)
	_buy(defender,catalog,&"defender_line_lock",3)
	_buy(defender,catalog,&"defender_guard_return",2)
	_buy(defender,catalog,&"defender_riposte",3)
	var summary := CharacterProgression.summary(defender,catalog)
	_check(summary["base_skill_points_available"] == 10 and summary["evolution_skill_points_available"] == 6, "approved Corridor build spends9 base14 evolution")
	var berserker := _character(&"berserker")
	_buy(berserker,catalog,&"dash",2)
	_buy(berserker,catalog,&"vigor",3)
	_buy(berserker,catalog,&"slash",2)
	_buy(berserker,catalog,&"brutal_strike",2)
	_buy(berserker,catalog,&"concentrated_rage",3)
	_buy(berserker,catalog,&"berserker_rupture",2)
	_buy(berserker,catalog,&"berserker_wound_leap",3)
	_buy(berserker,catalog,&"berserker_pursuit_cut",3)
	_buy(berserker,catalog,&"berserker_blood_rift",4)
	_buy(berserker,catalog,&"berserker_deep_bleeding",3)
	summary = CharacterProgression.summary(berserker,catalog)
	_check(summary["base_skill_points_available"] == 7 and summary["evolution_skill_points_available"] == 6, "Pursue/Bleed plus new base ancestors spends12 base14 evolution")
	_check(catalog.effective_skill_ranks(&"swordsman", &"defender", {}, {}).get(&"defender_counterstroke") == 1 and catalog.effective_skill_ranks(&"swordsman", &"berserker", {}, {}).get(&"berserker_rupture") == 1, "free roots preserved")

func _migration() -> void:
	var catalog := ProfileCatalog.pilot()
	var old := catalog.pre_swordsman_cluster_catalog()
	var character := _character(&"defender")
	_buy(character,old,&"defender_anchor",2)
	_buy(character,old,&"defender_line_lock",2)
	_buy(character,old,&"defender_guard_return",2)
	character.action_slots = ActionBarLayout.assign(ActionBarLayout.empty(),&"defender_anchor",0)
	character.action_slots = ActionBarLayout.assign(character.action_slots,&"defender_line_lock",23)
	character.action_slots[12] = ActionBarLayout.entry(&"teleport",1)
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	var encoded := ProfileCodec.encode(profile,old)
	_check(encoded["ok"], "historical legal envelope validates before new gates")
	if not encoded["ok"]: return
	# Historical fixture drops the schema-8 ownership envelope; schema 1-7 needs preview + confirmed digest: E07 F2 3b15ae8a (20/10).
	var raw: Dictionary = H.legacy_envelope(encoded["data"])
	raw["schema_version"] = 5
	for fixture_character: Dictionary in raw["characters"]: fixture_character.erase("admin_skills_unlocked")
	raw["catalog_version"] = 12
	raw["characters"][0]["action_slots"][12] = "teleport"
	_durable_migration(raw, catalog)
	_check(ProfileCodec.decode(JSON.stringify(raw),catalog).get("error_code") == &"migration_required", "known schema5/catalog12 opens protected until confirmed")
	var migrated := H.decode_confirmed(JSON.stringify(raw),catalog)
	_check(migrated["ok"] and migrated.get("migrated",false), "known schema5/catalog12 migrates explicitly")
	if not migrated["ok"]: return
	var restored: CharacterState = migrated["profile"].characters[0]
	_check(restored.purchased_skill_ranks.is_empty(), "fixed point refunds Marco then dependent Trava and Resguardo")
	_check(restored.base_xp_total == character.base_xp_total and restored.job_xp_total == character.job_xp_total and restored.evolution_id == character.evolution_id and restored.granted_skill_ranks == character.granted_skill_ranks, "refund preserves XP identity and grants")
	_check(restored.action_slots[0] == &"defender_anchor" and restored.action_slots[23] == &"defender_line_lock" and restored.action_slots[12] == &"teleport", "refunded skills retain disabled shortcuts alongside the item reference")
	_check(migrated["migration_removals"][0]["evolution_refund"] == 6 and CharacterProgression.summary(restored,catalog)["evolution_skill_points_available"] == 20, "six invested points return to original evolution wallet")
	var saved := ProfileCodec.encode(migrated["profile"],catalog)
	# Pin 7→8: E07 F2 3b15ae8a (20/10) made the current envelope schema 8.
	_check(saved["ok"] and saved["data"]["schema_version"] == ProfileState.SCHEMA_VERSION and ProfileState.SCHEMA_VERSION == 8 and saved["data"]["catalog_version"] == 14, "migration report encodes with schema8/catalog14")
	if saved["ok"]:
		var reopened := ProfileCodec.decode(saved["text"],catalog)
		_check(reopened["ok"] and not reopened.get("migrated",false), "new envelope roundtrip never repeats refund")
		if reopened["ok"]: _check(reopened["profile"].extension_fields.has("swordsman_skill_tree_migration"), "removal receipt remains visible after encoded reload")
	raw["characters"][0]["purchased_skill_ranks"]["defender_anchor"] = 50
	var invalid_investment := H.decode_confirmed(JSON.stringify(raw),catalog)
	_check(not invalid_investment["ok"] and invalid_investment.get("error_code") != &"migration_required", "invalid legacy investment rejected before refund rather than repaired")

func _durable_migration(raw: Dictionary, catalog: ProfileCatalog) -> void:
	for schema: int in [5, 6]:
		var historical := raw.duplicate(true)
		historical["schema_version"] = schema
		var text := JSON.stringify(historical)
		var directory := ProjectSettings.globalize_path("res://.godot/verification/cluster_durable_%d_%d" % [schema, Time.get_ticks_usec()])
		DirAccess.make_dir_recursive_absolute(directory)
		_write_fixture(directory.path_join(ProfileStore.PRIMARY_FILE), text)
		var store := ProfileStore.new(directory, catalog)
		var protected := store.load_profile()
		_check(not protected.get("ok", false) and protected.get("error_code") == &"migration_required" and protected.get("read_only", false) and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == text, "schema%d durable fixture opens protected without rewrite" % schema)
		var decoded := H.decode_confirmed(text, catalog)
		_check(decoded["ok"], "historical durable fixture decodes")
		if not decoded["ok"]: continue
		var forged: ProfileState = decoded["profile"].copy_state()
		forged.settings["forged"] = true
		_check(not store._preflight_commit(forged, true)["ok"] and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == text, "migration authority rejects changed same-revision source without writing")
		var preview := store.preview_migration()
		_check(preview.get("ok", false) and preview.get("complete", false) and not store.apply_migration(preview["plan"], preview["plan_digest"].reverse(), "forged-digest")["ok"] and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == text, "migration authority rejects an unconfirmed plan digest without writing")
		var loaded := H.load_confirmed(store)
		_check(loaded.get("ok", false) and loaded.get("migrated", false) and loaded.get("warning", &"") == &"profile_migrated", "schema%d migration commits through real store" % schema)
		if not loaded.get("ok", false): continue
		var current: ProfileState = loaded["profile"]
		_check(current.revision == int(raw["revision"]) + 1 and current.characters.size() == 1 and current.characters[0].purchased_skill_ranks.is_empty(), "durable migration advances exactly once and refunds incompatible ranks")
		_check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.BACKUP_FILE)) == text and not FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "durable migration preserves exact backup and clears confirmed pending")
		_check(current.extension_fields.has("swordsman_skill_tree_migration"), "durable refund receipt survives commit")
		var again := store.load_profile()
		_check(again["ok"] and not again.get("migrated", false) and again["profile"].revision == current.revision, "second durable load is idempotent")
		var facade := ProfileFacade.new(store)
		_check(facade.open_profile()["ok"], "facade opens migrated roster")
		var created := facade.create_character("post-cluster-migration", current.revision, "Após migração", &"mage")
		_check(created["ok"] and facade.current_profile().characters.size() == 2 and facade.current_profile().characters[0].character_id == current.characters[0].character_id, "first real mutation creates a character while preserving migrated roster")
		for stage: StringName in [&"write_pending", &"validate_pending", &"backup", &"replace", &"existing_pending"]:
			var failure_directory := directory.path_join(String(stage))
			DirAccess.make_dir_recursive_absolute(failure_directory)
			_write_fixture(failure_directory.path_join(ProfileStore.PRIMARY_FILE), text)
			var failing := FailingMigrationStore.new(failure_directory, catalog)
			failing.failure_stage = stage
			if stage == &"existing_pending": _write_fixture(failure_directory.path_join(ProfileStore.PENDING_FILE), "unconfirmed evidence")
			var failed := H.load_confirmed(failing)
			_check(not failed["ok"] and FileAccess.get_file_as_string(failure_directory.path_join(ProfileStore.PRIMARY_FILE)) == text, "schema%d failed %s preserves original primary" % [schema, stage])
			if stage == &"existing_pending": _check(FileAccess.get_file_as_string(failure_directory.path_join(ProfileStore.PENDING_FILE)) == "unconfirmed evidence", "existing pending evidence remains byte-identical")

func _write_fixture(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _item_previews() -> void:
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID,1),"Itens",&"swordsman")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters.append(character)
	profile.next_character_counter = 2
	profile.selected_character_id = character.character_id
	var instance := TX.own(profile,&"pilot_step_neck",catalog)
	character.equipped[&"neck"] = instance
	character.presets[character.selected_preset]["equipped"][&"neck"] = instance
	var directory := ProjectSettings.globalize_path("res://.godot/verification/pure_item_preview_%d" % Time.get_ticks_usec())
	var facade := ProfileFacade.new(ProfileStore.new(directory,catalog))
	facade._profile = profile
	var before := ProfileCodec.encode(profile,catalog)
	_check(before["ok"], "item fixture is a legal profile")
	var options := facade.available_build_options(character.character_id)
	_check(options["ok"] and &"teleport" in options["active_skills"] and options["effective_cast_ranks"].get(&"teleport") == 1, "lobby available options include canonical foreign item grant")
	var preview := facade.skill_allocation_preview(character.character_id,profile.revision,[])
	_check(preview["ok"], "item allocation preview composes without run or save IO")
	var found := false
	if preview["ok"]:
		for option: Dictionary in preview["skills"]:
			if option["skill_id"] != &"teleport": continue
			found = bool(option.get("item_only",false)) and option["rank"] == 0 and option["item_rank"] == 1 and option["next_rank"] == null and option["metadata"]["wallet"] == &"items"
	_check(found, "foreign item option cannot masquerade as purchased skill/wallet")
	_check(ProfileCodec.encode(profile,catalog)["text"] == before["text"] and not FileAccess.file_exists(directory.path_join(ProfileStore.PRIMARY_FILE)), "pure previews leave profile bytes and save directory untouched")
	_check(not CharacterProgression.learn_skill(character,catalog,&"teleport")["ok"], "foreign item cannot be purchased through permanent wallet")
	character.equipped[&"neck"] = null
	character.presets[character.selected_preset]["equipped"][&"neck"] = null
	options = facade.available_build_options(character.character_id)
	_check(options["ok"] and &"teleport" not in options["active_skills"], "lost item source removes effective availability")

func _player(evolution: StringName, navigation: ArenaNavigation) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = evolution
	snapshot.job_level = 40
	var catalog := ProfileCatalog.pilot()
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"swordsman", evolution)
	for id: StringName in snapshot.library_skill_ids:
		var metadata := catalog.skill_metadata(id)
		snapshot.skill_ranks[id] = int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("cluster-runtime",snapshot))
	root.add_child(player)
	player.position = Vector2(400,400)
	player.set_process(false)
	return player

func _skills() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0,0,1200,800),[],20.0)
	var defender := _player(&"defender",navigation)
	var enemy := EnemyActor.new()
	enemy.setup("Alvo",Color.WHITE,StatCalculator.calculate({&"vit":10}),18.0)
	root.add_child(enemy)
	enemy.position = Vector2(480,400)
	enemy.health.max_hp = 10000
	enemy.health.current_hp = 10000
	enemy.set_process(false)
	var enemies: Array[CombatActor] = [enemy]
	var requests: Array[DamageRequest] = []
	defender.attack_requested.connect(func(request: DamageRequest,_target: CombatActor) -> void: requests.append(request))
	var previous := defender.push_cast_rank(&"defender_riposte",1)
	var sp := defender.current_sp
	_check(not defender.use_defender_riposte(Vector2.RIGHT,enemies) and defender.current_sp == sp, "Rebater missing token has no cost")
	defender.defender_token_remaining = 3.0
	_check(defender.use_defender_riposte(Vector2.RIGHT,enemies) and not defender.has_defender_token() and defender.current_sp == sp - 18.0, "Rebater consumes shared token and rank1 cost once")
	defender.restore_cast_rank(previous)
	_check(requests.size() == 1 and is_equal_approx(requests[0].physical_damage,defender.stat_breakdown.value(&"melee_attack")*1.3), "Rebater rank1 emits focused captured power")
	var controller := RunController.new()
	controller.player = defender
	controller.navigation = navigation
	controller.enemies = enemies
	var riposte_result := enemy.health.apply(requests[0],0.0,1.0)
	controller._on_enemy_damage_resolved(riposte_result)
	_check(enemy.weaken_remaining > 0.0, "Rebater participates in Vigília direct-melee ledger and effect")
	controller.free()
	defender.defender_token_remaining = 3.0
	defender.mage_cooldowns.clear()
	sp = defender.current_sp
	_check(not defender.use_defender_riposte(Vector2.LEFT,enemies) and defender.has_defender_token() and defender.current_sp == sp, "Rebater invalid cone preserves token/SP")
	previous = defender.push_cast_rank(&"defender_retreat_guard",1)
	var start := defender.global_position
	var hp := defender.health.current_hp
	_check(defender.use_defender_retreat_guard(Vector2.RIGHT) and defender.global_position == start - Vector2(60,0), "Retirada rank1 moves60 backward")
	defender.restore_cast_rank(previous)
	_check(defender.defender_retreat_guard_remaining == .8 and defender.defender_retreat_guard_reduction == .15 and defender.defender_retreat_guard_facing == Vector2.RIGHT and defender.health.current_hp == hp, "Retirada freezes front15percent/.8seconds without heal")
	var incoming := DamageRequest.new()
	incoming.source_id = enemy.get_instance_id()
	incoming.target_id = defender.get_instance_id()
	incoming.physical_damage = 100.0
	incoming.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var rng := RandomNumberGenerator.new()
	var guarded := defender.apply_damage(incoming,rng)
	defender.defender_retreat_guard_remaining = 0
	var normal := defender.apply_damage(incoming,rng)
	_check(guarded["damage"] < normal["damage"], "Retirada reduces actual frontal damage")
	defender.clear_defender_state()
	_check(defender.defender_retreat_guard_remaining == 0, "cleanup removes Retirada guard")
	var berserker := _player(&"berserker",navigation)
	requests.clear()
	berserker.attack_requested.connect(func(request: DamageRequest,_target: CombatActor) -> void: requests.append(request))
	previous = berserker.push_cast_rank(&"berserker_pursuit_cut",1)
	_check(berserker.use_berserker_pursuit_cut(enemy), "Talho rank1 hits healthy target")
	berserker.restore_cast_rank(previous)
	_check(is_equal_approx(requests[-1].physical_damage,berserker.stat_breakdown.value(&"melee_attack")*.9), "healthy Talho uses.9 melee")
	var result := {"source_id":berserker.get_instance_id(),"target_id":enemy.get_instance_id(),"skill_id":&"berserker_pursuit_cut","actual_damage":10.0,"can_trigger_effects":true}
	berserker.record_berserker_damage(result)
	_check(berserker.berserker_wound_stacks(enemy.get_instance_id()) == 0, "Talho cannot create wound alone")
	berserker.berserker_wounds[enemy.get_instance_id()] = {"stacks":1,"remaining":8.0}
	berserker.mage_cooldowns.clear()
	previous = berserker.push_cast_rank(&"berserker_pursuit_cut",1)
	_check(berserker.use_berserker_pursuit_cut(enemy), "Talho hits existing wound")
	berserker.restore_cast_rank(previous)
	_check(is_equal_approx(requests[-1].physical_damage,berserker.stat_breakdown.value(&"melee_attack")*1.2), "wounded Talho adds exactly.3 to selected power")
	controller = RunController.new()
	controller.player = berserker
	controller.navigation = navigation
	controller.enemies = enemies
	var wounded_result := enemy.health.apply(requests[-1],0.0,1.0)
	controller._on_enemy_damage_resolved(wounded_result)
	_check(berserker.berserker_wound_stacks(enemy.get_instance_id()) == 2, "Talho adds only the common direct-melee charge to existing wound")
	var directs: Array[DamageRequest] = []
	var bleeds: Array[DamageRequest] = []
	berserker.berserker_rift_hit_requested.connect(func(direct: DamageRequest,_target: CombatActor,bleed: DamageRequest) -> void: directs.append(direct); bleeds.append(bleed))
	berserker.current_sp = berserker.max_sp
	previous = berserker.push_cast_rank(&"berserker_blood_rift",1)
	_check(berserker.use_berserker_blood_rift(Vector2.RIGHT,enemies), "Fenda emits selected direct/secondary requests")
	berserker.restore_cast_rank(previous)
	_check(bleeds.size() == 1 and bleeds[0].effect_snapshot["bleed_duration"] == 5.5 and bleeds[0].is_secondary and not bleeds[0].can_crit, "HemorragiaR3 extends only captured Fenda duration to5.5seconds")
	_check(is_equal_approx(bleeds[0].physical_damage,berserker.stat_breakdown.value(&"melee_attack")*.1), "Hemorragia preserves rank1 tick power/DPS")
	controller._on_berserker_rift_hit_requested(directs[0],enemy,bleeds[0])
	_check(enemy.bleed_streams.size() == 1 and enemy.bleed_streams.values()[0]["remaining"] == 5.5 and enemy.bleed_streams.values()[0]["tick_remaining"] == 1.0, "real bleed application preserves1second cadence and receives5.5second duration")
	controller.free()
	berserker.run_state.skill_levels[&"berserker_deep_bleeding"] = 1
	_check(bleeds[0].effect_snapshot["bleed_duration"] == 5.5, "emitted bleed duration does not recapture passive changes")
	defender.queue_free()
	berserker.queue_free()
	enemy.queue_free()
	await process_frame

func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
