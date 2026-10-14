extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:failures+=1;push_error(label)
func snapshot(identity: StringName) -> BuildSnapshot:
	var value := BuildSnapshot.new()
	value.base_class_id = &"swordsman" if identity in [&"swordsman",&"defender",&"berserker"] else (&"archer" if identity in [&"archer",&"sentinel",&"hunter"] else &"mage")
	value.evolution_id = &"" if identity in IdentityIds.base_class_ids() else identity
	value.attribute_allocations = {&"str":0,&"agi":0,&"vit":0,&"int":0,&"dex":0,&"luk":0}
	return value
func _run() -> void:
	var original := BuildContentLoader.load_catalog()
	var loaded := BuildContentLoader.load_catalog(true)
	check(original["ok"] and loaded["ok"],"base and expanded runtime load")
	if not loaded["ok"]:print(loaded);quit(1);return
	var catalog: BuildEffectCatalog = loaded["catalog"]
	check(original["catalog"].ids(&"equipment").size()==37 and catalog.ids(&"equipment").size()==85,"unchanged base37 plus runtime85 equipment")
	check(catalog.ids(&"card").size()==6 and BuildContentLoader.definitions(&"set",true).size()==14,"same six cards and existing plus13 sets")
	var authored := preload("res://tools/content/inventory_fixes_bundle.gd").entries()
	check(authored.size()==59,"exact closed46 equipment13sets")
	for entry: Dictionary in authored:
		var definition: Resource = entry["definition"]
		var policy := EquipmentEligibilityRules.for_resource(definition)
		check(EquipmentEligibilityRules.validate(policy)["ok"],"valid authored policy "+String(definition.id))
		for level: int in range(1,31):
			check(EquipmentEligibilityRules.level_allowed(policy,level)==(level>=definition.min_item_level and level<=definition.max_item_level),"literal inclusive band")
	var resolver := MobLootResolver.create(catalog,EquipmentLootProfiles.production(catalog))
	check(resolver["ok"],"expanded real production loot remains valid")
	if resolver["ok"]:
		for stage: int in range(1,7):
			for category: StringName in MobCatalog.CATEGORIES:
				var o := MobOccurrence.new();o.occurrence_id="loot_content";o.mob_base_id=&"test_gel";o.category_id=category;o.origin_id=PlaytestGameplay.origin(stage)
				for selector: float in [0.0,0.15,0.35,0.55,0.75,0.95,1.0]:
					var result: Dictionary = resolver["resolver"].roll(o,[0.0,0.5,selector,0.0,1.0])
					check(result["ok"] and result["equipment_drops"].size()==1,"eligible production drop")
					if result["ok"]:
						var drop: Dictionary = result["equipment_drops"][0]
						var item := catalog.get_definition(&"equipment",drop["definition_id"]) as EquipmentDefinition
						check(EquipmentEligibilityRules.level_allowed(EquipmentEligibilityRules.for_resource(item),drop["item_level"]),"no out-of-band drop")
	var families := {&"swordsman":[&"swordsman",&"defender",&"berserker"],&"mage":[&"mage",&"elementalist",&"spiritualist",&"mg_ar"],&"archer":[&"archer",&"sentinel",&"hunter"]}
	for identity: StringName in EquipmentEligibilityRules.CURRENT_IDENTITIES:
		var set_id := StringName("class_set_"+String(identity))
		var set_def := catalog.get_set(set_id)
		check(set_def!=null,"one set per current identity")
		if set_def==null:continue
		for candidate_id: StringName in EquipmentEligibilityRules.CURRENT_IDENTITIES:
			var allowed: bool = candidate_id in families[identity] if families.has(identity) else candidate_id==identity
			var state := snapshot(candidate_id)
			check(EquipmentEligibilityRules.identity_allowed(EquipmentEligibilityRules.for_resource(set_def),state.base_class_id,state.evolution_id)==allowed,"base family/exact advanced set eligibility")
		var state := snapshot(identity)
		var baseline := BuildEffectComposer.compose(state,{},[],catalog)
		check(baseline["ok"],"literal independent baseline")
		for index: int in 3:
			var slot: StringName = [&"head",&"torso",&"feet"][index]
			var piece := catalog.get_definition(&"equipment",StringName(String(set_id)+"_"+String(slot))) as EquipmentDefinition
			var id := StringName("equipment_%d" % (index+1))
			var created := EquipmentInstance.from_metadata(id,piece.id,piece.metadata())
			check(created["ok"],"physical set exemplar")
			state.equipment_instances[id]=created["instance"];state.equipped[slot]=id
			var composed := BuildEffectComposer.compose(state,{},[],catalog)
			check(composed["ok"],"class set composition "+String(identity))
			if composed["ok"]:
				var set_sources := {}
				for row: Dictionary in composed["provenance"]:
					if String(row.get("source_id","")).begins_with("set:"): set_sources[row["source_id"]] = true
				check(set_sources.size()==index,"literal0/1/2 threshold activation")
		if baseline["ok"]:
			var complete := BuildEffectComposer.compose(state,{},[],catalog)
			if complete["ok"]:
				var expected := &"melee_attack" if identity in [&"swordsman",&"berserker"] else (&"physical_defense" if identity==&"defender" else (&"precision_attack" if identity in [&"archer",&"sentinel",&"hunter"] else &"magic_attack"))
				check(is_equal_approx(complete["breakdown"].value(expected)-baseline["breakdown"].value(expected),2.0 if identity==&"mg_ar" else 4.0),"literal set-axis budget")
	for row: Array in [[&"shared_sword",&"swordsman"],[&"shared_axe",&"swordsman"],[&"shared_wand",&"mage"],[&"shared_bow",&"archer"]]:
		var item := catalog.get_definition(&"equipment",row[0]) as EquipmentDefinition
		for identity: StringName in families[row[1]]:check(BuildEffectCatalog.definition_allowed(item,snapshot(identity)),"generic weapon supports base and derivatives")
	var beads := catalog.get_definition(&"equipment",&"spiritualist_prayer_beads") as EquipmentDefinition
	check(beads.slot==&"arms" and beads.item_kind==&"armor" and beads.socket_capacity==1 and BuildEffectCatalog.definition_allowed(beads,snapshot(&"spiritualist")) and not BuildEffectCatalog.definition_allowed(beads,snapshot(&"elementalist")),"prayer beads typed physical arm item and exact identity")
	var prism := catalog.get_definition(&"equipment",&"elementalist_prism") as EquipmentDefinition
	check(prism.slot==&"off_hand" and prism.item_kind==&"focus" and prism.socket_capacity==0 and BuildEffectCatalog.definition_allowed(prism,snapshot(&"elementalist")),"prismatic offhand focus with no sockets")
	var frozen := ContentAuthoring.prepare(preload("res://tools/content/transform_bundle.gd").entries())
	check(frozen["ok"] and frozen["mechanical_digest"]=="b2480230ac8691fe155976ce4e311cfef233e6b32618a3ebd8a7c87fbd0658fd","neutral schema defaults preserve original69 recipes")
	print("E06 expanded equipment content: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
