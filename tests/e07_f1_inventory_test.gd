extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var catalog := ProfileCatalog.pilot()
	var skills: Dictionary = {}
	var identities: Array = []
	for identity: Array in [["swordsman",""],["mage",""],["archer",""],["swordsman","defender"],["swordsman","berserker"],["mage","elementalist"],["mage","spiritualist"],["archer","sentinel"],["archer","hunter"],["mage","mg_ar"]]:
		var ids := catalog.skill_ids_for_identity(StringName(identity[0]),StringName(identity[1]))
		check(not ids.is_empty(),"identity has real catalog: "+str(identity))
		identities.append({"base":identity[0],"evolution":identity[1],"skills":ids})
		for id: StringName in ids:
			var definition := ClassCatalog.skill_definition(id)
			check(definition != null,"catalog runtime definition exists: "+id)
			if definition == null: continue
			check(not WorldSkillGeometryRules.rule(id).is_empty(),"explicit geometry inventory: "+id)
			skills[id] = {"name":definition.display_name,"category":SkillDefinition.Category.keys()[definition.category],"targeting":SkillDefinition.Targeting.keys()[definition.targeting],"handler":SkillDefinition.Handler.keys()[definition.handler_id],"geometry":WorldSkillGeometryRules.rule(id)}
	var effects: Array = []
	var loaded := BuildContentLoader.load_catalog(true,true)
	check(loaded["ok"],"real complete item/augment/card catalog loads")
	if loaded["ok"]:
		var build_catalog: BuildEffectCatalog = loaded["catalog"]
		for origin: StringName in BuildEffectCatalog.ORIGINS:
			for id: StringName in build_catalog.ids(origin):
				var definition: Resource = build_catalog.get_definition(origin,id)
				for effect: EffectDefinition in definition.effects:
					if effect.kind == EffectDefinition.Kind.STAT: continue
					effects.append({"origin":origin,"definition_id":id,"effect_id":effect.id,"family":effect.family_id,"kind":EffectDefinition.Kind.keys()[effect.kind],"targets":effect.target_skill_ids,"grant":effect.granted_skill_id,"axis":effect.axis})
	var output := FileAccess.open("res://.godot/f1_inventory.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"identities":identities,"skills":skills,"effects":effects,"intrinsic_families":BuildEffectCatalog.INTRINSIC_FAMILIES,"intrinsic_components":BuildEffectCatalog.INTRINSIC_COMPONENTS},"  ",true))
	output.close()
	print("E07 F1 inventory: %d identities, %d skills, %d non-stat item effects; %d checks, %d failures; json_sha256=%s" % [identities.size(),skills.size(),effects.size(),checks,failures,FileAccess.get_sha256("res://.godot/f1_inventory.json")])
	quit(0 if failures == 0 else 1)
