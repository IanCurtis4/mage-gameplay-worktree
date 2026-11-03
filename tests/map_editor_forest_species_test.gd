extends SceneTree
## F10 Q4 (contracts/f10_first_phase.md): the forest phase species. Four field
## species cover chase, charge, flank and ranged; the boss charges and summons.
## They reuse the published trial origins, so no new reward policy is opened.
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const FIELD := {&"forest_wolf":&"chaser",&"forest_boar":&"charger",&"forest_stalker":&"flanker",&"forest_canopy_archer":&"archer"}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_FOREST_SPECIES_CHECK "+id+" "+str(ok)+" "+str(detail))
func occurrence(id: StringName, category: StringName, origin: StringName) -> MobOccurrence:
	var made := MobOccurrence.new(); made.occurrence_id = "forest_check"; made.mob_base_id = id; made.category_id = category; made.origin_id = origin
	return made
func run() -> void:
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(),true)
	check("runtime_catalog_loads",loaded.ok,loaded.get("error_code",""))
	if not loaded.ok: finish(); return
	var mobs: MobCatalog = loaded.catalog.mob_catalog()
	var archetypes := true
	for id: StringName in FIELD:
		var definition := mobs.get_definition(id)
		if definition == null or definition.archetype != FIELD[id] or &"normal" not in definition.allowed_occurrence_categories: archetypes = false
	check("field_species_cover_the_four_roles",archetypes)
	var boss := mobs.get_definition(&"forest_ancient_warden")
	check("boss_is_boss_only_and_summons",boss != null and boss.allowed_occurrence_categories == [&"boss"] and boss.summons_companion and boss.archetype == &"charger")
	var levels: Array = []
	for origin: StringName in [&"trial_stage_1",&"trial_stage_2",&"trial_stage_3"]:
		var level := mobs.level_for_occurrence(occurrence(&"forest_wolf",&"normal",origin))
		levels.append(level.get("level",-1))
	check("levels_follow_the_existing_origins",levels == [2,4,6],levels)
	var valid := true
	for id: StringName in FIELD:
		for category: StringName in [&"normal",&"elite"]:
			if not occurrence(id,category,&"trial_stage_2").validate(mobs).ok: valid = false
	check("field_occurrences_validate",valid and occurrence(&"forest_ancient_warden",&"boss",&"trial_stage_3").validate(mobs).ok and not occurrence(&"forest_ancient_warden",&"normal",&"trial_stage_3").validate(mobs).ok)
	var options := Catalog.options(mobs)
	var offered: Dictionary = {}
	for option: Dictionary in options: offered[option.species_id+"/"+option.category] = true
	check("population_editor_offers_them",FIELD.keys().all(func(id: StringName) -> bool: return offered.has(String(id)+"/normal")) and offered.has("forest_ancient_warden/boss"))
	var rule := Catalog.rule({"species_id":"forest_wolf","category":"normal","origin_id":"trial_stage_1"})
	check("existing_reward_rule_applies",not rule.is_empty(),rule)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_FOREST_SPECIES_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
