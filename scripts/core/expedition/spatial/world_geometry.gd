class_name WorldGeometry
extends RefCounted
## Logical world units: x/z horizontal, y height. No camera or projected pixels.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const SupportPatch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const EPS := 0.00001
var geometry_revision := 0
var configuration_revision := 0
var _stage: Dictionary = {}
var _temporary: Dictionary[String, AABB] = {}
var _segments: Dictionary[String, WorldSolidSegment] = {}
var _solid_slabs: Array[AABB] = []
var _occupancy: Dictionary[String, Dictionary] = {}
var _support_index: Dictionary = {}

func configure(manifest: ExpeditionManifest, stage_id: String) -> Dictionary:
	if manifest == null: return _failure(&"invalid_manifest")
	var data := manifest.to_data()
	for stage: Dictionary in data.get("stages", []):
		if stage["stage_id"] == stage_id:
			_stage = stage.duplicate(true)
			_support_index.clear()
			_solid_slabs.clear()
			# Preserve F0's distinction between authored solids and planar blockers.
			for instance: Dictionary in stage["part_instances"]:
				for definition: Dictionary in data["input"]["parts"]:
					if definition["part_id"] != instance["part_id"]: continue
					for original: AABB in definition["solid_volumes"]:
						var volume := Kernel.transform_volume(original,instance["rotation_quarters"],instance["translation"])
						if _supports_solid_floor(volume): _solid_slabs.append(volume)
			_temporary.clear()
			_segments.clear()
			_occupancy.clear()
			# Monotonic even when replacing a world with another revision-1 manifest.
			geometry_revision += 1
			configuration_revision += 1
			return _success({"manifest_hash": manifest.canonical_hash(), "stage_id": stage_id})
	return _failure(&"unknown_stage")

func _supports_solid_floor(volume: AABB) -> bool:
	var rectangle := PackedVector2Array([Vector2(volume.position.x,volume.position.z),Vector2(volume.end.x,volume.position.z),Vector2(volume.end.x,volume.end.z),Vector2(volume.position.x,volume.end.z)])
	for cell: Dictionary in _stage["surfaces"]:
		var polygon := PackedVector2Array()
		var horizontal := true
		for vertex: Vector3 in cell["vertices"]:
			if absf(vertex.y-volume.end.y) > EPS: horizontal = false; break
			polygon.append(Vector2(vertex.x,vertex.z))
		if horizontal and not Geometry2D.intersect_polygons(rectangle,polygon).is_empty(): return true
	return false
