extends SceneTree
## Complete library plus explicit readiness overrides; never touches personal saves.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid(), "production catalog valid with isolated Sentinel data")
	var sentinel := catalog.evolution_definition(&"sentinel")
	_check(sentinel != null and sentinel.content_ready, "Integrated S7 exposes complete Sentinel library")
	_check(sentinel.origin_class_id == &"archer" and sentinel.entry_skill_id == &"sentinel_headshot", "origin and free entry fixed")
	_check(sentinel.exclusive_skill_ids == SentinelTuning.SKILL_IDS, "complete ordered nine-skill library")
	_check(CharacterState.ACTIVE_SLOT_COUNT == 5 and CharacterState.PASSIVE_SLOT_COUNT == 2, "slot contracts unchanged")
	var gates: Array[int] = [20, 20, 23, 25, 28, 31, 31, 34, 37]
	var active_count := 0
	var passive_count := 0
	for index: int in SentinelTuning.SKILL_IDS.size():
		var skill_id := SentinelTuning.SKILL_IDS[index]
		var metadata := catalog.skill_metadata(skill_id)
		var definition := ClassCatalog.skill_definition(skill_id)
		var maximum := SentinelTuning.max_rank(skill_id)
		_check(not metadata.is_empty() and definition != null, "metadata and execution definition: %s" % skill_id)
		_check(definition.is_rank_catalog_valid() and definition.ranks.size() == maximum, "typed valid exact ranks: %s" % skill_id)
		_check(metadata["allowed_base_classes"] == [&"archer"] and metadata["required_evolution_id"] == &"sentinel" and metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET, "exclusive library ownership: %s" % skill_id)
		_check(metadata["free_rank"] == (1 if index == 0 else 0) and metadata["max_purchased_rank"] == maximum - (1 if index == 0 else 0), "only Headshot R1 free: %s" % skill_id)
		_check(skill_id not in catalog.skill_ids_for_identity(&"archer") and skill_id not in ClassCatalog.skill_ids(&"archer"), "base Archer does not receive Sentinel skill: %s" % skill_id)
		_check(skill_id in catalog.skill_ids_for_identity(&"archer", &"sentinel") and skill_id not in catalog.skill_ids_for_identity(&"mage", &"mg_ar"), "identity isolation: %s" % skill_id)
		_check(SentinelTuning.values(skill_id, 0).is_empty() and SentinelTuning.values(skill_id, maximum + 1).is_empty(), "rank bounds: %s" % skill_id)
		_check(not ClassCatalog.sentinel_description(skill_id, 1).is_empty() and ClassCatalog.sentinel_description(skill_id, 0).is_empty(), "useful bounded pt-BR description: %s" % skill_id)
		if maximum == 3:
			passive_count += 1
			_check(ClassCatalog.passive_modifier_source(skill_id, maximum).is_empty(), "conditional passives cannot leak a static Build bonus: %s" % skill_id)
		else:
			active_count += 1
		var previous_sp := -1.0
		var previous_power := -1.0
		for rank: int in range(1, maximum + 1):
			var data := SentinelTuning.values(skill_id, rank)
			var resource := definition.rank_definition(rank)
			_check(metadata["rank_requirements"][rank]["job_level"] == gates[index], "job gate R%d: %s" % [rank, skill_id])
			_check(resource != null and resource.is_valid() and resource.sp_cost == data["sp_cost"] and resource.power == data["power"] and resource.cooldown == data["cooldown"] and resource.range == data["range"], "Resource uses central tuning R%d: %s" % [rank, skill_id])
			_check(float(data["sp_cost"]) >= previous_sp and float(data["power"]) > previous_power, "rank improves power and nondecreasing SP: %s" % skill_id)
			previous_sp = data["sp_cost"]
			previous_power = data["power"]
			for number: Variant in data.values():
				_check((number is float or number is int) and is_finite(float(number)) and float(number) >= 0.0, "finite nonnegative tuning R%d: %s" % [rank, skill_id])
			data["power"] = 100000.0
			resource.power = 100000.0
			resource.effect_ids.clear()
			_check(SentinelTuning.values(skill_id, rank)["power"] != 100000.0 and definition.rank_definition(rank).power != 100000.0 and not definition.rank_definition(rank).effect_ids.is_empty(), "returned Dictionary/Resource isolation: %s" % skill_id)
	_check(active_count == 7 and passive_count == 2, "seven active/two passive, not seven total")
	_check(SentinelTuning.values(&"unknown", 1).is_empty(), "unknown tuning ID rejected")
	_check(SentinelTuning.values(&"sentinel_piercing_shot", 1)["range"] == ClassCatalog.skill_definition(&"piercing_arrow").rank_definition(1).range, "Perfurante reach matches existing executable Archer skill")
	for skill_id: StringName in [&"sentinel_headshot", &"sentinel_concussion_shot"]:
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and definition.can_crit and definition.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED, "physical smart lock and normal accuracy/crit")
	for skill_id: StringName in [&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition.can_crit and definition.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "magic collision accuracy with explicit crit")
	_check(ClassCatalog.skill_definition(&"sentinel_explosive_shot").targeting == SkillDefinition.Targeting.SELF and ClassCatalog.skill_definition(&"sentinel_absolute_focus").targeting == SkillDefinition.Targeting.SELF, "preparation and buff self targeting")
	_check(ClassCatalog.skill_definition(&"sentinel_net_shot").targeting == SkillDefinition.Targeting.POINT and ClassCatalog.skill_definition(&"sentinel_piercing_shot").targeting == SkillDefinition.Targeting.DIRECTION, "ground AoE and cursor line distinct")
	_check(not SentinelTuning.values(&"sentinel_net_shot", 5).has("dex_coefficient") and not SentinelTuning.values(&"sentinel_explosive_shot", 5).has("dex_coefficient"), "exclusive INT recipes have no hidden DES coefficient")
	_sp_endpoints()
	_overrides()
	var hunter := catalog.evolution_definition(&"hunter")
	_check(hunter.content_ready and hunter.entry_skill_id == &"hunter_freezing_trap" and hunter.exclusive_skill_ids == HunterTuning.SKILL_IDS, "complete Hunter metadata coexists with unchanged Sentinel")
	for evolution_id: StringName in [&"sp_mg", &"sp_ar", &"mg_sp", &"ar_sp", &"ar_mg"]:
		_check(not catalog.evolution_definition(evolution_id).content_ready and catalog.evolution_definition(evolution_id).exclusive_skill_ids.is_empty(), "other placeholders unchanged: %s" % evolution_id)
	print("Sentinel catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _sp_endpoints() -> void:
	var endpoints := {&"sentinel_headshot": Vector2(14, 20), &"sentinel_observe": Vector2(8, 12), &"sentinel_piercing_shot": Vector2(16, 22), &"sentinel_net_shot": Vector2(18, 26), &"sentinel_explosive_shot": Vector2(20, 28), &"sentinel_concussion_shot": Vector2(12, 18), &"sentinel_absolute_focus": Vector2(24, 32)}
	for skill_id: StringName in endpoints:
		var bounds: Vector2 = endpoints[skill_id]
		_check(SentinelTuning.values(skill_id, 1)["sp_cost"] == bounds.x and SentinelTuning.values(skill_id, 5)["sp_cost"] == bounds.y, "SP endpoints exact: %s" % skill_id)
		var previous_increment := INF
		for rank: int in range(2, 6):
			var increment: float = SentinelTuning.values(skill_id, rank)["sp_cost"] - SentinelTuning.values(skill_id, rank - 1)["sp_cost"]
			_check(increment > 0.0 and increment < previous_increment, "sqrt SP increments diminish: %s R%d" % [skill_id, rank])
			previous_increment = increment

func _overrides() -> void:
	for ready: bool in [false, true]:
		var content_only := ProfileCatalog.pilot({}, {}, {&"sentinel": {"content_ready": ready}})
		_check(content_only.is_valid() and content_only.evolution_definition(&"sentinel").content_ready == ready and content_only.evolution_definition(&"sentinel").exclusive_skill_ids == SentinelTuning.SKILL_IDS, "content-only override retains declared library")
		_check(not content_only.skill_metadata(&"sentinel_headshot").is_empty(), "content-only override retains executable metadata")
	var fixture_skills := {&"fixture_sentinel_entry": {"allowed_base_classes": [&"archer"], "category": ProfileCatalog.ACTIVE, "wallet": ProfileCatalog.EVOLUTION_WALLET, "free_rank": 1, "max_purchased_rank": 4, "required_evolution_id": &"sentinel"}}
	var replaced := ProfileCatalog.pilot({}, fixture_skills, {&"sentinel": {"entry_skill_id": &"fixture_sentinel_entry", "exclusive_skill_ids": [&"fixture_sentinel_entry"], "content_ready": true}})
	_check(replaced.is_valid() and replaced.skill_metadata(&"sentinel_headshot").is_empty() and replaced.evolution_definition(&"sentinel").exclusive_skill_ids == [&"fixture_sentinel_entry"], "exclusive replacement does not mix production and fixture libraries")
	var definition := ProfileCatalog.pilot().evolution_definition(&"sentinel")
	definition.exclusive_skill_ids.clear()
	_check(ProfileCatalog.pilot().evolution_definition(&"sentinel").exclusive_skill_ids.size() == 9, "evolution returns copy")
