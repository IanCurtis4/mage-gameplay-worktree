class_name BuildEffectComposer
extends RefCounted
## Pure composition. StatCalculator remains the sole authority for stats.

static func compose(snapshot: BuildSnapshot, run_effects: Dictionary, temporary_sources: Array[Dictionary] = [], catalog: BuildEffectCatalog = null) -> Dictionary:
	if snapshot == null:
		return BuildEffectCatalog.failure(&"missing_snapshot")
	var identity := snapshot._skill_catalog
	if ClassCatalog.class_definition(snapshot.base_class_id) == null or (not snapshot.evolution_id.is_empty() and not identity.evolution_is_ready(snapshot.evolution_id, snapshot.base_class_id)):
		return BuildEffectCatalog.failure(&"identity_unavailable")
	var registry := catalog if catalog != null else BuildEffectCatalog.pilot()
	var entries: Array[Dictionary] = []
	var set_members: Dictionary = {}
	var stacks: Dictionary = run_effects.get("augment_stacks", {})
	for id: Variant in stacks:
		if typeof(stacks[id]) != TYPE_INT or int(stacks[id]) < 1:
			return BuildEffectCatalog.failure(&"invalid_stacks")
		entries.append({"source_id": StringName("augment:%s" % id), "origin": &"augment", "id": StringName(id), "stacks": int(stacks[id])})
	var equipment_definitions: Dictionary = {}
	for id: StringName in registry.ids(&"equipment"):
		var definition := registry.get_definition(&"equipment", id) as EquipmentDefinition
		equipment_definitions[id] = definition.metadata()
	var layout_check := EquipmentRules.validate_layout(snapshot.equipped, snapshot.equipment_instances, equipment_definitions, snapshot.base_class_id, snapshot.evolution_id)
	if not layout_check["ok"]:
		return layout_check
	for slot: StringName in IdentityIds.equipment_slots():
		var item: Variant = snapshot.equipped[slot]
		if item == null:
			continue
		var instance: EquipmentInstance = snapshot.equipment_instances[item]
		var power_check := EquipmentPowerRules.validate_instance(instance)
		if not power_check["ok"]:
			return power_check
		var item_definition := registry.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		var quality_check := registry.validate_equipment_quality(item_definition, instance.quality_id)
		if not quality_check["ok"]:
			return quality_check
		var set_definition := registry.get_set(item_definition.set_id) if not item_definition.set_id.is_empty() else null
		if set_definition != null and EquipmentEligibilityRules.level_allowed(EquipmentEligibilityRules.for_resource(set_definition),instance.item_level) and EquipmentEligibilityRules.identity_allowed(EquipmentEligibilityRules.for_resource(set_definition),snapshot.base_class_id,snapshot.evolution_id):
			var members: Dictionary = set_members.get(item_definition.set_id, {})
			members[instance.definition_id] = true
			set_members[item_definition.set_id] = members
		entries.append({"source_id": StringName("equipment:%s:%s" % [slot, item]), "origin": &"equipment", "id": instance.definition_id, "slot": slot, "instance_id": item, "stacks": 1})
	var sockets: Dictionary = run_effects.get("card_sockets", snapshot.card_inventory.active_sockets(snapshot.equipped))
	var cards: Dictionary = run_effects.get("card_instances", snapshot.card_inventory.describe()["instances"])
	var seen_cards: Dictionary = {}
	for item: Variant in sockets:
		if typeof(item) not in [TYPE_STRING, TYPE_STRING_NAME] or item not in snapshot.equipped.values():
			return BuildEffectCatalog.failure(&"socket_item_not_equipped")
		var instance: EquipmentInstance = snapshot.equipment_instances[item]
		if not sockets[item] is Array or sockets[item].size() != instance.socket_capacity:
			return BuildEffectCatalog.failure(&"invalid_socket_capacity")
		if not EquipmentRules.allows_sockets(equipment_definitions[instance.definition_id]):
			return BuildEffectCatalog.failure(&"socket_not_allowed")
		var slot: StringName = &""
		for equipped_slot: StringName in IdentityIds.equipment_slots():
			if snapshot.equipped[equipped_slot] == item:
				slot = equipped_slot
		for index: int in sockets[item].size():
			var raw_card: Variant = sockets[item][index]
			if raw_card == null:
				continue
			if typeof(raw_card) not in [TYPE_STRING, TYPE_STRING_NAME] or not cards.has(raw_card) or typeof(cards[raw_card]) not in [TYPE_STRING, TYPE_STRING_NAME]:
				return BuildEffectCatalog.failure(&"card_instance_not_owned")
			var card_instance := StringName(raw_card)
			if seen_cards.has(card_instance):
				return BuildEffectCatalog.failure(&"duplicate_card")
			seen_cards[card_instance] = true
			entries.append({"source_id": StringName("card:%s:%d:%s" % [item, index, card_instance]), "origin": &"card", "id": StringName(cards[card_instance]), "slot": slot, "stacks": 1})
	for set_id: StringName in set_members:
		var set_definition := registry.get_set(set_id)
		for threshold: int in set_definition.thresholds:
			if set_members[set_id].size() < threshold:
				continue
			var recipe := AugmentDefinition.new()
			recipe.id = set_id
			recipe.display_name = set_definition.display_name
			recipe.max_stacks = 1
			recipe.effects.assign(set_definition.thresholds[threshold])
			entries.append({"source_id": StringName("set:%s:%d" % [set_id, threshold]), "origin": &"set", "id": set_id, "stacks": 1, "recipe": recipe})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["source_id"]) < String(b["source_id"]))
	# Access is resolved before targeting buffs, independent of source order.
	var effective_ranks := snapshot.skill_ranks.duplicate(true)
	var item_grants: Dictionary = {}
	var unique_effects: Dictionary = {}
	for entry: Dictionary in entries:
		var definition: Resource = entry.get("recipe") if entry["origin"] == &"set" else registry.get_definition(entry["origin"], entry["id"])
		if definition == null:
			return BuildEffectCatalog.failure(&"unknown_definition")
		for effect: EffectDefinition in definition.effects:
			var named_key := effect.unique_effect_id if not effect.unique_effect_id.is_empty() else (effect.id if effect.capability() != &"stat" else &"")
			if entry["origin"] == &"equipment" and not named_key.is_empty():
				if unique_effects.has(named_key) and unique_effects[named_key] != entry["instance_id"]:
					return BuildEffectCatalog.failure(&"effect_conflict" if effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE else &"duplicate_unique_effect", String(named_key))
				unique_effects[named_key] = entry["instance_id"]
			if effect.kind == EffectDefinition.Kind.ACTIVE_GRANT and BuildEffectCatalog.definition_allowed(definition, snapshot) and snapshot.base_class_id in effect.allowed_origins and (effect.allowed_evolutions.is_empty() or snapshot.evolution_id in effect.allowed_evolutions):
				var skill := effect.granted_skill_id
				item_grants[skill] = maxi(int(item_grants.get(skill, 0)), effect.granted_rank)
				effective_ranks[skill] = maxi(int(effective_ranks.get(skill, 0)), effect.granted_rank)
	var sources: Array[Dictionary] = []
	var rules: Dictionary = {}
	var kit_policies: Dictionary = {}
	var procs: Dictionary = {}
	var provenance: Array[Dictionary] = []
	var inactive: Array[Dictionary] = []
	var conflicts: Dictionary = {}
	var seen_sources: Dictionary = {}
	for source: Dictionary in snapshot.intrinsic_modifier_sources():
		seen_sources[source["source_id"]] = true
	for entry: Dictionary in entries:
		var source_id: StringName = entry["source_id"]
		if seen_sources.has(source_id):
			return BuildEffectCatalog.failure(&"duplicate_source", String(source_id))
		seen_sources[source_id] = true
		var definition: Resource = entry.get("recipe") if entry["origin"] == &"set" else registry.get_definition(entry["origin"], entry["id"])
		if definition == null:
			return BuildEffectCatalog.failure(&"unknown_definition", String(entry["id"]))
		if not BuildEffectCatalog.definition_allowed(definition, snapshot):
			return BuildEffectCatalog.failure(&"identity_restricted", String(entry["id"]))
		if definition is AugmentDefinition and entry["stacks"] > definition.max_stacks:
			return BuildEffectCatalog.failure(&"stack_cap")
		if (definition is EquipmentDefinition and not EquipmentRules.slot_matches(definition.slot, entry["slot"])) or (definition is CardDefinition and entry["slot"] not in definition.allowed_slots):
			return BuildEffectCatalog.failure(&"slot_restricted")
		var source := {"source_id": source_id, "label": definition.display_name, "primary_flat": {}, "flat": {}, "increased": {}}
		var effects: Array[EffectDefinition] = definition.effects.duplicate()
		effects.sort_custom(func(a: EffectDefinition, b: EffectDefinition) -> bool: return String(a.id) < String(b.id))
		for effect: EffectDefinition in effects:
			if (not effect.allowed_origins.is_empty() and snapshot.base_class_id not in effect.allowed_origins) or (not effect.allowed_evolutions.is_empty() and snapshot.evolution_id not in effect.allowed_evolutions):
				inactive.append({"source_id": source_id, "effect_id": effect.id, "reason": &"identity_restricted"})
				continue
			var targets: Array[StringName] = []
			for skill: StringName in effect.target_skill_ids:
				if skill == &"basic_attack" or (int(effective_ranks.get(skill, 0)) >= effect.minimum_rank and ClassCatalog.skill_definition(skill) != null):
					targets.append(skill)
			targets.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			if effect.kind == EffectDefinition.Kind.KIT_RULE:
				var prerequisites_met := true
				for required: StringName in BuildEffectCatalog.KIT_POLICIES[effect.axis].get("required", []):
					if int(effective_ranks.get(required, 0)) < 1 or ClassCatalog.skill_definition(required) == null: prerequisites_met = false
				if not prerequisites_met: targets.clear()
			if effect.kind == EffectDefinition.Kind.SKILL_RULE and targets.is_empty() or (not effect.target_skill_ids.is_empty() and targets.is_empty()):
				inactive.append({"source_id": source_id, "effect_id": effect.id, "reason": &"skill_not_learned"})
				continue
			var repeated_card := false
			if effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE:
				var equivalence := "%s:%s:%s" % [entry["origin"], entry["id"], effect.id]
				if conflicts.has(effect.conflict_group):
					if entry["origin"] != &"card" or conflicts[effect.conflict_group]["equivalence"] != equivalence:
						return BuildEffectCatalog.failure(&"effect_conflict", String(effect.conflict_group))
					repeated_card = true
				else:
					conflicts[effect.conflict_group] = {"source_id": source_id, "equivalence": equivalence}
			var magnitude := effect.value_at(entry["stacks"])
			if entry["origin"] == &"equipment":
				magnitude = EquipmentPowerRules.modifier_magnitude(effect, snapshot.equipment_instances[entry["instance_id"]], definition as EquipmentDefinition)
				if not is_finite(magnitude):
					return BuildEffectCatalog.failure(&"invalid_equipment_power")
			provenance.append({"source_id": source_id, "origin": entry["origin"], "definition_id": entry["id"], "effect_id": effect.id, "family_id": effect.family_id, "magnitude": magnitude, "targets": targets.duplicate(), "tags": effect.tags.duplicate(), "capability": effect.capability(), "granted_skill_id": effect.granted_skill_id, "unique_effect_id": effect.unique_effect_id, "repeated_card": repeated_card})
			if repeated_card or effect.kind == EffectDefinition.Kind.ACTIVE_GRANT:
				continue
			if effect.kind == EffectDefinition.Kind.STAT:
				source[effect.channel][effect.axis] = float(source[effect.channel].get(effect.axis, 0.0)) + magnitude
			elif effect.kind == EffectDefinition.Kind.KIT_RULE:
				kit_policies[effect.axis] = true
			elif effect.kind == EffectDefinition.Kind.SKILL_RULE:
				for skill: StringName in targets:
					if not rules.has(skill):
						rules[skill] = {}
					var axes: Dictionary = rules[skill]
					if axes.has(effect.axis) and float(axes[effect.axis]["limit"]) != effect.limit:
						return BuildEffectCatalog.failure(&"incompatible_axis_limits")
					var axis: Dictionary = axes.get(effect.axis, {"flat": 0.0, "increased": 0.0, "limit": effect.limit})
					axis["flat"] += magnitude
					axis["increased"] += effect.increased * int(entry["stacks"])
					axes[effect.axis] = axis
			else:
				var key := "%s:%s" % [effect.trigger, effect.family_id]
				var proc: Dictionary = procs.get(key, {"family_id": effect.family_id, "source_id": source_id, "trigger": effect.trigger, "axis": effect.axis, "flat": 0.0, "increased": 0.0, "limit": effect.limit, "targets": targets.duplicate(), "parts": []})
				if proc["axis"] != effect.axis or proc["limit"] != effect.limit or proc["targets"] != targets:
					return BuildEffectCatalog.failure(&"incompatible_family")
				var weapon: StringName = entry.get("instance_id", &"") if entry["origin"] == &"equipment" and definition.item_kind == &"weapon" else &""
				proc["parts"].append({"source_id": source_id, "flat": magnitude, "increased": effect.increased * int(entry["stacks"]), "weapon_instance_id": weapon})
				proc["flat"] += magnitude
				proc["increased"] += effect.increased * int(entry["stacks"])
				procs[key] = proc
		if not source["primary_flat"].is_empty() or not source["flat"].is_empty() or not source["increased"].is_empty():
			sources.append(source)
	for source: Dictionary in temporary_sources:
		if seen_sources.has(source.get("source_id", &"")):
			return BuildEffectCatalog.failure(&"duplicate_source")
		seen_sources[source.get("source_id", &"")] = true
		sources.append(source.duplicate(true))
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("source_id", "")) < String(b.get("source_id", "")))
	var stat_result := snapshot.try_stat_breakdown(sources)
	if not stat_result["ok"]:
		return stat_result
	var proc_list: Array[Dictionary] = []
	var proc_keys: Array = procs.keys()
	proc_keys.sort()
	for key: String in proc_keys:
		proc_list.append(procs[key].duplicate(true))
	return {"ok": true, "error_code": &"", "request_id": "", "build_version": snapshot.build_version, "skill_ranks": effective_ranks.duplicate(true), "item_grants": item_grants.duplicate(true), "unique_effects": unique_effects.duplicate(true), "stat_sources": sources.duplicate(true), "breakdown": stat_result["breakdown"], "skill_rules": rules.duplicate(true), "kit_policies": kit_policies.duplicate(true), "procs": proc_list, "provenance": provenance, "inactive": inactive, "conflicts": conflicts.duplicate(true)}

static func copy_result(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	if result.has("breakdown"):
		var old: StatBreakdown = result["breakdown"]
		var stats := StatBreakdown.new()
		stats.base_level = old.base_level
		stats.primary = old.primary.duplicate(true)
		stats.derived = old.derived.duplicate(true)
		stats.modifier_sources = old.modifier_sources.duplicate(true)
		copy["breakdown"] = stats
	return copy
