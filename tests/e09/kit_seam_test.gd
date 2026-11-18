extends SceneTree
## E09 C1.13 — the kit seam. A fixture kit (scripts/classes/fixture/fixture_kit.gd),
## outside the production registry, is installed over sp_ac/sp_la and exercises
## every hook; production modules stay empty and unavailable.
const FixtureKit = preload("res://scripts/classes/fixture/fixture_kit.gd")
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
## A14: body folders that never have art. The C1.8 fallback is proven on them, so the
## checks hold with or without the production art of the four hybrids (T7).
const FIXTURE_BODY_SP_AC := &"e09_fixture_body_sp_ac"
const FIXTURE_BODY_MG_AC := &"e09_fixture_body_mg_ac"
const FIXTURE_BODY_SP_LA := &"e09_fixture_body_sp_la"

## T9 (A9): production kits may be empty skeletons or ready; the lists below follow the
## kits' ready_for_play and the skeleton behaviour is proven with fixture skeletons.
const KIT_METADATA := {
	&"sp_ac": ["Paladino", &"swordsman", &"2-3", &"acolyte"],
	&"mg_ac": ["Taumaturgo", &"mage", &"2-3", &"acolyte"],
	&"sp_la": ["Duelista", &"swordsman", &"2-3", &"rogue"],
	&"mg_la": ["Lâmina Arcana", &"mage", &"2-3", &"rogue"],
}
const E00_DESTINATIONS := {
	&"swordsman": [&"defender", &"berserker", &"sp_mg", &"sp_ar"],
	&"mage": [&"elementalist", &"spiritualist", &"mg_sp", &"mg_ar"],
}

var checks := 0
var failures := 0
var requests: Array[DamageRequest] = []

## An empty production-like kit: valid, never ready, no skills (the T1 skeleton).
class SkeletonKit extends ClassKit:
	var skeleton_id: StringName = &""
	func _init(id: StringName = &"") -> void:
		skeleton_id = id
	func kit_id() -> StringName:
		return skeleton_id

class ForeignSkillKit extends "res://scripts/classes/fixture/fixture_kit.gd":
	func skill_definitions() -> Array[SkillDefinition]:
		var result := super.skill_definitions()
		var foreign: SkillDefinition = result[0].duplicate(true)
		foreign.id = &"slash"
		result.append(foreign)
		return result

class WrongLevelKit extends "res://scripts/classes/fixture/fixture_kit.gd":
	func learning_entries() -> Array[Dictionary]:
		var result := super.learning_entries()
		result[2]["job_level"] = 21
		return result

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_production_registry()
	_check_skeleton_and_readiness_states()
	_check_identities_and_eligibility()
	_check_fixture_catalogs()
	_check_forced_overrides()
	_check_player_hooks()
	_check_marks_and_facing()
	_check_threat_primitives()
	_check_snapshot_rules()
	_check_presentation()
	ClassKitRegistry.clear_fixtures()
	print("E09 kit seam: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Registry and production catalogs ----------------------------------------------

func _check_production_registry() -> void:
	ClassKitRegistry.clear_fixtures()
	# E10a C1.11: the registry also lists the pure kits priest and cultist; the E09
	# checks below cover exactly the four hybrids of section 1.
	_check(ClassKitRegistry.ids() == [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la", &"priest", &"cultist"] and ClassKitRegistry.hybrid_ids() == [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"], "registry lists the four hybrids of section 1, then the two E10a pure kits")
	for id: StringName in ClassKitRegistry.hybrid_ids():
		var kit := ClassKitRegistry.module(id)
		_check(kit != null and kit.kit_id() == id and String(ClassKitRegistry.MODULES[id]) == "res://scripts/classes/%s/%s_kit.gd" % [id, id], "%s module loads from its own folder" % id)
		var declared := kit != null and kit.ready_for_play()
		_check(ClassKitRegistry.validate(id)["ok"] and ClassKitRegistry.ready_for_play(id) == declared, "%s validates and its availability follows its declared ready_for_play (A9)" % id)
		_check(ClassKitRegistry.skill_ids(id).size() == 7 and String(ClassKitRegistry.skill_ids(id)[0]).begins_with(ClassKitRegistry.IDENTITIES[id]["prefix"]), "%s has seven stable prefixed skill IDs" % id)
		var onboarding := ClassKitRegistry.onboarding_script(id)
		_check(onboarding != null and onboarding.get_instance_base_type() == "Control", "%s has its onboarding script (T9, C1.12)" % id)
	_check(ClassKitRegistry.validate(&"defender")["error_code"] == &"kit_unknown_identity", "existing identities are not kits")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "production catalog stays valid with the seam")
	_check_destinations(catalog, "production")