func _success(data: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error_code": &"", "geometry_revision": geometry_revision, "data": data.duplicate(true)}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "geometry_revision": geometry_revision, "data": {}}

func _current(revision: int) -> bool:
	return not _stage.is_empty() and revision == geometry_revision

func _ensure_support_index() -> void:
	if _support_index.is_empty() and not _stage.is_empty(): _support_index = SupportPatch.index(_stage)

func _cell(id: String) -> Dictionary:
	_ensure_support_index()
	return _support_index.get("cells",{}).get(id,{})

func _volumes() -> Array:
	var volumes: Array = _stage.get("volumes", []).duplicate()
	var ids: Array = _temporary.keys()
	ids.sort()
	for id: String in ids: volumes.append(_temporary[id])
	return volumes

func _profile_valid(profile: Dictionary) -> bool:
	if not profile.has_all(["radius", "height", "connector_kinds"]): return false
	if not _finite_number(profile["radius"]) or not _finite_number(profile["height"]): return false
	if not (profile["connector_kinds"] is Array or profile["connector_kinds"] is PackedStringArray) or profile["connector_kinds"].is_empty(): return false
	for kind: Variant in profile["connector_kinds"]:
		if not (kind is String or kind is StringName) or str(kind).is_empty(): return false
	return float(profile["radius"]) > 0.0 and float(profile["height"]) > 0.0

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _point_valid(point: ExpeditionWorldPoint, radius: float = 0.0, height: float = 0.0) -> bool:
	if point == null or not point.position.is_finite() or point.stage_id != _stage.get("stage_id", ""): return false
	var cell := _cell(point.surface_id)
	return not cell.is_empty() and float(cell["headroom"]) + EPS >= height and _supported(cell, point.position, radius, height) and not sweep(point.position, point.position, {"radius":radius,"height":height}, geometry_revision)["data"]["hit"]

func _supported(cell: Dictionary, position: Vector3, radius: float, height: float) -> bool:
	_ensure_support_index()
	return SupportPatch.contains(cell,position,radius,height,_support_index)

func support_at(surface_id: String, horizontal: Vector2, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not horizontal.is_finite(): return _failure(&"invalid_position")
	var cell := _cell(surface_id)
	if cell.is_empty(): return _failure(&"unknown_surface")
	var point := Kernel.support_y(cell, Vector3(horizontal.x,0,horizontal.y))
	if not Kernel.contains(cell,point): return _failure(&"invalid_support")
	return _success({"point":ExpeditionWorldPoint.create(_stage["stage_id"],surface_id,point).to_data()})
func position_query(point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(point, profile["radius"], profile["height"]): return _failure(&"invalid_support")
	var occupants: Array[String] = []
	for id: String in _occupancy:
		var item: Dictionary = _occupancy[id]
		var other: Vector3 = item["point"]["position"]
		if point.position.y < other.y + float(item["height"]) and point.position.y + float(profile["height"]) > other.y and Vector2(point.position.x, point.position.z).distance_to(Vector2(other.x, other.z)) < float(profile["radius"]) + float(item["radius"]): occupants.append(id)
	occupants.sort()
	return _success({"point": point.to_data(), "occupants": occupants})

func set_occupant(id: String, point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	var check := position_query(point, profile, revision)
	if not check["ok"]: return check
	if id.is_empty(): return _failure(&"invalid_identity")
	_occupancy[id] = {"point": point.to_data(), "radius": profile["radius"], "height": profile["height"], "profile": profile.duplicate(true)}
	return _success()

func remove_occupant(id: String) -> void:
	_occupancy.erase(id)

func path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	return _path(from,to,profile,revision,null)

func _path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int, candidate: WorldSolidSegment) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	var radius: float = profile["radius"]
	var height: float = profile["height"]
	if not _candidate_point(from,radius,height,candidate) or not _candidate_point(to,radius,height,candidate): return _failure(&"invalid_support")
	# A clear straight ground route may cross any legal point of each opening.
	# Keep its support-plane transitions and recheck a proposed temporary segment.
	var direct := ground_line_to(from,to,profile,revision)
	if direct["ok"]:
		var route: Array = direct["data"]["points"]
		var clear := true
		for index: int in range(1,route.size()):
			if not _clear_path_segment(route[index-1]["position"],route[index]["position"],profile,candidate): clear = false; break
		if clear:
			route[-1] = to.to_data()
			return _success({"points":route,"connection_ids":_route_connection_ids(route),"cost":direct["data"]["cost"]})
	var nodes: Dictionary = {"@from": from.to_data(), "@to": to.to_data()}
	var edges: Dictionary = {"@from": [], "@to": []}
	var endpoints: Dictionary = {}
	for endpoint: Dictionary in _stage["connectors"]:
		if not endpoint["kind"] in profile["connector_kinds"] or float(endpoint["headroom"]) + EPS < height: continue
		endpoints[endpoint["connector_id"]] = endpoint
	# Portals are traversable intervals, clipped by the body radius. Visibility
	# candidates include interval ends, source/destination projections and obstacle
	# corners. A blocked center never removes the whole opening from the graph.
	for connection: Dictionary in _stage["connections"]:
		if not endpoints.has(connection["a_connector"]) or not endpoints.has(connection["b_connector"]): continue
		var a: Dictionary = endpoints[connection["a_connector"]]
		var b: Dictionary = endpoints[connection["b_connector"]]
		var index := 0
		for seam: Vector3 in _portal_candidates(a,b,from.position,to.position,radius,candidate):
			var pa := ExpeditionWorldPoint.create(from.stage_id,a["surface_id"],seam)
			var pb := ExpeditionWorldPoint.create(from.stage_id,b["surface_id"],seam)
			if not _candidate_point(pa,radius,height,candidate) or not _candidate_point(pb,radius,height,candidate): continue
			# Keep an inset state on each support, allowing turns between adjacent
			# openings without forcing the body to travel along their shared edge.
			var ia := Kernel.support_y(_cell(a["surface_id"]),seam-Vector3(a["outward"])*radius)
			var ib := Kernel.support_y(_cell(b["surface_id"]),seam-Vector3(b["outward"])*radius)
			var inside_a := ExpeditionWorldPoint.create(from.stage_id,a["surface_id"],ia)
			var inside_b := ExpeditionWorldPoint.create(from.stage_id,b["surface_id"],ib)
			if not _candidate_point(inside_a,radius,height,candidate): inside_a = pa; ia = seam
			if not _candidate_point(inside_b,radius,height,candidate): inside_b = pb; ib = seam
			if not _clear_path_segment(ia,seam,profile,candidate) or not _clear_path_segment(seam,ib,profile,candidate): continue
			if _support_segment_fraction(_cell(a["surface_id"]),ia,seam,profile) < 1.0-EPS or _support_segment_fraction(_cell(b["surface_id"]),seam,ib,profile) < 1.0-EPS: continue
			var aid := "@portal/%s/%d/a"%[connection["connection_id"],index]
			var bid := "@portal/%s/%d/b"%[connection["connection_id"],index]
			index += 1
			nodes[aid] = inside_a.to_data(); nodes[bid] = inside_b.to_data(); edges[aid] = []; edges[bid] = []
			var cost := ia.distance_to(seam)+seam.distance_to(ib)
			if connection["forward"]: edges[aid].append({"to":bid,"via":[pa.to_data(),pb.to_data()],"connection_id":connection["connection_id"],"cost":cost})
			if connection["backward"]: edges[bid].append({"to":aid,"via":[pb.to_data(),pa.to_data()],"connection_id":connection["connection_id"],"cost":cost})
	# Visibility graph corners give detours around AABBs within convex supports.
	for cell: Dictionary in _stage["surfaces"]:
		for volume_index: int in range(_volumes().size()):
			var box: AABB = _volumes()[volume_index]
			for x: float in [box.position.x - radius - EPS * 4.0, box.end.x + radius + EPS * 4.0]:
				for z: float in [box.position.z - radius - EPS * 4.0, box.end.z + radius + EPS * 4.0]:
					var position := Kernel.support_y(cell, Vector3(x, 0, z))
					var point := ExpeditionWorldPoint.create(from.stage_id, cell["surface_id"], position)
					if not _candidate_point(point,radius,height,candidate): continue
					var id := "@corner/%s/%d/%s/%s" % [cell["surface_id"], volume_index, x, z]
					nodes[id] = point.to_data()
					edges[id] = []
	var segments: Array = []
	var segment_ids: Array = _segments.keys(); segment_ids.sort()
	for id: String in segment_ids: segments.append(_segments[id])
	if candidate != null: segments.append(candidate)
	for cell: Dictionary in _stage["surfaces"]:
		for segment_index: int in segments.size():
			var segment := segments[segment_index] as WorldSolidSegment
			for corner_index: int in segment.corners(radius).size():
				var position := Kernel.support_y(cell,segment.corners(radius)[corner_index])
				var point := ExpeditionWorldPoint.create(from.stage_id,cell["surface_id"],position)
				if not _candidate_point(point,radius,height,candidate): continue
				var id := "@segment/%s/%d/%d" % [cell["surface_id"],segment_index,corner_index]
				nodes[id] = point.to_data(); edges[id] = []
	var by_surface: Dictionary = {}
	var ids: Array = nodes.keys(); ids.sort()
	for id: String in ids:
		var surface: String = nodes[id]["surface_id"]
		if not by_surface.has(surface): by_surface[surface] = []
		by_surface[surface].append(id)
	for group: Array in by_surface.values():
		for a: String in group:
			for b: String in group:
				if a == b: continue
				if _clear_path_segment(nodes[a]["position"],nodes[b]["position"],profile,candidate) and _support_segment_fraction(_cell(nodes[a]["surface_id"]),nodes[a]["position"],nodes[b]["position"],profile) >= 1.0-EPS:
					edges[a].append({"to": b, "via": [], "connection_id": "", "cost": Vector3(nodes[a]["position"]).distance_to(nodes[b]["position"])})
	var distances := {"@from": 0.0}
	var previous: Dictionary = {}
	var frontier: Array[String] = ["@from"]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: String, b: String) -> bool: return float(distances[a]) < float(distances[b]) if distances[a] != distances[b] else a < b)
		var current: String = frontier.pop_front()
		if visited.has(current): continue
		visited[current] = true
		if current == "@to": break
		for edge: Dictionary in edges[current]:
			var route_cost: float = float(distances[current]) + float(edge["cost"])
			if route_cost + EPS >= float(distances.get(edge["to"], INF)): continue
			distances[edge["to"]] = route_cost
			previous[edge["to"]] = {"from": current, "edge": edge}
			frontier.append(edge["to"])
	if not visited.has("@to"): return _failure(&"unreachable")
	var steps: Array[Dictionary] = []
	var cursor := "@to"
	while cursor != "@from":
		steps.push_front(previous[cursor])
		cursor = previous[cursor]["from"]
	var points: Array = [from.to_data()]
	var connections: Array[String] = []
	for step: Dictionary in steps:
		var edge: Dictionary = step["edge"]
		points.append_array(edge["via"])
		points.append(nodes[edge["to"]])
		if not edge["connection_id"].is_empty(): connections.append(edge["connection_id"])
	return _success({"points": points, "connection_ids": connections, "cost": distances["@to"]})

func _portal_candidates(a: Dictionary, b: Dictionary, source: Vector3, target: Vector3, radius: float, candidate: WorldSolidSegment) -> Array[Vector3]:
	var center: Vector3 = a["position"]
	var normal: Vector3 = a["outward"]
	var tangent := Vector3(-normal.z,0,normal.x)
	var half_width := minf(float(a["width"]),float(b["width"]))*0.5
	var inset := maxf(0.0,half_width-radius)
	var offsets: Array[float] = [-half_width,-inset,0.0,inset,half_width]
	var landmarks: Array[Vector3] = [source,target]
	for box: AABB in _volumes():
		for x: float in [box.position.x-radius-EPS*4.0,box.end.x+radius+EPS*4.0]:
			for z: float in [box.position.z-radius-EPS*4.0,box.end.z+radius+EPS*4.0]: landmarks.append(Vector3(x,center.y,z))
	for segment: WorldSolidSegment in _segments.values(): landmarks.append_array(segment.corners(radius))
	if candidate != null: landmarks.append_array(candidate.corners(radius))
	for point: Vector3 in landmarks:
		offsets.append(clampf((point-center).dot(tangent),-half_width,half_width))
	var delta := target-source
	var denominator := delta.dot(normal)
	if absf(denominator) > EPS:
		var intersection := source+delta*((center-source).dot(normal)/denominator)
		offsets.append(clampf((intersection-center).dot(tangent),-half_width,half_width))
	offsets.sort()
	var result: Array[Vector3] = []
	for offset: float in offsets:
		var point := Kernel.support_y(_cell(a["surface_id"]),center+tangent*offset)
		if result.is_empty() or result[-1].distance_to(point) > EPS: result.append(point)
	return result

func _route_connection_ids(route: Array) -> Array[String]:
	var result: Array[String] = []
	for index: int in range(1,route.size()):
		if route[index-1]["surface_id"] == route[index]["surface_id"]: continue
		for connection: Dictionary in _stage["connections"]:
			var a: Dictionary = {}; var b: Dictionary = {}
			for endpoint: Dictionary in _stage["connectors"]:
				if endpoint["connector_id"] == connection["a_connector"]: a = endpoint
				if endpoint["connector_id"] == connection["b_connector"]: b = endpoint
			if a.is_empty() or b.is_empty(): continue
			if [a["surface_id"],b["surface_id"]] == [route[index-1]["surface_id"],route[index]["surface_id"]] or [b["surface_id"],a["surface_id"]] == [route[index-1]["surface_id"],route[index]["surface_id"]]:
				var point: Vector3 = route[index]["position"]
				var normal: Vector3 = a["outward"]
				var delta := point-Vector3(a["position"])
				if absf(delta.dot(normal)) > EPS or absf(delta.dot(Vector3(-normal.z,0,normal.x))) > minf(float(a["width"]),float(b["width"]))*0.5+EPS: continue
				result.append(connection["connection_id"]); break
	return result

func sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName = &"all") -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not from.is_finite() or not to.is_finite() or not collider.has_all(["radius", "height"]) or not _finite_number(collider["radius"]) or not _finite_number(collider["height"]) or float(collider["radius"]) < 0.0 or float(collider["height"]) < 0.0: return _failure(&"invalid_collider")
	if mask not in [&"all",&"supporting_slabs"]: return _failure(&"invalid_mask")
	var fraction := 1.0
	var normal := Vector3.ZERO
	var hit_id := ""
	var volumes: Array = _volumes() if mask == &"all" else _solid_slabs
	for index: int in range(volumes.size()):
		var volume: AABB = volumes[index]
		var radius: float = collider["radius"]
		var height: float = collider["height"]
		var hit := Kernel.sweep_box(from,to,volume,radius,height)
		if hit.is_empty() or float(hit["fraction"]) > fraction: continue
		fraction = hit["fraction"]
		normal = hit["normal"]
		if mask == &"supporting_slabs":
			hit_id = "%s/slab/%d" % [_stage["stage_id"],index]
		elif index < _stage["volumes"].size():
			hit_id = "%s/volume/%d" % [_stage["stage_id"],index]
		else:
			var ids: Array = _temporary.keys()
			ids.sort()
			hit_id = "temporary/"+str(ids[index-_stage["volumes"].size()])
	if mask == &"all":
		var segment_ids: Array = _segments.keys(); segment_ids.sort()
		for id: String in segment_ids:
			var hit := _segments[id].contact(from,to,collider)
			if hit.is_empty() or float(hit["fraction"]) > fraction: continue
			fraction = hit["fraction"]; normal = hit["normal"]; hit_id = "temporary/"+id
	return _success({"hit": not hit_id.is_empty(), "fraction": fraction, "position": from.lerp(to, fraction), "normal": normal, "volume_id": hit_id})

