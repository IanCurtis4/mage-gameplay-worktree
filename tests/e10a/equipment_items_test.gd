extends SceneTree
## E10a T9 (C6): the three Acólito-family items as normal items of the current catalog, the
## book as the Acólito starter (A12), the cloth and shared armors open to the family (D9), with
## art, grips and 128 px icons. Real catalog, real loot resolver.
const IDS: Array[StringName] = [&"prayer_book", &"halo_scepter", &"eye_reliquary"]
const FAMILY: Array[StringName] = [&"acolyte", &"priest", &"cultist"]
const CLOTH_IDENTITIES: Array[StringName] = [&"mage", &"elementalist", &"spiritualist", &"mg_ar", &"acolyte", &"priest", &"cultist"]
## id -> [quality, min level, max level, starter, art size at x4, logical grip, angle]
const EXPECTED := {
	&"prayer_book": [&"common", 2, 5, true, Vector2(80, 120), Vector2(10, 12), 0.0],
	&"halo_scepter": [&"rare", 6, 10, false, Vector2(60, 168), Vector2(7.5, 33), 0.2],
	&"eye_reliquary": [&"rare", 6, 10, false, Vector2(56, 152), Vector2(7, 7), 0.0],
}
const CLOTH: Array[StringName] = [&"class_set_mage_head", &"class_set_mage_torso", &"class_set_mage_feet"]
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func snapshot(identity: StringName) -> BuildSnapshot:
	var value := BuildSnapshot.new()
	var pure := IdentityIds.is_base_class(identity)
	value.base_class_id = identity if pure else IdentityIds.evolution_origin(identity)
	value.evolution_id = &"" if pure else identity
	value.attribute_allocations = {&"str": 0, &"agi": 0, &"vit": 0, &"int": 0, &"dex": 0, &"luk": 0}
	return value
