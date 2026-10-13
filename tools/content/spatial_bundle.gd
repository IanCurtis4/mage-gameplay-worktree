extends RefCounted
const Pilot = preload("res://tools/content/pilot_bundle.gd")
static func entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = Pilot.entries()
	for row: Array in [[&"spiritualist_echo_fixed_origin", &"echo_origin_fixed", &"spiritualist", [&"spiritualist_echo_curse"]], [&"geometer_ground_anchor", &"geometer_ground_anchor", &"mg_ar", [&"geometer_trace", &"geometer_triangulation"]]]:
		var effect := EffectDefinition.new()
		effect.id = StringName(String(row[0]) + "_policy")
		effect.family_id = effect.id
		effect.kind = EffectDefinition.Kind.KIT_RULE
		effect.handler_id = EffectDefinition.Handler.KIT_POLICY
		effect.axis = row[1]
		effect.unit = &"policy"
		effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
		effect.conflict_group = effect.axis
		effect.target_skill_ids.assign(row[3])
		effect.allowed_origins = [&"mage"]
		effect.allowed_evolutions.assign([row[2]])
		var augment := AugmentDefinition.new()
		augment.id = row[0]
		augment.max_stacks = 1
		augment.allowed_origins = [&"mage"]
		augment.allowed_evolutions.assign([row[2]])
		augment.effects = [effect]
		entries.append({"origin": &"augment", "definition": augment, "purpose": "Transformação exclusiva de %s: posição fixa capturada, sem aumentar dano, duração ou quantidade. Nomes/flavor devem sugerir posição/fixação, sem prometer raiz/controle ou novos botões." % row[2]})
	return entries

static func comparison(identity: String, branch: int, catalog: BuildEffectCatalog) -> Dictionary:
	var result: Dictionary = Pilot.comparison(identity, branch, catalog)
	if not result["ok"]: return result
	if branch == 0 and identity in ["spiritualist", "mg_ar"]:
		result["run_effects"]["augment_stacks"][&"spiritualist_echo_fixed_origin" if identity == "spiritualist" else &"geometer_ground_anchor"] = 1
		var composed := BuildEffectComposer.compose(result["snapshot"], result["run_effects"], [], catalog)
		if not composed["ok"]: return composed
		result["composed"] = composed
	return result
