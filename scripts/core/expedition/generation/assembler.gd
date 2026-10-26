class_name ExpeditionAssembler
extends RefCounted
const REVISION := "f0_convex_cells_v1"
const Geometry = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")

static func result(input: ExpeditionGenerationInput, code: StringName, data: Dictionary) -> Dictionary:
	return {"ok": code == &"", "error_code": code, "request_id": input.request_id if input != null else "", "revision": 1, "data": data}

static func build(input: ExpeditionGenerationInput) -> Dictionary:
	var validation := ExpeditionInputValidator.validate(input)
	if not validation["ok"]: return result(input,validation["error_code"],{"diagnostic": {"detail": validation["detail"], "attempts": 0, "expansions": 0, "seed_text": input.seed_text if input != null else ""}})
	var snapshot := input.to_data()
	var definitions := {}
	for part: Dictionary in snapshot["parts"]: definitions[part["part_id"]] = part
	var policies := {}
	for policy: Dictionary in snapshot["policies"]: policies[policy["policy_id"]] = policy
	var budget: Dictionary = policies[snapshot["generation_policy_id"]]["parameters"]
	var tasks: Array[Dictionary] = []
	for stage: Dictionary in snapshot["stages"]:
		var remaining: Array = stage["parts"].duplicate(true)
		var known := {}
		while not remaining.is_empty():
			for index: int in range(remaining.size()):
				var node: Dictionary = remaining[index]
				if node["parent"].is_empty() or known.has(node["parent"]):
					tasks.append({"stage_id": stage["stage_id"], "biome": stage["biome"], "node": node})
					known[node["instance_id"]] = true
					remaining.remove_at(index)
					break
	var expansions := 0
	var attempts := 0
	var last_code: StringName = &"incompatible_connector"
	var detail := "no compatible placement"
	var best_depth := -1
	for attempt: int in range(budget["max_attempts"]):
		attempts += 1
		var choices: Array[Array] = []
		var cursors: Array[int] = []
		for task: Dictionary in tasks:
			var options: Array[Dictionary] = []
			for candidate: String in task["node"]["candidates"]:
				for rotation: int in definitions[candidate]["allowed_rotations"]:
					options.append({"part_id": candidate, "rotation": rotation})
			# Candidate enumeration is canonical before the independent layout stream ranks it.
			options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b))
			var stream := "%s/%d/%s/%s" % [input.seed_text,attempt,task["stage_id"],task["node"]["instance_id"]]
			options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (stream+ExpeditionCanonical.encode(a)).sha256_text() < (stream+ExpeditionCanonical.encode(b)).sha256_text())
			choices.append(options)
			cursors.append(0)
		var placements: Array[Dictionary] = []
		var depth := 0
		while depth >= 0:
			if depth == tasks.size():
				var final := finalize(snapshot,placements)
				if final["ok"]:
					var manifest := ExpeditionManifest.new()
					manifest._data = final["manifest"]
					return result(input,&"",{"manifest": manifest, "hash": manifest.canonical_hash(), "diagnostic": {"attempts": attempts,"expansions": expansions,"seed_text": input.seed_text}})
				last_code = final["error_code"]
				detail = final["detail"]
				best_depth = depth
				depth -= 1
				placements.resize(depth)
				continue
			if cursors[depth] >= choices[depth].size():
				cursors[depth] = 0
				depth -= 1
				if depth >= 0: placements.resize(depth)
				continue
			if expansions >= budget["max_expansions"]:
				return result(input,&"generation_exhausted",{"diagnostic": {"attempts": attempts,"expansions": expansions,"seed_text": input.seed_text,"obligation": tasks[depth]["node"]["instance_id"],"cause": last_code,"detail": detail}})
			var choice: Dictionary = choices[depth][cursors[depth]]
			cursors[depth] += 1
			expansions += 1
			var placed := place(tasks[depth],definitions[choice["part_id"]],choice["rotation"],placements,snapshot["traversal"])
			if not placed["ok"]:
				if depth >= best_depth:
					last_code = placed["error_code"]
					detail = placed["detail"]
					best_depth = depth
				continue
			placements.append(placed["instance"])
			depth += 1
	return result(input,last_code,{"diagnostic": {"attempts": attempts,"expansions": expansions,"seed_text": input.seed_text,"detail": detail}})

static func failed(code: StringName, detail: String) -> Dictionary:
	return {"ok": false,"error_code": code,"detail": detail}

