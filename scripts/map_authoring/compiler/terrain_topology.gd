@tool
extends RefCounted
## Pure topology of real terrain faces and exposed portions of their mass.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const EPS := Kernel.EPSILON
const MAX_FACES := 1024
const MAX_SIDES := 4096
const FIELDS := ["face_id","source_id","vertices","headroom","walkable","special"]

static func fail(code: String, id: String = "") -> Dictionary:
	return {"ok":false,"code":code,"entity_id":id}

static func is_walkable(vertices: Array) -> bool:
	return absf(Kernel.plane_normal(vertices).y) >= sqrt(0.5)-EPS

static func valid_face(value: Variant) -> bool:
	if not value is Dictionary or value.size() != FIELDS.size()+1 or not value.has_all(FIELDS): return false
	if not value.face_id is String or value.face_id.is_empty() or not value.source_id is String or value.source_id.is_empty() or not value.walkable is bool or not value.special is bool: return false
	if not (value.headroom is int or value.headroom is float) or not is_finite(float(value.headroom)) or value.headroom <= 0: return false
	var mass := {"volume_id":"terrain/"+str(value.face_id),"support_surface_id":str(value.face_id) if value.walkable else "","top":value.vertices}
	if value.has("bottom_y"): mass["bottom_y"] = value.bottom_y
	elif value.has("thickness_y"): mass["thickness_y"] = value.thickness_y
	else: return false
	return Prism.valid(mass) and value.walkable == is_walkable(value.vertices)

static func point_on_edge(point: Vector3, a: Vector3, b: Vector3, face: Dictionary) -> float:
	var dx := float(b.x)-float(a.x); var dz := float(b.z)-float(a.z)
	var px := float(point.x)-float(a.x); var pz := float(point.z)-float(a.z)
	var length := sqrt(dx*dx+dz*dz)
	if length <= EPS: return -1.0
	var cross := absf(dx*pz-dz*px)/length
	var nx := -dz/length; var nz := dx/length
	if cross > EPS+Kernel.horizontal_roundoff(nx,nz,a)+Kernel.horizontal_roundoff(nx,nz,point): return -1.0
	if not Kernel.contains({"vertices":face.vertices,"headroom":face.headroom},point): return -1.0
	return (px*dx+pz*dz)/(length*length)

static func bottom(face: Dictionary, point: Vector3) -> Vector3:
	return Vector3(point.x,float(face.bottom_y) if face.has("bottom_y") else float(point.y)-float(face.thickness_y),point.z)

static func interpolate(a: Vector3, b: Vector3, t: float) -> Vector3:
	if t == 0.0: return a
	if t == 1.0: return b
	return Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t)

static func skin(sides: Array, edge: Dictionary, top_a: Vector3, top_b: Vector3, bottom_a: Vector3, bottom_b: Vector3, token: Variant) -> void:
	if top_a == bottom_a and top_b == bottom_b: return
	sides.append({"side_id":"side_"+Canonical.digest([edge.span_id,token,top_a,top_b,bottom_a,bottom_b]).substr(0,20),"face_id":edge.face_id,"span_id":edge.span_id,"vertices":[top_a,top_b,bottom_b,bottom_a],"outward":edge.outward,"material_id":"stone"})

static func boundary(edge: Dictionary, closure: String, adjacent: String = "") -> Dictionary:
	return {"span_id":edge.span_id,"face_id":edge.face_id,"surface_id":edge.face_id if edge.walkable else "","source_id":edge.source_id,"a":edge.a,"b":edge.b,"outward":edge.outward,"kind":"support_edge" if closure == "profile" else "cliff_edge","closure":closure,"adjacent_face_id":adjacent,"openings":[]}

static func endpoint(edge: Dictionary) -> Dictionary:
	return {"connector_id":"j_"+edge.span_id,"surface_id":edge.face_id,"position":(edge.a+edge.b)*0.5,"outward":edge.outward,"kind":"walk","tags":["map_editor"],"width":Vector2(edge.b.x-edge.a.x,edge.b.z-edge.a.z).length(),"headroom":float(edge.face.headroom),"direction":"both"}