static func _segment_box(from: Vector3, to: Vector3, box: AABB) -> Dictionary:
	# Existing consumers supply their own expanded/local box; preserve this API.
	return Kernel.sweep_box(from,to,box,0.0,0.0,false)

func query_attack(shape: Dictionary, source: ExpeditionWorldPoint, target: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not shape.has_all(["geometry_rule_id", "range"]) or not _finite_number(shape["range"]) or float(shape["range"]) < 0.0: return _failure(&"invalid_shape")
	if not _point_valid(source) or not _point_valid(target): return _failure(&"invalid_support")
	if not (shape["geometry_rule_id"] is String or shape["geometry_rule_id"] is StringName): return _failure(&"invalid_shape")
	var rule: StringName = shape["geometry_rule_id"]
	if rule not in [&"direct_volume", &"ground_connected", &"teleport_legal"]: return _failure(&"unknown_geometry_rule")
	var source_position := source.position
	var target_position := target.position
	if shape.has("source_offset") or shape.has("target_offset"):
		if rule != &"direct_volume": return _failure(&"invalid_shape")
		if not shape.get("source_offset",Vector3.ZERO) is Vector3 or not shape.get("target_offset",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var source_offset: Vector3 = shape.get("source_offset",Vector3.ZERO)
		var target_offset: Vector3 = shape.get("target_offset",Vector3.ZERO)
		if not source_offset.is_finite() or not target_offset.is_finite(): return _failure(&"invalid_shape")
		source_position += source_offset
		target_position += target_offset
	var distance := source_position.distance_to(target_position)
	var range_ok := distance <= float(shape["range"]) + EPS
	var los_ok := true
	var surfaces: Array[String] = [source.surface_id]
	if rule == &"ground_connected":
		if not shape.has("traversal"): return _failure(&"invalid_profile")
		var route := path(source, target, shape["traversal"], revision)
		los_ok = route["ok"]
		if los_ok:
			distance = route["data"]["cost"]
			range_ok = distance <= float(shape["range"]) + EPS
			for point: Dictionary in route["data"]["points"]:
				if not surfaces.has(point["surface_id"]): surfaces.append(point["surface_id"])
	elif rule == &"teleport_legal":
		if not shape.has("traversal") or not _profile_valid(shape["traversal"]): return _failure(&"invalid_profile")
		if not _point_valid(target, shape["traversal"]["radius"], shape["traversal"]["height"]): return _failure(&"invalid_destination")
		# The swept body may leave a supporting top, but may not enter its solid slab.
		# Authored planar blockers and temporary walls retain E06's bypass exception.
		var check := sweep(source.position,target.position,shape["traversal"],revision,&"supporting_slabs")
		los_ok = not check["data"]["hit"]
	else:
		var check := sweep(source_position, target_position, {"radius": 0.0, "height": 0.0}, revision)
		los_ok = not check["data"]["hit"]
	var shape_ok := true
	if not (shape.get("kind",&"sphere") is String or shape.get("kind",&"sphere") is StringName): return _failure(&"invalid_shape")
	var kind: StringName = shape.get("kind", &"sphere" )
	if kind not in [&"sphere", &"cone", &"line"]: return _failure(&"invalid_shape")
	if kind in [&"cone", &"line"]:
		if not shape.get("direction",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var direction: Vector3 = shape.get("direction", Vector3.ZERO)
		if not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_shape")
		var offset := target_position - source_position
		var along := offset.dot(direction.normalized())
		if kind == &"cone":
			var angle := float(shape.get("half_angle", -1.0))
			if not is_finite(angle) or angle < 0.0 or angle > PI: return _failure(&"invalid_shape")
			shape_ok = offset.is_zero_approx() or direction.angle_to(offset) <= angle + EPS
		else:
			var width := float(shape.get("half_width", -1.0))
			if not is_finite(width) or width < 0.0: return _failure(&"invalid_shape")
			shape_ok = along >= 0.0 and (offset - direction.normalized() * along).length() <= width + EPS
	if not surfaces.has(target.surface_id): surfaces.append(target.surface_id)
	var hit := range_ok and los_ok and shape_ok
	return _success({"range_ok": range_ok, "los_ok": los_ok, "shape_ok": shape_ok, "hit": hit, "distance": distance, "affected_surfaces": surfaces if hit else []})

func trace_ground(source: ExpeditionWorldPoint, heading: Vector3, maximum_distance: float, profile: Dictionary, revision: int) -> Dictionary:
	if not is_finite(maximum_distance) or maximum_distance <= 0.0: return _failure(&"invalid_distance")
	var result := ground_line_samples(source,heading,maximum_distance,1,profile,revision)
	if not result["ok"]: return result
	var best: Dictionary = result if not result["data"]["points"].is_empty() else {}
	if best.is_empty():
		var low := 0.0
		var high := maximum_distance
		# Refine the first obstruction/support boundary; no detour or nearest-floor repair.
		for _iteration: int in 32:
			var middle := (low+high)*0.5
			var probe := ground_line_samples(source,heading,middle,1,profile,revision)
			if not probe["ok"]: return probe
			if probe["data"]["points"].is_empty(): high = middle
			else: low = middle; best = probe
	var route: Array = best["data"]["route"].duplicate(true) if not best.is_empty() else [source.to_data()]
	var cost := 0.0
	for index: int in range(1,route.size()): cost += Vector3(route[index-1]["position"]).distance_to(route[index]["position"])
	return _success({"points":route,"cost":cost,"destination":route[-1],"truncated":cost < maximum_distance-EPS})

func _support_segment_fraction(cell: Dictionary, from: Vector3, to: Vector3, profile: Dictionary) -> float:
	_ensure_support_index()
	return SupportPatch.fraction(cell,from,to,profile,_support_index)

static func point_tolerance(a: Vector3, b: Vector3) -> float:
	# Standard Godot Vector3 components are f32; comparisons must account for their ULP scale.
	return EPS+maxf(a.length(),b.length())*1.1920928955078125e-7*4.0

func ground_region(anchor: ExpeditionWorldPoint, polygon: PackedVector2Array, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	var segments: Array = _segments.values()
	var result := WorldSupportRegion.prepare(self,anchor,polygon,profile,revision,_stage["surfaces"],_volumes(),segments)
	return _success(result["data"]) if result["ok"] else _failure(result["error_code"])

func ground_line_to(source: ExpeditionWorldPoint, destination: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if source == null or destination == null: return _failure(&"invalid_ground_line")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(destination,float(profile.get("radius",-1.0)),float(profile.get("height",-1.0))): return _failure(&"invalid_support")
	var heading := Vector3(destination.position.x-source.position.x,0,destination.position.z-source.position.z)
	if heading.is_zero_approx():
		var valid := position_query(source,profile,revision)
		if not valid["ok"]: return valid
		return _success({"points":[source.to_data()],"cost":0.0,"destination":destination.to_data()}) if source.to_data() == destination.to_data() else _failure(&"unsupported_contact")
	var sampled := _ground_line_samples(source,heading,heading.length(),1,profile,revision,true)
	if not sampled["ok"]: return sampled
	if sampled["data"]["points"].is_empty(): return _failure(&"unsupported_contact")
	var reached: Dictionary = sampled["data"]["points"][0]
	if reached["stage_id"] != destination.stage_id or reached["surface_id"] != destination.surface_id or Vector3(reached["position"]).distance_to(destination.position) > point_tolerance(source.position,destination.position): return _failure(&"unsupported_contact")
	var route: Array = sampled["data"]["route"]
	var cost := 0.0
	for index: int in range(1,route.size()): cost += Vector3(route[index-1]["position"]).distance_to(route[index]["position"])
	return _success({"points":route.duplicate(true),"cost":cost,"destination":destination.to_data()})

func ground_line_point_at(source: ExpeditionWorldPoint, horizontal: Vector2, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if source == null or not horizontal.is_finite(): return _failure(&"invalid_ground_line")
	var heading := Vector3(horizontal.x-source.position.x,0,horizontal.y-source.position.z)
	if heading.is_zero_approx(): return position_query(source,profile,revision)
	var sampled := _ground_line_samples(source,heading,heading.length(),1,profile,revision,true)
	if not sampled["ok"]: return sampled
	if sampled["data"]["points"].is_empty(): return _failure(&"unsupported_contact")
	return _success({"point":sampled["data"]["points"][0]})

func ground_line_samples(source: ExpeditionWorldPoint, heading: Vector3, spacing: float, count: int, profile: Dictionary, revision: int) -> Dictionary:
	return _ground_line_samples(source,heading,spacing,count,profile,revision,false)

func _ground_line_samples(source: ExpeditionWorldPoint, heading: Vector3, spacing: float, count: int, profile: Dictionary, revision: int, horizontal_metric: bool) -> Dictionary:
	# Heading chooses x/z direction; support supplies y. Spacing measures actual 3D travel.
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(source,profile["radius"],profile["height"]): return _failure(&"invalid_support")
	if not heading.is_finite() or Vector2(heading.x,heading.z).is_zero_approx() or not is_finite(spacing) or spacing <= 0.0 or count < 1: return _failure(&"invalid_ground_line")
	var direction := Vector2(heading.x,heading.z).normalized()
	var point := source.position
	var cell := _cell(source.surface_id)
	var distance := 0.0
	var points: Array[Dictionary] = []
	var route: Array[Dictionary] = [source.to_data()]
	var visited: Array[String] = []
	var stopped: StringName = &"unsupported_edge"
	while not cell.is_empty() and not visited.has(cell["surface_id"]):
		visited.append(cell["surface_id"])
		var exit_distance := INF
		var exit := point
		var vertices: Array = cell["vertices"]
		for index: int in vertices.size():
			var a: Vector3 = vertices[index]
			var b: Vector3 = vertices[(index+1)%vertices.size()]
			# Intersect in scalar f64, then store the point ON the selected edge.
			# Vector2.cross and a second f32 ray interpolation can overshoot a vertex.
			var ex: float = float(b.x)-float(a.x); var ez: float = float(b.z)-float(a.z)
			var ox: float = float(a.x)-float(point.x); var oz: float = float(a.z)-float(point.z)
			var denominator: float = float(direction.x)*ez-float(direction.y)*ex
			if absf(denominator) <= EPS: continue
			var along: float = (ox*ez-oz*ex)/denominator
			var fraction: float = (ox*float(direction.y)-oz*float(direction.x))/denominator
			if along > EPS and along < exit_distance and fraction >= -EPS and fraction <= 1.0+EPS:
				exit_distance = along
				var t := clampf(fraction,0,1)
				exit = Kernel.support_y(cell,Vector3(float(a.x)+ex*t,0,float(a.z)+ez*t))
		if not is_finite(exit_distance):
			# A legal origin may already lie on the outgoing connector seam.
			var immediate := _ground_line_connection(cell["surface_id"],point,direction,profile)
			if immediate.is_empty(): break
			route.append(ExpeditionWorldPoint.create(source.stage_id,immediate["surface_id"],point).to_data())
			cell = immediate
			continue
		var length := Vector2(exit.x-point.x,exit.z-point.z).length() if horizontal_metric else point.distance_to(exit)
		while points.size() < count and spacing*float(points.size()+1) <= distance+length+EPS:
			# Re-evaluate this selected support plane after f32 interpolation; never choose another floor.
			var sample := Kernel.support_y(cell,point.lerp(exit,clampf((spacing*float(points.size()+1)-distance)/length,0.0,1.0)))
			var supported := ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],sample)
			var contact := sweep(point,sample,profile,revision)
			if _support_segment_fraction(cell,point,sample,profile) < 1.0-EPS or not _point_valid(supported,profile["radius"],profile["height"]) or not contact["ok"] or contact["data"]["hit"]:
				return _success({"points":points,"truncated":true,"stop_reason":&"blocked_or_unsupported"})
			points.append(supported.to_data())
		if points.size() == count:
			route.append(points[-1].duplicate(true))
			return _success({"points":points,"route":route,"truncated":false,"stop_reason":&""})
		var crossing := sweep(point,exit,profile,revision)
		if _support_segment_fraction(cell,point,exit,profile) < 1.0-EPS or not crossing["ok"] or crossing["data"]["hit"]: stopped = &"blocked"; break
		var following := _ground_line_connection(cell["surface_id"],exit,direction,profile)
		if following.is_empty(): break
		route.append(ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],exit).to_data())
		route.append(ExpeditionWorldPoint.create(source.stage_id,following["surface_id"],exit).to_data())
		distance += length
		point = exit
		cell = following
	return _success({"points":points,"route":route,"truncated":true,"stop_reason":stopped,"stopped_at":ExpeditionWorldPoint.create(source.stage_id,cell["surface_id"],point).to_data()})

func _ground_line_connection(surface: String, point: Vector3, direction: Vector2, profile: Dictionary) -> Dictionary:
	for endpoint: Dictionary in _stage["connectors"]:
		if endpoint["surface_id"] != surface or endpoint["kind"] not in profile["connector_kinds"] or float(endpoint["headroom"]) + EPS < float(profile["height"]): continue
		var outward: Vector3 = endpoint["outward"]
		if direction.dot(Vector2(outward.x,outward.z)) <= EPS: continue
		var delta := point-Vector3(endpoint["position"])
		var tangent := Vector2(-outward.z,outward.x)
		if absf(Vector2(delta.x,delta.z).dot(Vector2(outward.x,outward.z))) > EPS or absf(Vector2(delta.x,delta.z).dot(tangent)) > float(endpoint["width"])*0.5+EPS: continue
		for connection: Dictionary in _stage["connections"]:
			if endpoint["connector_id"] not in [connection["a_connector"],connection["b_connector"]]: continue
			if endpoint["connector_id"] == connection["a_connector"] and not connection["forward"]: continue
			if endpoint["connector_id"] == connection["b_connector"] and not connection["backward"]: continue
			var other_id: String = connection["b_connector"] if endpoint["connector_id"] == connection["a_connector"] else connection["a_connector"]
			for other: Dictionary in _stage["connectors"]:
				if other["connector_id"] != other_id or other["kind"] not in profile["connector_kinds"] or float(other["headroom"]) + EPS < float(profile["height"]): continue
				var following := _cell(other["surface_id"])
				if Kernel.contains(following,point) and _point_valid(ExpeditionWorldPoint.create(_stage["stage_id"],following["surface_id"],point),profile["radius"],profile["height"]): return following
	return {}

func _candidate_point(point: ExpeditionWorldPoint, radius: float, height: float, candidate: WorldSolidSegment) -> bool:
	if not _point_valid(point,radius,height): return false
	return candidate == null or candidate.contact(point.position,point.position,{"radius":radius,"height":height}).is_empty()

func _clear_path_segment(from: Vector3, to: Vector3, profile: Dictionary, candidate: WorldSolidSegment) -> bool:
	if not Kernel.clear_segment(from,to,_volumes(),profile["radius"],profile["height"]): return false
	for segment: WorldSolidSegment in _segments.values():
		if not segment.contact(from,to,profile).is_empty(): return false
	return candidate == null or candidate.contact(from,to,profile).is_empty()

func can_insert_segment(id: String, segment: WorldSolidSegment, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if id.is_empty() or _temporary.has(id) or _segments.has(id): return _failure(&"invalid_identity")
	if segment == null or not segment.is_valid(): return _failure(&"invalid_volume")
	var profile := segment.profile(); var anchor := segment.anchor()
	if not _profile_valid(profile) or not _point_valid(anchor,profile["radius"],profile["height"]): return _failure(&"invalid_support")
	var region := segment.support_region()
	if not region.is_empty():
		var support := ground_region(anchor,region["polygon"],region["profile"],revision)
		if not support["ok"]: return support
	else:
		var endpoints := segment.ends()
		for endpoint: Vector3 in endpoints:
			var support := ground_line_point_at(anchor,Vector2(endpoint.x,endpoint.z),profile,revision)
			if not support["ok"]: return support
			if Vector3(support["data"]["point"]["position"]).distance_to(endpoint) > EPS: return _failure(&"non_planar_field_support")
		if sweep(endpoints[0],endpoints[1],profile,revision)["data"]["hit"]: return _failure(&"blocked_obstacle")
	for occupant: Dictionary in _occupancy.values():
		var position: Vector3 = occupant["point"]["position"]
		if not segment.contact(position,position,occupant["profile"]).is_empty(): return _failure(&"occupied")
	for occupant: Dictionary in _occupancy.values():
		var data: Dictionary = occupant["point"]
		var origin := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
		for socket: Dictionary in _stage["sockets"]:
			var destination := ExpeditionWorldPoint.create(_stage["stage_id"],socket["surface_id"],socket["position"])
			if path(origin,destination,occupant["profile"],revision)["ok"] and not _path(origin,destination,occupant["profile"],revision,segment)["ok"]: return _failure(&"would_disconnect")
	return _success()

func insert_segment(id: String, segment: WorldSolidSegment, revision: int) -> Dictionary:
	var valid := can_insert_segment(id,segment,revision)
	if not valid["ok"]: return valid
	_segments[id] = segment.snapshot()
	geometry_revision += 1
	return _success()

func insert_obstacle(id: String, volume: AABB, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if id.is_empty() or _temporary.has(id) or _segments.has(id): return _failure(&"invalid_identity")
	if not volume.position.is_finite() or not volume.size.is_finite() or volume.size.x <= 0.0 or volume.size.y <= 0.0 or volume.size.z <= 0.0: return _failure(&"invalid_volume")
	for occupant: Dictionary in _occupancy.values():
		if not Kernel.clear_segment(occupant["point"]["position"], occupant["point"]["position"], [volume], occupant["radius"], occupant["height"]): return _failure(&"occupied")
	# Preserve every currently reachable authored socket for each registered occupant.
	# Compute before insertion, then reject atomically if the candidate disconnects one.
	var protected: Array[Dictionary] = []
	for occupant: Dictionary in _occupancy.values():
		var origin := ExpeditionWorldPoint.create(occupant["point"]["stage_id"], occupant["point"]["surface_id"], occupant["point"]["position"])
		for socket: Dictionary in _stage["sockets"]:
			var destination := ExpeditionWorldPoint.create(_stage["stage_id"], socket["surface_id"], socket["position"])
			if path(origin, destination, occupant["profile"], revision)["ok"]:
				protected.append({"from": origin, "to": destination, "profile": occupant["profile"]})
	_temporary[id] = volume
	for route: Dictionary in protected:
		if not path(route["from"], route["to"], route["profile"], revision)["ok"]:
			_temporary.erase(id)
			return _failure(&"would_disconnect")
	geometry_revision += 1
	return _success()

func remove_obstacle(id: String, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _temporary.erase(id) and not _segments.erase(id): return _failure(&"unknown_obstacle")
	geometry_revision += 1
	return _success()

func resolve_surface(origin: Vector3, direction: Vector3, visible_surfaces: Array[String], revision: int) -> Dictionary:
	# Pure logical ray query; the presentation adapter supplies the camera ray.
	if not _current(revision): return _failure(&"stale_geometry")
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_ray")
	var nearest := INF
	var hit: Dictionary = {}
	var ambiguous := false
	for cell: Dictionary in _stage["surfaces"]:
		if not cell["surface_id"] in visible_surfaces: continue
		var normal := Kernel.plane_normal(cell["vertices"])
		var denominator := normal.dot(direction)
		if absf(denominator) < EPS: continue
		var t: float = normal.dot(Vector3(cell["vertices"][0]) - origin) / denominator
		if t < 0.0: continue
		var point := Kernel.support_y(cell,origin + direction * t)
		var tolerance := point_tolerance(origin,point)
		if not _ray_contains(cell,point,tolerance): continue
		var time_tolerance := tolerance/direction.length()
		if t > nearest+time_tolerance: continue
		if absf(t - nearest) <= time_tolerance:
			ambiguous = true
			continue
		ambiguous = false
		nearest = t
		hit = {"point": ExpeditionWorldPoint.create(_stage["stage_id"], cell["surface_id"], point).to_data(), "normal": normal if normal.y > 0 else -normal}
	if hit.is_empty(): return _failure(&"hidden_or_missing_surface")
	if ambiguous: return _failure(&"ambiguous_surface")
	var obstruction := sweep(origin, hit["point"]["position"], {"radius": 0.0, "height": 0.0}, revision)
	if obstruction["data"]["hit"] and float(obstruction["data"]["fraction"]) < 1.0 - EPS: return _failure(&"occluded_surface")
	return _success(hit)

func presentation_snapshot(revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	# Copy only authored presentation geometry. Visibility never changes collision.
	return _success({"stage_id":_stage["stage_id"],"surfaces":_stage["surfaces"],"volumes":_volumes()})

static func _ray_contains(cell: Dictionary, point: Vector3, tolerance: float) -> bool:
	# A projection ray far from its plane loses f32 ULPs. Conservatively refuse
	# near-coincident edges instead of selecting a support by iteration order.
	var side := 0.0
	var vertices: Array = cell["vertices"]
	for index: int in vertices.size():
		var a: Vector3 = vertices[index]; var b: Vector3 = vertices[(index+1)%vertices.size()]
		var edge := Vector2(b.x-a.x,b.z-a.z)
		var signed_distance := edge.cross(Vector2(point.x-a.x,point.z-a.z))/edge.length()
		if absf(signed_distance) <= tolerance: continue
		if side == 0.0: side = signf(signed_distance)
		elif side*signed_distance < 0: return false
	return true