## A9: the lists hold the E00 destinations plus exactly the hybrids whose kit is ready;
## unready kits are absent (C1.3, A7) and every ready hybrid's metadata is exact.
func _check_destinations(catalog: ProfileCatalog, state: String) -> void:
	for origin: StringName in E00_DESTINATIONS:
		var listed: Array = catalog.evolution_definitions_for_origin(origin).map(func(d: EvolutionDefinition) -> StringName: return d.id)
		_check(listed == _expected_destinations(origin), "%s: %s destinations are the E00 four plus the ready kits only" % [state, origin])
	for id: StringName in ClassKitRegistry.hybrid_ids():
		var ready := ClassKitRegistry.ready_for_play(id)
		var values: Array = KIT_METADATA[id]
		# Production kits carry the pt-BR names of the sheets; fixture kits carry their own.
		var expected_name: String = values[0] if (state == "production" or not ready) else ClassKitRegistry.display_name(id)
		var definition := catalog.evolution_definition(id)
		_check((definition != null) == ready, "%s: %s is listed only when ready" % [state, id])
		if ready and definition != null:
			_check(definition.display_name == expected_name and definition.origin_class_id == values[1] and definition.branch_kind == values[2] and definition.affinity_class_id == values[3] and definition.content_ready, "%s: %s metadata is exact (name, origin, affinity, 2-3)" % [state, id])
		_check((ClassCatalog.skill_definition(ClassKitRegistry.skill_ids(id)[0]) != null) == ready, "%s: %s publishes skills only when ready" % [state, id])
		_check(SkillPresentation.job_name(id) == expected_name, "%s: %s job name is the kit identity name" % [state, id])

func _expected_destinations(origin: StringName) -> Array:
	var result: Array = E00_DESTINATIONS[origin].duplicate()
	for id: StringName in ClassKitRegistry.hybrid_ids():
		if ClassKitRegistry.origin(id) == origin and ClassKitRegistry.ready_for_play(id):
			result.append(id)
	return result

## A17: the skeleton behaviour and the zero/some/all ready states, on fixtures only, so the
## test holds whatever production kits are ready.
func _check_skeleton_and_readiness_states() -> void:
	ClassKitRegistry.clear_fixtures()
	for id: StringName in ClassKitRegistry.hybrid_ids():
		_check(ClassKitRegistry.install_fixture(id, SkeletonKit.new(id)), "skeleton fixture installs over %s" % id)
	for id: StringName in ClassKitRegistry.hybrid_ids():
		var kit := ClassKitRegistry.module(id)
		_check(kit != null and not kit.ready_for_play() and kit.skill_definitions().is_empty(), "%s skeleton is empty and not ready" % id)
		_check(ClassKitRegistry.validate(id)["ok"] and not ClassKitRegistry.ready_for_play(id), "%s skeleton validates and stays unavailable" % id)
	var none := ProfileCatalog.pilot()
	_check(none.is_valid(), "zero ready kits: catalog valid")
	_check_destinations(none, "zero ready")
	_check(none.evolution_definitions().size() == 12, "zero ready: only the twelve E00 identities")
	# Some ready: one kit of each origin, the other two stay skeletons.
	_check(ClassKitRegistry.install_fixture(&"sp_ac", FixtureKit.new(&"sp_ac")) and ClassKitRegistry.install_fixture(&"mg_la", FixtureKit.new(&"mg_la")), "ready fixtures install over sp_ac and mg_la")
	var some := ProfileCatalog.pilot()
	_check(some.is_valid(), "some ready kits: catalog valid")
	_check_destinations(some, "some ready")
	_check(some.evolution_definition(&"mg_ac") == null and some.evolution_definition(&"sp_la") == null and some.evolution_definitions().size() == 14, "some ready: the skeletons stay absent")
	# All four ready.
	_check(ClassKitRegistry.install_fixture(&"mg_ac", FixtureKit.new(&"mg_ac")) and ClassKitRegistry.install_fixture(&"sp_la", FixtureKit.new(&"sp_la")), "ready fixtures install over mg_ac and sp_la")
	var all := ProfileCatalog.pilot()
	_check(all.is_valid(), "four ready kits: catalog valid")
	_check_destinations(all, "four ready")
	_check(all.evolution_definitions().size() == 16, "four ready: the twelve plus the four hybrids")
	ClassKitRegistry.clear_fixtures()