static func build(faces: Array, cancellation: Callable = Callable()) -> Dictionary:
	if faces.size() > MAX_FACES: return fail("terrain_face_limit")
	var seen := {}; var ordered: Array = faces.duplicate(true)
	for face: Variant in ordered:
		if not valid_face(face): return fail("geometry_invalid")
		if seen.has(face.face_id): return fail("geometry_invalid",face.face_id)
		seen[face.face_id] = true
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.face_id < b.face_id)
	var edges: Array = []; var vertices: Dictionary = {}
	for face: Dictionary in ordered:
		for point: Vector3 in face.vertices: vertices[point] = true
		var area := 0.0
		for k: int in face.vertices.size():
			var a: Vector3 = face.vertices[k]; var b: Vector3 = face.vertices[(k+1)%face.vertices.size()]
			area += float(a.x)*float(b.z)-float(b.x)*float(a.z)
		for k: int in face.vertices.size():
			var a: Vector3 = face.vertices[k]; var b: Vector3 = face.vertices[(k+1)%face.vertices.size()]
			var dx := float(b.x)-float(a.x); var dz := float(b.z)-float(a.z); var length := sqrt(dx*dx+dz*dz)
			if length <= EPS: return fail("geometry_precision_limit",face.face_id)
			edges.append({"edge_id":"e_"+Canonical.digest([face.face_id,a,b]).substr(0,20),"face_id":face.face_id,"source_id":face.source_id,"face":face,"a":a,"b":b,"outward":Vector3(dz/length,0,-dx/length)*signf(area),"walkable":face.walkable})
	var spans: Dictionary = {}
	var work := 0
	for edge: Dictionary in edges:
		if cancellation.is_valid() and cancellation.call(): return fail("cancelled")
		var cuts: Array = [{"t":0.0,"point":edge.a},{"t":1.0,"point":edge.b}]
		for point: Vector3 in vertices:
			work += 1
			if work%64 == 0 and cancellation.is_valid() and cancellation.call(): return fail("cancelled")
			var t := point_on_edge(point,edge.a,edge.b,edge.face)
			if t > 0.0 and t < 1.0 and point != edge.a and point != edge.b: cuts.append({"t":t,"point":point})
		cuts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t < b.t)
		for k: int in range(1,cuts.size()):
			var a: Vector3 = cuts[k-1].point; var b: Vector3 = cuts[k].point
			if a == b: continue
			var ends := [Canonical.encode(a),Canonical.encode(b)]; ends.sort()
			var key: String = "|".join(ends)
			if not spans.has(key): spans[key] = []
			var span := edge.duplicate(); span.a = a; span.b = b; span["span_id"] = edge.edge_id+"_"+key.sha256_text().substr(0,12)
			spans[key].append(span)
	var ports: Array = []; var joins: Array = []; var boundaries: Array = []; var sides: Array = []
	var keys: Array = spans.keys(); keys.sort()
	for key: String in keys:
		if cancellation.is_valid() and cancellation.call(): return fail("cancelled")
		var pair: Array = spans[key]
		if pair.size() > 2: return fail("geometry_non_manifold")
		if pair.size() == 1:
			var edge: Dictionary = pair[0]
			boundaries.append(boundary(edge,"profile" if edge.walkable else "terrain"))
			skin(sides,edge,edge.a,edge.b,bottom(edge.face,edge.a),bottom(edge.face,edge.b),"external")
			if sides.size() > MAX_SIDES: return fail("terrain_side_limit")
			continue
		var a: Dictionary = pair[0]; var b: Dictionary = pair[1]
		if Vector3(a.outward).dot(b.outward) > -1.0+EPS: return fail("geometry_invalid")
		if a.walkable and b.walkable:
			var pa := endpoint(a); var pb := endpoint(b); ports.append(pa); ports.append(pb)
			joins.append({"connection_id":"join_"+key.sha256_text().substr(0,20),"a_connector":pa.connector_id,"b_connector":pb.connector_id,"forward":true,"backward":true})
		elif a.walkable != b.walkable:
			var walking: Dictionary = a if a.walkable else b; var cliff: Dictionary = b if a.walkable else a
			boundaries.append(boundary(walking,"terrain",cliff.face_id))
		# Equal top edges can have different lower bounds (ground meets a bridge).
		# Only the non-overlapped lower strip is exposed. Split a crossing once.
		var a0 := bottom(a.face,a.a); var a1 := bottom(a.face,a.b)
		var b0 := bottom(b.face,a.a); var b1 := bottom(b.face,a.b)
		var d0 := float(a0.y)-float(b0.y); var d1 := float(a1.y)-float(b1.y)
		var cuts: Array[float] = [0.0,1.0]
		if d0*d1 < 0.0: cuts.insert(1,d0/(d0-d1))
		for k: int in range(1,cuts.size()):
			var lo := cuts[k-1]; var hi := cuts[k]; var mid := (lo+hi)*0.5
			var difference := d0+(d1-d0)*mid
			if difference == 0.0: continue
			var owner: Dictionary = a if difference < 0 else b
			var lower0: Vector3 = a0 if difference < 0 else b0; var lower1: Vector3 = a1 if difference < 0 else b1
			var upper0: Vector3 = b0 if difference < 0 else a0; var upper1: Vector3 = b1 if difference < 0 else a1
			skin(sides,owner,interpolate(upper0,upper1,lo),interpolate(upper0,upper1,hi),interpolate(lower0,lower1,lo),interpolate(lower0,lower1,hi),[lo,hi])
			if sides.size() > MAX_SIDES: return fail("terrain_side_limit")
	return {"ok":true,"connectors":ports,"adjacency":joins,"boundaries":boundaries,"exposed_sides":sides}
