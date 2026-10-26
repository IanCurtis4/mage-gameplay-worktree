@tool
extends RefCounted
## Physical/presentation realization of already-owned closed spans. No actor
## support is emitted: flat obstacle caps remain solids, like catalog props.
const Catalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Topology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Union = preload("res://scripts/map_authoring/composition/border_union.gd")
const EPS := Kernel.EPSILON
const MAX_CAPS := 1024
const MAX_PROPS := 512

static func _point(a: Vector3, b: Vector3, t: float) -> Vector3:
	if t == 0.0: return a
	if t == 1.0: return b
	return Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t)

static func _cap(ctx: Dictionary, vertices: Array, span: Dictionary, profile: Dictionary, index: int) -> bool:
	# Test the footprint independently of planarity. A twisted convex cap may be
	# triangulated, but a folded miter must never become overlapping triangles.
	var flat: Array = []
	for vertex: Vector3 in vertices: flat.append(Vector3(vertex.x,0,vertex.z))
	if not Kernel.valid_cell({"vertices":flat,"headroom":1.0}): return false
	var polygons: Array = [vertices]
	if not Kernel.valid_cell({"vertices":vertices,"headroom":1.0}): polygons = [[vertices[0],vertices[1],vertices[2]],[vertices[0],vertices[2],vertices[3]]]
	var base := INF
	for point: Vector3 in vertices: base = minf(base,point.y)
	base -= float(profile.base_depth)
	for k: int in polygons.size():
		var id: String = "border/"+str(span.span_id)+"/cap_%d_%d"%[index,k]
		var face := {"face_id":id,"source_id":str(span.span_id),"vertices":polygons[k],"headroom":1.0,"walkable":Topology.is_walkable(polygons[k]),"special":false,"bottom_y":base}
		if not Topology.valid_face(face): return false
		for point: Vector3 in polygons[k]:
			if not point.is_finite() or point.length() > 32768: return false
		ctx.faces.append(face); ctx.prisms.append({"volume_id":id,"support_surface_id":"","top":polygons[k].duplicate(),"bottom_y":base})
		ctx.profiles[id] = profile
		if ctx.faces.size() > MAX_CAPS: ctx["error"] = "border_limit"; return false
	return true

static func _strip(ctx: Dictionary, span: Dictionary, profile: Dictionary, lo: float, hi: float, lo_y: float, hi_y: float, index: int) -> bool:
	var a: Vector3 = span.a; var b: Vector3 = span.b; var n: Vector3 = span.outward
	var ma: Vector3 = span.get("offset_a",n*float(profile.outward_width))/float(profile.outward_width)
	var mb: Vector3 = span.get("offset_b",n*float(profile.outward_width))/float(profile.outward_width)
	var ra := float(span.get("rise_a",profile.rise))/float(profile.rise)
	var rb := float(span.get("rise_b",profile.rise))/float(profile.rise)
	return _cap(ctx,[a+ma*lo+Vector3.UP*lo_y*ra,b+mb*lo+Vector3.UP*lo_y*rb,b+mb*hi+Vector3.UP*hi_y*rb,a+ma*hi+Vector3.UP*hi_y*ra],span,profile,index)

static func _join_ends(spans: Array, definitions: Dictionary) -> Dictionary:
	var nodes := {}
	for span: Dictionary in spans:
		for end: String in ["a","b"]:
			var position: Vector3 = span[end]
			if not nodes.has(position): nodes[position] = []
			nodes[position].append({"span":span,"end":end})
	for position: Vector3 in nodes:
		var entries: Array = nodes[position]
		if entries.size() != 2: continue
		var first: Dictionary = entries[0].span; var second: Dictionary = entries[1].span
		var a: Dictionary = definitions[first.profile_id]; var b: Dictionary = definitions[second.profile_id]
		if a.geometry != b.geometry: continue
		var na: Vector3 = first.outward; var nb: Vector3 = second.outward
		var dot := float(na.x)*float(nb.x)+float(na.z)*float(nb.z)
		if dot < -1.0+EPS: continue
		var offset: Vector3
		if dot > 1.0-EPS:
			offset = na*maxf(float(a.outward_width),float(b.outward_width))
		else:
			var denominator := float(na.x)*float(nb.z)-float(na.z)*float(nb.x)
			offset = Vector3((float(a.outward_width)*float(nb.z)-float(b.outward_width)*float(na.z))/denominator,0,(float(b.outward_width)*float(na.x)-float(a.outward_width)*float(nb.x))/denominator)
		if not offset.is_finite() or offset.length() > 2048: return Catalog.fail("profile_space_conflict")
		var rise := minf(float(a.rise),float(b.rise))
		for entry: Dictionary in entries:
			entry.span["offset_"+entry.end] = offset
			entry.span["rise_"+entry.end] = rise
	return {"ok":true}

