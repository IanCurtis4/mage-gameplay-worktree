extends SceneTree
## E09 T8 (C7): four weapons as normal items of existing categories, in the current loot and
## power bands, with art, grips and 128 px icons. Real catalog, real loot resolver.
const IDS: Array[StringName] = [&"halo_shield", &"buckler", &"rapier", &"prism_staff"]
const KIT: Array[StringName] = [&"sp_ac", &"mg_ac", &"sp_la", &"mg_la"]
## id -> [slot, item_kind, hand_usage, quality, min level, max level, origin family, art size]
const EXPECTED := {
	&"halo_shield": [&"off_hand", &"shield", &"none", &"rare", 11, 15, &"any", Vector2(72, 116)],
	&"buckler": [&"off_hand", &"shield", &"none", &"common", 2, 5, &"any", Vector2(72, 76)],
	&"rapier": [&"main_hand", &"weapon", &"one_hand", &"uncommon", 6, 10, &"swordsman", Vector2(40, 160)],
	&"prism_staff": [&"main_hand", &"weapon", &"two_hands", &"rare", 6, 10, &"mage", Vector2(52, 168)],
}
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
	var pure := identity in IdentityIds.base_class_ids()
	value.base_class_id = identity if pure else IdentityIds.evolution_origin(identity)
	value.evolution_id = &"" if pure else identity
	value.attribute_allocations = {&"str": 0, &"agi": 0, &"vit": 0, &"int": 0, &"dex": 0, &"luk": 0}
	return value