func _check_identities_and_eligibility() -> void:
	_check(IdentityIds.hybrid_evolution_ids().size() == 6 and IdentityIds.kit_evolution_ids() == [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la", &"priest", &"cultist"], "stable hybrid list kept; kit IDs (E09 hybrids, then E10a pure kits) listed apart")
	for id: StringName in IdentityIds.kit_evolution_ids():
		_check(IdentityIds.is_evolution(id) and IdentityIds.evolution_origin(id) == ClassKitRegistry.origin(id) and IdentityIds.evolution_belongs_to(id, ClassKitRegistry.origin(id)), "%s is an evolution of its origin" % id)
		_check(IdentityIds.kit_affinity(id) == ClassKitRegistry.IDENTITIES[id]["affinity"], "%s affinity label matches section 1" % id)
		_check(EquipmentEligibilityRules.validate({"allowed_identities": [id]})["ok"], "%s is a valid equipment identity" % id)
	# E10a C1.11: acolyte became a registered base; rogue stays the only reserved one.
	_check(IdentityIds.reserved_base_ids() == [&"rogue"] and IdentityIds.is_reserved_base(&"rogue"), "rogue is the reserved base")
	_check(IdentityIds.is_registered_base(&"acolyte") and not IdentityIds.is_base_class(&"rogue") and IdentityIds.base_class_ids().size() == 3, "the reserved base is not a playable base; the E00 list keeps three")
	_check(EquipmentEligibilityRules.CURRENT_IDENTITIES.size() == 10 and EquipmentEligibilityRules.eligible_identities().size() == 17, "class-set identity list unchanged; eligibility accepts seventeen (E10a family)")
	_check(not EquipmentEligibilityRules.validate({"allowed_identities": [&"rogue"]})["ok"], "a reserved base is not an equipment identity")

# --- Fixture data aggregation ------------------------------------------------------

func _install_fixtures() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassKitRegistry.install_fixture(&"sp_ac", FixtureKit.new(&"sp_ac")), "fixture installs over sp_ac")
	_check(ClassKitRegistry.install_fixture(&"sp_la", FixtureKit.new(&"sp_la")), "fixture installs over sp_la")
	_check(not ClassKitRegistry.install_fixture(&"mg_ac", FixtureKit.new(&"sp_ac")), "fixture with another ID is refused")
	_check(ClassKitRegistry.install_fixture_body(&"sp_ac", FIXTURE_BODY_SP_AC) and ClassKitRegistry.install_fixture_body(&"mg_ac", FIXTURE_BODY_MG_AC) and ClassKitRegistry.install_fixture_body(&"sp_la", FIXTURE_BODY_SP_LA), "fixture body folders without art install over sp_ac, mg_ac and sp_la (A14)")
	_check(not ClassKitRegistry.install_fixture_body(&"mg_ac", &"arcane_blade") and not ClassKitRegistry.install_fixture_body(&"defender", &"e09_fixture_body_defender") and not ClassKitRegistry.install_fixture_body(&"mg_la", &""), "a fixture body colliding with an identity folder, outside the kits or empty is refused")

func _check_fixture_catalogs() -> void:
	_install_fixtures()
	_check(ClassKitRegistry.validate(&"sp_ac")["ok"] and ClassKitRegistry.ready_for_play(&"sp_ac"), "valid ready fixture is available")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "catalog with two ready kits of one origin is valid")
	var swordsman_ids: Array = catalog.evolution_definitions_for_origin(&"swordsman").map(func(d: EvolutionDefinition) -> StringName: return d.id)
	_check(swordsman_ids == [&"defender", &"berserker", &"sp_mg", &"sp_ar", &"sp_ac", &"sp_la"], "an origin can have more than two 2-3 hybrids (C1.10)")
	var paladin := catalog.evolution_definition(&"sp_ac")
	_check(paladin != null and paladin.content_ready and paladin.affinity_class_id == &"acolyte" and paladin.branch_kind == EvolutionDefinition.BRANCH_2_3 and paladin.entry_skill_id == &"paladin_oath", "kit evolution carries origin, reserved affinity and entry")
	_check(catalog.evolution_definitions_for_origin(&"mage").map(func(d: EvolutionDefinition) -> StringName: return d.id) == _expected_destinations(&"mage"), "other origin unchanged (the E00 four plus its own ready kits)")
	var library := catalog.skill_ids_for_identity(&"swordsman", &"sp_ac")
	_check(&"paladin_oath_hour" in library and &"slash" in library and &"duelist_parry" not in library, "kit library joins the origin library only")
	var entry := catalog.skill_metadata(&"paladin_oath")
	var last := catalog.skill_metadata(&"paladin_oath_hour")
	_check(int(entry["free_rank"]) == 1 and int(entry["rank_requirements"][1]["job_level"]) == 20 and int(last["rank_requirements"][1]["job_level"]) == 37 and catalog.skill_metadata(&"paladin_guard_grace")["category"] == ProfileCatalog.PASSIVE, "learning entries keep the section-1 job levels")
	_check(ClassCatalog.skill_definition(&"paladin_consecrated_impact") != null and ClassCatalog.skill_definition(&"paladin_consecrated_impact").handler_id == SkillDefinition.Handler.KIT, "ClassCatalog aggregates kit skills")
	_check(ClassCatalog.skill_definition(&"slash").handler_id == SkillDefinition.Handler.SLASH, "base skills are untouched")
	_check(not ClassCatalog.passive_modifier_source(&"paladin_guard_grace", 2).is_empty(), "kit passive stat source reaches the shared composition")
	_check(String(SkillCopy.text_for(&"paladin_oath").get("effect", "")) == "Efeito de teste." and not SkillCopy.text_for(&"paladin_oath").has("mechanics"), "SkillCopy aggregates kit texts")
	_check(SkillPresentation.mechanics_of(&"paladin_oath") == "Mecânica de teste." and SkillPresentation.mechanics_of(&"slash") == SkillPresentation.MECHANICS[&"slash"], "mechanics line from the module, base first")
	# E10a C1.8: the Paladino shows its arcane rows in the light colour (presentation only).
	_check(not FeedbackRecipeCatalog.recipe(&"paladin_oath").generic and FeedbackRecipeCatalog.recipe(&"paladin_oath").element == &"light", "FeedbackRecipeCatalog aggregates kit recipes (arcane rows of the Paladino shown as light)")
	_check(FeedbackRecipeCatalog.recipe(&"basic_attack", &"sp_ac").family == &"melee" and FeedbackRecipeCatalog.for_event({"kind": &"impact", "skill_id": &"", "payload": {"actor_variant": &"sp_ac"}}).skill_id == &"basic_attack", "kit evolution resolves its basic attack recipe")
	_check(&"paladin_oath" in FeedbackRecipeCatalog.known_ids(), "kit recipe IDs are known")
	_check(BuildEffectCatalog.is_intrinsic_family(&"paladin_fixture_family") and not BuildEffectCatalog.is_intrinsic_family(&"other_family"), "kit causal families are intrinsic")
	var proc := EffectDefinition.new()
	proc.id = &"fixture_proc"; proc.family_id = &"paladin_fixture_family"; proc.kind = EffectDefinition.Kind.PROC; proc.handler_id = EffectDefinition.Handler.HIT_DAMAGE; proc.trigger = EffectDefinition.Trigger.ON_HIT; proc.axis = &"physical_damage"; proc.unit = &"damage"; proc.limit = 10.0
	_check(BuildEffectCatalog.validate_effect(proc)["error_code"] == &"intrinsic_family_requires_adapter", "items cannot reuse a kit family as PROC")
	_check(ClassKitRegistry.install_fixture(&"mg_la", ForeignSkillKit.new(&"mg_la")) and ClassKitRegistry.validate(&"mg_la")["error_code"] == &"kit_skill_outside_identity" and not ClassKitRegistry.ready_for_play(&"mg_la"), "a skill outside the kit table is refused")
	_check(ProfileCatalog.pilot().evolution_definition(&"mg_la") == null and not ProfileCatalog.pilot().is_valid(), "a kit declared ready with invalid data fails the catalog loudly")
	_check(ClassKitRegistry.install_fixture(&"mg_la", WrongLevelKit.new(&"mg_la")) and ClassKitRegistry.validate(&"mg_la")["error_code"] == &"kit_learning_invalid", "learning rows must keep the section-1 job levels")
	ClassKitRegistry.clear_fixtures()
	_install_fixtures()