static func _height(ctx: Dictionary, owner: String, point: Vector3) -> Dictionary:
	for face: Dictionary in ctx.faces:
		if face.source_id != owner: continue
		var cell := {"vertices":face.vertices,"headroom":1.0}
		var position := Kernel.support_y(cell,point)
		if Kernel.contains(cell,position): return {"ok":true,"position":position,"normal":Kernel.plane_normal(face.vertices)}
	return {"ok":false}

static func _decorations(ctx: Dictionary, span: Dictionary, profile: Dictionary, catalog: Dictionary, cancellation: Callable) -> bool:
	if profile.props.is_empty(): return true
	var a: Vector3 = span.a; var b: Vector3 = span.b; var n: Vector3 = span.outward
	var length := Vector2(b.x-a.x,b.z-a.z).length()
	var raw_count := length/float(profile.minimum_spacing)
	if raw_count > MAX_PROPS*8: return false
	var count := maxi(1,floori(raw_count))
	var quarter := int(span.get("rotation_quarters",0))
	for k: int in count:
		if cancellation.is_valid() and cancellation.call(): return false
		var at := length*float(k+1)/float(count+1)
		for offset: int in profile.props.size():
			var id: String = profile.props[(k+offset)%profile.props.size()]
			var definition: Dictionary = catalog.definitions[id]
			# Reserve both the actual footprint and the projected visual overhang
			# at an opening end. A short span may use the smaller fallback plant.
			var margin := maxf(float(definition.footprint_radius),float(definition.world_height)*0.4)
			if at < margin or length-at < margin: continue
			var distance := float(profile.outward_width)*0.5
			var radius := float(definition.footprint_radius)
			if distance < radius+EPS or float(profile.outward_width)-distance < radius+EPS: continue
			var raw := _point(a,b,at/length)+n*distance
			var support := _height(ctx,span.span_id,raw)
			if not support.ok or absf(Vector3(support.normal).y) < cos(deg_to_rad(float(definition.max_slope_degrees)))-EPS: continue
			var placement_id: String = "border/"+str(span.span_id)+"/prop_%d"%k
			var record := {"placement_id":placement_id,"definition_id":id,"revision":int(definition.revision),"surface_id":"","source_surface_id":"border/"+str(span.span_id),"position":support.position,"rotation_y":float(quarter)*90.0,"definition":definition.duplicate(true),"editor_state":{"placement_id":placement_id,"group_id":"","locked":false,"hidden":false}}
			if definition.capabilities.body:
				var v: Array = definition.body_box_xyz
				var box := Kernel.transform_volume(AABB(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5])),quarter,support.position)
				var overlap := false
				for other: AABB in ctx.volumes:
					if Kernel.overlaps(box,other): overlap = true; break
				if overlap: continue
				record["body_volume"] = box; ctx.volumes.append(box)
			ctx.props.append(record)
			if ctx.props.size() > MAX_PROPS: return false
			break
	return true