static func lookup(values: Array, field: String, id: String) -> Dictionary:
	for value: Dictionary in values:
		if value[field] == id: return value
	return {}

static func qualified(stage: String, instance: String, kind: String, local: String) -> String:
	return "%s/%s/%s/%s" % [stage,instance,kind,local]

static func place(task: Dictionary, definition: Dictionary, rotation: int, placements: Array[Dictionary], traversal: Dictionary) -> Dictionary:
	var stage: String = task["stage_id"]
	var node: Dictionary = task["node"]
	var instance_id: String = node["instance_id"]
	if not task["biome"] in definition["biome_tags"]: return failed(&"invalid_recipe","biome: "+definition["part_id"])
	var offset := Vector3.ZERO
	var connection := {}
	if not node["parent"].is_empty():
		var parent := {}
		for placement: Dictionary in placements:
			if placement["stage_id"] == stage and placement["instance_id"] == node["parent"]: parent = placement
		var a := lookup(parent["connectors"],"local_id",node["parent_connector"])
		var b := lookup(definition["connectors"],"connector_id",node["connector"])
		if a.is_empty() or b.is_empty(): return failed(&"incompatible_connector","missing endpoint: "+instance_id)
		for placement: Dictionary in placements:
			if not placement["connection"].is_empty() and a["connector_id"] in [placement["connection"]["a_connector"],placement["connection"]["b_connector"]]: return failed(&"incompatible_connector","endpoint already used: "+a["connector_id"])
		var forward: bool = a["direction"] in ["both","out"] and b["direction"] in ["both","in"]
		var backward: bool = a["direction"] in ["both","in"] and b["direction"] in ["both","out"]
		if not forward and not backward: return failed(&"incompatible_connector","directions: "+instance_id)
		if a["kind"] != b["kind"] or a["tags"] != b["tags"] or not a["kind"] in traversal["connector_kinds"]: return failed(&"incompatible_connector","type/tags: "+instance_id)
		if minf(a["width"],b["width"]) + Geometry.EPSILON < 2.0*traversal["radius"] or minf(a["headroom"],b["headroom"]) + Geometry.EPSILON < traversal["height"]: return failed(&"incompatible_connector","clearance: "+instance_id)
		if Vector3(a["outward"]).distance_to(-Geometry.rotate(b["outward"],rotation)) > Geometry.EPSILON: return failed(&"incompatible_connector","orientation: "+instance_id)
		offset = Vector3(a["position"]) - Geometry.rotate(b["position"],rotation)
		# Horizontal attachment cannot repair a mismatched authored level silently.
		if absf(offset.y) > Geometry.EPSILON: return failed(&"incompatible_connector","level: "+instance_id)
		offset.y = 0.0
		connection = {"connection_id": stage+"/"+instance_id,"a_connector": a["connector_id"],"b_connector": qualified(stage,instance_id,"connector",b["connector_id"]),"forward": forward,"backward": backward}
	var instance := {"stage_id": stage,"instance_id": instance_id,"part_id": definition["part_id"],"part_revision": definition["revision"],"part_hash": ExpeditionCanonical.digest(definition),"rotation_quarters": rotation,"translation": offset,"surfaces": [],"connectors": [],"sockets": [],"solid_volumes": [],"blockers": [],"connection": connection}
	for original: Dictionary in definition["surfaces"]:
		var cell := original.duplicate(true)
		cell["local_id"] = original["surface_id"]
		cell["surface_id"] = qualified(stage,instance_id,"surface",original["surface_id"])
		cell["stage_id"] = stage
		cell["vertices"] = []
		cell["triangles"] = []
		for point: Vector3 in original["vertices"]: cell["vertices"].append(Geometry.rotate(point,rotation)+offset)
		for index: int in range(1,cell["vertices"].size()-1): cell["triangles"].append([0,index,index+1])
		instance["surfaces"].append(cell)
	for kind: String in ["connectors","sockets"]:
		var id_field := "connector_id" if kind == "connectors" else "socket_id"
		var namespace_id := "connector" if kind == "connectors" else "socket"
		for original: Dictionary in definition[kind]:
			var item := original.duplicate(true)
			item["local_id"] = original[id_field]
			item[id_field] = qualified(stage,instance_id,namespace_id,original[id_field])
			item["surface_id"] = qualified(stage,instance_id,"surface",original["surface_id"])
			item["stage_id"] = stage
			item["position"] = Geometry.rotate(original["position"],rotation)+offset
			if kind == "connectors": item["outward"] = Geometry.rotate(original["outward"],rotation)
			instance[kind].append(item)
	for kind: String in ["solid_volumes","blockers"]:
		for volume: AABB in definition[kind]: instance[kind].append(Geometry.transform_volume(volume,rotation,offset))
	if not definition.get("solid_prisms",[]).is_empty():
		instance["solid_prisms"] = []
		for prism: Dictionary in definition.solid_prisms:
			instance.solid_prisms.append(preload("res://scripts/core/expedition/spatial/world_solid_prism.gd").transformed(prism,rotation,offset,qualified(stage,instance_id,"mass",""),qualified(stage,instance_id,"surface","")))
	if not definition.get("internal_connections",[]).is_empty():
		instance["internal_connections"] = []
		for original: Dictionary in definition.internal_connections:
			var link := original.duplicate(true)
			link.connection_id = qualified(stage,instance_id,"join",original.connection_id)
			link.a_connector = qualified(stage,instance_id,"connector",original.a_connector)
			link.b_connector = qualified(stage,instance_id,"connector",original.b_connector)
			instance.internal_connections.append(link)
	for other: Dictionary in placements:
		if other["stage_id"] != stage: continue
		for cell: Dictionary in instance["surfaces"]:
			for previous: Dictionary in other["surfaces"]:
				if Geometry.cells_overlap(cell,previous): return failed(&"invalid_recipe","support overlap: "+instance_id)
		for volume: AABB in instance["solid_volumes"]:
			for previous: AABB in other["solid_volumes"]:
				if Geometry.overlaps(volume,previous): return failed(&"invalid_recipe","solid overlap: "+instance_id)
	return {"ok": true,"instance": instance}

