@tool
extends RefCounted
## Scalar interval arrangement. Original endpoints survive subdivision exactly;
## every closed interval has one stable owner before mass or dressing is emitted.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Catalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Operations = preload("res://scripts/map_authoring/composition/border_operations.gd")
const EPS := Kernel.EPSILON
const MAX_SPANS := 4096
const MAX_WORK := 8388608

static func point(a: Vector3, b: Vector3, t: float) -> Vector3:
	if t == 0.0: return a
	if t == 1.0: return b
	return Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t)

static func parameter(p: Vector3, a: Vector3, b: Vector3) -> float:
	var dx := float(b.x)-float(a.x); var dz := float(b.z)-float(a.z)
	var px := float(p.x)-float(a.x); var pz := float(p.z)-float(a.z)
	var length := sqrt(dx*dx+dz*dz)
	if length <= EPS: return -INF
	var nx := -dz/length; var nz := dx/length
	if absf(nx*px+nz*pz) > EPS+Kernel.horizontal_roundoff(nx,nz,a)+Kernel.horizontal_roundoff(nx,nz,p): return -INF
	var t := (px*dx+pz*dz)/(length*length)
	var y := float(a.y)+(float(b.y)-float(a.y))*t
	if absf(float(p.y)-y) > EPS+Kernel._half_ulp(p.y)+absf(1.0-t)*Kernel._half_ulp(a.y)+absf(t)*Kernel._half_ulp(b.y): return -INF
	return t

static func _key(a: Vector3, b: Vector3) -> String:
	var ends := [Canonical.encode(a),Canonical.encode(b)]; ends.sort()
	return "|".join(ends)

static func _selection(owners: Array, settings: Dictionary, catalog: Dictionary) -> Dictionary:
	var first: Dictionary = owners[0]
	var profiles := {}; var references := {}
	for owner: Dictionary in owners:
		profiles[owner.profile_id] = true; references[owner.instance_id] = true
	if profiles.size() == 1: return {"ok":true,"profile_id":first.profile_id}
	var selected := ""; var ids: Array = references.keys(); ids.sort()
	for i: int in ids.size():
		for j: int in range(i+1,ids.size()):
			var a: Dictionary = owners.filter(func(entry: Dictionary) -> bool: return entry.instance_id == ids[i])[0]
			var b: Dictionary = owners.filter(func(entry: Dictionary) -> bool: return entry.instance_id == ids[j])[0]
			if a.profile_id == b.profile_id: continue
			var chosen := ""
			for entry: Dictionary in settings.transitions:
				if entry.a_instance in [ids[i],ids[j]] and entry.b_instance in [ids[i],ids[j]]: chosen = entry.profile_id; break
			if chosen.is_empty() or not catalog.definitions.has(chosen): return Catalog.fail("transition_required",ids[i]+"/"+str(ids[j]))
			var definition: Dictionary = catalog.definitions[chosen]
			if not definition.has("pairs") or a.profile_id == Operations.LEGACY or b.profile_id == Operations.LEGACY: return Catalog.fail("transition_required",ids[i]+"/"+str(ids[j]))
			var pair := [catalog.definitions[a.profile_id].biome_id,catalog.definitions[b.profile_id].biome_id]; pair.sort()
			if pair not in definition.pairs or (not selected.is_empty() and selected != chosen): return Catalog.fail("transition_required",ids[i]+"/"+str(ids[j]))
			selected = chosen
	return {"ok":true,"profile_id":selected}

