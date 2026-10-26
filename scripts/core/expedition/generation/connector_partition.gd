@tool
extends RefCounted
## Pure logical opening validation and common physical partition; no mutations.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const EPS := Kernel.EPSILON
const MAX_FRAGMENTS := 2048
const GROUP_FIELDS := ["connector_id","position","outward","width","headroom","kind","tags","direction","fragments"]

static func failure(code: String, entity: String = "", interval: Array = []) -> Dictionary:
	return {"ok":false,"code":code,"entity_id":entity,"interval":interval}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty()

static func _shape(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and value.has_all(fields)

static func _lookup(items: Array, field: String, id: String) -> Dictionary:
	for item: Variant in items:
		if item is Dictionary and item.get(field) == id: return item
	return {}

static func _port_schema(port: Dictionary) -> bool:
	if not port.has_all(["connector_id","position","outward","width","headroom","kind","tags","direction"]): return false
	if not _text(port.connector_id) or not _text(port.kind) or not port.position is Vector3 or not port.position.is_finite() or not port.outward is Vector3 or not port.outward.is_finite(): return false
	if not _number(port.width) or port.width <= 0 or not _number(port.headroom) or port.headroom <= 0: return false
	if absf(port.outward.y) > EPS or absf(port.outward.length()-1.0) > EPS or port.direction not in ["both","in","out"]: return false
	if not port.tags is Array or port.tags.is_empty(): return false
	var seen: Dictionary = {}
	for tag: Variant in port.tags:
		if not _text(tag) or seen.has(tag): return false
		seen[tag] = true
	return true

static func _tags(tags: Array) -> Array:
	var result := tags.duplicate(); result.sort(); return result

static func _horizontal(port: Dictionary, t: float) -> Vector3:
	var origin: Vector3 = port.position; var normal: Vector3 = port.outward
	return Vector3(float(origin.x)-float(normal.z)*t,0,float(origin.z)+float(normal.x)*t)

static func _same_xz(a: Vector3, b: Vector3) -> bool:
	return absf(float(a.x)-float(b.x)) <= EPS+Kernel.horizontal_roundoff(1,0,a)+Kernel.horizontal_roundoff(1,0,b) and absf(float(a.z)-float(b.z)) <= EPS+Kernel.horizontal_roundoff(0,1,a)+Kernel.horizontal_roundoff(0,1,b)

static func _physical(endpoint: Dictionary, cells: Array, guaranteed_headroom: bool = true) -> Dictionary:
	if not _port_schema(endpoint) or not _text(endpoint.get("surface_id")): return failure("connector_invalid",str(endpoint.get("connector_id","")))
	var cell := _lookup(cells,"surface_id",endpoint.surface_id)
	if not cell.get("vertices") is Array or cell.vertices.size() < 3 or not _number(cell.get("headroom")) or float(cell.headroom) <= 0: return failure("connector_invalid",endpoint.connector_id)
	for vertex: Variant in cell.vertices:
		if not vertex is Vector3 or not vertex.is_finite(): return failure("connector_invalid",endpoint.connector_id)
	if not Kernel.valid_cell(cell) or (guaranteed_headroom and endpoint.headroom > float(cell.headroom)+EPS) or not Kernel.connector_valid(endpoint,cell): return failure("connector_invalid",endpoint.connector_id)
	return {"ok":true,"cell":cell}

static func validate_port_group(group: Dictionary, part: Dictionary) -> Dictionary:
	var id := str(group.get("connector_id",""))
	if not _shape(group,GROUP_FIELDS) or not _port_schema(group) or not group.fragments is Array or group.fragments.is_empty() or group.fragments.size() > MAX_FRAGMENTS: return failure("connector_invalid",id)
	if not part.get("connectors") is Array or not part.get("surfaces") is Array: return failure("connector_invalid",id)
	var fragments: Array = group.fragments.duplicate(true); var seen: Dictionary = {}
	for fragment: Variant in fragments:
		if not fragment is Dictionary or not _shape(fragment,["connector_id","t0","t1"]) or not _text(fragment.connector_id) or not _number(fragment.t0) or not _number(fragment.t1) or float(fragment.t1) <= float(fragment.t0) or seen.has(fragment.connector_id): return failure("connector_invalid",id)
		seen[fragment.connector_id] = true
	fragments.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t0 < b.t0 if a.t0 != b.t0 else a.connector_id < b.connector_id)
	var cursor := -float(group.width)*0.5; var result: Array = []; var member_ids: Array[String] = []
	for fragment: Dictionary in fragments:
		var lo := float(fragment.t0); var hi := float(fragment.t1)
		if lo != cursor: return failure("geometry_precision_limit" if absf(lo-cursor) <= EPS else "connector_coverage",id,[cursor,lo])
		if hi > float(group.width)*0.5: return failure("connector_coverage",id,[lo,hi])
		if hi-lo <= EPS: return failure("geometry_precision_limit",id,[lo,hi])
		var endpoint := _lookup(part.connectors,"connector_id",fragment.connector_id)
		var checked := _physical(endpoint,part.surfaces)
		if not checked.ok: return failure("connector_invalid",id,[lo,hi])
		if endpoint.connector_id == id and fragments.size() != 1: return failure("connector_invalid",id)
		if endpoint.kind != group.kind or endpoint.direction != group.direction or _tags(endpoint.tags) != _tags(group.tags) or Vector3(endpoint.outward).distance_to(group.outward) > EPS: return failure("connector_invalid",id,[lo,hi])
		if absf(float(endpoint.width)-(hi-lo)) > EPS or float(endpoint.headroom) > float(group.headroom)+EPS or not _same_xz(endpoint.position,_horizontal(group,(lo+hi)*0.5)): return failure("connector_invalid",id,[lo,hi])
		var cell: Dictionary = checked.cell
		for t: float in [lo,hi]:
			if not Kernel.contains(cell,Kernel.support_y(cell,_horizontal(group,t))): return failure("connector_coverage",id,[lo,hi])
		if lo <= 0 and hi >= 0 and not Kernel.contains(cell,group.position): return failure("connector_invalid",id,[lo,hi])
		if not result.is_empty():
			var prior: Dictionary = result[-1]
			var point := Kernel.support_y(prior.cell,_horizontal(group,lo))
			if not Kernel.contains(cell,point): return failure("seam_position",id,[lo,lo])
		result.append({"endpoint":endpoint.duplicate(true),"cell":cell.duplicate(true),"t0":lo,"t1":hi})
		member_ids.append(endpoint.connector_id); cursor = hi
	if cursor != float(group.width)*0.5: return failure("geometry_precision_limit" if absf(cursor-float(group.width)*0.5) <= EPS else "connector_coverage",id,[cursor,float(group.width)*0.5])
	return {"ok":true,"grouped":true,"port":group.duplicate(true),"fragments":result,"member_ids":member_ids}