static func finalize(snapshot: Dictionary, placements: Array[Dictionary]) -> Dictionary:
	var stages: Array[Dictionary] = []
	for recipe: Dictionary in snapshot["stages"]:
		var stage := {"stage_id": recipe["stage_id"],"biome": recipe["biome"],"entrance": recipe["stage_id"]+"/"+recipe["entrance"].replace("/","/socket/"),"part_instances": [],"surfaces": [],"connectors": [],"sockets": [],"connections": [],"volumes": []}
		for instance: Dictionary in placements:
			if instance["stage_id"] != stage["stage_id"]: continue
			stage["part_instances"].append({"instance_id": instance["instance_id"],"part_id": instance["part_id"],"part_revision": instance["part_revision"],"part_hash": instance["part_hash"],"rotation_quarters": instance["rotation_quarters"],"translation": instance["translation"]})
			for field: String in ["surfaces","connectors","sockets"]: stage[field].append_array(instance[field])
			stage["volumes"].append_array(instance["solid_volumes"])
			stage["volumes"].append_array(instance["blockers"])
			if instance.has("solid_prisms"):
				if not stage.has("solid_prisms"): stage["solid_prisms"] = []
				stage.solid_prisms.append_array(instance.solid_prisms)
			stage.connections.append_array(instance.get("internal_connections",[]))
			if not instance["connection"].is_empty(): stage["connections"].append(instance["connection"])
		var entrance := lookup(stage["sockets"],"socket_id",stage["entrance"])
		if entrance.is_empty() or entrance["kind"] != "entrance": return failed(&"objective_unreachable","stage entrance: "+stage["stage_id"])
		stages.append(stage)
	var spatial := ExpeditionWitnessGraph.new()
	var prepared := spatial.prepare(stages,snapshot["traversal"])
	if not prepared["ok"]: return prepared
	var obligations: Array[Dictionary] = []
	var resolved_portals: Array[Dictionary] = []
	for portal: Dictionary in snapshot["portals"]:
		var copy := portal.duplicate(true)
		for side: String in ["from","to"]:
			var stage := lookup(stages,"stage_id",portal[side+"_stage"])
			var key: String = portal[side+"_stage"]+"/"+portal[side+"_socket"].replace("/","/socket/")
			var socket := lookup(stage["sockets"],"socket_id",key)
			if socket.is_empty() or not socket["kind"] in ["portal","entrance"]: return failed(&"objective_unreachable","portal endpoint: "+portal["portal_id"])
			copy[side+"_anchor"] = ExpeditionWorldPoint.create(stage["stage_id"],socket["surface_id"],socket["position"]).to_data()
			obligations.append({"id": "portal/"+portal["portal_id"]+"/"+side,"stage_id": stage["stage_id"],"socket": key,"error": &"objective_unreachable"})
		resolved_portals.append(copy)
	var objectives: Array[Dictionary] = []
	var plan := ExpeditionPopulationPlan.new()
	for kind: String in ["objectives","population"]:
		for spec: Dictionary in snapshot[kind]:
			var key := qualified(spec["stage_id"],spec["instance_id"],"socket",spec["socket_id"])
			var stage := lookup(stages,"stage_id",spec["stage_id"])
			var socket := lookup(stage["sockets"],"socket_id",key)
			var error: StringName = &"objective_unreachable" if kind == "objectives" else &"population_unreachable"
			if socket.is_empty(): return failed(error,"missing socket: "+key)
			if kind == "population":
				var species := lookup(snapshot["species"],"species_id",spec["species_id"])
				if not stage["biome"] in species["biome_tags"] or not spec["occurrence_category"] in species["occurrence_categories"]: return failed(&"incompatible_species",spec["species_id"])
				for tag: String in species["required_site_tags"]:
					if not tag in socket["tags"]: return failed(&"missing_thematic_site",spec["species_id"]+"/"+key)
			var allowed := ["objective","exit"] if kind == "objectives" else ["population","thematic_encounter"]
			if not socket["kind"] in allowed: return failed(error,"socket kind: "+key)
			for tag: String in spec["required_tags"]:
				if not tag in socket["tags"]: return failed(&"missing_thematic_site","socket tag: "+key)
			var resolved := spec.duplicate(true)
			resolved["home" if kind == "population" else "point"] = ExpeditionWorldPoint.create(stage["stage_id"],socket["surface_id"],socket["position"]).to_data()
			var id_key := "slot_id" if kind == "population" else "objective_id"
			obligations.append({"id": kind+"/"+spec[id_key],"stage_id": spec["stage_id"],"socket": key,"error": error})
			if kind == "population": plan._slots.append(resolved)
			else: objectives.append(resolved)
	# Every authored exit and every stage entrance is independently witnessed before any clear-gated travel edge is admitted.
	for stage: Dictionary in stages:
		obligations.append({"id": "entrance/"+stage["stage_id"],"stage_id": stage["stage_id"],"socket": stage["entrance"],"error": &"objective_unreachable"})
		for socket: Dictionary in stage["sockets"]:
			if socket["kind"] == "exit": obligations.append({"id": "exit/"+socket["socket_id"],"stage_id": stage["stage_id"],"socket": socket["socket_id"],"error": &"objective_unreachable"})
	var witnesses := {}
	for obligation: Dictionary in obligations:
		var stage := lookup(stages,"stage_id",obligation["stage_id"])
		var path := spatial.path(stage["entrance"],obligation["socket"])
		if not path["ok"]: return failed(obligation["error"],obligation["id"])
		witnesses[obligation["id"]] = path["data"]
	for portal: Dictionary in resolved_portals:
		var stage := lookup(stages,"stage_id",portal["to_stage"])
		var anchor: String = portal["to_stage"]+"/"+portal["to_socket"].replace("/","/socket/")
		var arrival := spatial.path(anchor,stage["entrance"])
		if not arrival["ok"]: return failed(&"objective_unreachable","portal arrival: "+portal["portal_id"])
		witnesses["arrival/"+portal["portal_id"]] = arrival["data"]
	# Phase topology is separate from floor traversal. Prove every declared stage is reachable through admitted travel edges.
	var visited := {snapshot["entry_stage_id"]: true}
	var changed := true
	while changed:
		changed = false
		for portal: Dictionary in resolved_portals:
			if visited.has(portal["from_stage"]) and not visited.has(portal["to_stage"]): visited[portal["to_stage"]] = true; changed = true
	if visited.size() != stages.size(): return failed(&"objective_unreachable","disconnected phase graph")
	return {"ok": true,"manifest": {"manifest_revision": 1,"geometry_revision": 1,"input": snapshot.duplicate(true),"input_hash": ExpeditionCanonical.digest(snapshot),"stage_ids": stages.map(func(stage: Dictionary) -> String: return stage["stage_id"]),"stages": stages,"portals": resolved_portals,"objectives": objectives,"population": plan.to_data(),"witnesses": witnesses,"traversal": snapshot["traversal"].duplicate(true)}}
