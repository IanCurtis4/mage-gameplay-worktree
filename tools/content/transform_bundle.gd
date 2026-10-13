extends RefCounted
const Spatial = preload("res://tools/content/spatial_bundle.gd")
const ROWS := [
	[&"spiritualist_drain_inscription", &"drain_inscription"],
	[&"hunter_marked_mechanism", &"hunter_marked_mechanism"],
	[&"hunter_covering_fan", &"hunter_covering_fan"],
	[&"geometer_collapse_first_element", &"geometer_collapse_first_element"],
]
static func entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = Spatial.entries()
	for row: Array in ROWS:
		var policy: Dictionary = BuildEffectCatalog.KIT_POLICIES[row[1]]
		var effect := EffectDefinition.new()
		effect.id = StringName(String(row[0]) + "_policy")
		effect.family_id = effect.id
		effect.kind = EffectDefinition.Kind.KIT_RULE
		effect.handler_id = EffectDefinition.Handler.KIT_POLICY
		effect.axis = row[1]
		effect.unit = &"policy"
		effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
		effect.conflict_group = effect.axis
		effect.target_skill_ids.assign(policy["skills"])
		effect.allowed_origins.assign([policy["origin"]])
		effect.allowed_evolutions.assign([policy["evolution"]])
		var augment := AugmentDefinition.new()
		augment.id = row[0]
		augment.max_stacks = 1
		augment.allowed_origins.assign(effect.allowed_origins)
		augment.allowed_evolutions.assign(effect.allowed_evolutions)
		augment.effects = [effect]
		entries.append({"origin": &"augment", "definition": augment, "purpose": "Transformação aprovada %s. Nome/flavor deve retratar a regra factual abaixo, sem prometer dano extra, outra skill ou efeito fora do contrato." % row[1]})
	return entries
static func comparison(identity: String, branch: int, catalog: BuildEffectCatalog) -> Dictionary:
	var result: Dictionary = Spatial.comparison(identity, branch, catalog)
	if not result["ok"]: return result
	var policy_id: StringName = &""
	if identity == "spiritualist" and branch == 1: policy_id = &"spiritualist_drain_inscription"
	if identity == "mg_ar" and branch == 1: policy_id = &"geometer_collapse_first_element"
	if identity == "hunter":
		policy_id = &"hunter_marked_mechanism" if branch == 0 else &"hunter_covering_fan"
		if branch == 0:
			var snapshot: BuildSnapshot = result["snapshot"]
			result["purchased_ranks"][&"hunter_mark"] = 1
			var checked: Dictionary = snapshot._skill_catalog.validate_purchased_ranks(snapshot.base_class_id, snapshot.evolution_id, snapshot.job_level, result["purchased_ranks"])
			if not checked["ok"]: return checked
			snapshot.skill_ranks = snapshot._skill_catalog.effective_skill_ranks(snapshot.base_class_id, snapshot.evolution_id, result["purchased_ranks"])
			snapshot.action_slots[2] = &"hunter_mark"
	if policy_id != &"":
		result["run_effects"]["augment_stacks"][policy_id] = 1
		result["composed"] = BuildEffectComposer.compose(result["snapshot"], result["run_effects"], [], catalog)
		if not result["composed"]["ok"]: return result["composed"]
	return result
