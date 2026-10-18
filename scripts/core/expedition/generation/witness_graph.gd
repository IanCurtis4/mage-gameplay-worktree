class_name ExpeditionWitnessGraph
extends RefCounted
## Builds witnesses solely from realized surfaces/endpoints. Travel portals never repair local disconnection.
var _nodes: Dictionary = {}
var _edges: Dictionary = {}
var _profile: Dictionary = {}

func prepare(stages: Array[Dictionary], profile: Dictionary) -> Dictionary:
	_nodes.clear()
	_edges.clear()
	_profile = profile.duplicate(true)
	for stage: Dictionary in stages:
		for kind: String in ["sockets","connectors"]:
			var field := "socket_id" if kind == "sockets" else "connector_id"
			for item: Dictionary in stage[kind]:
				var cell := ExpeditionAssembler.lookup(stage["surfaces"],"surface_id",item["surface_id"])
				var point: Vector3 = item["position"]
				if kind == "connectors": point = ExpeditionFixtureGeometry.support_y(cell,point-Vector3(item["outward"])*profile["radius"])
				if cell["headroom"] + ExpeditionFixtureGeometry.EPSILON < profile["height"] or not ExpeditionFixtureGeometry.contains(cell,point,profile["radius"]): continue
				if not ExpeditionFixtureGeometry.clear_segment(point,point,stage["volumes"],profile["radius"],profile["height"]): continue
				_nodes[item[field]] = {"id": item[field],"point": ExpeditionWorldPoint.create(stage["stage_id"],item["surface_id"],point).to_data()}
				_edges[item[field]] = []
		var ids: Array = _nodes.keys()
		ids.sort()
		for from_id: String in ids:
			for to_id: String in ids:
				if from_id == to_id: continue
				var a: Dictionary = _nodes[from_id]["point"]
				var b: Dictionary = _nodes[to_id]["point"]
				if a["surface_id"] != b["surface_id"] or a["stage_id"] != stage["stage_id"]: continue
				if ExpeditionFixtureGeometry.clear_segment(a["position"],b["position"],stage["volumes"],profile["radius"],profile["height"]): _edges[from_id].append({"to": to_id,"connection_id": "","via": []})
		for connection: Dictionary in stage["connections"]:
			var a_id: String = connection["a_connector"]
			var b_id: String = connection["b_connector"]
			if not _nodes.has(a_id) or not _nodes.has(b_id): continue
			var a := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",a_id)
			var b := ExpeditionAssembler.lookup(stage["connectors"],"connector_id",b_id)
			if Vector3(a["position"]).distance_to(b["position"]) > ExpeditionFixtureGeometry.EPSILON: return ExpeditionAssembler.failed(&"incompatible_connector","discontinuous seam")
			var pa: Vector3 = _nodes[a_id]["point"]["position"]
			var pb: Vector3 = _nodes[b_id]["point"]["position"]
			if not ExpeditionFixtureGeometry.clear_segment(pa,a["position"],stage["volumes"],profile["radius"],profile["height"]) or not ExpeditionFixtureGeometry.clear_segment(b["position"],pb,stage["volumes"],profile["radius"],profile["height"]): continue
			var via := [ExpeditionWorldPoint.create(stage["stage_id"],a["surface_id"],a["position"]).to_data(),ExpeditionWorldPoint.create(stage["stage_id"],b["surface_id"],b["position"]).to_data()]
			if connection["forward"]: _edges[a_id].append({"to": b_id,"connection_id": connection["connection_id"],"via": via})
			via = via.duplicate(true)
			via.reverse()
			if connection["backward"]: _edges[b_id].append({"to": a_id,"connection_id": connection["connection_id"],"via": via})
	for edges: Array in _edges.values(): edges.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["to"] < b["to"])
	return {"ok": true}

func path(from_id: String, to_id: String) -> Dictionary:
	if not _nodes.has(from_id) or not _nodes.has(to_id): return {"ok": false}
	var frontier: Array[String] = [from_id]
	var predecessor := {from_id: {}}
	var index := 0
	while index < frontier.size():
		var current: String = frontier[index]
		index += 1
		if current == to_id: break
		for edge: Dictionary in _edges[current]:
			if predecessor.has(edge["to"]): continue
			predecessor[edge["to"]] = {"from": current,"edge": edge}
			frontier.append(edge["to"])
	if not predecessor.has(to_id): return {"ok": false}
	var steps: Array[Dictionary] = []
	var current := to_id
	while current != from_id:
		steps.push_front(predecessor[current])
		current = predecessor[current]["from"]
	var points: Array[Dictionary] = [_nodes[from_id]["point"].duplicate(true)]
	var connections: Array[String] = []
	var nodes: Array[String] = [from_id]
	for step: Dictionary in steps:
		var edge: Dictionary = step["edge"]
		points.append_array(edge["via"].duplicate(true))
		points.append(_nodes[edge["to"]]["point"].duplicate(true))
		nodes.append(edge["to"])
		if edge["connection_id"] != "": connections.append(edge["connection_id"])
	var cost := 0.0
	for point_index: int in range(1,points.size()): cost += Vector3(points[point_index-1]["position"]).distance_to(points[point_index]["position"])
	return {"ok": true,"data": {"profile": _profile.duplicate(true),"geometry_revision": 1,"points": points,"nodes": nodes,"connection_ids": connections,"cost": cost}}