static func validate_groups(part: Dictionary) -> Dictionary:
	if not part.get("connector_groups",[]) is Array or not part.get("connectors") is Array or not part.get("surfaces") is Array: return failure("connector_invalid")
	var cell_ids := {}
	for cell: Variant in part.surfaces:
		if not cell is Dictionary or not _text(cell.get("surface_id")) or cell_ids.has(cell.surface_id) or not cell.get("vertices") is Array or not _number(cell.get("headroom")): return failure("connector_invalid")
		for vertex: Variant in cell.vertices:
			if not vertex is Vector3 or not vertex.is_finite(): return failure("connector_invalid")
		if not Kernel.valid_cell(cell): return failure("connector_invalid",cell.surface_id)
		cell_ids[cell.surface_id] = true
	var endpoints: Dictionary = {}; var group_ids: Dictionary = {}; var members: Dictionary = {}; var ports: Dictionary = {}
	for endpoint: Variant in part.connectors:
		if not endpoint is Dictionary or not _text(endpoint.get("connector_id")) or endpoints.has(endpoint.connector_id): return failure("connector_invalid")
		if not _physical(endpoint,part.surfaces,false).ok: return failure("connector_invalid",endpoint.connector_id)
		endpoints[endpoint.connector_id] = true
	for group: Variant in part.get("connector_groups",[]):
		if not group is Dictionary: return failure("connector_invalid")
		var checked := validate_port_group(group,part)
		if not checked.ok: return checked
		var id: String = group.connector_id
		if group_ids.has(id): return failure("connector_invalid",id)
		group_ids[id] = true; ports[id] = checked
		for member: String in checked.member_ids:
			if members.has(member): return failure("connector_invalid",id)
			members[member] = id
	for id: String in group_ids:
		if endpoints.has(id) and (not members.has(id) or members[id] != id or ports[id].member_ids.size() != 1): return failure("connector_invalid",id)
	return {"ok":true,"ports":ports,"members":members}