static func build(boundaries: Array, endpoints: Dictionary, settings: Dictionary, fallback: String, instances: Array, cancellation: Callable = Callable()) -> Dictionary:
	var checked := Operations.validate(settings,instances)
	if not checked.ok: return checked
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return catalog
	var style := {}; var rotations := {}; var raw: Array = []
	for instance: Dictionary in instances: style[instance.instance_id] = fallback; rotations[instance.instance_id] = int(instance.rotation_quarters)
	for entry: Dictionary in settings.instances: style[entry.instance_id] = entry.profile_id
	for id: String in style.values():
		if id != Operations.LEGACY and (not catalog.definitions.has(id) or not catalog.definitions[id].has("biome_id")): return Catalog.fail("profile_missing",id)
	for boundary: Dictionary in boundaries:
		if cancellation.is_valid() and cancellation.call(): return Catalog.fail("cancelled")
		if boundary.closure != "profile": continue
		if not style.has(boundary.instance_id): return Catalog.fail("profile_invalid")
		var a: Vector3 = boundary.a; var b: Vector3 = boundary.b
		var dx := float(b.x)-float(a.x); var dz := float(b.z)-float(a.z); var length := sqrt(dx*dx+dz*dz)
		if length <= EPS: return Catalog.fail("geometry_precision_limit",boundary.span_id)
		var gaps: Array = []
		for id: String in boundary.openings:
			if not endpoints.has(id): return Catalog.fail("connector_missing",id)
			var port: Dictionary = endpoints[id]
			var t := ((float(port.position.x)-float(a.x))*dx+(float(port.position.z)-float(a.z))*dz)/length
			gaps.append([maxf(0.0,t-float(port.width)*0.5),minf(length,t+float(port.width)*0.5)])
		gaps.sort_custom(func(x: Array,y: Array) -> bool: return x[0] < y[0])
		var cursor := 0.0; var closed: Array = []
		for gap: Array in gaps:
			if gap[0] > cursor+EPS: closed.append([cursor,gap[0]])
			cursor = maxf(cursor,gap[1])
		if cursor < length-EPS: closed.append([cursor,length])
		for interval: Array in closed:
			raw.append({"a":point(a,b,float(interval[0])/length),"b":point(a,b,float(interval[1])/length),"outward":boundary.outward,"profile_id":style[boundary.instance_id],"instance_id":boundary.instance_id,"boundary_id":boundary.span_id,"rotation_quarters":rotations[boundary.instance_id]})
			if raw.size() > MAX_SPANS: return Catalog.fail("border_limit")
	raw.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id or (a.instance_id == b.instance_id and a.boundary_id < b.boundary_id))
	var arranged := {}; var work := 0
	for span: Dictionary in raw:
		var cuts: Array = [{"t":0.0,"point":span.a},{"t":1.0,"point":span.b}]; var seen := {span.a:true,span.b:true}
		for other: Dictionary in raw:
			for original: Vector3 in [other.a,other.b]:
				work += 1
				if work > MAX_WORK: return Catalog.fail("border_limit")
				if work%64 == 0 and cancellation.is_valid() and cancellation.call(): return Catalog.fail("cancelled")
				if seen.has(original): continue
				var t := parameter(original,span.a,span.b)
				if t > 0.0 and t < 1.0: cuts.append({"t":t,"point":original}); seen[original] = true
		cuts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t < b.t)
		for i: int in range(1,cuts.size()):
			var a: Vector3 = cuts[i-1].point; var b: Vector3 = cuts[i].point
			if Vector2(b.x-a.x,b.z-a.z).length() <= EPS: return Catalog.fail("geometry_precision_limit",span.boundary_id)
			var key := _key(a,b)
			if not arranged.has(key): arranged[key] = []
			var copy := span.duplicate(true); copy.a = a; copy.b = b; arranged[key].append(copy)
	var keys: Array = arranged.keys(); keys.sort(); var output: Array = []
	for key: String in keys:
		var owners: Array = arranged[key]
		var selected := _selection(owners,settings,catalog)
		if not selected.ok: return selected
		var span: Dictionary = owners[0].duplicate(true); span.profile_id = selected.profile_id
		var provenance: Array = []
		for owner: Dictionary in owners: provenance.append({"instance_id":owner.instance_id,"boundary_id":owner.boundary_id,"profile_id":owner.profile_id})
		span["owners"] = provenance
		span["span_id"] = "closed_"+Canonical.digest([key,selected.profile_id,provenance]).substr(0,24)
		output.append(span)
		if output.size() > MAX_SPANS: return Catalog.fail("border_limit")
	return {"ok":true,"spans":output}
