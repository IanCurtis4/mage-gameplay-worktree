extends RefCounted
const Transform = preload("res://tools/content/transform_bundle.gd")
const SUPPORT := {
	"defender": {0: {&"shield_wall": 1}},
	"berserker": {1: {&"berserker_rupture": 2}},
	"elementalist": {0: {&"elementalist_prismatic_focus": 1}},
	"spiritualist": {0: {&"fire_spear": 1, &"spiritualist_echo_recovery": 1}, 1: {&"fire_spear": 1}},
	"hunter": {1: {&"hunter_freezing_trap": 0}},
	"mg_ar": {1: {&"geometer_triangulation": 3}},
}
static func comparison(identity: String, branch: int, catalog: BuildEffectCatalog) -> Dictionary:
	var result: Dictionary = Transform.comparison(identity, branch, catalog)
	if not result["ok"]: return result
	var snapshot: BuildSnapshot = result["snapshot"]
	var support: Dictionary = SUPPORT.get(identity, {}).get(branch, {})
	for skill: StringName in support:
		result["purchased_ranks"][skill] = support[skill]
		if snapshot._skill_catalog.skill_metadata(skill)["category"] == ProfileCatalog.ACTIVE and skill not in snapshot.action_slots:
			var slot := snapshot.action_slots.find(null)
			if slot < 0: return BuildEffectCatalog.failure(&"invalid_action_slots")
			snapshot.action_slots[slot] = skill
	var checked: Dictionary = snapshot._skill_catalog.validate_purchased_ranks(snapshot.base_class_id, snapshot.evolution_id, snapshot.job_level, result["purchased_ranks"])
	if not checked["ok"]: return checked
	snapshot.skill_ranks = snapshot._skill_catalog.effective_skill_ranks(snapshot.base_class_id, snapshot.evolution_id, result["purchased_ranks"])
	if not ActionBarLayout.valid(snapshot.action_slots, snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)): return BuildEffectCatalog.failure(&"invalid_action_slots")
	result["composed"] = BuildEffectComposer.compose(snapshot, result["run_effects"], [], catalog)
	if not result["composed"]["ok"]: return result["composed"]
	result["support_purchases"] = support.duplicate(true)
	return result

static func describe(result: Dictionary) -> Dictionary:
	var snapshot: BuildSnapshot = result["snapshot"]
	var instances: Dictionary = {}
	for id: StringName in snapshot.equipment_instances:
		var instance: EquipmentInstance = snapshot.equipment_instances[id]
		var record := instance.to_record()
		# Historical offline blueprint schema stays six fields only for frozen legacy.
		if instance.power_ruleset_id == &"legacy_unscaled" and instance.recipe_revision_id == &"catalog_v1":
			record.erase("power_ruleset_id")
			record.erase("recipe_revision_id")
		instances[id] = record
	return {"base_class_id": snapshot.base_class_id, "evolution_id": snapshot.evolution_id, "base_level": snapshot.base_level, "job_level": snapshot.job_level, "purchased_ranks": result["purchased_ranks"].duplicate(true), "effective_ranks": snapshot.skill_ranks.duplicate(true), "action_slots": snapshot.action_slots.duplicate(), "equipment_instances": instances, "equipped": snapshot.equipped.duplicate(true), "augment_stacks": result["run_effects"]["augment_stacks"].duplicate(true), "card_instances": result["run_effects"]["card_instances"].duplicate(true), "card_sockets": result["run_effects"]["card_sockets"].duplicate(true), "support_purchases": result["support_purchases"].duplicate(true)}
