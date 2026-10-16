class_name BuildPresentation
extends RefCounted
## Value DTOs for T4. All numbers come from the canonical compositor/services.

static var _profile_catalog_owner := 0
static var _profile_catalog: BuildEffectCatalog

static func describe_profile(facade: ProfileFacade, character_id: String) -> Dictionary:
	if facade == null:
		return BuildEffectCatalog.failure(&"profile_unavailable")
	var profile := facade.current_profile()
	if profile == null:
		return BuildEffectCatalog.failure(&"profile_unavailable")
	var character := profile.character_by_id(character_id)
	if character == null:
		return BuildEffectCatalog.failure(&"invalid_character_id")
	var preview := facade.build_preview(character_id)
	if not preview.get("ok", false):
		return preview
	if _profile_catalog_owner != facade.get_instance_id() or _profile_catalog == null:
		var loaded := BuildContentLoader.load_catalog_for_profile(facade._catalog)
		if not loaded.get("ok", false):
			return loaded
		_profile_catalog = loaded["catalog"]
		_profile_catalog_owner = facade.get_instance_id()
	var catalog := _profile_catalog
	var snapshot: BuildSnapshot = preview["snapshot"]
	var equipment: Array[Dictionary] = []
	for id: StringName in profile.equipment_instance_ids():
		var instance: EquipmentInstance = profile.equipment_instances[id]
		var item := catalog.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		if item == null: continue
		var row := instance.to_record()
		row.merge({"id": id, "name": EquipmentPresentation.item_name(item), "description": _equipment_description(item, instance, catalog), "flavor": item.flavor_text, "icon": EquipmentPresentation.icon(item), "hand_usage": item.hand_usage, "origin_label": PlaytestGameplay.origin_name(instance.origin_id), "slot": item.slot, "selected": id in snapshot.equipped.values(), "allowed": BuildEffectCatalog.definition_allowed(item, snapshot)})
		equipment.append(row)
	var inventory: Dictionary = profile.card_inventory.describe()
	var cards: Array[Dictionary] = []
	for id: StringName in inventory["owned"]:
		var definition_id: StringName = inventory["instances"][id]
		var card := catalog.get_definition(&"card", definition_id) as CardDefinition
		if card == null: continue
		var species := catalog.mob_catalog().get_definition(card.mob_base_id)
		cards.append({"flavor": card.flavor_text, "origin_label": "Espécie: " + (species.display_name if species != null else "Espécie desconhecida"), "id": id, "definition_id": definition_id, "name": card.display_name, "description": card.description, "free": id in inventory["free"]})
	var visual: Dictionary = {}
	if ResourceLoader.exists("res://scripts/actors/equipment_attachment_visual.gd"):
		var visual_script := load("res://scripts/actors/equipment_attachment_visual.gd") as GDScript
		visual = visual_script.call("describe", snapshot, catalog)
	return {"ok": true, "error_code": &"", "request_id": "", "title": "Equipamentos e cartas", "collection_label": "Coleção permanente", "inventory_label": "Cartas permanentes", "context": {"profile_revision": profile.revision}, "equipped": snapshot.equipped.duplicate(true), "equipment": equipment, "cards": cards, "inventory": inventory, "stats": preview["stat_breakdown"].values(), "sources": {}, "inactive": [], "skill_rules": {}, "skill_ranks": snapshot.skill_ranks.duplicate(true), "kit_policies": {}, "procs": [], "item_grants": [], "unique_effects": [], "identity_id": portrait_identity(snapshot), "equipment_visual": visual}

