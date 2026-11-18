extends SceneTree
## E08 P6 A1: exhaustive recipe coverage (every active skill of the production profile
## catalog, basic attacks, forest enemy attacks), immutability, fallback, element
## override and planned audio cue coverage. Presentation data only.
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
const Bridge = preload("res://scripts/presentation/presentation_event_bridge.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _initialize() -> void: _run.call_deferred()

## E09 C1 (Sol, 17/11): kit skills reach the catalog and their recipes through the seam
## (ClassKitRegistry), never through RECIPES. The E08 audio palette got no new cue in E09;
## these kit kinds have no planned family cue (neither family x element nor family x
## physical) and fall back to the kind cue, or stay silent where the kind has none. Exact
## list, documented in docs/epics/e09_contract.md (C1, note on the E08 recipe test): a gap
## that gains a cue must leave this list.
const KIT_AUDIO_GAPS: Array[String] = ["paladin_oath/impact", "thaumaturge_votive_circle/impact", "thaumaturge_healing_refraction/heal", "arcane_blade_prism_specter/summon", "acolyte_shadow_seal/impact", "priest_sanctuary/impact"]

## Library of every identity (base classes and their evolutions), split by category and
## by source: the E08 base catalog and the E09 kit skills (ClassKitRegistry.skill_owner).
func _library() -> Dictionary:
	var catalog := ProfileCatalog.pilot()
	var active: Array[StringName] = []
	var passive: Array[StringName] = []
	var kit_active: Array[StringName] = []
	var kit_passive: Array[StringName] = []
	for base: StringName in [&"swordsman", &"mage", &"archer", &"acolyte"]:
		var identities: Array[StringName] = [&""]
		for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(base): identities.append(evolution.id)
		for evolution: StringName in identities:
			for skill: StringName in catalog.skill_ids_for_identity(base, evolution):
				var is_active: bool = catalog.skill_metadata(skill)["category"] == ProfileCatalog.ACTIVE
				var from_kit := not ClassKitRegistry.skill_owner(skill).is_empty()
				var bucket := (kit_active if is_active else kit_passive) if from_kit else (active if is_active else passive)
				if skill not in bucket: bucket.append(skill)
	return {"active":active, "passive":passive, "kit_active":kit_active, "kit_passive":kit_passive}

## Expected kit skills of the production catalog: the seven of each ready kit, by slot category.
func _expected_kit_skills() -> Dictionary:
	var active: Array[StringName] = []
	var passive: Array[StringName] = []
	for kit: StringName in ClassKitRegistry.ids():
		if not ClassKitRegistry.ready_for_play(kit): continue
		# E10a: a pure kit is offered (and its skills published) only with a ready base module.
		var origin := ClassKitRegistry.origin(kit)
		if IdentityIds.is_registered_base(origin) and not ProfileCatalog.pilot().base_class_is_available(origin): continue
		var skills := ClassKitRegistry.skill_ids(kit)
		for index: int in skills.size():
			(active if ClassKitRegistry.SLOT_CATEGORIES[index] == ProfileCatalog.ACTIVE else passive).append(skills[index])
	# E10a T5 (A10 item 3, A11): the library of a registered base that is available is published too.
	for base: StringName in ClassBaseRegistry.ids():
		if not ProfileCatalog.pilot().base_class_is_available(base): continue
		var base_skills := ClassBaseRegistry.skill_ids(base)
		for index: int in base_skills.size():
			(active if ClassBaseRegistry.SKILL_CATEGORIES[base][index] == ProfileCatalog.ACTIVE else passive).append(base_skills[index])
	return {"active":active, "passive":passive}

static func _sorted(values: Array[StringName]) -> Array[StringName]:
	var copy: Array[StringName] = values.duplicate()
	copy.sort()
	return copy

## Bridge kinds a recipe can actually produce (mirrors the bridge emitters).
func _kinds(recipe: Dictionary) -> Array[StringName]:
	var kinds: Array[StringName] = []
	var family: StringName = recipe.family
	if bool(recipe.periodic):
		kinds.append(&"impact")
		return kinds
	match family:
		&"projectile": kinds.assign([&"projectile_launch", &"impact"])
		&"melee": kinds.assign([&"melee_swing", &"impact"])
		&"impact": kinds.assign([&"impact"])
		&"area": kinds.assign([&"area_start", &"impact"])
		&"trap": kinds.assign([&"area_start", &"trap_trigger", &"impact"])
		&"movement": kinds.assign([&"movement", &"impact"])
		&"teleport": kinds.assign([&"teleport"])
		&"summon": kinds.assign([&"summon"])
		&"charge": kinds.assign([&"charge_start"])
		&"heal": kinds.assign([&"heal"])
	if bool(recipe.commit_effect): kinds.append(&"effect_start")
	# A signature names the kind its skill really emits (blood rift swings via `slash`).
	if bool(recipe.is_signature) and recipe.signature_kind not in kinds: kinds.append(recipe.signature_kind)
	return kinds

func _run() -> void:
	var library := _library()
	var active: Array[StringName] = library.active
	check(active.size() == 71, "production catalog exposes 71 active skills, got %d" % active.size())
	check(library.passive.size() == 22, "production catalog exposes 22 passive skills, got %d" % library.passive.size())
	var subjects: Array[Dictionary] = []
	for skill: StringName in active:
		var recipe := Recipes.recipe(skill)
		check(Recipes.RECIPES.has(skill) and not recipe.generic, "active skill has its own recipe: " + String(skill))
		check(recipe.family in Recipes.FAMILIES and recipe.element in Recipes.ELEMENTS, "family/element valid: " + String(skill))
		subjects.append(recipe)
	# E09 C1 (A15 exact counts): the four ready kits add 5 actives and 2 passives each, the
	# exact skills of the registry table; their recipe comes from the kit module (seam).
	var kit_active: Array[StringName] = library.kit_active
	var expected_kit := _expected_kit_skills()
	# E10a A9/A11: the four E09 kits, the Sacerdote (T6) and the Cultista (T7) are ready (4 + 1 + 1 = 6).
	check(ClassKitRegistry.ids().filter(func(kit: StringName) -> bool: return ClassKitRegistry.ready_for_play(kit)).size() == 6, "the four E09 kits, the E10a Sacerdote and the Cultista are ready in the production catalog")
	# With the Acólito base ready the catalog also offers the pure kits (A10.2, A11): 20/8 of the E09 kits, plus 6/2 of
	# the Acólito base, 5/2 of the Sacerdote and 5/2 of the Cultista.
	check(kit_active.size() == 36 and library.kit_passive.size() == 14, "the kits and the Acólito base offered by the catalog expose 36 active and 14 passive skills (20/8 of the four E09 kits, plus 6/2 of the Acólito base, 5/2 of the Sacerdote and 5/2 of the Cultista), got %d/%d" % [kit_active.size(), library.kit_passive.size()])
	check(_sorted(kit_active) == _sorted(expected_kit.active) and _sorted(library.kit_passive) == _sorted(expected_kit.passive), "kit skills of the catalog are exactly the registry table of the ready kits")
	for skill: StringName in kit_active:
		var recipe := Recipes.recipe(skill)
		var row := ClassKitRegistry.feedback_recipe(skill)
		check(not Recipes.RECIPES.has(skill) and row.size() == 4 and not recipe.generic and recipe.family == row[0] and recipe.element == row[1] and not recipe.is_signature, "kit active skill has its own recipe through the seam: " + String(skill))
		check(recipe.family in Recipes.FAMILIES and recipe.element in Recipes.ELEMENTS, "family/element valid: " + String(skill))
		subjects.append(recipe)
	# Kit basic attacks: the kit row (C1.2) or the origin row, reported under the kit variant.
	for kit: StringName in ClassKitRegistry.ids():
		var kit_basic := Recipes.recipe(&"basic_attack", kit)
		check(not kit_basic.generic and kit_basic.variant == kit and bool(kit_basic.basic_hit), "kit basic attack recipe: " + String(kit))
		subjects.append(kit_basic)
	# Basic attacks: identity-free default plus the three class variants.
	var expected_basics := {&"swordsman":[&"melee", &"physical"], &"mage":[&"projectile", &"arcane"], &"archer":[&"projectile", &"physical"]}
	for variant: StringName in expected_basics:
		var basic := Recipes.recipe(&"basic_attack", variant)
		check(not basic.generic and [basic.family, basic.element] == expected_basics[variant] and basic.variant == variant, "basic attack variant " + String(variant))
		subjects.append(basic)
	check(Recipes.recipe(&"basic_attack").family == &"melee" and Recipes.recipe(&"basic_attack", &"unknown_class").variant == &"", "identity-free basic attack default; unknown variant falls back to the base row")
	check(Recipes.is_melee(&"basic_attack", &"swordsman") and not Recipes.is_melee(&"basic_attack", &"mage") and not Recipes.is_melee(&"basic_attack", &"archer"), "only the Swordsman basic is a melee swing")
	# Forest enemies: claw/arrow basics, charger burst and companion call (warden signatures).
	var claw := Recipes.recipe(&"enemy_claw", &"forest_wolf")
	var arrow := Recipes.recipe(&"enemy_arrow", &"forest_canopy_archer")
	check(not claw.generic and claw.family == &"melee" and not arrow.generic and arrow.family == &"projectile", "forest enemy basic attacks mapped")
	# P7-C5: only basic attacks (class basics, enemy claw) are flagged for the AA hit cue and the white hit burst.
	# P7-C7: enemy_arrow (ranged enemy basic) moved from the "not a basic hit" list to this one; all ten classes/evolutions are listed.
	for entry: Array in [[&"basic_attack", &"archer"], [&"basic_attack", &"mage"], [&"basic_attack", &"swordsman"], [&"basic_attack", &""], [&"enemy_claw", &"forest_wolf"], [&"enemy_arrow", &"forest_canopy_archer"]]:
		check(bool(Recipes.recipe(entry[0], entry[1]).basic_hit), "recipe flagged as a basic hit: %s/%s" % [entry[0], entry[1]])
	# P7-C7: the auto-attack of every one of the ten classes/evolutions is `basic_attack` and maps to the white hit; AA cues follow the weapon.
	check(Recipes.BASIC_ATTACK_OWNERS.size() == 10, "ten classes/evolutions own a basic attack")
	for owner: StringName in Recipes.BASIC_ATTACK_OWNERS:
		var basic := Recipes.recipe(&"basic_attack", owner)
		check(bool(basic.basic_hit) and not basic.generic and basic.variant == owner, "class auto-attack maps to basic_hit: " + String(owner))
		var impact_cue: StringName = Catalog.candidates(&"impact", basic)[0]
		check(impact_cue == (&"p6.aa.hit_blunt" if owner in [&"swordsman", &"defender", &"berserker"] else &"p6.aa.hit_body"), "auto-attack hit cue by weapon: " + String(owner))
		var launch: Array = Catalog.candidates(&"projectile_launch", basic)
		check((launch[0] == &"p6.aa.bow_release") == (owner in [&"archer", &"sentinel", &"hunter"]), "bow release only for bow classes: " + String(owner))
		# An impact/launch of a player class with an empty skill id is derived to the auto-attack (presentation layer only).
		for kind: StringName in [&"impact", &"projectile_launch"]:
			var derived := Recipes.for_event({"kind":kind, "skill_id":&"", "payload":{"actor_variant":String(owner)}})
			check(derived.skill_id == &"basic_attack" and bool(derived.basic_hit), "empty skill id derives basic_attack: %s/%s" % [owner, kind])
	check(Recipes.for_event({"kind":&"cast_cancel", "skill_id":&"", "payload":{"actor_variant":"archer"}}).skill_id == &"", "empty skill ids of other kinds are not derived")
	check(not bool(Recipes.for_event({"kind":&"impact", "skill_id":&"", "payload":{"actor_variant":"forest_wolf"}}).basic_hit), "an empty skill id of an enemy is not derived")
	for skill: StringName in [&"double_shot", &"fireball", &"slash", &"brutal_strike", &"enemy_charge", &"totally_unknown"]:
		check(not bool(Recipes.recipe(skill).basic_hit), "skill is not a basic hit: " + String(skill))
	check(Catalog.candidates(&"impact", Recipes.recipe(&"basic_attack", &"archer")) == [&"p6.aa.hit_body", &"p6.impact.physical", &"world.impact"], "basic hit chain: AA cue, family cue, kind cue")
	check(Catalog.candidates(&"projectile_launch", Recipes.recipe(&"basic_attack", &"archer"))[0] == &"p6.aa.bow_release" and Catalog.candidates(&"melee_swing", Recipes.recipe(&"basic_attack", &"swordsman"))[0] == &"p6.melee.physical", "bow release only on the Archer launch; the melee swing keeps its whoosh")
	var charge := Recipes.recipe(&"enemy_charge", &"forest_ancient_warden")
	var summon := Recipes.recipe(&"enemy_summon", &"forest_ancient_warden")
	check(charge.family == &"charge" and charge.signature == &"warden_charge" and charge.signature_kind == &"charge_start", "warden charge signature")
	check(summon.family == &"summon" and summon.signature == &"warden_summon" and summon.signature_kind == &"summon", "warden summon signature")
	check(Recipes.recipe(&"enemy_charge", &"forest_boar").signature == &"" and Recipes.recipe(&"enemy_charge", &"forest_boar").family == &"charge", "other chargers share the generic charge recipe without the warden signature")
	subjects.append_array([claw, arrow, charge, summon, Recipes.recipe(&"enemy_charge")])
	# Derived damage ids published by impacts (ticks, detonations) are mapped too.
	for derived: StringName in [&"cone_slash", &"burn_tick", &"bleed_tick", &"berserker_blood_rift_tick", &"berserker_rupture_detonation", &"hunter_thorn_bleed", &"hunter_exploit", &"geometer_triangle_maintenance", &"geometer_incidence", &"geometer_wall_entry", &"geometer_wall_exit", &"blood_thirst"]:
		check(not Recipes.recipe(derived).generic, "derived feedback id mapped: " + String(derived))
		subjects.append(Recipes.recipe(derived))
	check(Recipes.recipe(&"burn_tick").periodic and Recipes.recipe(&"bleed_tick").periodic and not Recipes.recipe(&"fireball").periodic, "DOT ticks are periodic recipes")
	# Signatures: exactly the contract list, 1-2 per class, attached to an emitted bridge kind.
	var expected_signatures := {&"mage":[&"fireball", &"teleport"], &"swordsman":[&"slash", &"terrifying_shout"], &"archer":[&"arrow_rain", &"explosive_trap"], &"defender":[&"defender_reprisal_wave", &"defender_counterstroke"], &"berserker":[&"berserker_blood_rift", &"berserker_wound_leap"], &"elementalist":[&"elementalist_tri_nova", &"elementalist_lightning_arc"], &"spiritualist":[&"spiritualist_dissipation"], &"mg_ar":[&"geometer_collapse", &"geometer_triangulation"], &"sentinel":[&"sentinel_explosive_shot", &"sentinel_headshot"], &"hunter":[&"hunter_freezing_trap", &"hunter_covering_shot"], &"forest_ancient_warden":[&"enemy_charge", &"enemy_summon"]}
	var by_owner := {}
	for id: StringName in Recipes.signature_ids():
		var signature := Recipes.signature(id)
		var owner: StringName = signature.owner
		if not by_owner.has(owner): by_owner[owner] = []
		by_owner[owner].append(signature.skill_id)
		var recipe := Recipes.recipe(signature.skill_id, owner if owner == &"forest_ancient_warden" else &"")
		check(recipe.signature == id and recipe.is_signature and recipe.signature_kind == signature.kind and signature.kind in Bridge.KINDS, "signature wired to its skill and a real bridge kind: " + String(id))
		check(Catalog.PLANNED.has(StringName("p6.sig." + String(id))) and Catalog.candidates(signature.kind, recipe)[0] == StringName("p6.sig." + String(id)), "signature cue planned and selected first: " + String(id))
	for owner: StringName in expected_signatures:
		var listed: Array = by_owner.get(owner, [])
		listed.sort(); var wanted: Array = expected_signatures[owner].duplicate(); wanted.sort()
		check(listed == wanted, "contract signatures for " + String(owner) + ": " + str(listed))
	check(by_owner.size() == expected_signatures.size(), "no signature outside the contract list")
	# Immutability: callers receive copies of rows, nested audio chains and signatures.
	var copy := Recipes.recipe(&"fireball")
	copy.family = &"melee"; copy.element = &"ice"; (copy.audio[&"impact"] as Array).clear()
	var fresh := Recipes.recipe(&"fireball")
	check(fresh.family == &"projectile" and fresh.element == &"fire" and not (fresh.audio[&"impact"] as Array).is_empty(), "recipe copies cannot mutate the catalog")
	var signature_copy := Recipes.signature(&"mage_fireball"); signature_copy.kind = &"death"
	check(Recipes.signature(&"mage_fireball").kind == &"impact", "signature copies cannot mutate the catalog")
	var ids := Recipes.known_ids(); ids.clear()
	check(not Recipes.known_ids().is_empty(), "id list is a copy")
	# Unknown ids: generic recipe keeps the pre-P6 kind cue only.
	var unknown := Recipes.recipe(&"not_a_skill")
	check(unknown.generic and unknown.family == &"impact" and unknown.element == &"physical" and not unknown.is_signature, "unknown id gets the generic recipe")
	for kind: StringName in [&"impact", &"cast_start", &"projectile_launch", &"area_start", &"teleport", &"death"]:
		check(Catalog.candidates(kind, unknown) == [Catalog.for_kind(kind)], "generic recipe uses only the current kind cue: " + String(kind))
	check(Catalog.candidates(&"melee_swing", unknown).is_empty() and Catalog.candidates(&"trap_trigger", unknown) == [&"world.area_end"], "new kinds without a cue stay silent; trap trigger keeps the trap's current sound")
	check(Recipes.for_event({"skill_id":&"fireball", "payload":{"source_variant":&"mage"}}).element == &"fire" and Recipes.for_event({}).generic and Recipes.for_event({"skill_id":"fireball", "payload":[]}).generic, "event recipe tolerates malformed DTO fields")
	# Element override: Elementalist/Geometer payload element wins only when valid.
	var nova := Recipes.for_event({"skill_id":&"elementalist_tri_nova", "payload":{"element":&"ice"}})
	check(nova.element == &"ice" and nova.signature == &"elementalist_tri_nova" and Catalog.candidates(&"impact", nova).has(&"p6.impact.ice"), "explicit pulse element overrides the default and reselects cues")
	check(Recipes.for_event({"skill_id":&"geometer_trace", "payload":{"element":"lightning"}}).element == &"lightning", "string element accepted")
	for bad: Variant in [&"plasma", 7, null, ["fire"]]:
		check(Recipes.for_event({"skill_id":&"elementalist_tri_nova", "payload":{"element":bad}}).element == &"arcane", "invalid element ignored: " + str(bad))
	check(Recipes.element_override(Recipes.recipe(&"fireball"), {}) == &"fire", "no payload element keeps the recipe element")
	# Audio coverage: every recipe/kind it can produce resolves to a planned family cue
	# first, ending in the current kind cue where one exists; every planned cue is used.
	var used := {}
	var gaps_seen: Array[String] = []
	for recipe: Dictionary in subjects:
		check(recipe.audio is Dictionary and not recipe.audio.is_empty(), "recipe exposes its audio chains: " + String(recipe.skill_id))
		for kind: StringName in _kinds(recipe):
			var chain := Catalog.candidates(kind, recipe)
			var key := "%s/%s" % [recipe.skill_id, kind]
			if key in KIT_AUDIO_GAPS:
				# Registered E09 kit gap: a kit skill whose chain has no planned cue at all.
				gaps_seen.append(key)
				check(not ClassKitRegistry.skill_owner(recipe.skill_id).is_empty() and not chain.any(func(id: StringName) -> bool: return Catalog.PLANNED.has(id)), "registered kit audio gap still has no planned cue: %s: %s" % [key, chain])
			else:
				check(not chain.is_empty() and Catalog.PLANNED.has(chain[0]), "planned cue first for %s: %s" % [key, chain])
			var fallback := Catalog.for_kind(kind)
			if fallback == &"": fallback = Catalog.KIND_FALLBACK.get(kind, &"")
			check(fallback == &"" or chain.back() == fallback, "chain ends with the current kind cue: %s/%s" % [recipe.skill_id, kind])
			for id: StringName in chain: used[id] = true
		var cast := Catalog.candidates(&"cast_start", recipe)
		check(Catalog.PLANNED.has(cast[0]) and cast.back() == &"world.cast_start", "cast chain per element: " + String(recipe.skill_id))
		for id: StringName in cast: used[id] = true
		for id: StringName in Catalog.candidates(&"heal", recipe): used[id] = true
	gaps_seen.sort()
	var gaps_wanted := KIT_AUDIO_GAPS.duplicate()
	gaps_wanted.sort()
	check(gaps_seen == gaps_wanted, "kit audio gaps are exactly the registered list: " + str(gaps_seen))
	# E10a C1.8: light and shadow get no P6 cue of their own (no new audio). Exact list of the
	# family x element gaps: every cue family lacks both; the families below fall back to
	# family x physical, the others (dot, heal, summon, teleport, trap) to the kind cue or silence.
	var physical_fallback: Array[StringName] = [&"area", &"buff", &"cast", &"charge", &"impact", &"melee", &"movement", &"projectile"]
	for family: StringName in [&"area", &"buff", &"cast", &"charge", &"dot", &"heal", &"impact", &"melee", &"movement", &"projectile", &"summon", &"teleport", &"trap"]:
		for element: StringName in [&"light", &"shadow"]:
			check(not Catalog.PLANNED.has(StringName("p6.%s.%s" % [family, element])), "registered E10a gap: no p6.%s.%s cue" % [family, element])
		check(Catalog.PLANNED.has(StringName("p6.%s.physical" % family)) == (family in physical_fallback), "light/shadow %s falls back to family x physical only where that cue exists" % family)
	for id: StringName in Catalog.candidates(&"impact", Recipes.for_event({"skill_id":&"basic_attack", "payload":{"source_variant":"archer", "critical":true}})): used[id] = true # P7-C5: critical basic hit
	for id: StringName in Catalog.planned_cue_ids():
		check(used.has(id), "planned cue reachable by a recipe: " + String(id))
	# Planned definitions: own ids/paths, effects channel, bounded priorities; EVENTS intact.
	var paths := {}
	for id: StringName in Catalog.planned_cue_ids():
		var definition := Catalog.definition(id)
		check(not Catalog.EVENTS.has(id) and definition.channel == &"effects" and int(definition.priority) >= 0 and int(definition.priority) <= 60 and String(definition.path).begins_with("res://assets/audio/e08/p6/") and String(definition.path).ends_with(".wav") and not paths.has(definition.path), "planned cue definition valid: " + String(id))
		paths[definition.path] = true
		check((id in Catalog.ids()) == ResourceLoader.exists(definition.path), "planned cue enters ids() only once its WAV exists: " + String(id))
	var expected_events := {&"world.cast_start":[20, "world_cast_start"], &"world.cast_cancel":[30, "world_cast_cancel"], &"world.projectile_launch":[10, "world_projectile_launch"], &"world.impact":[40, "world_impact"], &"world.area_start":[20, "world_area_start"], &"world.area_end":[20, "world_area_end"], &"world.teleport":[50, "world_teleport"], &"world.death":[60, "world_death"], &"world.revive":[60, "world_revive"], &"ui.confirm":[50, "ui_confirm"], &"ui.cancel":[50, "ui_cancel"], &"ambience.stage":[0, "ambience_stage"], &"ambience.forest":[0, "ambience_forest"]}
	check(Catalog.EVENTS.size() == 13, "the 13 existing cues are kept")
	for id: StringName in expected_events:
		var definition := Catalog.definition(id)
		check(definition.priority == expected_events[id][0] and definition.path == "res://assets/audio/e08/%s.wav" % expected_events[id][1] and id in Catalog.ids(), "existing cue unchanged: " + String(id))
	check(Catalog.LIMITS == {&"effects":24, &"interface":4, &"ambience":4}, "voice limits unchanged")
	print("E08 feedback recipes: %s (%d checks, failures=%d)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures else 0)
