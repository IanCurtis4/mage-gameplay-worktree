extends SceneTree
## E10a C1.13 — the base seam and the two-module composition. A fixture base module
## (scripts/classes/fixture/fixture_base.gd) is installed over `acolyte` and a fixture kit
## over `priest`; the production Cultista stays an empty skeleton, never ready (the Acólito base and the Sacerdote are delivered, T5 and T6).
const FixtureBase = preload("res://scripts/classes/fixture/fixture_base.gd")
const FixtureKit = preload("res://scripts/classes/fixture/fixture_kit.gd")

## The fourteen identities of E09 (three bases, six pure, the Geometer and four kits).
const CURRENT_IDENTITIES: Array[StringName] = [&"swordsman", &"mage", &"archer", &"defender", &"berserker", &"elementalist", &"spiritualist", &"sentinel", &"hunter", &"mg_ar", &"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]
const E00_ATTRIBUTES := {
	&"swordsman": {&"str": 8, &"agi": 5, &"vit": 8, &"int": 2, &"dex": 5, &"luk": 2},
	&"mage": {&"str": 2, &"agi": 5, &"vit": 5, &"int": 9, &"dex": 7, &"luk": 2},
	&"archer": {&"str": 3, &"agi": 7, &"vit": 5, &"int": 2, &"dex": 10, &"luk": 3},
}

var checks := 0
var failures := 0
var requests: Array[DamageRequest] = []

class WrongIdBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func base_id() -> StringName:
		return &"rogue"

class ForeignSkillBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func skill_definitions() -> Array[SkillDefinition]:
		var result := super.skill_definitions()
		var foreign: SkillDefinition = result[0].duplicate(true)
		foreign.id = &"fireball"
		result.append(foreign)
		return result

class FreeRankBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func learning_entries() -> Array[Dictionary]:
		var result := super.learning_entries()
		result[0]["free_rank"] = 1
		return result

class AttributeBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func initial_attributes() -> Dictionary[StringName, int]:
		return {&"str": 9, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3}

class AttackBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func basic_attack() -> Dictionary:
		return {"delivery": &"thrown", "range": 220.0, "power": 1.0}

class IncompleteBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func skill_texts() -> Dictionary:
		var result := super.skill_texts()
		result.erase(&"acolyte_devotion")
		return result

## A base that declares itself unready: the Acólito of production is ready since T5, so the C1.3 rule is proved with this one.
class UnreadyBase extends "res://scripts/classes/fixture/fixture_base.gd":
	func ready_for_play() -> bool:
		return false

## An origin that cancels every hit before the evolution is asked.
class OrderedKit extends "res://scripts/classes/fixture/fixture_kit.gd":
	var hit_multiplier := 1.0
	func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
		FixtureBase.order_log.append("kit:before")
		var answer := super.before_hit_mitigation(player, hit)
		if hit_multiplier != 1.0 and not bool(answer.get("cancel", false)): answer["damage_multiplier"] = hit_multiplier
		return answer
	func after_hit_mitigation(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
		FixtureBase.order_log.append("kit:after")
		super.after_hit_mitigation(player, hit, result)
	func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
		FixtureBase.order_log.append("kit:heal:" + String(source))
		super.on_heal(player, requested, applied, source)
	func on_build_changed(player: PlayerActor) -> void:
		FixtureBase.order_log.append("kit:build")
		super.on_build_changed(player)
	func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
		FixtureBase.order_log.append("kit:confirmed:" + String(cast["skill_id"]))
		super.on_cast_confirmed(player, cast)
	func on_base_skill_committed(player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
		FixtureBase.order_log.append("kit:commit:" + String(skill_id))
		super.on_base_skill_committed(player, skill_id, context)
	func on_death(player: PlayerActor) -> void:
		FixtureBase.order_log.append("kit:death")
		super.on_death(player)
	func compose_basic_attack(player: PlayerActor, target: CombatActor, request: DamageRequest) -> DamageRequest:
		FixtureBase.order_log.append("kit:basic")
		return super.compose_basic_attack(player, target, request)
	func temporary_stat_sources(_player: PlayerActor) -> Array[Dictionary]:
		return [{"source_id": &"priest_fixture_bonus", "label": "Bônus do kit", "increased": {&"physical_defense": 0.1}}]

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_production_state()
	_check_current_identities()
	_check_validation_errors()
	_check_fixture_catalogs()
	_check_player_composition()
	_check_base_only_player()
	_check_snapshot()
	ClassKitRegistry.clear_fixtures()
	print("E10a base seam: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Production state ---------------------------------------------------------------

func _check_production_state() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassBaseRegistry.ids() == [&"acolyte"] and String(ClassBaseRegistry.MODULES[&"acolyte"]) == "res://scripts/classes/bases/acolyte/acolyte_base.gd", "the base registry lists acolyte in its own folder")
	var base := ClassBaseRegistry.module(&"acolyte")
	_check(base != null and base is ClassBase and base.base_id() == &"acolyte" and base.kit_id() == &"acolyte" and base.display_name() == "Acólito", "the acolyte module loads with its ID and pt-BR name")
	_check(ClassBaseRegistry.validate(&"acolyte")["ok"] and ClassBaseRegistry.ready_for_play(&"acolyte"), "the Acólito module validates and is ready (C1.3, T5, A11)")
	_check(ClassBaseRegistry.validate(&"swordsman")["error_code"] == &"base_unknown_identity", "the E00 bases stay outside the base registry")
	_check(ClassBaseRegistry.skill_ids(&"acolyte").size() == 8 and ClassBaseRegistry.identity(&"acolyte")["fallback_body"] == &"mage", "eight stable library IDs and the Mage fallback body (A5, C1.2)")
	for id: StringName in ClassBaseRegistry.skill_ids(&"acolyte"):
		_check(ClassKitRegistry.skill_owner(id) == &"acolyte" and ClassCatalog.skill_definition(id) != null, "%s belongs to the base and is published by the catalog (ready module, T5, A11)" % id)
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.base_class_is_available(&"acolyte"), "production catalog valid; Acólito offered at creation (T5, A11)")
	_check(catalog.evolution_definitions_for_origin(&"acolyte").map(func(d: EvolutionDefinition) -> StringName: return d.id) == [&"priest"], "the Acólito offers only the ready pure kit of its branch: the Sacerdote (T6); the Cultista skeleton stays out (A11)")
	_check(ClassKitRegistry.ids() == [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la", &"priest", &"cultist"] and ClassKitRegistry.hybrid_ids() == [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"] and ClassKitRegistry.pure_ids() == [&"priest", &"cultist"], "kit registry: the four hybrids then the two pure kits")
	for row: Array in [[&"priest", &"2-1", "Sacerdote"], [&"cultist", &"2-2", "Cultista"]]:
		var id: StringName = row[0]
		var kit := ClassKitRegistry.module(id)
		_check(kit != null and kit.kit_id() == id and String(ClassKitRegistry.MODULES[id]) == "res://scripts/classes/%s/%s_kit.gd" % [id, id], "%s skeleton loads from its own folder" % id)
		if id == &"priest":
			# E10a T6 (A9, A15 of E09): the Sacerdote is delivered and ready; its own tests live in tests/classes/priest.
			_check(ClassKitRegistry.validate(id)["ok"] and ClassKitRegistry.ready_for_play(id) and kit.skill_definitions().size() == 7, "priest is a ready kit with its seven skills (T6)")
		else:
			_check(ClassKitRegistry.validate(id)["ok"] and not ClassKitRegistry.ready_for_play(id) and kit.skill_definitions().is_empty(), "%s skeleton validates, empty and not ready" % id)
		_check(ClassKitRegistry.origin(id) == &"acolyte" and ClassKitRegistry.branch(id) == row[1] and ClassKitRegistry.affinity(id).is_empty() and ClassKitRegistry.is_pure(id), "%s: origin acolyte, branch %s by data" % [id, row[1]])
		_check(ClassKitRegistry.display_name(id) == row[2] and ClassKitRegistry.skill_ids(id).size() == 7 and String(ClassKitRegistry.skill_ids(id)[0]).begins_with(String(id) + "_"), "%s: name and seven prefixed IDs of section 1" % id)
		_check(IdentityIds.is_evolution(id) and IdentityIds.evolution_origin(id) == &"acolyte" and IdentityIds.evolution_belongs_to(id, &"acolyte") and IdentityIds.kit_affinity(id).is_empty(), "%s is an evolution of the Acólito, without affinity" % id)
	_check(IdentityIds.reserved_base_ids() == [&"rogue"] and not IdentityIds.is_reserved_base(&"acolyte"), "acolyte is no longer a reserved base")
	_check(IdentityIds.base_class_ids() == [&"swordsman", &"mage", &"archer"] and IdentityIds.registered_base_ids() == [&"acolyte"] and IdentityIds.all_base_ids() == [&"swordsman", &"mage", &"archer", &"acolyte"], "E00 base list stable; the registered base listed apart")
	_check(IdentityIds.is_base_class(&"acolyte") and not IdentityIds.is_base_class(&"rogue") and IdentityIds.initial_attributes(&"acolyte") == {&"str": 3, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3}, "acolyte is a base class with the attributes of D2 (T5)")
	_check(IdentityIds.kit_evolution_ids() == ClassKitRegistry.ids() and IdentityIds.kit_affinity(&"sp_ac") == &"acolyte" and IdentityIds.kit_affinity(&"mg_ac") == &"acolyte" and IdentityIds.kit_affinity(&"sp_la") == &"rogue", "kit list and affinity labels come from the registry")
	_check(&"shadow" in ClassKitRegistry.KIT_ELEMENTS and &"light" in ClassKitRegistry.KIT_ELEMENTS and &"shadow" in ClassBaseRegistry.BASE_ELEMENTS, "shadow joins the accepted skill elements (D5)")
	_check(&"light" in FeedbackRecipeCatalog.ELEMENTS and &"shadow" in FeedbackRecipeCatalog.ELEMENTS and WorldProjectileArt.PALETTE.has(&"light") and WorldProjectileArt.PALETTE.has(&"shadow") and WorldProjectileArt.PALETTE[&"light"] != WorldProjectileArt.PALETTE[&"arcane"], "light and shadow have their own colour (C1.8)")
	_check(EquipmentEligibilityRules.eligible_identities().has(&"acolyte") and EquipmentEligibilityRules.eligible_identities().has(&"priest") and EquipmentEligibilityRules.eligible_identities().has(&"cultist") and EquipmentEligibilityRules.validate({"allowed_identities": [&"acolyte", &"priest", &"cultist"]})["ok"], "the three family identities are eligible equipment restrictions")
	var registry := SnapshotRegistry.new()
	_check(registry.fragment_errors.is_empty(), "every manifest fragment merges without errors")
	for path: String in ["res://scripts/classes/bases/class_base.gd", "res://scripts/classes/bases/acolyte/acolyte_base.gd", "res://scripts/classes/priest/priest_kit.gd", "res://scripts/classes/cultist/cultist_kit.gd", "res://scripts/classes/kit_decoy.gd", "res://scripts/classes/fixture/fixture_base.gd"]:
		_check(registry.schemas.has(path), "schema present for " + path)

## The fourteen current identities keep their origin, branch, attributes and bodies.
func _check_current_identities() -> void:
	ClassKitRegistry.clear_fixtures()
	var catalog := ProfileCatalog.pilot()
	for base: StringName in E00_ATTRIBUTES:
		_check(IdentityIds.initial_attributes(base) == E00_ATTRIBUTES[base] and catalog.base_class_is_available(base), "%s keeps attributes and creation" % base)
		_check(ClassCatalog.class_definition(base) != null and ClassCatalog.class_definition(base).basic_delivery.is_empty(), "%s keeps the E00 basic-attack rule" % base)
		_check(ClassKitRegistry.actor_kind(&"", base) == base and ClassKitRegistry.base_actor_kind(base) == base, "%s body is itself" % base)
	var listed: Array = []
	for base: StringName in IdentityIds.base_class_ids():
		for definition: EvolutionDefinition in catalog.evolution_definitions_for_origin(base): listed.append(definition.id)
	for id: StringName in CURRENT_IDENTITIES:
		if IdentityIds.is_base_class(id): continue
		_check(id in listed, "%s still offered by the production catalog" % id)
		var definition := catalog.evolution_definition(id)
		if definition == null: continue
		var expected_branch: StringName = ClassKitRegistry.branch(id) if ClassKitRegistry.is_kit(id) else definition.branch_kind
		_check(definition.origin_class_id == IdentityIds.evolution_origin(id) and IdentityIds.is_base_class(definition.origin_class_id) and not IdentityIds.is_registered_base(definition.origin_class_id) and definition.branch_kind == expected_branch, "%s keeps its E00 origin and branch" % id)
	for id: StringName in ClassKitRegistry.hybrid_ids():
		_check(ClassKitRegistry.branch(id) == &"2-3" and catalog.evolution_definition(id).branch_kind == &"2-3", "%s stays a 2-3 hybrid" % id)

# --- Validation (C1.1–C1.3) ---------------------------------------------------------

func _check_validation_errors() -> void:
	for row: Array in [[WrongIdBase.new(), &"install_refused"], [ForeignSkillBase.new(), &"base_skill_outside_identity"], [FreeRankBase.new(), &"base_learning_invalid"], [AttributeBase.new(), &"base_attributes_invalid"], [AttackBase.new(), &"base_attack_invalid"], [IncompleteBase.new(), &"base_incomplete"]]:
		ClassKitRegistry.clear_fixtures()
		var base: ClassBase = row[0]
		var installed := ClassBaseRegistry.install_fixture(&"acolyte", base)
		if row[1] == &"install_refused":
			_check(not installed, "a module answering another base ID is refused")
			continue
		var validation := ClassBaseRegistry.validate(&"acolyte")
		_check(installed and not validation["ok"] and validation["error_code"] == row[1], "invalid base data fails with %s (got %s)" % [row[1], validation["error_code"]])
		_check(not ClassBaseRegistry.ready_for_play(&"acolyte") and not ProfileCatalog.pilot().is_valid(), "%s: a base declared ready with invalid data fails loudly" % row[1])
	ClassKitRegistry.clear_fixtures()
	_check(ProfileCatalog.pilot().is_valid(), "clearing the fixtures restores the production catalog")

# --- Fixture catalogs (C1.2, C1.3, C1.5) ----------------------------------------------

func _install(kit: ClassKit = null) -> void:
	ClassKitRegistry.clear_fixtures()
	FixtureBase.order_log.clear()
	ClassBaseRegistry.install_fixture(&"acolyte", FixtureBase.new())
	ClassKitRegistry.install_fixture(&"priest", kit if kit != null else OrderedKit.new(&"priest"))

func _check_fixture_catalogs() -> void:
	_install()
	_check(ClassBaseRegistry.validate(&"acolyte")["ok"] and ClassBaseRegistry.ready_for_play(&"acolyte"), "fixture base validates and is ready")
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.base_class_is_available(&"acolyte"), "a ready base appears in creation")
	var library := catalog.skill_ids_for_identity(&"acolyte")
	_check(library.size() == 8 and library.all(func(id: StringName) -> bool: return id in ClassBaseRegistry.skill_ids(&"acolyte")), "the base library is the eight skills of the module")
	var shield := catalog.skill_metadata(&"acolyte_votive_shield")
	_check(shield["wallet"] == ProfileCatalog.BASE_WALLET and shield["category"] == ProfileCatalog.ACTIVE and int(shield["free_rank"]) == 0 and int(shield["max_purchased_rank"]) == 5 and shield["rank_requirements"][1]["skill_ranks"] == {&"acolyte_prayer": 1}, "base rows: base wallet, ranks 1–5 and the module prerequisites")
	_check(int(catalog.skill_metadata(&"acolyte_devotion")["max_purchased_rank"]) == 3 and catalog.skill_metadata(&"acolyte_devotion")["category"] == ProfileCatalog.PASSIVE, "base passives have ranks 1–3")
	_check(SkillDependencyRules.requirements_for(&"acolyte_devotion") == {&"acolyte_punishing_light": 1, &"acolyte_shadow_seal": 1} and SkillDependencyRules.requirements_for(&"fire_spear") == {&"fire_wall": 2}, "SkillDependencyRules aggregates module prerequisites")
	var definition := ClassCatalog.class_definition(&"acolyte")
	_check(definition != null and definition.display_name == "Base de teste" and definition.attributes == IdentityIds.initial_attributes(&"acolyte") and definition.basic_delivery == &"mage" and is_equal_approx(definition.basic_range, 220.0) and definition.skill_ids == [&"acolyte_punishing_light", &"acolyte_prayer"] and definition.passive_id == &"acolyte_protective_faith", "ClassCatalog composes the base definition from the module")
	var attributes := IdentityIds.initial_attributes(&"acolyte")
	_check(attributes == {&"str": 3, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3} and attributes.values().reduce(func(a: int, b: int) -> int: return a + b, 0) == 30, "D2 attributes sum 30")
	_check(ClassCatalog.skill_definition(&"acolyte_shadow_seal").element == &"shadow" and PlayerActor.base_skill_element(&"acolyte_punishing_light") == &"light", "base skills publish their light/shadow element")
	_check(not ClassCatalog.passive_modifier_source(&"acolyte_protective_faith", 2).is_empty(), "the base passive source reaches ClassCatalog")
	_check(BuildEffectCatalog.is_intrinsic_family(&"acolyte_fixture_family") and &"acolyte_fixture_family" in ClassKitRegistry.causal_families(&"acolyte"), "base causal families are intrinsic")
	var recipe := FeedbackRecipeCatalog.recipe(&"acolyte_punishing_light")
	_check(not recipe.generic and recipe.family == &"projectile" and recipe.element == &"light" and &"acolyte_shadow_seal" in FeedbackRecipeCatalog.known_ids(), "base recipes come through the seam with their light/shadow element")
	var basic := FeedbackRecipeCatalog.recipe(&"basic_attack", &"acolyte")
	_check(not basic.generic and basic.variant == &"acolyte" and basic.element == &"light" and bool(basic.basic_hit), "the base basic-attack row is the module row")
	var priest_basic := FeedbackRecipeCatalog.recipe(&"basic_attack", &"priest")
	_check(priest_basic.variant == &"priest" and priest_basic.family == &"melee", "a pure kit row wins over its base row")
	_check(FeedbackRecipeCatalog.for_event({"kind": &"impact", "skill_id": &"", "payload": {"actor_variant": "acolyte"}}).skill_id == &"basic_attack", "an empty-skill hit of the base derives its basic attack")
	_check(SkillCopy.text_for(&"acolyte_prayer").get("effect", "") == "Efeito de base de teste." and SkillPresentation.mechanics_of(&"acolyte_prayer") == "Mecânica de base de teste.", "texts reach SkillCopy and SkillPresentation")
	var effect := ClassKitRegistry.vfx_effect(&"acolyte_punishing_light", &"impact")
	_check(effect.get("effect_id") == &"acolyte_fixture_glow" and effect.get("kit") == &"acolyte", "base effect drawers are found by skill and kind")
	# Paladin and Thaumaturge show their arcane rows in light (C1.8), gameplay untouched.
	for kit: StringName in [&"sp_ac", &"mg_ac"]:
		for skill: StringName in ClassKitRegistry.skill_ids(kit):
			var row := ClassKitRegistry.feedback_recipe(skill)
			if row.is_empty(): continue
			_check(row[1] != &"arcane", "%s presentation no longer uses arcane" % skill)
	# Bodies: base folder when it has art, else the fallback; kits chain through the base.
	var base_body := &"acolyte" if not DirectionalAnimationSet.kit_body_path(&"acolyte").is_empty() else &"mage"
	_check(ClassKitRegistry.base_actor_kind(&"acolyte") == base_body and ClassKitRegistry.actor_kind(&"", &"acolyte") == base_body, "the base body is its folder or the Mage fallback")
	var priest_body := &"priest" if not DirectionalAnimationSet.kit_body_path(&"priest").is_empty() else base_body
	_check(ClassKitRegistry.actor_kind(&"priest", &"acolyte") == priest_body, "a pure kit falls back to the base body")
	_check(ClassKitRegistry.is_body_kind(&"acolyte") and ClassKitRegistry.body_origin(&"priest") == &"acolyte" and ClassKitRegistry.body_origin(&"acolyte") == &"mage" and ClassKitRegistry.legacy_body_kind(&"cultist") == &"mage" and ClassKitRegistry.legacy_body_kind(&"paladin") == &"swordsman", "body chain kit -> base -> fallback")
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = &"priest"
	_check(BuildPresentation.portrait_identity(snapshot) == priest_body, "portrait identity uses the same chain")
	# Evolutions: the ready pure kit appears for its base with branch 2-1, no affinity.
	var destinations := catalog.evolution_definitions_for_origin(&"acolyte")
	_check(destinations.size() == 1 and destinations[0].id == &"priest" and destinations[0].branch_kind == &"2-1" and destinations[0].affinity_class_id.is_empty() and destinations[0].content_ready and destinations[0].entry_skill_id == &"priest_sanctuary", "the ready pure kit is offered with its branch by data")
	_check(catalog.evolution_definition(&"cultist") == null, "the unready pure kit is not offered")
	var forced := ProfileCatalog.pilot({}, {}, {&"cultist": {"content_ready": false}})
	_check(forced.is_valid() and forced.evolution_definition(&"cultist") != null and not forced.evolution_definition(&"cultist").content_ready, "a fixture override lists the unready pure kit as unavailable")
	ClassBaseRegistry.clear_fixtures()
	ClassBaseRegistry.install_fixture(&"acolyte", UnreadyBase.new())
	_check(ClassKitRegistry.ready_for_play(&"priest") and ProfileCatalog.pilot().evolution_definition(&"priest") == null and not ProfileCatalog.pilot().base_class_is_available(&"acolyte"), "a ready pure kit is not offered while its base is not ready (C1.3): an unready fixture base replaces the ready Acólito (A11)")
	ClassBaseRegistry.clear_fixtures()
	_check(ProfileCatalog.pilot().evolution_definition(&"priest") != null and ProfileCatalog.pilot().base_class_is_available(&"acolyte"), "with the production Acólito ready again, the Sacerdote is offered (T5, A11)")
	ClassKitRegistry.clear_fixtures()

# --- Player: two modules (C1.4) --------------------------------------------------------

func _family_player(evolution: StringName) -> PlayerActor:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL if not evolution.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in ClassBaseRegistry.skill_ids(&"acolyte"): snapshot.skill_ranks[skill] = 1
	if not evolution.is_empty():
		for skill: StringName in ClassKitRegistry.skill_ids(evolution): snapshot.skill_ranks[skill] = 1
		snapshot.active_slots = [&"acolyte_punishing_light", &"acolyte_prayer", ClassKitRegistry.skill_ids(evolution)[0], ClassKitRegistry.skill_ids(evolution)[2], null]
	else:
		snapshot.active_slots = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_shadow_seal", null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("base-seam-" + String(evolution), snapshot))
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

func _hit(player: PlayerActor, source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _check_player_composition() -> void:
	_install()
	var player := _family_player(&"priest")
	var origin := player.origin_kit
	var kit := player.kit
	_check(origin != null and origin.get_script() == FixtureBase and origin.evolution_id == &"acolyte" and origin != ClassBaseRegistry.module(&"acolyte"), "configure attaches the origin object (not the catalog module)")
	_check(kit != null and kit.get_script() == OrderedKit and kit.evolution_id == &"priest", "configure attaches the evolution kit")
	_check(player.kit_modules() == [origin, kit] and player.has_kit(), "hook order: origin, then evolution")
	_check(FixtureBase.order_log.has("base:attach") and origin.get("calls").count("attach") == 1 and kit.get("calls").count("attach") == 1, "attach runs once on each module")
	_check(player.kit_for_skill(&"acolyte_punishing_light") == origin and player.kit_for_skill(&"priest_sanctuary") == kit and not player.kit_owns_skill(&"fireball"), "each skill belongs to its module")
	_check(&"acolyte_punishing_light" in player.available_skill_ids() and &"priest_sanctuary" in player.available_skill_ids(), "base and kit skills are learned actives")
	# Basic attack: the base data (magic, 220), replaced by the evolution only when it declares.
	_check(player._basic_delivery() == &"mage" and is_equal_approx(player._basic_range(), 220.0), "the origin data sets the basic attack (magic, 220)")
	kit.set("basic_range", 90.0)
	kit.set("basic_delivery", &"direct")
	_check(player._basic_delivery() == &"direct" and is_equal_approx(player._basic_range(), 90.0), "the evolution profile replaces the origin when it declares one")
	kit.set("basic_range", 0.0)
	_check(player._basic_delivery() == &"mage", "without a kit profile the origin profile returns")
	var controller := RunController.new()
	var enemy := _enemy(Vector2(470, 350), player.stat_breakdown)
	controller.player = player
	controller.enemies = [enemy]
	player.attack_requested.connect(_on_attack)
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _facing: Vector2, _count: int) -> void: requests.append(request))
	# Basic composition: chained, origin first.
	origin.set("basic_bonus", 0.5)
	kit.set("basic_bonus", 1.0)
	player.target = enemy
	player.attack_cooldown = 0.0
	FixtureBase.order_log.clear()
	var before := requests.size()
	player._try_basic_attack()
	var plain := player.outgoing_damage_multiplier()
	_check(requests.size() == before + 1 and is_equal_approx(requests[-1].damage_dealt_multiplier, plain * 1.5 * 2.0) and requests[-1].magic_damage > 0.0, "basic composition chains origin then evolution (magic request)")
	_check(FixtureBase.order_log.find("base:basic") < FixtureBase.order_log.find("kit:basic") and FixtureBase.order_log.find("base:basic") >= 0, "origin composes the basic attack first")
	player.target = null
	origin.set("basic_bonus", 0.0)
	kit.set("basic_bonus", 0.0)
	# Cost: chained (base + offset, then the kit's scale), floored at 0.
	var base_cost := player.base_skill_cost(&"acolyte_prayer")
	origin.set("cost_offset", 2.0)
	kit.set("cost_scale", 0.5)
	_check(is_equal_approx(player.skill_cost(&"acolyte_prayer"), (base_cost + 2.0) * 0.5), "skill_cost chains origin then evolution")
	origin.set("cost_offset", -100.0)
	_check(player.skill_cost(&"acolyte_prayer") == 0.0, "skill_cost is floored at 0")
	origin.set("cost_offset", 0.0)
	kit.set("cost_scale", 1.0)
	# can_cast: any refusal, with the first code.
	origin.set("refuse_skill", &"priest_aegis")
	player.current_sp = player.max_sp
	_check(not player.use_kit_skill(&"priest_aegis", enemy.global_position, enemy), "a refusal of the origin blocks a kit skill")
	_check(player._kit_can_cast(player._kit_cast_legacy(&"priest_aegis", enemy.global_position, enemy))["error_code"] == &"fixture_base_refused", "the refusal keeps the origin code")
	origin.set("refuse_skill", &"")
	# Casts: the owner confirms and resolves; the other module sees on_base_skill_committed.
	FixtureBase.order_log.clear()
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(&"acolyte_punishing_light", enemy.global_position, enemy), "a base skill casts through the seam")
	_check(FixtureBase.order_log == ["base:requested:acolyte_punishing_light", "base:confirmed:acolyte_punishing_light:light", "kit:commit:acolyte_punishing_light", "base:resolved:acolyte_punishing_light"], "base skill: origin requested/confirmed, evolution on_base_skill_committed, origin resolves: %s" % str(FixtureBase.order_log))
	var kit_commits: Array = kit.get("base_commits")
	_check(not kit_commits.is_empty() and kit_commits[-1]["skill_id"] == &"acolyte_punishing_light" and kit_commits[-1]["element"] == &"light" and kit_commits[-1]["target_id"] == enemy.get_instance_id(), "the evolution receives the paid commit of the origin skill with element and target")
	FixtureBase.order_log.clear()
	player.current_sp = player.max_sp
	_check(player.use_kit_skill(&"priest_aegis", enemy.global_position, enemy), "a kit skill casts")
	_check(FixtureBase.order_log == ["base:commit:priest_aegis", "kit:confirmed:priest_aegis"], "kit skill: origin on_base_skill_committed first, then the kit confirms: %s" % str(FixtureBase.order_log))
	var base_commits: Array = origin.get("commits")
	_check(base_commits[-1]["skill_id"] == &"priest_aegis" and base_commits[-1]["element"] == &"light", "the origin sees the evolution commit with its element (Devoção reads it)")
	_check(origin.get("calls").count("resolved:priest_aegis") == 0 and kit.get("calls").count("resolved:priest_aegis") == 1, "only the owner resolves")
	# Damage dealt and kill confirmed reach both modules once.
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	enemy.apply_damage(requests[-1], rng)
	_check(origin.get("calls").has("dealt:priest_aegis") and kit.get("calls").has("dealt:priest_aegis"), "damage dealt reaches both modules")
	# Temporary stat sources: concatenated.
	origin.set("stat_bonus", 0.25)
	player.refresh_kit_stats()
	var ids: Array = player.temporary_stat_sources().map(func(source: Dictionary) -> StringName: return source["source_id"])
	_check(&"acolyte_fixture_bonus" in ids and &"priest_fixture_bonus" in ids and ids.find(&"acolyte_fixture_bonus") < ids.find(&"priest_fixture_bonus"), "temporary sources of both modules are concatenated, origin first")
	origin.set("stat_bonus", 0.0)
	player.refresh_kit_stats()
	# Incoming hits: multipliers multiply; a cancel by the origin stops the chain.
	var source := _enemy(player.global_position + Vector2(60, 0), player.stat_breakdown)
	origin.set("hit_multiplier", 0.5)
	kit.set("hit_multiplier", 0.5)
	FixtureBase.order_log.clear()
	var result := player.apply_damage(_hit(player, source, 40.0), rng)
	_check(is_equal_approx(float(result.get("kit_damage_multiplier", 1.0)), 0.25), "before_hit_mitigation multipliers multiply (0.5 x 0.5)")
	_check(FixtureBase.order_log.slice(0, 4) == ["base:before", "kit:before", "base:after", "kit:after"], "hit pipeline order: origin, then evolution, in each step")
	origin.set("hit_multiplier", 1.0)
	kit.set("hit_multiplier", 1.0)
	origin.set("cancel_next_hit", true)
	FixtureBase.order_log.clear()
	var cancelled := player.apply_damage(_hit(player, source, 40.0), rng)
	_check(bool(cancelled.get("cancelled", false)) and cancelled.get("cancel_reason") == &"fixture_base_ward" and FixtureBase.order_log == ["base:before"], "a cancel by the origin cancels the hit before the evolution is asked")
	# Heal, build change and death reach both modules, origin first.
	player.health.current_hp = player.health.max_hp - 10.0
	FixtureBase.order_log.clear()
	player.heal_player(25.0, &"fixture")
	_check(FixtureBase.order_log == ["base:heal:fixture", "kit:heal:fixture"] and is_equal_approx(float(origin.get("last_heal")["requested"]), 25.0), "on_heal reaches both modules")
	FixtureBase.order_log.clear()
	player.apply_run_modifiers(player.run_state)
	_check(FixtureBase.order_log == ["base:build", "kit:build"], "on_build_changed reaches both modules")
	# Compact blocker: any module.
	origin.set("compact_blocker", "base_zone")
	_check(player.kit_compact_blocker() == "base_zone", "the origin may block the compact cut")
	origin.set("compact_blocker", "")
	kit.set("compact_blocker", "kit_zone")
	_check(player.kit_compact_blocker() == "kit_zone", "the evolution may block the compact cut")
	kit.set("compact_blocker", "")
	# Tick and pause.
	root.add_child(player)
	paused = true
	player._process(1.0)
	_check(float(origin.get("ticks")) == 0.0 and float(kit.get("ticks")) == 0.0, "pause freezes both module clocks")
	paused = false
	player._process(0.5)
	_check(is_equal_approx(float(origin.get("ticks")), 0.5) and is_equal_approx(float(kit.get("ticks")), 0.5), "on_tick reaches both modules")
	FixtureBase.order_log.clear()
	player.health.clear_shield()
	player.apply_damage(_hit(player, source, 1.0e6), rng)
	_check(not player.is_alive() and FixtureBase.order_log.has("base:death") and FixtureBase.order_log.find("base:death") < FixtureBase.order_log.find("kit:death"), "death reaches both modules, origin first")
	root.remove_child(player)
	source.free()
	if is_instance_valid(enemy): enemy.free()
	controller.free()
	player.free()

