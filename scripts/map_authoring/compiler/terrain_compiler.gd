@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const SolidPrism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const REVISION := "map_terrain_v3"
const MAX_SUPPORTS := 1024
const MAX_GRID_QUADS := 65536
const PROFILE := {"radius":2.0,"height":12.0,"connector_kinds":["walk"]}
const EPS := 0.00001
var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false
var _progress := 0.0
var _input: Dictionary

func start(source: Dictionary) -> void:
	_input = source.duplicate(true)
	_thread = Thread.new()
	_thread.start(func() -> Dictionary: return compile(_input, _poll))

func _poll(progress: float) -> bool:
	_mutex.lock()
	_progress = progress
	var cancelled := _cancelled
	_mutex.unlock()
	return cancelled

func cancel() -> void:
	_mutex.lock(); _cancelled = true; _mutex.unlock()

func progress() -> float:
	_mutex.lock(); var value := _progress; _mutex.unlock()
	return value

func ready() -> bool: return _thread != null and not _thread.is_alive()

func take(current_hash: String) -> Dictionary:
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	if _cancelled: return failure("cancelled")
	if result.ok and result.input_hash != current_hash: return failure("stale_source")
	return result

func close() -> void:
	if _thread != null:
		cancel(); _thread.wait_to_finish(); _thread = null

static func failure(code: String, entity: String = "", field: String = "terrain") -> Dictionary:
	var messages := {"terrain_empty":"Adicione uma camada de terreno.","material_missing":"Um material de terreno está ausente.","terrain_sample_limit":"A fonte excede o orçamento de 65536 quadrados de grade nesta sessão.","terrain_limit_exceeded":"O relevo excede o orçamento de 1024 suportes gerados. Reduza a densidade ou simplifique o relevo.","source_invalid":"Corrija os diagnósticos da fonte.","source_non_finite":"A fonte contém um número inválido.","capability_unsupported":"Esta peça usa uma capacidade ainda não disponível na compilação de terreno.","material_unsupported":"Use os materiais Grama e Terra nesta entrega.","geometry_invalid":"O piso precisa ser convexo e plano.","geometry_overlap":"Há pisos sobrepostos na mesma altura.","geometry_non_manifold":"Mais de dois pisos disputam a mesma borda.","insufficient_headroom":"Não há folga para o corpo de teste.","slope_too_steep":"A inclinação supera 45°; alongue a rampa.","geometry_precision_limit":"A coordenada excede o domínio técnico de 8192 unidades.","connector_invalid":"O conector não coincide com uma abertura válida.","connector_ambiguous":"O conector coincide com mais de uma borda.","socket_invalid":"O ponto marcado não tem suporte ou tipo válido.","route_unreachable":"Há uma região sem ligação para o corpo de teste.","cancelled":"Compilação cancelada.","stale_source":"A fonte mudou; compile novamente."}
	return Schema.result(false, code, [{"code":code,"severity":"error","entity_id":entity,"field":field,"message":messages.get(code,"Não foi possível concluir a compilação."),"suggestion":"Corrija a região indicada e compile novamente."}])

static func _valid_authoring_value(value: Variant, depth: int = 0) -> bool:
	# GDScript dot assignment introduces StringName keys; the source reader
	# canonicalizes them to text. Keep the same finite-value preflight for both APIs.
	if depth > 64: return false
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _valid_authoring_value(value[key],depth+1): return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _valid_authoring_value(item,depth+1): return false
		return true
	return Canonical.valid(value,depth)

