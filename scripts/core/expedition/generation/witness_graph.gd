class_name ExpeditionWitnessGraph
extends RefCounted
## Generation witnesses consume the same support/body/path authority as gameplay.
var _nodes: Dictionary = {}
var _worlds: Dictionary = {}
var _stages: Dictionary = {}
var _profile: Dictionary = {}

func prepare(stages: Array[Dictionary], profile: Dictionary) -> Dictionary:
	_nodes.clear(); _worlds.clear(); _stages.clear(); _profile = profile.duplicate(true)
	for stage: Dictionary in stages:
		for link: Dictionary in stage["connections"]:
			var a := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",link["a_connector"])
			var b := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",link["b_connector"])
			if a.is_empty() or b.is_empty() or Vector3(a["position"]).distance_to(b["position"]) > ExpeditionFixtureGeometry.EPSILON: return ExpeditionAssembler.failed(&"incompatible_connector","discontinuous seam")
		var manifest := ExpeditionManifest.new()
		manifest._data = {"stages":[stage.duplicate(true)],"input":{"parts":[]}}
		var world := WorldGeometry.new()
		if not world.configure(manifest,stage["stage_id"])["ok"]: return ExpeditionAssembler.failed(&"invalid_recipe","stage geometry")
		_worlds[stage["stage_id"]] = world; _stages[stage["stage_id"]] = stage
		for kind: String in ["sockets","connectors"]:
			var field := "socket_id" if kind == "sockets" else "connector_id"
			for item: Dictionary in stage[kind]:
				var cell := world._cell(item["surface_id"])
				var candidates: Array[Vector3] = [item["position"]]
				if kind == "connectors":
					candidates.clear()
					for seam: Vector3 in world._portal_candidates(item,item,item["position"],item["position"],profile["radius"],null,profile["height"]): candidates.append(ExpeditionFixtureGeometry.support_y(cell,seam-Vector3(item["outward"])*float(profile["radius"])))
				for position: Vector3 in candidates:
					var point := ExpeditionWorldPoint.create(stage["stage_id"],item["surface_id"],position)
					if world.position_query(point,profile,world.geometry_revision)["ok"]:
						_nodes[item[field]] = {"id":item[field],"point":point.to_data()}; break
	return {"ok":true}

func path(from_id: String, to_id: String) -> Dictionary:
	if not _nodes.has(from_id) or not _nodes.has(to_id): return {"ok":false}
	var a: Dictionary = _nodes[from_id]["point"]; var b: Dictionary = _nodes[to_id]["point"]
	if a["stage_id"] != b["stage_id"]: return {"ok":false}
	var world: WorldGeometry = _worlds[a["stage_id"]]
	var result := world.path(ExpeditionWorldPoint.create(a["stage_id"],a["surface_id"],a["position"]),ExpeditionWorldPoint.create(b["stage_id"],b["surface_id"],b["position"]),_profile,world.geometry_revision)
	if not result["ok"]: return {"ok":false}
	var nodes: Array[String] = [from_id]
	var stage: Dictionary = _stages[a["stage_id"]]
	var route: Array = result["data"]["points"]
	var connection_index := 0
	for index: int in range(1,route.size()):
		if route[index-1]["surface_id"] == route[index]["surface_id"]: continue
		if connection_index >= result.data.connection_ids.size(): return {"ok":false}
		var link := ExpeditionAssembler.lookup(stage["connections"],"connection_id",result.data.connection_ids[connection_index]); connection_index += 1
		if link.is_empty(): return {"ok":false}
		var p := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",link["a_connector"])
		var q := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",link["b_connector"])
		if p["surface_id"] == route[index-1]["surface_id"] and q["surface_id"] == route[index]["surface_id"]: nodes.append(p["connector_id"]); nodes.append(q["connector_id"])
		elif q["surface_id"] == route[index-1]["surface_id"] and p["surface_id"] == route[index]["surface_id"]: nodes.append(q["connector_id"]); nodes.append(p["connector_id"])
		else: return {"ok":false}
	if connection_index != result.data.connection_ids.size(): return {"ok":false}
	if from_id != to_id: nodes.append(to_id)
	result["data"]["profile"] = _profile.duplicate(true); result["data"]["geometry_revision"] = world.geometry_revision; result["data"]["nodes"] = nodes
	return result
