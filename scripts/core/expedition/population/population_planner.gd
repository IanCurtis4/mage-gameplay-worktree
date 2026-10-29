class_name ExpeditionPopulationPlanner
extends RefCounted
## Realized F0 slots are checked against F1 geometry and the canonical mob catalog.
static func build(manifest: ExpeditionManifest, catalog: MobCatalog, rules: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	if manifest == null or catalog == null: return BuildEffectCatalog.failure(&"invalid_manifest")
	if cancellation.is_valid() and cancellation.call(): return BuildEffectCatalog.failure(&"cancelled")
	var data := manifest.to_data()
	var slots: Dictionary = {}
	var worlds: Dictionary = {}
	var groups: Dictionary = {}
	var traversal: Dictionary = data["input"]["traversal"]
	for stage: Dictionary in data["stages"]:
		var geometry := WorldGeometry.new()
		var configured := geometry.configure(manifest, stage["stage_id"])
		if not configured["ok"]: return configured
		worlds[stage["stage_id"]] = geometry
	for source: Dictionary in manifest.population_plan().slots():
		if cancellation.is_valid() and cancellation.call(): return BuildEffectCatalog.failure(&"cancelled")
		var id: String = source["slot_id"]
		if slots.has(id) or not rules.has(id): return BuildEffectCatalog.failure(&"policy_unresolved")
		var rule: Variant = rules[id]
		if not rule is Dictionary or not rule.has_all(["trash", "base_xp", "job_xp"]) or not rule["trash"] is bool: return BuildEffectCatalog.failure(&"invalid_population_policy")
		for key: String in ["base_xp", "job_xp"]:
			if not EquipmentRules.exact_integer(rule[key], 0): return BuildEffectCatalog.failure(&"invalid_population_policy")
		if rule["trash"] and source["occurrence_category"] not in ["normal", "elite"]: return BuildEffectCatalog.failure(&"invalid_respawn_policy")
		var occurrence := MobOccurrence.new()
		occurrence.occurrence_id = occurrence_id("validation", source["stage_id"], id, 0)
		occurrence.mob_base_id = StringName(source["species_id"])
		occurrence.category_id = StringName(source["occurrence_category"])
		occurrence.origin_id = StringName(source["origin_id"])
		var checked := occurrence.validate(catalog)
		if not checked["ok"]: return checked
		if checked["definition"].id == &"animal_companion": return BuildEffectCatalog.failure(&"summoned_mob_ineligible")
		var geometry: WorldGeometry = worlds[source["stage_id"]]
		var mob_profile := traversal.duplicate(true)
		mob_profile["radius"] = maxf(float(traversal["radius"]), checked["definition"].collision_radius)
		var legal := geometry.position_query(point(source["home"]), mob_profile, geometry.geometry_revision)
		if not legal["ok"] or manifest.witness("population/" + id).is_empty(): return BuildEffectCatalog.failure(&"population_unreachable")
		var entry: Dictionary
		for socket: Dictionary in geometry._stage["sockets"]:
			if socket["socket_id"] == geometry._stage["entrance"]: entry = ExpeditionWorldPoint.create(source["stage_id"], socket["surface_id"], socket["position"]).to_data()
		if entry.is_empty(): return BuildEffectCatalog.failure(&"population_unreachable")
		# Admission needs existence, not a shortest movement or leash cost.
		var group_id: String = source["stage_id"]+"/"+ExpeditionCanonical.digest(mob_profile)
		if not groups.has(group_id):
			var targets: Array[ExpeditionWorldPoint] = []
			groups[group_id] = {"stage_id":source["stage_id"],"profile":mob_profile.duplicate(true),"entry":point(entry),"targets":targets}
		groups[group_id].targets.append(point(source["home"]))
		var slot := source.duplicate(true)
		slot["traversal"] = mob_profile
		slot.merge({"generation": 0, "life_state": "alive", "pending_wave": 0, "trash": rule["trash"], "base_xp": int(rule["base_xp"]), "job_xp": int(rule["job_xp"]), "initial_resolved": false, "deaths": {}}, true)
		slots[id] = slot
	if rules.size() != slots.size(): return BuildEffectCatalog.failure(&"invalid_population_policy")
	var navigation_metrics: Array = []
	var ordered: Array = groups.keys(); ordered.sort()
	for id: String in ordered:
		if cancellation.is_valid() and cancellation.call(): return BuildEffectCatalog.failure(&"cancelled")
		var group: Dictionary = groups[id]
		var geometry: WorldGeometry = worlds[group.stage_id]
		var certified := geometry.connectivity_batch(group.entry,group.targets,group.profile,geometry.geometry_revision,cancellation)
		if not certified.ok:
			var code: StringName = certified.error_code
			var failed := BuildEffectCatalog.failure(&"population_unreachable" if code == &"invalid_support" else code)
			failed["geometry_diagnostic"] = certified.data.duplicate(true)
			return failed
		if not certified.data.complete: return BuildEffectCatalog.failure(&"navigation_budget_exceeded")
		for target: Dictionary in certified.data.targets:
			if not target.outward_reachable: return BuildEffectCatalog.failure(&"population_unreachable")
		navigation_metrics.append({"stage_id":group.stage_id,"profile":group.profile.duplicate(true),"targets":group.targets.size(),"metrics":certified.data.metrics.duplicate(true)})
	if cancellation.is_valid() and cancellation.call(): return BuildEffectCatalog.failure(&"cancelled")
	return {"ok": true, "slots": slots, "worlds": worlds, "navigation_metrics":navigation_metrics}

static func point(record: Dictionary) -> ExpeditionWorldPoint:
	return ExpeditionWorldPoint.create(record["stage_id"], record["surface_id"], record["position"])

static func occurrence_id(expedition: String, stage: String, slot: String, generation: int) -> String:
	return "occ_" + ExpeditionCanonical.digest([expedition, stage, slot, generation]).substr(0, 60)