func _run() -> void:
	var loaded := BuildContentLoader.load_catalog(true)
	check(loaded["ok"], "expanded catalog loads with the four new items")
	if not loaded["ok"]:
		quit(1)
		return
	var catalog: BuildEffectCatalog = loaded["catalog"]
	catalog_checks(catalog)
	eligibility_checks(catalog)
	loot_checks(catalog)
	art_checks(catalog)
	print("E09 equipment items: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func catalog_checks(catalog: BuildEffectCatalog) -> void:
	check(catalog.ids(&"equipment").size() == 89, "89 equipment definitions (85 previous plus four) (%d)" % catalog.ids(&"equipment").size())
	for id: StringName in IDS:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		check(item != null, "definition exists " + String(id))
		if item == null:
			continue
		var row: Array = EXPECTED[id]
		check(item.slot == row[0] and item.item_kind == row[1] and item.hand_usage == row[2], "existing category, slot and hands " + String(id))
		check(item.quality_id == row[3] and item.min_item_level == row[4] and item.max_item_level == row[5] and item.item_level == row[4], "current quality and power band " + String(id))
		check(item.set_id.is_empty() and not item.starter and item.origin_id == &"demo_arena", "plain item without set, not starter " + String(id))
		check(item.effects.size() == 1 and item.effects[0].capability() == &"stat" and item.socket_capacity == 1, "stat-only recipe with one socket " + String(id))
		check(not item.display_name.is_empty() and not item.flavor_text.is_empty() and item.display_name != String(id), "pt-BR visible text " + String(id))
		check(EquipmentEligibilityRules.validate(EquipmentEligibilityRules.for_resource(item))["ok"], "valid eligibility policy " + String(id))
		check(EquipmentArtCatalog.e09_prop_profile(id).generic_key == item.visual_key, "in-hand key matches the profile " + String(id))
func eligibility_checks(catalog: BuildEffectCatalog) -> void:
	var identities: Array[StringName] = EquipmentEligibilityRules.eligible_identities()
	check(identities.size() == 14, "ten current plus four kit identities")
	var reference := {&"halo_shield": &"shared_shield", &"buckler": &"shared_shield", &"rapier": &"shared_sword", &"prism_staff": &"shared_wand"}
	for id: StringName in IDS:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		var twin := catalog.get_definition(&"equipment", reference[id]) as EquipmentDefinition
		var family: StringName = EXPECTED[id][6]
		for identity: StringName in identities:
			var state := snapshot(identity)
			var allowed := BuildEffectCatalog.definition_allowed(item, state)
			var expected := true if family == &"any" else state.base_class_id == family
			check(allowed == expected, "category eligibility %s for %s" % [id, identity])
			# Same category as an existing item: every current identity of the twin keeps access.
			if BuildEffectCatalog.definition_allowed(twin, state):
				check(allowed, "current identity of the category keeps access %s for %s" % [id, identity])
	# Paladino and Duelista use their own gear; Taumaturgo and Lâmina Arcana use the staff.
	for row: Array in [[&"sp_ac", &"halo_shield"], [&"sp_la", &"buckler"], [&"sp_la", &"rapier"], [&"mg_ac", &"prism_staff"], [&"mg_la", &"prism_staff"], [&"swordsman", &"halo_shield"], [&"mage", &"prism_staff"]]:
		check(BuildEffectCatalog.definition_allowed(catalog.get_definition(&"equipment", row[1]) as EquipmentDefinition, snapshot(row[0])), "%s may use %s" % [row[0], row[1]])
	check(not BuildEffectCatalog.definition_allowed(catalog.get_definition(&"equipment", &"rapier") as EquipmentDefinition, snapshot(&"mg_la")), "mage origin cannot use the rapier")
	# Composition: the item reaches the owner's stats exactly once.
	var paladin := snapshot(&"sp_ac")
	var baseline := BuildEffectComposer.compose(paladin, {}, [], catalog)
	var shield := catalog.get_definition(&"equipment", &"halo_shield") as EquipmentDefinition
	var created := EquipmentInstance.from_metadata(&"equipment_1", shield.id, shield.metadata())
	check(created["ok"], "halo shield exemplar for the Paladino")
	if created["ok"] and baseline["ok"]:
		paladin.equipment_instances[&"equipment_1"] = created["instance"]
		paladin.equipped[&"off_hand"] = &"equipment_1"
		var composed := BuildEffectComposer.compose(paladin, {}, [], catalog)
		check(composed["ok"] and is_equal_approx(composed["breakdown"].value(&"physical_defense") - baseline["breakdown"].value(&"physical_defense"), 2.0), "equipped halo shield adds physical defense +2")
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
			occurrence.occurrence_id = "t8_loot"
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
						if int(drop["item_level"]) < int(row[4]) or int(drop["item_level"]) > int(row[5]) or drop["quality_id"] != row[3]:
							out_of_band += 1
						seen[id] = int(seen.get(id, 0)) + 1
	check(all_ok, "every sampled production roll is valid")
	check(out_of_band == 0, "no new item drops outside its level band or quality (%d)" % out_of_band)
	for id: StringName in IDS:
		check(seen.has(id), "current loot drops %s at least once" % id)
func art_checks(catalog: BuildEffectCatalog) -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/e09_equipment/manifest.json"))
	check(manifest is Dictionary and manifest.get("items") is Array and (manifest.items as Array).size() == 4, "art manifest lists the four items")
	if not manifest is Dictionary:
		return
	var rows: Dictionary = {}
	for row: Dictionary in manifest.items:
		rows[StringName(row.id)] = row
	check(EquipmentArtCatalog.e09_prop_ids() == IDS, "art catalog enumerates exactly the four ids")
	for id: StringName in IDS:
		var row: Dictionary = rows.get(id, {})
		check(not row.is_empty() and FileAccess.get_sha256("res://assets/art/e09_equipment/" + String(row.prop_png)) == String(row.prop_sha256), "prop hash " + String(id))
		check(not row.is_empty() and FileAccess.get_sha256("res://assets/art/" + String(row.icon_png)) == String(row.icon_sha256), "icon hash " + String(id))
		check(not row.is_empty() and FileAccess.get_sha256("res://" + String(row.source)) == String(row.source_sha256), "source sheet hash " + String(id))
		var profile := EquipmentArtCatalog.e09_prop_profile(id)
		var size: Vector2 = EXPECTED[id][7]
		check(not profile.is_empty() and (profile.size as Vector2) * EquipmentArtCatalog.SOURCE_SCALE == size, "profile size is the prop at x4 " + String(id))
		var texture := EquipmentArtCatalog.e09_prop_texture(id)
		check(texture != null and texture.get_size() == size, "prop texture loads at its exact size " + String(id))
		if texture != null and not profile.is_empty():
			var image := texture.get_image()
			var grip: Vector2 = (profile.grip as Vector2) * EquipmentArtCatalog.SOURCE_SCALE
			check(image.get_pixel(int(grip.x), int(grip.y)).a > 0.5, "grip rests on opaque art " + String(id))
			var used := image.get_used_rect()
			check(used.position.x >= 2 and used.position.y >= 2 and used.end.x <= size.x - 2 and used.end.y <= size.y - 2, "art stays inside its cell " + String(id))
			check((profile.grip as Vector2).x >= 0.0 and (profile.grip as Vector2).x <= (profile.size as Vector2).x and (profile.grip as Vector2).y >= 0.0 and (profile.grip as Vector2).y <= (profile.size as Vector2).y, "grip inside logical size " + String(id))
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		var icon := EquipmentPresentation.icon(item)
		check(icon != null and icon == EquipmentPresentation.painted_icon(id) and icon.get_size() == Vector2(128, 128), "item shows its painted 128 px icon " + String(id))
		var icon_image := icon.get_image() if icon != null else null
		check(icon_image != null and maxi(icon_image.get_used_rect().size.x, icon_image.get_used_rect().size.y) >= 110, "icon fills its 128 px frame " + String(id))
	check(EquipmentArtCatalog.e09_prop_profile(&"shared_sword").is_empty() and EquipmentArtCatalog.e09_prop_texture(&"nope") == null, "unknown ids resolve to nothing")