static func describe(controller: RunController) -> Dictionary:
	if controller == null or controller.build_service == null or controller.run_state == null:
		return BuildEffectCatalog.failure(&"invalid_session")
	var state := controller.run_state
	var catalog := state.effect_catalog()
	var owned: Dictionary = state.local_equipment_instances
	if controller.persistent_facade != null:
		var profile := controller.persistent_facade.current_profile()
		if profile != null:
			owned = profile.equipment_instances
	var equipment: Array[Dictionary] = []
	var ids: Array = owned.keys()
	ids.sort()
	for id: StringName in ids:
		var instance: EquipmentInstance = owned[id]
		var item := catalog.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		if item != null:
			var row := instance.to_record()
			row.merge({"id": id, "name": EquipmentPresentation.item_name(item), "description": _equipment_description(item, instance, catalog), "flavor": item.flavor_text, "icon": EquipmentPresentation.icon(item), "hand_usage": item.hand_usage, "origin_label": PlaytestGameplay.origin_name(instance.origin_id), "slot": item.slot, "selected": id in state.build_snapshot.equipped.values(), "allowed": BuildEffectCatalog.definition_allowed(item, state.build_snapshot)})
			equipment.append(row)
	var inventory := state.card_inventory.describe()
	var cards: Array[Dictionary] = []
	for id: StringName in inventory["owned"]:
		var definition_id: StringName = inventory["instances"][id]
		var card := catalog.get_definition(&"card", definition_id) as CardDefinition
		var species := catalog.mob_catalog().get_definition(card.mob_base_id)
		cards.append({"flavor": card.flavor_text, "origin_label": "Espécie: " + (species.display_name if species != null else "Espécie de teste"), "id": id, "definition_id": definition_id, "name": card.display_name, "description": card.description, "free": id in inventory["free"]})
	var composed := state.composed_build(controller.player.temporary_stat_sources())
	if not composed["ok"]:
		return composed
	var visual: Dictionary = {}
	if ResourceLoader.exists("res://scripts/actors/equipment_attachment_visual.gd"):
		var visual_script := load("res://scripts/actors/equipment_attachment_visual.gd") as GDScript
		visual = visual_script.call("describe", state.build_snapshot, catalog)
	var identity_id := portrait_identity(state.build_snapshot)
	return {"ok": true, "error_code": &"", "request_id": "", "title": "Equipamentos e cartas", "collection_label": "Coleção permanente", "inventory_label": "Cartas permanentes", "context": controller.build_service.context(), "equipped": state.build_snapshot.equipped.duplicate(true), "equipment": equipment, "cards": cards, "inventory": inventory, "stats": composed["breakdown"].values(), "sources": composed["provenance"].duplicate(true), "inactive": composed["inactive"].duplicate(true), "skill_rules": composed["skill_rules"].duplicate(true), "skill_ranks": composed["skill_ranks"].duplicate(true), "kit_policies": composed["kit_policies"].duplicate(true), "procs": composed["procs"].duplicate(true), "item_grants": composed["item_grants"].duplicate(true), "unique_effects": composed["unique_effects"].duplicate(true), "identity_id": identity_id, "equipment_visual": visual}

static func portrait_identity(snapshot: BuildSnapshot) -> StringName:
	# Persistent hybrid identity differs from its animation asset ID.
	if snapshot.evolution_id == IdentityIds.MG_AR:
		return &"geometer"
	if snapshot.evolution_id in [&"defender", &"berserker", &"elementalist", &"spiritualist", &"geometer", &"sentinel", &"hunter"]:
		return snapshot.evolution_id
	return snapshot.base_class_id

static func compare(service: RunBuildService, intent: Dictionary) -> Dictionary:
	var preview := service.preview_change(intent)
	preview["message"] = "Troca disponível." if preview["ok"] else error_text(preview.get("error_code", &""))
	return preview

static func error_text(code: StringName) -> String:
	match code:
		&"encounter_active": return "Conclua o encontro antes de trocar."
		&"offer_open": return "Resolva a escolha de aprimoramento aberta."
		&"hp_deficit": return "A troca deixaria o personagem sem vida."
		&"sp_deficit": return "O novo máximo de SP não cobre o SP já gasto."
		&"item_not_owned", &"card_not_owned": return "Este item ainda não foi obtido."
		&"identity_restricted": return "Esta peça não serve à identidade deste personagem."
		&"slot_restricted", &"invalid_slot": return "Esta peça não cabe no espaço escolhido."
		&"item_level_restricted": return "O nível desta peça está fora da faixa permitida."
		&"effect_conflict", &"duplicate_unique_effect": return "A troca conflita com um efeito já ativo."
		&"duplicate_equipment_instance": return "Este exemplar já ocupa outra posição."
		&"identical_accessory": return "Duas peças iguais não podem ocupar os acessórios."
		&"off_hand_blocked", &"invalid_hand_configuration": return "A arma de duas mãos ocupa também a mão secundária."
		&"socket_not_allowed", &"invalid_socket_capacity": return "Esta peça não tem encaixes para cartas."
		&"socket_item_not_equipped": return "Equipe a peça antes de encaixar uma carta."
		&"invalid_socket_index": return "Escolha um encaixe existente na peça."
		&"socket_empty": return "Este encaixe já está vazio."
		&"card_instance_already_socketed": return "A carta já está encaixada; use a transferência."
		&"socket_occupied": return "Remova primeiro a carta que já está encaixada."
		&"stale_revision", &"stale_resources": return "A build mudou. Confira a comparação novamente."
		&"save_in_progress", &"result_uncertain", &"recovery_required": return "Aguarde a confirmação da gravação atual."
		&"save_failed": return "Não foi possível salvar. A build anterior foi mantida."
		&"no_change": return "Esta seleção já está aplicada."
		&"actor_dead", &"invalid_session": return "A run não permite esta troca."
		&"replayed_request": return "Este pedido já foi concluído."
		_: return "Não foi possível aplicar esta troca."