static func compile(source: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	if not _valid_authoring_value(source): return failure("source_non_finite")
	# Cheap bounded preflight before decimal parsing/copying an over-budget height field.
	if source.get("layers") is Array:
		var preflight_quads := 0.0
		for entry: Variant in source.layers:
			if entry is Dictionary and (entry.get("rows") is int or entry.get("rows") is float) and (entry.get("columns") is int or entry.get("columns") is float):
				if entry.rows >= 2 and entry.columns >= 2: preflight_quads += (float(entry.rows)-1.0)*(float(entry.columns)-1.0)
		if preflight_quads > MAX_GRID_QUADS: return failure("terrain_sample_limit")
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	if not read.ok: return read
	if not read.valid: return failure("source_invalid")
	if source.composition != null: return failure("capability_unsupported", "composition")
	var cells: Array = []; var visuals: Array = []; var slabs: Array = []; var edges: Array = []
	var mass_bases: Dictionary = {}
	var layers: Array = source.layers.duplicate(true)
	layers.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.layer_id < b.layer_id)
	var grid_quads := 0
	for layer: Dictionary in layers: grid_quads += (int(layer.rows)-1)*(int(layer.columns)-1)
	if grid_quads > MAX_GRID_QUADS: return failure("terrain_sample_limit")
	var material_dependencies := Materials.dependencies()
	if material_dependencies.is_empty(): return failure("material_missing")
	for layer: Dictionary in layers:
		var base_y := float(layer.heights[0])
		for value: float in layer.heights: base_y = minf(base_y,value)
		mass_bases[layer.layer_id] = base_y-4.0
		for material: String in layer.material_masks:
			if material not in ["grass","earth"]: return failure("material_unsupported",layer.layer_id)
		var cancelled := func() -> bool: return cancellation.is_valid() and cancellation.call(0.1)
		var patches := Partition.build(layer,cancelled)
		if patches.is_empty(): return failure("cancelled")
		for patch: Dictionary in patches:
			var x: int = patch.x; var z: int = patch.z; var width: int = patch.width; var height: int = patch.height
			var columns: int = layer.columns
			var indices := [z*columns+x,z*columns+x+width,(z+height)*columns+x+width,(z+height)*columns+x]
			var vertices: Array = [Partition.point(layer,x,z),Partition.point(layer,x+width,z),Partition.point(layer,x+width,z+height),Partition.point(layer,x,z+height)]
			var id: String = "c_" + layer.layer_id.sha256_text().substr(0,16) + "_%d_%d_%d_%d" % [x,z,width,height]
			if not patch.triangles:
				_add_cell(cells,visuals,{"surface_id":id,"vertices":vertices,"headroom":100.0},layer,indices)
			else:
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var tri := {"surface_id":id+"_t%d"%triangle[1],"vertices":[vertices[triangle[0]],vertices[triangle[1]],vertices[triangle[2]]],"headroom":100.0}
					_add_cell(cells,visuals,tri,layer,[indices[triangle[0]],indices[triangle[1]],indices[triangle[2]]])
			if cells.size() > MAX_SUPPORTS: return failure("terrain_limit_exceeded",layer.layer_id)
	var specials: Array = source.special_surfaces.duplicate(true)
	specials.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.surface_id < b.surface_id)
	for special: Dictionary in specials:
		var vertices: Array = []
		for xyz: Array in special.vertices_xyz: vertices.append(Vector3(xyz[0],xyz[1],xyz[2]))
		var cell := {"surface_id":"s_"+special.surface_id.sha256_text().substr(0,20),"vertices":vertices,"headroom":float(special.headroom)}
		cells.append(cell)
		visuals.append({"surface_id":cell.surface_id,"source_id":special.surface_id,"vertices":vertices.duplicate(),"earth_weights":[],"special":true})
		if vertices.size() == 4:
			var box := AABB(vertices[0],Vector3.ZERO)
			for vertex: Vector3 in vertices: box = box.expand(vertex)
			if box.size.y < EPS and absf(box.size.x*box.size.z-_area(vertices)) < EPS:
				slabs.append(AABB(box.position-Vector3(0,4,0),Vector3(box.size.x,4,box.size.z)))
	if cells.is_empty(): return failure("terrain_empty")
	if cells.size() > MAX_SUPPORTS: return failure("terrain_limit_exceeded")
	for i: int in cells.size():
		if cancellation.is_valid() and cancellation.call(0.4+0.3*float(i)/cells.size()): return failure("cancelled")
		var cell: Dictionary = cells[i]
		if not Kernel.valid_cell(cell): return failure("geometry_invalid",cell.surface_id)
		if cell.headroom < PROFILE.height: return failure("insufficient_headroom",cell.surface_id)
		var normal := Kernel.plane_normal(cell.vertices)
		if absf(normal.y) < sqrt(0.5)-EPS: return failure("slope_too_steep",cell.surface_id)
		for vertex: Vector3 in cell.vertices:
			if not vertex.is_finite() or maxf(absf(vertex.x),maxf(absf(vertex.y),absf(vertex.z))) > 8192: return failure("geometry_precision_limit",cell.surface_id)
		for j: int in i:
			# Generated regions of the same height grid have disjoint interiors by construction.
			if visuals[i].source_id == visuals[j].source_id: continue
			if Kernel.cells_overlap(cell,cells[j]): return failure("geometry_overlap",cell.surface_id)
		for slab: AABB in slabs:
			var polygon := PackedVector2Array()
			for vertex: Vector3 in cell.vertices: polygon.append(Vector2(vertex.x,vertex.z))
			var rectangle := PackedVector2Array([Vector2(slab.position.x,slab.position.z),Vector2(slab.end.x,slab.position.z),Vector2(slab.end.x,slab.end.z),Vector2(slab.position.x,slab.end.z)])
			for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,rectangle):
				for horizontal: Vector2 in intersection:
					var y := Kernel.support_y(cell,Vector3(horizontal.x,0,horizontal.y)).y
					if y < slab.end.y-EPS and slab.position.y-y < PROFILE.height-EPS: return failure("insufficient_headroom",cell.surface_id)
		var vertices: Array = cell.vertices
		var sign_value := signf(Vector2(vertices[1].x-vertices[0].x,vertices[1].z-vertices[0].z).cross(Vector2(vertices[2].x-vertices[1].x,vertices[2].z-vertices[1].z)))
		for k: int in vertices.size():
			var a: Vector3 = vertices[k]; var b: Vector3 = vertices[(k+1)%vertices.size()]
			var delta := b-a
			edges.append({"a":a,"b":b,"surface_id":cell.surface_id,"edge_id":cell.surface_id+"_e%d"%k,"outward":Vector3(delta.z,0,-delta.x).normalized()*sign_value,"headroom":cell.headroom,"source_id":visuals[i].source_id})
	# Split collinear edges at existing vertices, so a long edge joins two short ones.
	var spans: Dictionary = {}
	for i: int in edges.size():
		if cancellation.is_valid() and cancellation.call(0.7+0.25*float(i)/edges.size()): return failure("cancelled")
		var edge: Dictionary = edges[i]
		var cuts: Array = [{"t":0.0,"point":edge.a},{"t":1.0,"point":edge.b}]
		var delta: Vector3 = edge.b-edge.a
		for other: Dictionary in edges:
			for vertex: Vector3 in [other.a,other.b]:
				var t := (vertex-Vector3(edge.a)).dot(delta)/delta.length_squared()
				if t > 0.0 and t < 1.0 and vertex.distance_to(edge.a) > EPS and vertex.distance_to(edge.b) > EPS and (Vector3(edge.a)+delta*t).distance_to(vertex) <= EPS:
					var exists := false
					for cut: Dictionary in cuts:
						if Vector3(cut.point).distance_to(vertex) <= EPS: exists = true; break
					if not exists: cuts.append({"t":t,"point":vertex})
		cuts.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t < b.t)
		for k: int in range(1,cuts.size()):
			# Reuse exact source endpoints; re-interpolation can drift one float32 ULP.
			var a: Vector3 = cuts[k-1].point; var b: Vector3 = cuts[k].point
			var ends: Array = [Canonical.encode(a),Canonical.encode(b)]; ends.sort()
			var key: String = "|".join(ends)
			if not spans.has(key): spans[key] = []
			var span := edge.duplicate(); span.a = a; span.b = b
			span.span_id = edge.edge_id+"_"+key.sha256_text().substr(0,12)
			spans[key].append(span)
	var connectors: Array = []; var adjacency: Array = []; var boundaries: Array = []
	var keys: Array = spans.keys(); keys.sort()
	for key: String in keys:
		var pair: Array = spans[key]
		if pair.size() > 2: return failure("geometry_non_manifold")
		if pair.size() == 2:
			if Vector3(pair[0].outward).dot(pair[1].outward) > -1.0+EPS: return failure("geometry_invalid")
			var ids: Array = []
			for span: Dictionary in pair:
				var id: String = "j_"+span.span_id
				connectors.append(_endpoint(id,span)); ids.append(id)
			adjacency.append({"connection_id":"join_"+key.sha256_text().substr(0,20),"a_connector":ids[0],"b_connector":ids[1],"forward":true,"backward":true})
		else:
			var span: Dictionary = pair[0]
			boundaries.append({"span_id":span.span_id,"surface_id":span.surface_id,"source_id":span.source_id,"a":span.a,"b":span.b,"kind":"support_edge","openings":[]})
	for authored: Dictionary in source.connectors:
		if authored.kind != "walk" or authored.tags.is_empty(): return failure("connector_invalid",authored.connector_id)
		if authored.width < PROFILE.radius*2 or authored.headroom < PROFILE.height: return failure("insufficient_headroom",authored.connector_id)
		var position := Vector3(authored.position_xyz[0],authored.position_xyz[1],authored.position_xyz[2])
		var normal := Vector3(authored.normal_xyz[0],authored.normal_xyz[1],authored.normal_xyz[2])
		var found := false
		for boundary: Dictionary in boundaries:
			if boundary.source_id != authored.surface_id: continue
			var candidate := {"connector_id":"port_"+authored.connector_id.sha256_text().substr(0,20),"surface_id":boundary.surface_id,"position":position,"outward":normal,"kind":authored.kind,"tags":authored.tags.duplicate(),"width":float(authored.width),"headroom":float(authored.headroom),"direction":authored.direction}
			var cell := _cell(cells,boundary.surface_id)
			if Kernel.connector_valid(candidate,cell) and _on_segment(position,boundary.a,boundary.b) and _opening_fits(candidate,boundary):
				if found: return failure("connector_ambiguous",authored.connector_id)
				connectors.append(candidate); boundary.openings.append(candidate.connector_id); boundary.kind = "opening"; found = true
		if not found: return failure("connector_invalid",authored.connector_id)
	var sockets: Array = []
	for authored: Dictionary in source.sockets:
		if authored.kind not in ["entrance","exit","objective","thematic_encounter","population","portal"]: return failure("socket_invalid",authored.socket_id)
		var position := Vector3(authored.position_xyz[0],authored.position_xyz[1],authored.position_xyz[2])
		var candidates: Array = []
		for i: int in cells.size():
			if visuals[i].source_id == authored.surface_id and Kernel.contains(cells[i],position): candidates.append(cells[i])
		if candidates.is_empty(): return failure("socket_invalid",authored.socket_id)
		sockets.append({"socket_id":"socket_"+authored.socket_id.sha256_text().substr(0,20),"surface_id":candidates[0].surface_id,"position":position,"kind":authored.kind,"tags":[]})
	# One authored piece must be connected for the declared technical body.
	var reachable := {cells[0].surface_id:true}
	var endpoints: Dictionary = {}
	for endpoint: Dictionary in connectors: endpoints[endpoint.connector_id] = endpoint
	var changed := true
	while changed:
		changed = false
		for link: Dictionary in adjacency:
			var a: Dictionary = endpoints[link.a_connector]; var b: Dictionary = endpoints[link.b_connector]
			if minf(a.width,b.width) < PROFILE.radius*2 or minf(a.headroom,b.headroom) < PROFILE.height: continue
			if reachable.has(a.surface_id) and not reachable.has(b.surface_id): reachable[b.surface_id] = true; changed = true
			if reachable.has(b.surface_id) and not reachable.has(a.surface_id): reachable[a.surface_id] = true; changed = true
	if reachable.size() != cells.size():
		for cell: Dictionary in cells:
			if not reachable.has(cell.surface_id): return failure("route_unreachable",cell.surface_id)
	if cancellation.is_valid() and cancellation.call(1.0): return failure("cancelled")
	var solid_prisms: Array = []
	for i: int in cells.size():
		var cell: Dictionary = cells[i]; var visual: Dictionary = visuals[i]
		var mass := {"volume_id":"terrain/"+str(cell.surface_id),"support_surface_id":cell.surface_id,"top":cell.vertices.duplicate()}
		if visual.special: mass["thickness_y"] = 4.0
		else: mass["bottom_y"] = mass_bases[visual.source_id]
		if not SolidPrism.valid(mass): return failure("geometry_invalid",cell.surface_id)
		solid_prisms.append(mass)
	var part := {"part_id":"piece_"+source.document_id.sha256_text().substr(0,20),"revision":int(source.revision),"biome_tags":["authored"],"allowed_rotations":[0],"surfaces":cells,"connectors":connectors,"sockets":sockets,"solid_volumes":[],"solid_prisms":solid_prisms,"blockers":[]}
	var render_layers: Array = []
	for layer: Dictionary in layers:
		render_layers.append({"layer_id":layer.layer_id,"origin_xz":layer.origin_xz.duplicate(),"sample_spacing":float(layer.sample_spacing),"columns":int(layer.columns),"rows":int(layer.rows),"heights":layer.heights.duplicate(),"material_masks":layer.material_masks.duplicate(true)})
	var package := {"format_version":3,"compiler_revision":REVISION,"source_hash":read.output_hash,"dependencies":material_dependencies,"part":part,"adjacency":adjacency,"boundaries":boundaries,"visuals":visuals,"render_layers":render_layers,"profile":PROFILE.duplicate(true),"grid_quads":grid_quads,"piece_count":1}
	package.package_hash = Canonical.digest(package)
	if not source.placements.is_empty() or not source.dependencies.is_empty():
		var compiled_objects := Objects.compile(source,package,preview_manifest(package))
		if not compiled_objects.ok: return compiled_objects
		package.erase("package_hash")
		package["objects"] = compiled_objects.objects
		package.part.solid_volumes.append_array(compiled_objects.volumes)
		package.dependencies.append_array(compiled_objects.dependencies)
		package.package_hash = Canonical.digest(package)
	var result := Schema.result(true)
	result.input_hash = read.output_hash; result.output_hash = package.package_hash; result.package = package
	return result