static func build(spans: Array, definitions: Dictionary, decorations: bool = true, cancellation: Callable = Callable()) -> Dictionary:
	var ordered: Array = spans.duplicate(true); var seen := {}
	for span: Variant in ordered:
		if not span is Dictionary or not span.has_all(["span_id","a","b","outward","profile_id"]) or not span.span_id is String or span.span_id.is_empty() or seen.has(span.span_id) or not definitions.has(span.profile_id): return Catalog.fail("profile_invalid")
		if span.has("rotation_quarters") and (not span.rotation_quarters is int or span.rotation_quarters < 0 or span.rotation_quarters > 3): return Catalog.fail("profile_invalid",span.span_id)
		seen[span.span_id] = true
		for point: Variant in [span.a,span.b,span.outward]:
			if not point is Vector3 or not point.is_finite(): return Catalog.fail("profile_invalid",span.span_id)
		if absf(Vector3(span.outward).length()-1.0) > EPS or absf(float(span.outward.y)) > EPS: return Catalog.fail("profile_invalid",span.span_id)
		var dx := float(span.b.x)-float(span.a.x); var dz := float(span.b.z)-float(span.a.z)
		if sqrt(dx*dx+dz*dz) <= EPS: return Catalog.fail("geometry_precision_limit",span.span_id)
		if absf(dx*float(span.outward.x)+dz*float(span.outward.z)) > EPS+Kernel.horizontal_roundoff(span.outward.x,span.outward.z,span.a)+Kernel.horizontal_roundoff(span.outward.x,span.outward.z,span.b): return Catalog.fail("profile_invalid",span.span_id)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.span_id < b.span_id)
	var joined := _join_ends(ordered,definitions)
	if not joined.ok: return joined
	var ctx := {"faces":[],"prisms":[],"profiles":{},"props":[],"volumes":[],"water":[],"error":""}
	var catalog := Props.load_catalog()
	if not catalog.ok: return Catalog.fail("profile_asset_missing")
	for span: Dictionary in ordered:
		if cancellation.is_valid() and cancellation.call(): return Catalog.fail("cancelled")
		var profile: Dictionary = definitions[span.profile_id]
		if profile.geometry == "raised_bank":
			# A real inner ledge closes the span; the cap slopes outward and supports
			# the dressing. It is never inserted in the actor's support list.
			if not _strip(ctx,span,profile,0,profile.outward_width,profile.rise,0,0): return Catalog.fail(ctx.error if not ctx.error.is_empty() else "profile_geometry",span.span_id)
		elif profile.geometry == "unsupported_channel":
			var bank := float(profile.outward_width)*0.25; var far := float(profile.outward_width)*0.75
			if not _strip(ctx,span,profile,0,bank,0,profile.rise,0) or not _strip(ctx,span,profile,far,profile.outward_width,profile.rise,0,1): return Catalog.fail(ctx.error if not ctx.error.is_empty() else "profile_geometry",span.span_id)
			var a: Vector3 = span.a; var b: Vector3 = span.b; var n: Vector3 = span.outward
			var ma: Vector3 = span.get("offset_a",n*float(profile.outward_width))/float(profile.outward_width)
			var mb: Vector3 = span.get("offset_b",n*float(profile.outward_width))/float(profile.outward_width)
			ctx.water.append({"face_id":"border/"+str(span.span_id)+"/water","span_id":span.span_id,"vertices":[a+ma*bank+Vector3.UP*float(span.get("rise_a",profile.rise)),b+mb*bank+Vector3.UP*float(span.get("rise_b",profile.rise)),b+mb*far+Vector3.UP*float(span.get("rise_b",profile.rise)),a+ma*far+Vector3.UP*float(span.get("rise_a",profile.rise))]})
		else: return Catalog.fail("profile_invalid",span.span_id)
	var envelope := Union.build(ctx.faces,cancellation)
	if not envelope.ok: return Catalog.fail(envelope.code)
	var profiles := {}; ctx.prisms = []
	for face: Dictionary in envelope.faces:
		profiles[face.face_id] = ctx.profiles[envelope.origins[face.face_id]]
		ctx.prisms.append({"volume_id":face.face_id,"support_surface_id":"","top":face.vertices.duplicate(),"bottom_y":face.bottom_y})
	ctx.faces = envelope.faces; ctx.profiles = profiles
	for span: Dictionary in ordered:
		var profile: Dictionary = definitions[span.profile_id]
		if decorations and profile.geometry != "unsupported_channel" and not _decorations(ctx,span,profile,catalog,cancellation): return Catalog.fail("cancelled" if cancellation.is_valid() and cancellation.call() else "border_limit",span.span_id)
	var topology := Topology.build(ctx.faces,cancellation)
	if not topology.ok: return Catalog.fail(topology.code)
	var presentation: Array = []
	for face: Dictionary in ctx.faces:
		var paint: Array = []
		for _point_value: Vector3 in face.vertices: paint.append(ctx.profiles[face.face_id].material_weights.duplicate())
		presentation.append({"face_id":face.face_id,"span_id":face.source_id,"vertices":face.vertices.duplicate(),"outward":Vector3.ZERO,"material_weights":paint})
	for side: Dictionary in topology.exposed_sides:
		var paint: Array = []
		for _point_value: Vector3 in side.vertices: paint.append(ctx.profiles[side.face_id].material_weights.duplicate())
		presentation.append({"face_id":side.side_id,"span_id":ctx.faces.filter(func(face: Dictionary) -> bool: return face.face_id == side.face_id)[0].source_id,"vertices":side.vertices.duplicate(),"outward":side.outward,"material_weights":paint})
	return {"ok":true,"solid_prisms":ctx.prisms,"volumes":ctx.volumes,"faces":presentation,"water":ctx.water,"props":ctx.props}