static func mechanics_lines(before: Dictionary, after: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var skills: Array = before.get("skill_ranks", {}).keys()
	for skill: Variant in after.get("skill_ranks", {}):
		if skill not in skills: skills.append(skill)
	for skill: Variant in skills:
		var previous: int = before.get("skill_ranks", {}).get(skill, 0)
		var current: int = after.get("skill_ranks", {}).get(skill, 0)
		if previous != current: lines.append("%s: rank %d → %d · o atalho escolhido é preservado" % [ClassCatalog.skill_definition(skill).display_name, previous, current])
	var affected: Array = before.get("skill_rules", {}).keys()
	for skill: Variant in after.get("skill_rules", {}):
		if skill not in affected: affected.append(skill)
	for skill: Variant in affected:
		var axes: Array = before.get("skill_rules", {}).get(skill, {}).keys()
		for axis: Variant in after.get("skill_rules", {}).get(skill, {}):
			if axis not in axes: axes.append(axis)
		for axis: Variant in axes:
			var current: Dictionary = after.get("skill_rules", {}).get(skill, {}).get(axis, {})
			var previous: Dictionary = before.get("skill_rules", {}).get(skill, {}).get(axis, {})
			if current != previous: lines.append("%s · %s: bônus %.2f → %.2f (limite %.0f)" % [ClassCatalog.skill_definition(skill).display_name, "projéteis" if axis == &"projectile_count" else "alcance", previous.get("flat", 0), current.get("flat", 0), current.get("limit", previous.get("limit", 0))])
	var policies: Array = before.get("kit_policies", {}).keys()
	for axis: Variant in after.get("kit_policies", {}):
		if axis not in policies: policies.append(axis)
	for axis: Variant in policies:
		var previous: bool = before.get("kit_policies", {}).get(axis, false)
		var current: bool = after.get("kit_policies", {}).get(axis, false)
		if previous == current: continue
		var names: Array[String] = []
		for skill: StringName in BuildEffectCatalog.KIT_POLICIES.get(axis, {}).get("skills", []):
			names.append(ClassCatalog.skill_definition(skill).display_name)
		lines.append("%s: transformação %s." % [", ".join(names), "ativada" if current else "removida"])
	var old_procs: Dictionary = {}
	var new_procs: Dictionary = {}
	for proc: Dictionary in before.get("procs", []): old_procs[proc["family_id"]] = proc
	for proc: Dictionary in after.get("procs", []): new_procs[proc["family_id"]] = proc
	var families: Array = old_procs.keys()
	for family: Variant in new_procs:
		if family not in families: families.append(family)
	for family: Variant in families:
		var previous: Dictionary = old_procs.get(family, {})
		var current: Dictionary = new_procs.get(family, {})
		if previous != current: lines.append("Adicional bruto de acerto: %.2f → %.2f (limite %.0f)." % [previous.get("flat", 0), current.get("flat", 0), current.get("limit", previous.get("limit", 0))])
	return lines
static func augment_progress(controller: RunController, definition: AugmentDefinition) -> String:
	var state := controller.run_state
	var before := state.composed_build(controller.player.temporary_stat_sources())
	var effects := state.effect_state()
	var count: int = state.augment_stacks.get(definition.id, 0)
	effects["augment_stacks"][definition.id] = count + 1
	var snapshot := state.build_snapshot.copy_snapshot()
	snapshot.skill_ranks = state.skill_levels.duplicate(true)
	var after := BuildEffectComposer.compose(snapshot, effects, controller.player.temporary_stat_sources(), state.effect_catalog())
	if not before["ok"] or not after["ok"]: return "Confira os pré-requisitos da habilidade."
	var lines: Array[String] = ["Aquisições: %d → %d / %d" % [count, count + 1, definition.max_stacks]]
	for key: StringName in after["breakdown"].values():
		if key not in ContentAuthoring.STAT_LABELS: continue
		var first: float = before["breakdown"].value(key)
		var second: float = after["breakdown"].value(key)
		if not is_equal_approx(first, second): lines.append("%s: %s → %s" % [ContentAuthoring.STAT_LABELS.get(key, String(key)), value_text(key, first), value_text(key, second)])
	lines.append_array(mechanics_lines(before, after))
	return "\n".join(lines)

static func value_text(axis: StringName, value: float) -> String:
	if axis in ContentAuthoring.FRACTION_AXES:
		var percentage := String.num(value * 100.0, 2)
		if percentage.contains("."): percentage = percentage.rstrip("0").rstrip(".")
		return percentage + "%"
	return String.num(value, 2)

static func _equipment_description(item: EquipmentDefinition, instance: EquipmentInstance, catalog: BuildEffectCatalog) -> String:
	var text := EquipmentPresentation.instance_description(item,instance)
	if not item.set_id.is_empty():
		var set_definition := catalog.get_set(item.set_id)
		if set_definition != null:
			text += "\nConjunto: %s · ilvl %d–%d\n%s" % [set_definition.display_name,set_definition.min_item_level,set_definition.max_item_level,ContentAuthoring.describe(&"set",set_definition)]
	return text
