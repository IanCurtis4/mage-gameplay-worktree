class_name BuildPresentation
extends RefCounted
## Value DTOs for T4. All numbers come from the canonical compositor/services.

static func describe(controller: RunController) -> Dictionary:
	if controller == null or controller.build_service == null or controller.run_state == null:
		return BuildEffectCatalog.failure(&"invalid_session")
	var state := controller.run_state
	var catalog := state.effect_catalog()
	var owned := state.local_equipment.duplicate()
	if controller.persistent_facade != null:
		var profile := controller.persistent_facade.current_profile()
		if profile != null:
			owned = profile.equipment_collection
	var equipment: Array[Dictionary] = []
	for id: StringName in owned:
		var item := catalog.get_definition(&"equipment", id) as EquipmentDefinition
		if item != null:
			equipment.append({"id": id, "name": item.display_name, "description": item.description, "slot": item.slot, "selected": id in state.build_snapshot.equipped.values(), "allowed": BuildEffectCatalog.definition_allowed(item, state.build_snapshot)})
	var inventory := state.card_inventory.describe()
	var cards: Array[Dictionary] = []
	for id: StringName in inventory["owned"]:
		var card := catalog.get_definition(&"card", id) as CardDefinition
		cards.append({"id": id, "name": card.display_name, "description": card.description, "free": id in inventory["free"]})
	var composed := state.composed_build(controller.player.temporary_stat_sources())
	if not composed["ok"]:
		return composed
	return {"ok": true, "error_code": &"", "request_id": "", "title": "Equipamentos e cartas", "collection_label": "Coleção permanente", "inventory_label": "Cartas desta run", "context": controller.build_service.context(), "equipped": state.build_snapshot.equipped.duplicate(true), "equipment": equipment, "cards": cards, "inventory": inventory, "stats": composed["breakdown"].values(), "sources": composed["provenance"].duplicate(true), "inactive": composed["inactive"].duplicate(true), "skill_rules": composed["skill_rules"].duplicate(true)}

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
		&"identity_restricted", &"slot_restricted", &"invalid_slot": return "O item não é compatível com este personagem ou espaço."
		&"effect_conflict": return "A troca conflita com um efeito já ativo."
		&"socket_occupied": return "Remova primeiro a carta que já está encaixada."
		&"stale_revision", &"stale_resources": return "A build mudou. Confira a comparação novamente."
		&"save_in_progress", &"result_uncertain", &"recovery_required": return "Aguarde a confirmação da gravação atual."
		&"save_failed": return "Não foi possível salvar. A build anterior foi mantida."
		&"no_change": return "Esta seleção já está aplicada."
		&"actor_dead", &"invalid_session": return "A run não permite esta troca."
		&"replayed_request": return "Este pedido já foi concluído."
		_: return "Não foi possível aplicar esta troca."