func _check_forced_overrides() -> void:
	ClassKitRegistry.clear_fixtures()
	ClassKitRegistry.install_fixture(&"mg_ac", SkeletonKit.new(&"mg_ac"))
	var unavailable := ProfileCatalog.pilot({}, {}, {&"mg_ac": {"content_ready": false}})
	_check(unavailable.is_valid() and unavailable.evolution_definition(&"mg_ac") != null and not unavailable.evolution_definition(&"mg_ac").content_ready, "a fixture override can list a skeleton as unavailable")
	var forced_empty := ProfileCatalog.pilot({}, {}, {&"mg_ac": {"content_ready": true}})
	_check(not forced_empty.is_valid(), "forcing an empty skeleton ready is refused")
	_install_fixtures()
	var forced := ProfileCatalog.pilot({}, {}, {&"sp_ac": {"content_ready": true}})
	_check(forced.is_valid() and forced.evolution_is_ready(&"sp_ac", &"swordsman"), "fixture profiles may force a kit evolution")

# --- Player hooks --------------------------------------------------------------

func _kit_player(evolution: StringName) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in ClassKitRegistry.skill_ids(evolution): snapshot.skill_ranks[skill] = 1
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = [ClassKitRegistry.skill_ids(evolution)[0], ClassKitRegistry.skill_ids(evolution)[2], ClassKitRegistry.skill_ids(evolution)[3], null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("kit-seam-" + String(evolution), snapshot))
	player.global_position = Vector2(400, 350)
	return player

func _enemy(at: Vector2, stats: StatBreakdown) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, stats, 18.0)
	enemy.global_position = at
	enemy.health.max_hp = 1000.0
	enemy.health.current_hp = 1000.0
	return enemy

func _on_attack(request: DamageRequest, _target: CombatActor) -> void:
	requests.append(request)

func _calls_index(kit: ClassKit, prefix: String) -> int:
	var calls: Array[String] = kit.get("calls")
	for index: int in calls.size():
		if calls[index].begins_with(prefix): return index
	return -1

