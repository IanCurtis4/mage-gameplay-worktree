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
	var stacks: Dictionary = run_effects.get("augment_stacks", {})
	for id: Variant in stacks:
		if typeof(stacks[id]) != TYPE_INT or int(stacks[id]) < 1:
			return BuildEffectCatalog.failure(&"invalid_stacks")
		entries.append({"source_id": StringName("augment:%s" % id), "origin": &"augment", "id": StringName(id), "stacks": int(stacks[id])})
	for slot: Variant in snapshot.equipped:
		var item: Variant = snapshot.equipped[slot]
		if item == null:
			continue
		entries.append({"source_id": StringName("equipment:%s:%s" % [slot, item]), "origin": &"equipment", "id": StringName(item), "slot": StringName(slot), "stacks": 1})
	var sockets: Dictionary = run_effects.get("card_sockets", {})
	var seen_cards: Dictionary = {}
	for item: Variant in sockets:
		var card: StringName = StringName(sockets[item])
		if seen_cards.has(card):
			return BuildEffectCatalog.failure(&"duplicate_card")
		seen_cards[card] = true
		var slot: StringName = &""
		for equipped_slot: Variant in snapshot.equipped:
			if snapshot.equipped[equipped_slot] != null and StringName(snapshot.equipped[equipped_slot]) == StringName(item):
				slot = StringName(equipped_slot)
		if slot.is_empty():
			return BuildEffectCatalog.failure(&"socket_item_not_equipped")
		entries.append({"source_id": StringName("card:%s:%s" % [card, item]), "origin": &"card", "id": card, "slot": slot, "stacks": 1})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["source_id"]) < String(b["source_id"]))
	var sources: Array[Dictionary] = []
	var rules: Dictionary = {}
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
		var definition := registry.get_definition(entry["origin"], entry["id"])
		if definition == null:
			return BuildEffectCatalog.failure(&"unknown_definition", String(entry["id"]))
		if not BuildEffectCatalog.definition_allowed(definition, snapshot):
			return BuildEffectCatalog.failure(&"identity_restricted", String(entry["id"]))
		if definition is AugmentDefinition and entry["stacks"] > definition.max_stacks:
			return BuildEffectCatalog.failure(&"stack_cap")
		if (definition is EquipmentDefinition and definition.slot != entry["slot"]) or (definition is CardDefinition and entry["slot"] not in definition.allowed_slots):
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
				if skill == &"basic_attack" or (skill in snapshot.learned_skill_ids(ProfileCatalog.ACTIVE) and int(snapshot.skill_ranks.get(skill, 0)) >= effect.minimum_rank):
					targets.append(skill)
			targets.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			if effect.kind == EffectDefinition.Kind.SKILL_RULE and targets.is_empty() or (not effect.target_skill_ids.is_empty() and targets.is_empty()):
				inactive.append({"source_id": source_id, "effect_id": effect.id, "reason": &"skill_not_learned"})
				continue
			if effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE:
				if conflicts.has(effect.conflict_group):
					return BuildEffectCatalog.failure(&"effect_conflict", "%s / %s / %s" % [effect.conflict_group, conflicts[effect.conflict_group], source_id])
				conflicts[effect.conflict_group] = source_id
			var magnitude := effect.value_at(entry["stacks"])
			provenance.append({"source_id": source_id, "origin": entry["origin"], "definition_id": entry["id"], "effect_id": effect.id, "family_id": effect.family_id, "magnitude": magnitude, "targets": targets.duplicate()})
			if effect.kind == EffectDefinition.Kind.STAT:
				source[effect.channel][effect.axis] = float(source[effect.channel].get(effect.axis, 0.0)) + magnitude
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
				var proc: Dictionary = procs.get(key, {"family_id": effect.family_id, "source_id": source_id, "trigger": effect.trigger, "axis": effect.axis, "flat": 0.0, "increased": 0.0, "limit": effect.limit, "targets": targets.duplicate()})
				if proc["axis"] != effect.axis or proc["limit"] != effect.limit or proc["targets"] != targets:
					return BuildEffectCatalog.failure(&"incompatible_family")
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
	return {"ok": true, "error_code": &"", "request_id": "", "build_version": snapshot.build_version, "skill_ranks": snapshot.skill_ranks.duplicate(true), "stat_sources": sources.duplicate(true), "breakdown": stat_result["breakdown"], "skill_rules": rules.duplicate(true), "procs": proc_list, "provenance": provenance, "inactive": inactive, "conflicts": conflicts.duplicate(true)}

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