## A base without evolution: the origin object alone, the basic attack from its data.
func _check_base_only_player() -> void:
	_install()
	var player := _family_player(&"")
	_check(player.origin_kit != null and player.kit == null and player.kit_modules().size() == 1 and player.has_kit(), "an unevolved Acólito carries only the origin object")
	_check(player.class_definition.basic_delivery == &"mage" and player._basic_delivery() == &"mage" and not player.is_mage(), "the basic attack type comes from the module, not from is_mage()")
	var body := ClassKitRegistry.base_actor_kind(&"acolyte")
	_check(player.character_animation.actor_kind == body, "the base body (or its fallback) is configured: %s" % player.character_animation.actor_kind)
	_check(not player.kit_owns_skill(&"priest_sanctuary") and player.kit_owns_skill(&"acolyte_prayer"), "only the base library belongs to an unevolved player")
	player.free()

# --- Snapshot (C1.9) ------------------------------------------------------------------

func _check_snapshot() -> void:
	# The snapshot knows only the fixture scripts of the manifest (not test inner classes).
	_install(FixtureKit.new(&"priest"))
	var player := _family_player(&"priest")
	player.origin_kit.set("ticks", 2.5)
	player.kit.set("ticks", 1.25)
	player.kit_time = 4.0
	var barrier := SnapshotTickBarrier.new()
	_check(barrier.acquire(player)["ok"], "barrier acquired on the family player")
	var captured := SnapshotRegistry.new().capture(player, barrier)
	_check(captured.get("ok", false), "exact capture with both modules: " + str(captured.get("detail", captured.get("error_code", ""))))
	if captured.get("ok", false):
		var restored := SnapshotRegistry.new().restore(bytes_to_var(var_to_bytes(captured["snapshot"])))
		_check(restored.get("ok", false), "exact restore with both modules: " + str(restored.get("detail", restored.get("error_code", ""))))
		if restored.get("ok", false):
			var copy: PlayerActor = restored["root"]
			_check(copy.origin_kit != null and copy.origin_kit.get_script() == FixtureBase and float(copy.origin_kit.get("ticks")) == 2.5 and copy.kit != null and float(copy.kit.get("ticks")) == 1.25 and copy.kit_time == 4.0, "both module states survive the exact format")
			_check(copy.origin_kit.get("calls").count("attach") == 1 and copy.kit_modules() == [copy.origin_kit, copy.kit], "restore keeps the order and does not re-run attach")
			SnapshotRegistry.new().activate(restored)
			copy.free()
	var projection := {"fields": {}, "excluded": {}}
	player.origin_kit.set("compact_blocker", "base_zone")
	var compact := SnapshotRegistry.new().capture(player, barrier, false, projection)
	_check(compact.get("error_code") == &"kit_compact_ineligible" and compact.get("detail") == "base_zone", "an origin blocker makes the compact cut ineligible")
	player.origin_kit.set("compact_blocker", "")
	var compact_ok := SnapshotRegistry.new().capture(player, barrier, false, projection)
	_check(compact_ok.get("ok", false), "without a blocker the projected cut is accepted: " + str(compact_ok.get("detail", compact_ok.get("error_code", ""))))
	barrier.release()
	player.free()