func _check_player_hooks() -> void:
	_install_fixtures()
	var player := _kit_player(&"sp_ac")
	var kit := player.kit
	_check(player.has_kit() and kit != null and kit.get_script() == FixtureKit and kit.evolution_id == &"sp_ac", "configure attaches one kit object per character")
	_check(kit != ClassKitRegistry.module(&"sp_ac"), "the kit object is not the catalog module")
	_check(kit.get("calls") == ["attach"], "attach hook runs once at configure")
	_check(ClassKitRegistry.body_folder(&"sp_ac") == FIXTURE_BODY_SP_AC and player.character_animation.actor_kind == &"swordsman", "without kit art the origin body is used (C1.8)")
	_check(&"paladin_oath" in player.available_skill_ids() and player.kit_owns_skill(&"paladin_oath") and not player.kit_owns_skill(&"slash"), "kit skills are learned actives of the player")
	# Cast requested -> confirmed -> resolved with skill, rank and element.
	var sp_before := player.current_sp
	_check(player.use_kit_skill(&"paladin_oath", player.global_position), "self kit cast commits")
	var calls: Array[String] = kit.get("calls")
	_check(calls.slice(-3) == ["requested:paladin_oath", "confirmed:paladin_oath:1:", "resolved:paladin_oath"], "cast hooks run requested, confirmed and resolved in order")
	_check(player.current_sp < sp_before and player.skill_cooldown(&"paladin_oath") > 0.0, "payment is the canonical SP/cooldown commit")
	_check(not player.use_kit_skill(&"paladin_oath", player.global_position) and kit.get("calls").size() == calls.size(), "cooldown blocks before any hook")
	var controller := RunController.new()
	var enemy := _enemy(Vector2(470, 350), player.stat_breakdown)
	controller.player = player
	controller.enemies = [enemy]
	player.attack_requested.connect(_on_attack)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	_check(player.use_kit_skill(&"paladin_consecrated_impact", enemy.global_position, enemy) and requests.size() == 1 and requests[0].skill_id == &"paladin_consecrated_impact", "targeted kit cast emits through the shared request factory")
	_check(_calls_index(kit, "confirmed:paladin_consecrated_impact:1:light") >= 0, "confirmed hook receives rank and element")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result := enemy.apply_damage(requests[0], rng)
	_check(float(result.get("actual_damage", 0.0)) > 0.0 and _calls_index(kit, "dealt:paladin_consecrated_impact") >= 0, "damage dealt hook after the claim")
	enemy.health.current_hp = 1.0
	player.mage_cooldowns[&"paladin_consecrated_impact"] = 0.0
	player.current_sp = player.max_sp
	player.use_kit_skill(&"paladin_consecrated_impact", enemy.global_position, enemy)
	var kill_result := enemy.apply_damage(requests[-1], rng)
	_check(not enemy.is_alive() and bool(kill_result.get("killed", false)) and kit.get("calls").count("kill") == 1, "kill confirmed after the claim")
	controller._on_enemy_damage_resolved(kill_result)
	_check(kit.get("calls").count("kill") == 1, "kill confirmed exactly once per victim, even on a retry")
	# Preparation (cast time) goes through begin_skill_cast: requested once, then commit.
	player.current_sp = player.max_sp
	var before_prepare: int = kit.get("calls").size()
	_check(player.begin_skill_cast(&"paladin_oath_aegis", player.global_position) and kit.get("calls").slice(before_prepare) == ["requested:paladin_oath_aegis"], "a prepared cast is requested before its preparation")
	player.cancel_active_cast()
	_check(player.use_kit_skill(&"paladin_oath_aegis", player.global_position, null, false) and kit.get("calls").count("requested:paladin_oath_aegis") == 1, "the prepared commit does not request twice")
	# Basic attack replacement.
	var target := _enemy(Vector2(470, 350), player.stat_breakdown)
	player.target = target
	kit.set("basic_range", 120.0)
	kit.set("basic_bonus", 0.5)
	_check(is_equal_approx(player.basic_attack_distance(target), player.collision_radius + target.collision_radius + 120.0), "kit profile replaces the basic reach")
	kit.set("basic_delivery", &"precision")
	_check(player._basic_delivery() == &"precision", "kit profile chooses the basic delivery")
	kit.set("basic_delivery", &"direct")
	var count := requests.size()
	player.attack_cooldown = 0.0
	player._try_basic_attack()
	_check(requests.size() == count + 1 and requests[-1].skill_id == &"basic_attack" and requests[-1].damage_dealt_multiplier > player.outgoing_damage_multiplier() and _calls_index(kit, "basic") >= 0, "kit composes the basic attack damage request")
	player.target = null
	_check_hit_pipeline(player, kit, controller)
	_check_heal_death_and_return(player, kit)
	target.free()
	if is_instance_valid(enemy): enemy.free()
	controller.free()

