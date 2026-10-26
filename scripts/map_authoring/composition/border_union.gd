@tool
extends RefCounted
## Upper envelope of intersecting convex banks, with the union's real lower
## bases. Each projected interior has exactly one cap, also at a T junction.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Topology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const EPS := Kernel.EPSILON
const MAX_FRAGMENTS := 1024
const MAX_WORK := 8388608

static func _area(vertices: Array) -> float:
	var area := 0.0
	for i: int in vertices.size():
		var a: Vector3 = vertices[i]; var b: Vector3 = vertices[(i+1)%vertices.size()]
		area += float(a.x)*float(b.z)-float(b.x)*float(a.z)
	return absf(area)*0.5

static func _clean(vertices: Array) -> Array:
	var unique: Array = []
	for point: Vector3 in vertices:
		if unique.is_empty() or unique[-1] != point: unique.append(point)
	if unique.size() > 1 and unique[0] == unique[-1]: unique.pop_back()
	var changed := true
	while changed and unique.size() >= 3:
		changed = false
		for i: int in unique.size():
			var a: Vector3 = unique[posmod(i-1,unique.size())]; var b: Vector3 = unique[i]; var c: Vector3 = unique[(i+1)%unique.size()]
			var dx := float(c.x)-float(a.x); var dz := float(c.z)-float(a.z); var length := sqrt(dx*dx+dz*dz)
			if length <= EPS or absf(dx*(float(b.z)-float(a.z))-dz*(float(b.x)-float(a.x)))/length <= EPS:
				unique.remove_at(i); changed = true; break
	return unique if unique.size() >= 3 and _area(unique) > EPS else []

static func _clip(vertices: Array, plane: PackedFloat64Array, inside: bool) -> Array:
	var output: Array = []
	for i: int in vertices.size():
		var a: Vector3 = vertices[i]; var b: Vector3 = vertices[(i+1)%vertices.size()]
		var da := plane[2]-plane[0]*float(a.x)-plane[1]*float(a.z)
		var db := plane[2]-plane[0]*float(b.x)-plane[1]*float(b.z)
		var accept_a := da >= 0.0 if inside else da <= 0.0
		var accept_b := db >= 0.0 if inside else db <= 0.0
		if accept_a: output.append(a)
		if accept_a != accept_b:
			var t := da/(da-db)
			output.append(Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t))
	return _clean(output)

static func _partition(vertices: Array, planes: Array) -> Dictionary:
	var remaining: Array = vertices; var outside: Array = []
	for plane: PackedFloat64Array in planes:
		if remaining.is_empty(): break
		var rejected := _clip(remaining,plane,false)
		if not rejected.is_empty(): outside.append(rejected)
		remaining = _clip(remaining,plane,true)
	return {"inside":remaining,"outside":outside}

static func _projected_overlap(a: Array, b: Array) -> bool:
	var av: Array = []; var bv: Array = []
	for point: Vector3 in a: av.append(Vector3(point.x,0,point.z))
	for point: Vector3 in b: bv.append(Vector3(point.x,0,point.z))
	return Kernel.cells_overlap({"vertices":av},{"vertices":bv})

static func _height_plane(face: Dictionary) -> PackedFloat64Array:
	var normal := Kernel._plane(face.vertices); var a: Vector3 = face.vertices[0]
	var sx := normal[0]/normal[1]; var sz := normal[2]/normal[1]
	return PackedFloat64Array([sx,sz,float(a.y)+sx*float(a.x)+sz*float(a.z)])

static func build(faces: Array, cancellation: Callable = Callable()) -> Dictionary:
	var ordered: Array = faces.duplicate(true); ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.face_id < b.face_id)
	var prepared := {}; var height := {}; var work := 0
	for face: Dictionary in ordered:
		if not Topology.valid_face(face) or not face.has("bottom_y"): return {"ok":false,"code":"profile_geometry"}
		prepared[face.face_id] = Prism.prepare({"volume_id":face.face_id,"support_surface_id":"","top":face.vertices,"bottom_y":face.bottom_y})
		height[face.face_id] = _height_plane(face)
	var output: Array = []; var origins := {}
	for face: Dictionary in ordered:
		var fragments: Array = [face.vertices]
		for other: Dictionary in ordered:
			work += fragments.size()
			if work > MAX_WORK: return {"ok":false,"code":"border_limit"}
			if cancellation.is_valid() and cancellation.call(): return {"ok":false,"code":"cancelled"}
			if face.face_id == other.face_id or not _projected_overlap(face.vertices,other.vertices): continue
			var planes: Array = []
			for p: PackedFloat64Array in prepared[other.face_id].planes.slice(2): planes.append(PackedFloat64Array([p[0],p[2],p[3]]))
			var a: PackedFloat64Array = height[face.face_id]; var b: PackedFloat64Array = height[other.face_id]
			var difference := PackedFloat64Array([b[0]-a[0],b[1]-a[1],b[2]-a[2]])
			if absf(difference[0])+absf(difference[1]) <= 0.000000000001:
				if difference[2] < 0.0 or (difference[2] == 0.0 and other.face_id > face.face_id): continue
			else: planes.append(difference)
			var kept: Array = []
			for polygon: Array in fragments:
				if not _projected_overlap(polygon,other.vertices): kept.append(polygon); continue
				var partition := _partition(polygon,planes)
				kept.append_array(partition.outside)
			fragments = kept
			if fragments.size()+output.size() > MAX_FRAGMENTS: return {"ok":false,"code":"border_limit"}
		var bases: Array = []
		for polygon: Array in fragments: bases.append({"vertices":polygon,"bottom_y":float(face.bottom_y)})
		for other: Dictionary in ordered:
			var split: Array = []
			for fragment: Dictionary in bases:
				work += 1
				if work > MAX_WORK: return {"ok":false,"code":"border_limit"}
				if float(other.bottom_y) >= float(fragment.bottom_y) or not _projected_overlap(fragment.vertices,other.vertices): split.append(fragment); continue
				var planes: Array = []
				for p: PackedFloat64Array in prepared[other.face_id].planes.slice(2): planes.append(PackedFloat64Array([p[0],p[2],p[3]]))
				var partition := _partition(fragment.vertices,planes)
				for polygon: Array in partition.outside: split.append({"vertices":polygon,"bottom_y":fragment.bottom_y})
				if not partition.inside.is_empty(): split.append({"vertices":partition.inside,"bottom_y":float(other.bottom_y)})
			bases = split
			if bases.size()+output.size() > MAX_FRAGMENTS: return {"ok":false,"code":"border_limit"}
		for fragment: Dictionary in bases:
			var copy := face.duplicate(true); copy.vertices = fragment.vertices; copy.bottom_y = fragment.bottom_y
			if copy.vertices != face.vertices or float(copy.bottom_y) != float(face.bottom_y): copy.face_id = face.face_id+"/union_"+Canonical.digest(fragment).substr(0,16)
			copy.walkable = Topology.is_walkable(copy.vertices)
			if not Topology.valid_face(copy): return {"ok":false,"code":"geometry_precision_limit"}
			output.append(copy); origins[copy.face_id] = face.face_id
			if output.size() > MAX_FRAGMENTS: return {"ok":false,"code":"border_limit"}
	return {"ok":true,"faces":output,"origins":origins,"work":work}