static func resolve_port(part: Dictionary, id: String) -> Dictionary:
	var checked := validate_groups(part)
	if not checked.ok: return checked
	if checked.ports.has(id): return checked.ports[id]
	if checked.members.has(id): return failure("connector_invalid",id)
	for link: Dictionary in part.get("internal_connections",[]):
		if id in [link.get("a_connector"),link.get("b_connector")]: return failure("connector_reused",id)
	var endpoint := _lookup(part.connectors,"connector_id",id)
	var physical := _physical(endpoint,part.surfaces,false)
	if not physical.ok: return physical
	return {"ok":true,"grouped":false,"port":endpoint.duplicate(true),"member_ids":[id],"fragments":[{"endpoint":endpoint.duplicate(true),"cell":physical.cell.duplicate(true),"t0":-float(endpoint.width)*0.5,"t1":float(endpoint.width)*0.5}]}

static func transform_group(group: Dictionary, quarter: int, offset: Vector3, prefix: String) -> Dictionary:
	var result := group.duplicate(true)
	result.connector_id = prefix+str(group.connector_id)
	result.position = Kernel.rotate(group.position,quarter)+offset; result.outward = Kernel.rotate(group.outward,quarter)
	for fragment: Dictionary in result.fragments: fragment.connector_id = prefix+str(fragment.connector_id)
	return result

static func compatibility(a: Dictionary, b: Dictionary, profile: Dictionary, legacy_assembly: bool = false) -> Dictionary:
	if not _port_schema(a) or not _port_schema(b): return failure("connector_invalid")
	if Vector3(a.position).distance_to(b.position) > EPS: return failure("seam_position",a.connector_id)
	if (Vector3(a.outward).distance_to(-b.outward) > EPS if legacy_assembly else Vector3(a.outward).dot(b.outward) > -1.0+EPS): return failure("seam_orientation",a.connector_id)
	if not legacy_assembly and (absf(float(a.width)-float(b.width)) > EPS or absf(float(a.headroom)-float(b.headroom)) > EPS): return failure("seam_dimensions",a.connector_id)
	if not _number(profile.get("radius")) or not _number(profile.get("height")) or float(profile.radius) <= 0 or float(profile.height) <= 0 or not (profile.get("connector_kinds") is Array or profile.get("connector_kinds") is PackedStringArray): return failure("connector_invalid")
	if minf(a.width,b.width)+EPS < 2.0*float(profile.radius): return failure("seam_dimensions",a.connector_id)
	if minf(a.headroom,b.headroom)+EPS < float(profile.height): return failure("insufficient_headroom",a.connector_id)
	var shared := false
	for tag: String in a.tags:
		if tag in b.tags: shared = true
	if a.kind != b.kind or a.kind not in profile.connector_kinds or (not shared if not legacy_assembly else _tags(a.tags) != _tags(b.tags)): return failure("seam_tags",a.connector_id)
	var forward: bool = a.direction in ["both","out"] and b.direction in ["both","in"]
	var backward: bool = b.direction in ["both","out"] and a.direction in ["both","in"]
	if not forward and not backward: return failure("seam_direction",a.connector_id)
	return {"ok":true,"forward":forward,"backward":backward}

static func _cover(fragments: Array, lo: float, hi: float, reversed: bool) -> Dictionary:
	var found: Dictionary = {}
	for fragment: Dictionary in fragments:
		var left: float = -fragment.t1 if reversed else fragment.t0
		var right: float = -fragment.t0 if reversed else fragment.t1
		if left <= lo+EPS and right >= hi-EPS:
			if not found.is_empty(): return {}
			found = fragment
	return found

