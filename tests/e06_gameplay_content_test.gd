extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)
func occurrence(species: StringName, category: StringName, origin: StringName) -> MobOccurrence:
	var o := MobOccurrence.new()
	o.occurrence_id = "content_occurrence"
	o.mob_base_id = species
	o.category_id = category
	o.origin_id = origin
	return o
func _run() -> void:
	var base := BuildContentLoader.load_catalog()
	var loaded := BuildContentLoader.load_catalog(true, true)
	check(base["ok"] and loaded["ok"], "base/runtime catalogs validate")
	var catalog: BuildEffectCatalog = loaded["catalog"]
	var mobs := catalog.mob_catalog()
	# F10 Q4 adds the five forest phase species to the runtime catalog only.
	var forest := [&"forest_wolf", &"forest_boar", &"forest_stalker", &"forest_canopy_archer", &"forest_ancient_warden"]
	check(base["catalog"].mob_catalog().ids().size() == 8 and mobs.ids().size() == 16 and forest.all(func(id: StringName) -> bool: return mobs.get_definition(id) != null and base["catalog"].mob_catalog().get_definition(id) == null), "eight frozen species plus3new plus five forest")
	check(catalog.ids(&"equipment").size() == 92 and catalog.ids(&"card").size() == 6, "expanded89 equipment and preserved6 cards")
	for stage: int in range(1,7):
		for index: int in MobCatalog.CATEGORIES.size():
			var o := occurrence(&"test_gel", MobCatalog.CATEGORIES[index], PlaytestGameplay.origin(stage))
			var stats := mobs.stats_for_occurrence(o)
			var normal := mobs.stats_for_occurrence(occurrence(&"test_gel", &"normal", o.origin_id))
			check(stats["ok"] and stats["level"] == PlaytestGameplay.LEVELS[stage-1], "fixed origin level")
			var s: StatBreakdown = stats["breakdown"]
			var n: StatBreakdown = normal["breakdown"]
			check(is_equal_approx(s.value(&"max_hp"),n.value(&"max_hp") * [1.0,1.5,2.2,3.0,6.0][index]), "literal HP tier oracle")
			check(is_equal_approx(s.value(&"damage_dealt_multiplier"), [1.0,1.10,1.20,1.30,1.50][index]) and s.value(&"move_speed") == 154.0, "literal damage and category-independent slow speed")
		check(not mobs.level_for_occurrence(occurrence(&"test_gel",&"normal",&"unknown_origin"))["ok"], "unknown origin fails without fallback")
		var rng := RandomNumberGenerator.new(); rng.seed = stage
		var a := PlaytestGameplay.spawns(stage,rng)
		rng.seed = stage
		check(a == PlaytestGameplay.spawns(stage,rng), "same seed same exposure")
		var nav := ArenaNavigation.new(); nav.configure(PlaytestGameplay.BOUNDS,PlaytestGameplay.obstacles(stage),22)
		check(nav.is_walkable(PlaytestGameplay.ENTRANCE), "safe entrance is walkable")
		for row: Dictionary in a:
			var o := occurrence(row["species"],row["category"],PlaytestGameplay.origin(stage))
			check(o.validate(mobs)["ok"], "declared exposure category/origin valid")
			var route := nav.get_path(PlaytestGameplay.ENTRANCE,row["position"])
			check(not route.is_empty() and nav.is_walkable(route[-1]) and route[-1].distance_to(PlaytestGameplay.ENTRANCE)>420, "reachable spawn outside natural acquisition")
	var definition := mobs.get_definition(&"test_gel")
	definition.modifier_sources.append({"source_id": &"existing_increase", "increased": {&"max_hp":0.25, &"damage_dealt_multiplier":0.20}})
	var combined := MobCatalog.new(); check(combined.register_definition(definition)["ok"], "existing modifier fixture")
	var normal := combined.stats_for_occurrence(occurrence(definition.id,&"normal",&"trial_stage_1"))["breakdown"] as StatBreakdown
	var boss := combined.stats_for_occurrence(occurrence(definition.id,&"boss",&"trial_stage_1"))["breakdown"] as StatBreakdown
	check(is_equal_approx(boss.value(&"max_hp"),normal.value(&"max_hp")*6) and is_equal_approx(boss.value(&"damage_dealt_multiplier"),normal.value(&"damage_dealt_multiplier")*1.5), "tier factors compose exactly with preexisting increases")
	definition.origin_levels[&"trial_stage_1"] = 31
	check(not MobCatalog.new().register_definition(definition)["ok"], "origin cap validation")
	definition = mobs.get_definition(&"test_beast_master")
	definition.allowed_occurrence_categories.append(&"normal")
	check(not MobCatalog.new().register_definition(definition)["ok"], "normal summoner has no lower tier")
	var resolver := MobLootResolver.create(catalog,EquipmentLootProfiles.production(catalog))["resolver"] as MobLootResolver
	for stage: int in range(1,7):
		var result := resolver.roll(occurrence(&"test_gel",&"boss",PlaytestGameplay.origin(stage)),[0.0,1.0,0.0,0.99,0.0])
		check(result["ok"] and result["equipment_drops"].size()==1 and result["equipment_drops"][0]["item_level"] == PlaytestGameplay.LEVELS[stage-1] and result["card_id"]==&"", "loot and stats share fixed origin authority")
	for pair: Array in [[&"normal",&""],[&"rare",&"normal"],[&"elite",&"rare"],[&"rare_elite",&"elite"],[&"boss",&"rare_elite"]]:
		check(MobTierRules.lower_category(pair[0]) == pair[1], "literal lower-tier ordering")
	for species: StringName in PlaytestGameplay.PILOTS:
		var old: MobDefinition = base["catalog"].mob_catalog().get_definition(species)
		var copied := mobs.get_definition(species)
		check(old.aggro_radius == 0 and copied.aggro_radius == 420 and old.fixed_level == copied.fixed_level and old.card_id == copied.card_id, "copied pilot behavior without mutating frozen definition")
	var historical := ContentAuthoring.prepare(preload("res://tools/content/transform_bundle.gd").entries())
	var editorial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/transform_texts.json"))
	check(historical["ok"] and historical["mechanical_digest"] == editorial["mechanical_digest"], "neutral new mob fields preserve historical69 digest")
	var neutral := MobDefinition.new()
	neutral.id = &"digest_fixture"
	neutral.base_category = &"rare"
	neutral.allowed_occurrence_categories.assign([&"rare"])
	neutral.primary_attributes = {&"str":2,&"agi":2,&"vit":2,&"int":2,&"dex":2,&"luk":2}
	var neutral_entry: Array[Dictionary] = [{"origin":&"mob","definition":neutral,"purpose":"Signature invariant"}]
	var baseline := ContentAuthoring.prepare(neutral_entry)
	check(baseline["ok"], "neutral digest fixture validates")
	var effective := {&"origin_levels":{&"trial_stage_1":2}, &"encounter_tiers":true, &"aggro_radius":420.0, &"leash_radius":850.0, &"sight_timeout":5.0, &"visual_kind":&"gel", &"summons_companion":true}
	var invalid: MobDefinition = neutral.duplicate(true)
	invalid.aggro_radius = 420.0
	var invalid_entry: Array[Dictionary] = [{"origin":&"mob","definition":invalid,"purpose":"Invalid behavior pair"}]
	check(not ContentAuthoring.prepare(invalid_entry)["ok"], "aggro without larger leash is rejected")
	for field: StringName in effective:
		var reference: MobDefinition = neutral.duplicate(true)
		if field == &"aggro_radius": reference.leash_radius = 850.0
		var reference_entry: Array[Dictionary] = [{"origin":&"mob","definition":reference,"purpose":"Signature invariant"}]
		var reference_signature := ContentAuthoring.prepare(reference_entry)
		var changed: MobDefinition = reference.duplicate(true)
		changed.set(field,effective[field])
		var changed_entry: Array[Dictionary] = [{"origin":&"mob","definition":changed,"purpose":"Signature invariant"}]
		var signature := ContentAuthoring.prepare(changed_entry)
		check(signature["ok"] and signature["mechanical_digest"] != reference_signature["mechanical_digest"] and signature["briefs"][0]["mechanics"].has(String(field)), "effective mob value participates in digest: %s" % field)
	print("E06 gameplay content: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