static func _add_cell(cells: Array, visuals: Array, cell: Dictionary, layer: Dictionary, indices: Array) -> void:
	cells.append(cell)
	var weights: Array = []
	for index: int in indices:
		var grass: float = layer.material_masks.get("grass",[])[index] if layer.material_masks.has("grass") else 1.0
		var earth: float = layer.material_masks.get("earth",[])[index] if layer.material_masks.has("earth") else 0.0
		weights.append(earth/maxf(EPS,grass+earth))
	visuals.append({"surface_id":cell.surface_id,"source_id":layer.layer_id,"vertices":cell.vertices.duplicate(),"earth_weights":weights,"special":false})

static func _area(vertices: Array) -> float:
	var total := 0.0
	for i: int in vertices.size(): total += vertices[i].x*vertices[(i+1)%vertices.size()].z-vertices[(i+1)%vertices.size()].x*vertices[i].z
	return absf(total)*0.5

static func _cell(cells: Array, id: String) -> Dictionary:
	for cell: Dictionary in cells:
		if cell.surface_id == id: return cell
	return {}

static func _endpoint(id: String, span: Dictionary) -> Dictionary:
	return {"connector_id":id,"surface_id":span.surface_id,"position":(Vector3(span.a)+Vector3(span.b))*0.5,"outward":span.outward,"kind":"walk","tags":["map_editor"],"width":Vector2(span.b.x-span.a.x,span.b.z-span.a.z).length(),"headroom":float(span.headroom),"direction":"both"}