static func partition_link(a: Dictionary, b: Dictionary, link_id: String, profile: Dictionary, legacy_assembly: bool = false) -> Dictionary:
	if not a.get("ok",false) or not b.get("ok",false) or not _text(link_id): return failure("connector_invalid")
	var legacy: bool = legacy_assembly and not a.grouped and not b.grouped
	var matched := compatibility(a.port,b.port,profile,legacy)
	if not matched.ok: return matched
	if legacy:
		var pa: Dictionary = a.fragments[0].endpoint.duplicate(true); var pb: Dictionary = b.fragments[0].endpoint.duplicate(true)
		return {"ok":true,"endpoints":[pa,pb],"connections":[{"connection_id":link_id,"a_connector":pa.connector_id,"b_connector":pb.connector_id,"forward":matched.forward,"backward":matched.backward}],"remap":{pa.connector_id:[pa.connector_id],pb.connector_id:[pb.connector_id]},"consumed":[pa.connector_id,pb.connector_id],"provenance":[]}
	var cuts: Array[float] = [-float(a.port.width)*0.5,float(a.port.width)*0.5]
	for fragment: Dictionary in a.fragments: cuts.append(fragment.t0); cuts.append(fragment.t1)
	for fragment: Dictionary in b.fragments: cuts.append(-float(fragment.t1)); cuts.append(-float(fragment.t0))
	cuts.sort()
	var unique: Array[float] = []
	for cut: float in cuts:
		if unique.is_empty() or cut != unique[-1]: unique.append(cut)
	if unique.size()-1 > MAX_FRAGMENTS: return failure("geometry_precision_limit",link_id)
	var endpoints: Array = []; var connections: Array = []; var remap: Dictionary = {}; var provenance: Array = []; var consumed: Array[String] = []
	for resolved: Dictionary in [a,b]:
		for id: String in resolved.member_ids:
			if remap.has(id): return failure("connector_reused",id)
			remap[id] = []; consumed.append(id)
	for k: int in range(1,unique.size()):
		var lo := unique[k-1]; var hi := unique[k]
		if hi-lo <= EPS: return failure("geometry_precision_limit",link_id,[lo,hi])
		var fa := _cover(a.fragments,lo,hi,false); var fb := _cover(b.fragments,lo,hi,true)
		if fa.is_empty() or fb.is_empty(): return failure("connector_coverage",link_id,[lo,hi])
		if minf(fa.endpoint.headroom,fb.endpoint.headroom)+EPS < float(profile.height): return failure("insufficient_headroom",link_id,[lo,hi])
		for t: float in [lo,hi]:
			var point := Kernel.support_y(fa.cell,_horizontal(a.port,t))
			if not Kernel.contains(fa.cell,point) or not Kernel.contains(fb.cell,point): return failure("seam_position",link_id,[lo,hi])
		var center := Kernel.support_y(fa.cell,_horizontal(a.port,(lo+hi)*0.5))
		var token := Canonical.digest([link_id,fa.endpoint.connector_id,fb.endpoint.connector_id,lo,hi]).substr(0,20)
		var pair: Array = []
		for side: int in 2:
			var fragment: Dictionary = fa if side == 0 else fb
			var original: Dictionary = fragment.endpoint
			var full: bool = absf(lo-(float(fragment.t0) if side == 0 else -float(fragment.t1))) <= EPS and absf(hi-(float(fragment.t1) if side == 0 else -float(fragment.t0))) <= EPS
			var copy := original.duplicate(true)
			copy.connector_id = original.connector_id if full else str(original.connector_id)+"/cut_"+token
			copy.position = center; copy.width = hi-lo
			if not Kernel.connector_valid(copy,fragment.cell): return failure("geometry_precision_limit",link_id,[lo,hi])
			endpoints.append(copy); pair.append(copy.connector_id); remap[original.connector_id].append(copy.connector_id)
		connections.append({"connection_id":link_id if unique.size() == 2 else link_id+"/cut_"+token,"a_connector":pair[0],"b_connector":pair[1],"forward":matched.forward,"backward":matched.backward})
		provenance.append({"t0":lo,"t1":hi,"a_original":fa.endpoint.connector_id,"b_original":fb.endpoint.connector_id,"a_connector":pair[0],"b_connector":pair[1]})
	return {"ok":true,"endpoints":endpoints,"connections":connections,"remap":remap,"consumed":consumed,"provenance":provenance}