func _enemy_hit(player: PlayerActor, source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _check_hit_pipeline(player: PlayerActor, kit: ClassKit, controller: RunController) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var front := _enemy(player.global_position + Vector2(60, 0), player.stat_breakdown)
	var back := _enemy(player.global_position + Vector2(-60, 0), player.stat_breakdown)
	player.character_animation.state.face(Vector2.RIGHT)
	var start: int = kit.get("calls").size()
	player.apply_damage(_enemy_hit(player, front, 5.0), rng)
	var tail: Array = kit.get("calls").slice(start)
	_check(tail == ["before:melee", "after:front"], "pipeline order: before mitigation, then after with frontal")
	player.apply_damage(_enemy_hit(player, back, 5.0), rng)
	_check(kit.get("calls")[-1] == "after:back", "a hit from behind is not frontal")
	kit.set("cancel_next_hit", true)
	var hp := player.health.current_hp
	var cancelled := player.apply_damage(_enemy_hit(player, front, 50.0), rng)
	_check(bool(cancelled.get("cancelled", false)) and not bool(cancelled.get("landed", true)) and player.health.current_hp == hp and kit.get("calls")[-1] == "before:melee", "step 1 may cancel the whole hit (parry)")
	player.health.grant_shield(1.0)
	start = kit.get("calls").size()
	player.apply_damage(_enemy_hit(player, front, 20.0), rng)
	_check(kit.get("calls").slice(start) == ["before:melee", "after:front", "shield_broken"], "shield broken is step 3, after mitigation")
	var secondary := _enemy_hit(player, front, 1.0)
	secondary.is_secondary = true
	start = kit.get("calls").size()
	player.apply_damage(secondary, rng)
	_check(kit.get("calls").size() == start, "secondary ticks skip the hit pipeline")
	# Enemy attack event: commit, then projectile impact with both instants.
	player.kit_time = 4.0
	var arrow := _enemy_hit(player, front, 2.0)
	arrow.skill_id = &"enemy_arrow"
	controller._kit_publish_enemy_attack(arrow, player, &"projectile", false)
	var committed: Dictionary = kit.get("last_event")
	_check(committed.get("kind") == &"projectile" and float(committed.get("commit_time")) == 4.0 and float(committed.get("impact_time")) == -1.0, "enemy attack event carries kind and commit instant")
	player.kit_time = 4.5
	controller._kit_apply_enemy_hit(arrow, player, &"melee")
	_check(_calls_index(kit, "before:projectile") >= 0 and player.incoming_attack_event.is_empty(), "impact reaches the pipeline with the event kind")
	var claw := _enemy_hit(player, front, 2.0)
	controller._kit_publish_enemy_attack(claw, player, &"melee", true)
	_check(kit.get("last_event").get("kind") == &"melee" and kit.get("last_event").get("impact_time") == kit.get("last_event").get("commit_time"), "melee commit and impact share the instant")
	front.free()
	back.free()

func _check_heal_death_and_return(player: PlayerActor, kit: ClassKit) -> void:
	player.health.current_hp = player.health.max_hp - 10.0
	var applied := player.heal_player(50.0, &"fixture")
	var heal: Dictionary = kit.get("last_heal")
	_check(is_equal_approx(applied, 10.0) and is_equal_approx(float(heal["requested"]), 50.0) and is_equal_approx(float(heal["excess"]), 40.0), "heal hook receives requested and applied (excess)")
	# Concealment from the kit and reveal by offense.
	kit.set("concealed", true)
	_check(player.is_concealed() and not player.can_be_acquired_by(player.global_position + Vector2(10, 0)), "kit concealment hides the player")
	_check(player.reveal_from_offense() and not player.is_concealed() and _calls_index(kit, "reveal") >= 0, "an offensive action reveals and notifies the kit")
	# Build change: no heal, no reset.
	var hp := player.health.current_hp
	var sp := player.current_sp
	player.apply_run_modifiers(player.run_state)
	_check(kit.get("calls")[-1] == "build" and player.health.current_hp == hp and player.current_sp == sp, "build change hook without implicit heal or reset")
	# Tick and pause.
	root.add_child(player)
	var ticks: float = kit.get("ticks")
	var clock := player.kit_time
	paused = true
	player._process(1.0)
	_check(kit.get("ticks") == ticks and player.kit_time == clock, "pause freezes the kit clock")
	paused = false
	player._process(0.5)
	_check(is_equal_approx(float(kit.get("ticks")), ticks + 0.5) and is_equal_approx(player.kit_time, clock + 0.5), "tick hook advances on the gameplay clock")
	# Death and return.
	var rng := RandomNumberGenerator.new()
	var killer := _enemy(player.global_position + Vector2(60, 0), player.stat_breakdown)
	player.health.clear_shield()
	player.apply_damage(_enemy_hit(player, killer, 100000.0), rng)
	_check(not player.is_alive() and kit.get("calls").count("death") == 1, "death hook")
	player.health._death_emitted = false
	player.health.current_hp = player.health.max_hp
	player._process(0.1)
	_check(kit.get("calls").count("return") == 1, "return hook once the player is alive again")
	player._process(0.1)
	_check(kit.get("calls").count("return") == 1, "return hook does not repeat")
	root.remove_child(player)
	killer.free()
	player.free()

# --- Enemy marks, facing and threat ------------------------------------------------

func _check_marks_and_facing() -> void:
	var stats := StatCalculator.calculate({&"vit": 10})
	var enemy := _enemy(Vector2(100, 100), stats)
	enemy.set_animation_kind(&"warrior")
	_check(enemy.marks.set_mark(&"sp_ac_seal", 77, 3, 2.0) and enemy.marks.value(&"sp_ac_seal") == 3 and enemy.marks.owner_of(&"sp_ac_seal") == 77, "a mark has key, owner and value")
	_check(not enemy.marks.set_mark(&"bad", 1, enemy, 1.0), "marks hold plain data only")
	enemy.advance_statuses(1.0)
	_check(is_equal_approx(enemy.marks.remaining(&"sp_ac_seal"), 1.0), "mark expiry runs on the gameplay clock")
	enemy.advance_statuses(1.0, true)
	_check(enemy.marks.has_mark(&"sp_ac_seal"), "paused simulation freezes marks")
	enemy.advance_statuses(1.5)
	_check(not enemy.marks.has_mark(&"sp_ac_seal") and enemy.marks.valid(), "an expired mark disappears")
	enemy.marks.set_mark(&"sp_la_sentence", 5, 4)
	enemy.marks.set_mark(&"other", 6, 1)
	_check(enemy.marks.remove_owner(5) == 1 and enemy.marks.keys() == [&"other"], "marks of one owner can be removed")
	# Facing.
	enemy.character_animation.state.face(Vector2.RIGHT)
	_check(enemy.gameplay_facing() == Vector2.RIGHT, "gameplay facing is the drawn facing")
	_check(enemy.override_gameplay_facing(Vector2.LEFT, 1.0, &"turn") and enemy.gameplay_facing() == Vector2.LEFT and enemy.character_animation.state.facing == Vector2.LEFT and enemy.gameplay_facing_override_owner() == &"turn", "override turns rule and drawing together")
	enemy.advance_statuses(0.5, true)
	_check(enemy.gameplay_facing_override_remaining() == 1.0, "pause freezes the override")
	enemy.advance_statuses(1.1)
	_check(enemy.gameplay_facing_override_remaining() == 0.0 and enemy.gameplay_facing_override_owner() == &"", "override expires on the gameplay clock")
	_check(enemy.gameplay_ground_facing().is_equal_approx(Vector3(-1, 0, 0)), "flat arena maps facing x/y to ground x/z")
	var ground := Vector3(0.6, 0.0, -0.8)
	_check(CombatActor.canvas_to_ground_direction(CombatActor.ground_to_canvas_direction(ground)).is_equal_approx(ground), "projected facing round-trips to the ground plane")
	enemy.override_gameplay_facing(Vector2.UP, 5.0)
	enemy.marks.set_mark(&"sp_ac_seal", 1, 1)
	enemy._on_health_died(enemy.get_instance_id())
	_check(enemy.marks.is_empty() and enemy.gameplay_facing_override_remaining() == 0.0, "death clears marks and override")
	enemy.free()

func _plain_hit(target: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.target_id = target.get_instance_id()
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request

func _check_threat_primitives() -> void:
	var threat := ThreatService.new()
	threat.enemy_id = "fixture_enemy"
	threat.register("a", "owner_a", "party")
	threat.register("b", "owner_b", "party")
	threat.observe("hit_a", &"damage", "a", 100.0)
	threat.observe("hit_b", &"damage", "b", 10.0)
	_check(threat.current_id == "a", "highest threat is the current target")
	var amounts := threat.amounts.duplicate()
	_check(threat.force_target("b", 2.0)["ok"] and threat.current_id == "b" and threat.amounts == amounts, "force_target selects without changing amounts")
	threat.advance(1.0, true)
	_check(threat.forced_remaining == 2.0, "frozen advance keeps the force")
	threat.advance(2.1)
	_check(threat.forced_id.is_empty() and threat.current_id == "a", "force expires and the usual rule returns")
	_check(threat.break_sight("a", 1.0)["ok"] and threat.current_id == "b" and threat.sight_broken("a") and threat.valid(), "break_sight makes the source ineligible")
	_check(not threat.force_target("a", 1.0)["ok"], "cannot force a source out of sight")
	threat.advance(1.1)
	_check(not threat.sight_broken("a") and threat.current_id == "a" and threat.valid(), "sight returns on the gameplay clock")
	_check(threat.force_target("zzz", 1.0)["error_code"] == &"invalid_participant" and threat.break_sight("a", 0.0)["error_code"] == &"invalid_payload", "primitive error codes")
	var plain := ThreatService.new()
	plain.register("a", "owner_a", "party")
	plain.observe("hit", &"damage", "a", 1.0)
	var revision := plain.revision
	plain.advance(1.0)
	_check(plain.revision == revision, "without force or sight breaks, advance stays a no-op")
	_check_player_threat_helpers()

## The player helpers reach an EnemyActor ledger without naming EnemyActor in
## player_actor.gd (that script cycle leaks resources at exit in Godot 4.7.2).
func _check_player_threat_helpers() -> void:
	_install_fixtures()
	var player := _kit_player(&"sp_ac")
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var hostile := EnemyActor.new()
	hostile.configure(&"chaser", navigation, player)
	player.add_child(hostile)
	_check(hostile.threat_id_for(player) == "player", "configure registers the kit player on the ledger")
	var forced := player.kit_force_target(hostile, 2.0)
	_check(forced["ok"] and hostile.threat.forced_id == "player", "kit_force_target reaches the enemy ledger")
	var broken := player.kit_break_sight(hostile, 1.0)
	_check(broken["ok"] and hostile.threat.sight_broken("player"), "kit_break_sight reaches the enemy ledger")
	var plain_actor := _enemy(Vector2(10, 10), player.stat_breakdown)
	player.add_child(plain_actor)
	_check(player.kit_force_target(plain_actor, 1.0)["error_code"] == &"invalid_target" and player.kit_break_sight(plain_actor, 1.0)["error_code"] == &"invalid_target", "a non-enemy actor is an invalid target")
	var other_player := _kit_player(&"sp_la")
	var stranger := EnemyActor.new()
	stranger.configure(&"chaser", navigation, other_player)
	player.add_child(stranger)
	_check(player.kit_force_target(stranger, 1.0)["error_code"] == &"invalid_participant", "an enemy without the player registered reports invalid_participant")
	var source := FileAccess.get_file_as_string("res://scripts/actors/player_actor.gd")
	var typed_reference := RegEx.create_from_string("(as|:|->)\\s*EnemyActor\\b|EnemyActor\\.")
	_check(typed_reference.search(source) == null, "player_actor.gd does not reference EnemyActor as a type")
	player.queue_free()
	other_player.queue_free()
	ClassKitRegistry.clear_fixtures()

# --- Snapshot rules -------------------------------------------------------------

func _check_snapshot_rules() -> void:
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty(), "every manifest fragment merges without errors")
	for path: String in ["res://scripts/classes/class_kit.gd", "res://scripts/classes/kit_world_skill_cast.gd", "res://scripts/classes/fixture/fixture_kit.gd", "res://scripts/core/actor_marks.gd"]:
		_check(registry.schemas.has(path), "schema present for " + path)
	for id: StringName in ClassKitRegistry.ids():
		_check(registry.schemas.has(String(ClassKitRegistry.MODULES[id])), "kit fragment present for %s" % id)
	_check("res://scripts/classes/sp_ac/snapshot_manifest.json" in SnapshotRegistry.fragment_paths(), "fragments are discovered by folder")
	_install_fixtures()
	var player := _kit_player(&"sp_ac")
	var enemy := _enemy(Vector2(470, 350), player.stat_breakdown)
	player.add_child(enemy)
	enemy.marks.set_mark(&"sp_ac_seal", player.get_instance_id(), 2, 3.0)
	player.kit.set("ticks", 1.25)
	player.kit.set("victim_id", enemy.get_instance_id())
	player.kit_time = 9.5
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(player)["ok"], "barrier acquired on the kit player")
	var captured := registry.capture(player, barrier)
	_check(captured.get("ok", false), "exact capture of a kit player: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore of a kit player: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			var copied_enemy: CombatActor
			for child: Node in copy.get_children():
				if child is CombatActor: copied_enemy = child
			_check(copy.kit != null and copy.kit.get_script() == FixtureKit and copy.kit.evolution_id == &"sp_ac" and copy.kit.get("ticks") == 1.25 and copy.kit_time == 9.5, "kit state survives the exact format")
			_check(copy.kit.get("calls") == player.kit.get("calls") and copy.kit.get("calls").count("attach") == 1, "restore does not re-run attach")
			_check(copied_enemy != null and copied_enemy.marks.value(&"sp_ac_seal") == 2 and copied_enemy.marks.owner_of(&"sp_ac_seal") == copy.get_instance_id() and int(copy.kit.get("victim_id")) == copied_enemy.get_instance_id(), "marks and entity IDs rebind to restored actors")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	player.kit.set("compact_blocker", "fixture_zone")
	var compact := SnapshotRegistry.new().capture(player, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "fixture_zone", "an active kit zone makes the compact cut ineligible")
	player.kit.set("compact_blocker", "")
	var compact_ok := SnapshotRegistry.new().capture(player, barrier, false, projection)
	_check(compact_ok.get("ok", false), "without a blocker the same projected cut is accepted: " + str(compact_ok.get("detail", compact_ok.get("error_code", ""))))
	barrier.release()
	player.free()

# --- Presentation -----------------------------------------------------------------

func _check_presentation() -> void:
	_install_fixtures()
	var effect := ClassKitRegistry.vfx_effect(&"paladin_consecrated_impact", &"impact")
	_check(effect.get("effect_id") == &"paladin_fixture_burst" and effect.get("kit") == &"sp_ac" and ClassKitRegistry.vfx_effect(&"paladin_consecrated_impact", &"cast_start").is_empty(), "module effect drawers are found by skill and kind")
	_check(ClassKitRegistry.actor_kind(&"sp_ac", &"swordsman") == &"swordsman" and ClassKitRegistry.actor_kind(&"mg_ac", &"mage") == &"mage", "evolution -> actor_kind falls back to the origin body")
	_check(ClassKitRegistry.body_folder(&"sp_ac") == FIXTURE_BODY_SP_AC and DirectionalAnimationSet.kit_body_path(FIXTURE_BODY_SP_AC).is_empty() and ClassKitRegistry.body_folder(&"mg_la") == &"arcane_blade", "body folders follow section 1")
	var animation := CharacterAnimation.new()
	animation.configure(FIXTURE_BODY_MG_AC)
	_check(animation.actor_kind == &"mage" and animation.atlas != null, "a kit body without art configures the origin body as a whole")
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"sp_la"
	_check(ClassKitRegistry.body_folder(&"sp_la") == FIXTURE_BODY_SP_LA and BuildPresentation.portrait_identity(snapshot) == &"swordsman", "portrait identity uses the same fallback")
	var layer: Control = load("res://scripts/presentation/feedback_vfx_layer.gd").new()
	layer.flipbook_provider = func(id: StringName) -> Dictionary: return {"texture": null, "grid": [1, 1], "cell": [8, 8], "frames": 1, "fps": 10.0, "hint": 8.0} if id == &"paladin_fixture_burst" else {}
	_check(not layer.flipbook(&"paladin_fixture_burst").is_empty(), "a flipbook with the effect ID replaces the code drawing")
	layer.free()