func _run() -> void:
	var loaded := BuildContentLoader.load_catalog(true)
	check(loaded["ok"], "expanded catalog loads with the three family items")
	if not loaded["ok"]:
		quit(1)
		return
	var catalog: BuildEffectCatalog = loaded["catalog"]
	catalog_checks(catalog)
	eligibility_checks(catalog)
	restriction_checks(catalog)
	armor_checks(catalog)
	starter_checks()
	loot_checks(catalog)
	art_checks(catalog)
	hand_checks(catalog)
	print("E10a equipment items: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func catalog_checks(catalog: BuildEffectCatalog) -> void:
	check(catalog.ids(&"equipment").size() == 92, "92 equipment definitions (89 previous plus three) (%d)" % catalog.ids(&"equipment").size())
	for id: StringName in IDS:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		check(item != null, "definition exists " + String(id))
		if item == null:
			continue
		var row: Array = EXPECTED[id]
		check(item.slot == &"main_hand" and item.item_kind == &"weapon" and item.hand_usage == &"one_hand", "main hand, one hand weapon " + String(id))
		check(item.quality_id == row[0] and item.min_item_level == row[1] and item.max_item_level == row[2] and item.item_level == row[1], "current quality and power band " + String(id))
		check(item.set_id.is_empty() and item.starter == row[3] and item.origin_id == &"demo_arena", "plain item without set, starter only for the book " + String(id))
		check(item.allowed_origins == ([&"acolyte"] as Array[StringName]), "origin acolyte only " + String(id))
		check(item.allowed_identities == FAMILY, "the three family identities " + String(id))
		check(item.effects.size() == 1 and item.effects[0].capability() == &"stat" and item.effects[0].allowed_origins == ([&"acolyte"] as Array[StringName]) and item.socket_capacity == 1, "stat-only recipe with one socket " + String(id))
		check(not item.display_name.is_empty() and not item.flavor_text.is_empty() and item.display_name != String(id), "pt-BR visible text " + String(id))
		check(EquipmentEligibilityRules.validate(EquipmentEligibilityRules.for_resource(item))["ok"], "valid eligibility policy " + String(id))
		check(item.visual_key == id and id in EquipmentAttachmentVisual.SUPPORTED, "own visual key in SUPPORTED " + String(id))
		var profile := EquipmentArtCatalog.e09_prop_profile(id)
		var live: Dictionary = EquipmentAttachmentVisual.PROFILES.get(id, {})
		check(not live.is_empty() and live.size == profile.size and live.grip == profile.grip and is_equal_approx(float(live.angle), float(profile.angle)), "PROFILES mirror hand_rigs.json props " + String(id))
func eligibility_checks(catalog: BuildEffectCatalog) -> void:
	var all: Array[StringName] = EquipmentEligibilityRules.eligible_identities()
	check(all.size() == 17, "seventeen eligible identities (%d)" % all.size())
	for id: StringName in IDS:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		for identity: StringName in all:
			var allowed := BuildEffectCatalog.definition_allowed(item, snapshot(identity))
			check(allowed == (identity in FAMILY), "family-only eligibility %s for %s" % [id, identity])
## A13: the origin restriction accepts every base (acolyte included) and still refuses reserved ids.
func restriction_checks(catalog: BuildEffectCatalog) -> void:
	var source := catalog.get_definition(&"equipment", &"prayer_book") as EquipmentDefinition
	var cases := [
		[&"acolyte", &"acolyte", true, "acolyte accepted as equipment and effect origin"],
		[&"mage", &"mage", true, "mage still accepted"],
		[&"rogue", &"acolyte", false, "reserved rogue refused as equipment origin"],
		[&"acolyte", &"rogue", false, "reserved rogue refused as effect origin"],
	]
	for row: Array in cases:
		var item: EquipmentDefinition = source.duplicate(true)
		item.id = &"t9_probe"
		item.allowed_origins = [row[0]] as Array[StringName]
		item.allowed_identities = [] as Array[StringName]
		item.effects[0].allowed_origins = [row[1]] as Array[StringName]
		var registered := BuildEffectCatalog.new().register_definition(&"equipment", item)
		check(registered["ok"] == row[2], String(row[3]))
		if not row[2]:
			check(registered.get("error_code") == &"invalid_restrictions", "refusal code for " + String(row[3]))
	var duplicate: EquipmentDefinition = source.duplicate(true)
	duplicate.allowed_origins = [&"acolyte", &"acolyte"] as Array[StringName]
	check(not BuildEffectCatalog.new().register_definition(&"equipment", duplicate)["ok"], "duplicate origin stays refused")
func armor_checks(catalog: BuildEffectCatalog) -> void:
	for id: StringName in CLOTH:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		check(item != null and item.allowed_origins == ([&"mage", &"acolyte"] as Array[StringName]) and item.allowed_identities == CLOTH_IDENTITIES, "cloth armor lists gain the family " + String(id))
		if item == null:
			continue
		check(item.effects.size() == 1 and item.effects[0].allowed_origins == ([&"mage", &"acolyte"] as Array[StringName]), "cloth armor effect origin gains the family " + String(id))
		for identity: StringName in EquipmentEligibilityRules.eligible_identities():
			check(BuildEffectCatalog.definition_allowed(item, snapshot(identity)) == (identity in CLOTH_IDENTITIES), "cloth eligibility %s for %s" % [id, identity])
	# Shared pieces carry no lists, so they already accept every identity, the family included.
	for tier: String in ["low", "mid", "high"]:
		for part: String in ["head", "torso", "feet"]:
			var shared := catalog.get_definition(&"equipment", StringName("shared_set_%s_%s" % [tier, part])) as EquipmentDefinition
			check(shared != null and shared.allowed_origins.is_empty() and shared.allowed_identities.is_empty(), "shared armor has no restriction list shared_set_%s_%s" % [tier, part])
			for identity: StringName in FAMILY:
				check(shared != null and BuildEffectCatalog.definition_allowed(shared, snapshot(identity)), "shared armor is open to %s %s_%s" % [identity, tier, part])
	# Class-specific sets of other origins stay closed to the family.
	for id: StringName in [&"class_set_swordsman_torso", &"class_set_archer_head", &"class_set_elementalist_torso"]:
		var other := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		for identity: StringName in FAMILY:
			check(not BuildEffectCatalog.definition_allowed(other, snapshot(identity)), "%s stays closed to %s" % [id, identity])
func starter_checks() -> void:
	var profiles := ProfileCatalog.pilot()
	var starters := profiles.starter_equipment(&"acolyte")
	var main: Variant = starters.get(EquipmentRules.legacy_position(&"main_hand"))
	check(main == &"prayer_book", "the Acólito starts with the prayer book (%s)" % str(main))
	for base: StringName in [&"swordsman", &"mage", &"archer"]:
		check(not profiles.starter_equipment(base).values().has(&"prayer_book"), "the book is not a starter of " + String(base))
func loot_checks(catalog: BuildEffectCatalog) -> void:
	var table := EquipmentLootProfiles.production(catalog)
	for category: StringName in EquipmentLootProfiles.CHANCES:
		for id: StringName in IDS:
			check((table.profiles[category]["equipment_weights"] as Dictionary).has(id), "production weights include %s in %s" % [id, category])
	var resolver := MobLootResolver.create(catalog, table)
	check(resolver["ok"], "production resolver stays valid")
	if not resolver["ok"]:
		return
	var seen: Dictionary = {}
	var out_of_band := 0
	var all_ok := true
	for stage: int in range(1, 7):
		for category: StringName in MobCatalog.CATEGORIES:
			var occurrence := MobOccurrence.new()
			occurrence.occurrence_id = "t9_loot"
			occurrence.mob_base_id = &"test_gel"
			occurrence.category_id = category
			occurrence.origin_id = PlaytestGameplay.origin(stage)
			for quality_pick: float in [0.05, 0.5, 0.95, 0.999]:
				for step: int in 50:
					var result: Dictionary = resolver["resolver"].roll(occurrence, [0.0, quality_pick, step / 50.0 + 0.01, 0.0, 1.0])
					if not result["ok"] or result["equipment_drops"].size() != 1:
						all_ok = false
						continue
					var drop: Dictionary = result["equipment_drops"][0]
					var id: StringName = drop["definition_id"]
					if id in IDS:
						var row: Array = EXPECTED[id]
						if int(drop["item_level"]) < int(row[1]) or int(drop["item_level"]) > int(row[2]) or drop["quality_id"] != row[0]:
							out_of_band += 1
						seen[id] = int(seen.get(id, 0)) + 1
	check(all_ok, "every sampled production roll is valid")
	check(out_of_band == 0, "no family item drops outside its level band or quality (%d)" % out_of_band)
	for id: StringName in IDS:
		check(seen.has(id), "current loot drops %s at least once" % id)
	# Other starters stay out of the loot; only the book is exempt.
	for category: StringName in EquipmentLootProfiles.CHANCES:
		for id: StringName in [&"starter_blade", &"starter_staff", &"starter_bow"]:
			check(not (table.profiles[category]["equipment_weights"] as Dictionary).has(id), "legacy starter %s stays out of %s loot" % [id, category])
func art_checks(catalog: BuildEffectCatalog) -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/e10a_equipment/manifest.json"))
	check(manifest is Dictionary and manifest.get("items") is Array and (manifest.items as Array).size() == 3, "art manifest lists the three items")
	if not manifest is Dictionary:
		return
	var rows: Dictionary = {}
	for row: Dictionary in manifest.items:
		rows[StringName(row.id)] = row
	check(EquipmentArtCatalog.e10a_prop_ids() == IDS and EquipmentArtCatalog.e09_prop_ids().size() == 4, "art catalog enumerates the three family ids apart from the four of E09")
	for id: StringName in IDS:
		var row: Dictionary = rows.get(id, {})
		check(not row.is_empty() and FileAccess.get_sha256("res://assets/art/e10a_equipment/" + String(row.prop_png)) == String(row.prop_sha256), "prop hash " + String(id))
		check(not row.is_empty() and FileAccess.get_sha256("res://assets/art/" + String(row.icon_png)) == String(row.icon_sha256), "icon hash " + String(id))
		check(not row.is_empty() and FileAccess.get_sha256("res://" + String(row.source)) == String(row.source_sha256), "source sheet hash " + String(id))
		check(not row.is_empty() and String(row.source) == "assets/art/e08_codex_1118/equipment/weapons_b1.png" and int(row.object_index) == IDS.find(id) + 1, "cut from sheet B1 object %d %s" % [IDS.find(id) + 1, id])
		var profile := EquipmentArtCatalog.e09_prop_profile(id)
		var size: Vector2 = EXPECTED[id][4]
		check(not profile.is_empty() and (profile.size as Vector2) * EquipmentArtCatalog.SOURCE_SCALE == size, "profile size is the prop at x4 " + String(id))
		check(not profile.is_empty() and profile.grip == EXPECTED[id][5] and is_equal_approx(float(profile.angle), float(EXPECTED[id][6])) and profile.slot == &"main_hand", "grip, angle and slot " + String(id))
		var texture := EquipmentArtCatalog.e09_prop_texture(id)
		check(texture != null and texture.get_size() == size, "prop texture loads at its exact size " + String(id))
		if texture != null and not profile.is_empty():
			var image := texture.get_image()
			var grip: Vector2 = (profile.grip as Vector2) * EquipmentArtCatalog.SOURCE_SCALE
			check(image.get_pixel(int(grip.x), int(grip.y)).a > 0.5, "grip rests on opaque art " + String(id))
			var used := image.get_used_rect()
			check(used.position.x >= 2 and used.position.y >= 2 and used.end.x <= size.x - 2 and used.end.y <= size.y - 2, "art stays inside its cell " + String(id))
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		var icon := EquipmentPresentation.icon(item)
		check(icon != null and icon == EquipmentPresentation.painted_icon(id) and icon.get_size() == Vector2(128, 128), "item shows its painted 128 px icon " + String(id))
		var icon_image := icon.get_image() if icon != null else null
		check(icon_image != null and maxi(icon_image.get_used_rect().size.x, icon_image.get_used_rect().size.y) >= 110, "icon fills its 128 px frame " + String(id))
func hand_checks(catalog: BuildEffectCatalog) -> void:
	for id: StringName in IDS:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		for identity: StringName in FAMILY:
			var state := snapshot(identity)
			var created := EquipmentInstance.from_metadata(&"equipment_1", item.id, item.metadata())
			check(created["ok"], "exemplar for the hand check %s %s" % [id, identity])
			if not created["ok"]:
				continue
			state.equipment_instances[&"equipment_1"] = created["instance"]
			state.equipped[&"main_hand"] = &"equipment_1"
			var visual := EquipmentAttachmentVisual.describe(state, catalog)
			check(visual[&"main_hand"] == id, "describe resolves its own key %s for %s" % [id, identity])
		for kind: StringName in [&"swordsman", &"mage"]:
			var anim := CombatAnimationState.new()
			var placed := EquipmentAttachmentVisual.resolve_equipment(kind, anim, {&"main_hand": id}, Vector2.ZERO)
			check(placed.size() == 1 and placed[0].key == id and Vector2(placed[0].grip) == (EquipmentAttachmentVisual.PROFILES[id].grip as Vector2), "resolved placement uses the grip %s on %s" % [id, kind])
			if placed.size() == 1:
				check(EquipmentArtCatalog.prop_texture(placed[0].key, Vector2(placed[0].size)) == EquipmentArtCatalog.e09_prop_texture(id), "in-hand texture is the family art " + String(id))