static func _on_segment(point: Vector3, a: Vector3, b: Vector3) -> bool:
	return Geometry3D.get_closest_point_to_segment(point,a,b).distance_to(point) < EPS

static func _opening_fits(endpoint: Dictionary, boundary: Dictionary) -> bool:
	var tangent: Vector3 = Vector3(-endpoint.outward.z,0,endpoint.outward.x)*endpoint.width*0.5
	# Project endpoints onto the same sloping edge rather than flattening their y.
	var a := Vector2(boundary.a.x,boundary.a.z); var b := Vector2(boundary.b.x,boundary.b.z)
	var p := Vector2(endpoint.position.x,endpoint.position.z)
	return Geometry2D.get_closest_point_to_segment(p+Vector2(tangent.x,tangent.z),a,b).distance_to(p+Vector2(tangent.x,tangent.z)) < EPS and Geometry2D.get_closest_point_to_segment(p-Vector2(tangent.x,tangent.z),a,b).distance_to(p-Vector2(tangent.x,tangent.z)) < EPS

static func validate_package(package: Dictionary) -> bool:
	if package.get("compiler_revision") != REVISION or package.get("format_version") != 3 or not package.has("package_hash"): return false
	# Existing v2 producers may store textual keys as StringName via dot assignment.
	# Keep the same bounded passive-value check used by the source preflight.
	if not _valid_authoring_value(package) or (package.has("objects") and not Objects.validate_records(package.objects)): return false
	if not package.get("part") is Dictionary or not WorldGeometry._stage_prisms_valid({"surfaces":package.part.get("surfaces",[]),"solid_prisms":package.part.get("solid_prisms",[])}): return false
	var content := package.duplicate(true); content.erase("package_hash")
	return Canonical.digest(content) == package.package_hash and Objects.validate_dependencies(package.get("dependencies",[]),Materials.dependencies())

static func preview_manifest(package: Dictionary) -> Manifest:
	if not validate_package(package): return null
	var part: Dictionary = package.part
	var stage := {"stage_id":"terrain_preview","biome":"authored","entrance":"","part_instances":[{"part_id":part.part_id,"rotation_quarters":0,"translation":Vector3.ZERO}],"surfaces":part.surfaces.duplicate(true),"connectors":part.connectors.duplicate(true),"connections":package.adjacency.duplicate(true),"sockets":part.sockets.duplicate(true),"volumes":part.solid_volumes.duplicate(true),"solid_prisms":part.get("solid_prisms",[]).duplicate(true)}
	var manifest := Manifest.new()
	manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":[part.duplicate(true)]},"stages":[stage],"traversal":package.profile.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	return manifest
