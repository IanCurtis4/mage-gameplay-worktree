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
const Ports = preload("res://scripts/core/expedition/generation/connector_partition.gd")
const Topology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const REVISION := "map_terrain_v5"
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
	messages["material_unsupported"] = "Use os materiais Grama, Terra, Areia ou Pedra."
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
	var generated := _collect_geometry(source,cancellation)
	if not generated.ok: return generated
	var candidates: Array = generated.candidates; var visuals: Array = generated.visuals; var slabs: Array = generated.slabs; var cells: Array = []
	var layers: Array = generated.layers; var grid_quads: int = generated.grid_quads; var material_dependencies: Array = generated.material_dependencies
	if candidates.is_empty(): return failure("terrain_empty")
	if candidates.size() > MAX_SUPPORTS: return failure("terrain_limit_exceeded")
	var faces: Array = []; var origins := {}
	for i: int in candidates.size():
		if cancellation.is_valid() and cancellation.call(0.4+0.3*float(i)/candidates.size()): return failure("cancelled")
		var cell: Dictionary = candidates[i]; var visual: Dictionary = visuals[i]
		if not Kernel.valid_cell(cell): return failure("geometry_invalid",cell.surface_id)
		for vertex: Vector3 in cell.vertices:
			if not vertex.is_finite() or maxf(absf(vertex.x),maxf(absf(vertex.y),absf(vertex.z))) > 8192: return failure("geometry_precision_limit",cell.surface_id)
		for j: int in i:
			# Generated regions of one height grid have disjoint interiors by construction.
			if visual.source_id != visuals[j].source_id and Kernel.cells_overlap(cell,candidates[j]): return failure("geometry_overlap",cell.surface_id)
		var walkable: bool = visual.walkable
		faces.append(_face(visual))
		if not walkable: continue
		if cell.headroom < PROFILE.height: return failure("insufficient_headroom",cell.surface_id)
		for slab: AABB in slabs:
			var polygon := PackedVector2Array()
			for vertex: Vector3 in cell.vertices: polygon.append(Vector2(vertex.x,vertex.z))
			var rectangle := PackedVector2Array([Vector2(slab.position.x,slab.position.z),Vector2(slab.end.x,slab.position.z),Vector2(slab.end.x,slab.end.z),Vector2(slab.position.x,slab.end.z)])
			for intersection: PackedVector2Array in Geometry2D.intersect_polygons(polygon,rectangle):
				for horizontal: Vector2 in intersection:
					var y := Kernel.support_y(cell,Vector3(horizontal.x,0,horizontal.y)).y
					if y < slab.end.y-EPS and slab.position.y-y < PROFILE.height-EPS: return failure("insufficient_headroom",cell.surface_id)
		cells.append(cell); origins[cell.surface_id] = visual.source_id
	if cells.is_empty(): return failure("slope_too_steep",candidates[0].surface_id)
	var topology := Topology.build(faces,func() -> bool: return cancellation.is_valid() and cancellation.call(0.8))
	if not topology.ok: return failure(topology.code,topology.get("entity_id",""))
	var connectors: Array = topology.connectors; var adjacency: Array = topology.adjacency; var boundaries: Array = topology.boundaries
	var authored_ports: Array = []; var connector_groups: Array = []
	var authored_connectors: Array = source.connectors.duplicate(true)
	authored_connectors.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.connector_id < b.connector_id)
	for authored: Dictionary in authored_connectors:
		var built_port := _compile_authored_port(authored,boundaries,cells)
		if not built_port.ok: return built_port
		for fragment: Dictionary in built_port.authored_port.fragments:
			for boundary: Dictionary in boundaries:
				if boundary.span_id != fragment.span_id: continue
				for prior: Dictionary in connectors:
					if prior.connector_id not in boundary.openings: continue
					var incoming: Dictionary = _port_endpoint(built_port.endpoints,fragment.connector_id)
					var axis := Vector2(-incoming.outward.z,incoming.outward.x)
					var separation := absf((float(prior.position.x)-float(incoming.position.x))*float(axis.x)+(float(prior.position.z)-float(incoming.position.z))*float(axis.y))
					if separation < (float(prior.width)+float(incoming.width))*0.5: return failure("connector_ambiguous",authored.connector_id)
				boundary.openings.append(fragment.connector_id); boundary.kind = "opening"
		connectors.append_array(built_port.endpoints); authored_ports.append(built_port.authored_port); connector_groups.append(built_port.group)
	var sockets: Array = []
	for authored: Dictionary in source.sockets:
		if authored.kind not in ["entrance","exit","objective","thematic_encounter","population","portal"]: return failure("socket_invalid",authored.socket_id)
		var position := Vector3(authored.position_xyz[0],authored.position_xyz[1],authored.position_xyz[2])
		var matches: Array = []
		for i: int in cells.size():
			if origins[cells[i].surface_id] == authored.surface_id and Kernel.contains(cells[i],position): matches.append(cells[i])
		if matches.is_empty(): return failure("socket_invalid",authored.socket_id)
		sockets.append({"socket_id":"socket_"+authored.socket_id.sha256_text().substr(0,20),"surface_id":matches[0].surface_id,"position":position,"kind":authored.kind,"tags":[]})
	# One authored piece must be connected for the declared technical body.
	var reachable := {cells[0].surface_id:true}
	var endpoints: Dictionary = {}
	for endpoint: Dictionary in connectors: endpoints[endpoint.connector_id] = endpoint
	var changed := true
	while changed:
		changed = false
		for link: Dictionary in adjacency:
			var a: Dictionary = endpoints[link.a_connector]; var b: Dictionary = endpoints[link.b_connector]
			# Internal mesh fragments need not each fit the full disk: support is
			# the connected local union. Consumers validate the actual body/path.
			if minf(a.headroom,b.headroom) < PROFILE.height: continue
			if reachable.has(a.surface_id) and not reachable.has(b.surface_id): reachable[b.surface_id] = true; changed = true
			if reachable.has(b.surface_id) and not reachable.has(a.surface_id): reachable[a.surface_id] = true; changed = true
	if reachable.size() != cells.size():
		for cell: Dictionary in cells:
			if not reachable.has(cell.surface_id): return failure("route_unreachable",cell.surface_id)
	if cancellation.is_valid() and cancellation.call(1.0): return failure("cancelled")
	var solid_prisms: Array = []
	for visual: Dictionary in visuals: solid_prisms.append(_mass(visual))
	var part := {"part_id":"piece_"+source.document_id.sha256_text().substr(0,20),"revision":int(source.revision),"biome_tags":["authored"],"allowed_rotations":[0],"surfaces":cells,"connectors":connectors,"sockets":sockets,"solid_volumes":[],"solid_prisms":solid_prisms,"blockers":[]}
	if not connector_groups.is_empty(): part["connector_groups"] = connector_groups
	var render_layers: Array = []
	for layer: Dictionary in layers:
		render_layers.append({"layer_id":layer.layer_id,"origin_xz":layer.origin_xz.duplicate(),"sample_spacing":float(layer.sample_spacing),"columns":int(layer.columns),"rows":int(layer.rows),"heights":layer.heights.duplicate(),"material_masks":layer.material_masks.duplicate(true)})
	var package := {"format_version":5,"compiler_revision":REVISION,"source_hash":read.output_hash,"dependencies":material_dependencies,"part":part,"authored_ports":authored_ports,"adjacency":adjacency,"boundaries":boundaries,"visuals":visuals,"exposed_sides":topology.exposed_sides,"render_layers":render_layers,"profile":PROFILE.duplicate(true),"grid_quads":grid_quads,"piece_count":1}
	package.package_hash = Canonical.digest(package)
	if not source.placements.is_empty() or not source.dependencies.is_empty():
		var compiled_objects := Objects.compile(source,package,preview_manifest(package))
		if not compiled_objects.ok: return compiled_objects
		package.erase("package_hash")
		package["objects"] = compiled_objects.objects
		package.part.solid_volumes.append_array(compiled_objects.volumes)
		package.dependencies.append_array(compiled_objects.dependencies)
		package.package_hash = Canonical.digest(package)
	if var_to_bytes(package).size() > 4*1024*1024: return failure("terrain_limit_exceeded")
	var result := Schema.result(true)
	result.input_hash = read.output_hash; result.output_hash = package.package_hash; result.package = package
	return result

static func _collect_geometry(source: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var candidates: Array = []; var visuals: Array = []; var slabs: Array = []
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
			if material not in Materials.IDS: return failure("material_unsupported",layer.layer_id)
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
				_add_cell(candidates,visuals,{"surface_id":id,"vertices":vertices,"headroom":100.0},layer,indices)
			else:
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var tri := {"surface_id":id+"_t%d"%triangle[1],"vertices":[vertices[triangle[0]],vertices[triangle[1]],vertices[triangle[2]]],"headroom":100.0}
					_add_cell(candidates,visuals,tri,layer,[indices[triangle[0]],indices[triangle[1]],indices[triangle[2]]])
			if candidates.size() > MAX_SUPPORTS: return failure("terrain_limit_exceeded",layer.layer_id)
	var specials: Array = source.special_surfaces.duplicate(true)
	specials.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.surface_id < b.surface_id)
	for special: Dictionary in specials:
		var vertices: Array = []
		for xyz: Array in special.vertices_xyz: vertices.append(Vector3(xyz[0],xyz[1],xyz[2]))
		var cell := {"surface_id":"s_"+special.surface_id.sha256_text().substr(0,20),"vertices":vertices,"headroom":float(special.headroom)}
		candidates.append(cell)
		visuals.append({"surface_id":cell.surface_id,"source_id":special.surface_id,"vertices":vertices.duplicate(),"earth_weights":[],"material_weights":[],"special":true})
		if vertices.size() == 4:
			var box := AABB(vertices[0],Vector3.ZERO)
			for vertex: Vector3 in vertices: box = box.expand(vertex)
			if box.size.y < EPS and absf(box.size.x*box.size.z-_area(vertices)) < EPS:
				slabs.append(AABB(box.position-Vector3(0,4,0),Vector3(box.size.x,4,box.size.z)))
	for i: int in candidates.size():
		var cell: Dictionary = candidates[i]; var visual: Dictionary = visuals[i]
		visual["face_id"] = cell.surface_id; visual["walkable"] = Topology.is_walkable(cell.vertices); visual["headroom"] = cell.headroom
		visual.surface_id = cell.surface_id if visual.walkable else ""
		if visual.special:
			visual["thickness_y"] = 4.0
			for _vertex: Vector3 in cell.vertices: visual.material_weights.append([0.0,0.0,0.0,1.0])
		else: visual["bottom_y"] = mass_bases[visual.source_id]
	return {"ok":true,"candidates":candidates,"visuals":visuals,"slabs":slabs,"layers":layers,"grid_quads":grid_quads,"material_dependencies":material_dependencies}

static func preview_geometry(source: Dictionary) -> Dictionary:
	var generated := _collect_geometry(source)
	if not generated.ok: return generated
	var faces: Array = []
	for visual: Dictionary in generated.visuals: faces.append(_face(visual))
	var topology := Topology.build(faces)
	if not topology.ok: return topology
	return {"ok":true,"visuals":generated.visuals,"exposed_sides":topology.exposed_sides}

static func _add_cell(cells: Array, visuals: Array, cell: Dictionary, layer: Dictionary, indices: Array) -> void:
	cells.append(cell)
	var weights: Array = []; var paints: Array = []
	for index: int in indices:
		var paint := Materials.weights(layer,index); weights.append(paint[1]); paints.append(paint)
	visuals.append({"surface_id":cell.surface_id,"source_id":layer.layer_id,"vertices":cell.vertices.duplicate(),"earth_weights":weights,"material_weights":paints,"special":false})

static func _port_endpoint(endpoints: Array, id: String) -> Dictionary:
	for endpoint: Dictionary in endpoints:
		if endpoint.connector_id == id: return endpoint
	return {}

static func _compile_authored_port(authored: Dictionary, boundaries: Array, cells: Array) -> Dictionary:
	var id: String = authored.connector_id
	if authored.kind != "walk" or authored.tags.is_empty(): return failure("connector_invalid",id)
	if authored.width < PROFILE.radius*2 or authored.headroom < PROFILE.height: return failure("insufficient_headroom",id)
	var position := Vector3(authored.position_xyz[0],authored.position_xyz[1],authored.position_xyz[2])
	var normal := Vector3(authored.normal_xyz[0],authored.normal_xyz[1],authored.normal_xyz[2])
	var tags: Array = []
	for tag: String in authored.tags:
		if tag not in tags: tags.append(tag)
	tags.sort()
	var group := {"connector_id":"port_"+id.sha256_text().substr(0,20),"position":position,"outward":normal,"width":float(authored.width),"headroom":float(authored.headroom),"kind":authored.kind,"tags":tags,"direction":authored.direction,"fragments":[]}
	if not Ports._port_schema(group): return failure("connector_invalid",id)
	var tangent := Vector2(-normal.z,normal.x); var half := float(authored.width)*0.5
	var pieces: Array = []
	for boundary: Dictionary in boundaries:
		if boundary.closure != "profile" or boundary.source_id != authored.surface_id or normal.dot(boundary.outward) < 1.0-EPS: continue
		var parameters: Array[float] = []; var collinear := true
		for point: Vector3 in [boundary.a,boundary.b]:
			var dx := float(point.x)-float(position.x); var dz := float(point.z)-float(position.z)
			if absf(dx*float(normal.x)+dz*float(normal.z)) > EPS+Kernel.horizontal_roundoff(normal.x,normal.z,point)+Kernel.horizontal_roundoff(normal.x,normal.z,position): collinear = false; break
			parameters.append(dx*float(tangent.x)+dz*float(tangent.y))
		if not collinear: continue
		var lo := maxf(-half,minf(parameters[0],parameters[1])); var hi := minf(half,maxf(parameters[0],parameters[1]))
		if hi <= lo: continue
		if hi-lo <= EPS: return failure("geometry_precision_limit",id)
		pieces.append({"boundary":boundary,"t0":lo,"t1":hi})
	pieces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t0 < b.t0 if a.t0 != b.t0 else a.boundary.span_id < b.boundary.span_id)
	if pieces.is_empty(): return failure("connector_invalid",id)
	# Preserve the legacy out-of-edge diagnostic; an internal gap is coverage.
	if pieces[0].t0 != -half: return failure("geometry_precision_limit" if absf(float(pieces[0].t0)+half) <= EPS else "connector_invalid",id)
	if pieces[-1].t1 != half: return failure("geometry_precision_limit" if absf(float(pieces[-1].t1)-half) <= EPS else "connector_invalid",id)
	var endpoints: Array = []; var provenance: Array = []; var cursor := -half
	for piece: Dictionary in pieces:
		if piece.t0 < cursor: return failure("connector_ambiguous",id)
		if piece.t0 != cursor: return failure("geometry_precision_limit" if absf(piece.t0-cursor) <= EPS else "connector_coverage",id)
		var boundary: Dictionary = piece.boundary; var cell := _cell(cells,boundary.surface_id)
		var connector_id: String = group.connector_id if pieces.size() == 1 else str(group.connector_id)+"_f_"+Canonical.digest([boundary.span_id,piece.t0,piece.t1]).substr(0,20)
		var center := Kernel.support_y(cell,Ports._horizontal(group,(float(piece.t0)+float(piece.t1))*0.5))
		var endpoint := {"connector_id":connector_id,"surface_id":cell.surface_id,"position":center,"outward":normal,"width":float(piece.t1)-float(piece.t0),"headroom":minf(authored.headroom,cell.headroom),"kind":authored.kind,"tags":tags.duplicate(),"direction":authored.direction}
		if endpoint.headroom < PROFILE.height or not Kernel.connector_valid(endpoint,cell): return failure("connector_invalid",id)
		endpoints.append(endpoint); group.fragments.append({"connector_id":connector_id,"t0":piece.t0,"t1":piece.t1})
		provenance.append({"connector_id":connector_id,"span_id":boundary.span_id,"t0":piece.t0,"t1":piece.t1}); cursor = piece.t1
	if cursor != half: return failure("geometry_precision_limit" if absf(cursor-half) <= EPS else "connector_coverage",id)
	var checked := Ports.validate_port_group(group,{"connectors":endpoints,"surfaces":cells})
	if not checked.ok: return failure(checked.code,id)
	var authored_port := group.duplicate(true); authored_port.connector_id = id; authored_port["port_id"] = group.connector_id; authored_port["surface_id"] = authored.surface_id; authored_port.fragments = provenance
	return {"ok":true,"group":group,"authored_port":authored_port,"endpoints":endpoints}

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

static func _face(visual: Dictionary) -> Dictionary:
	var face := {}
	for field: String in Topology.FIELDS: face[field] = visual[field]
	var base := "bottom_y" if visual.has("bottom_y") else "thickness_y"
	face[base] = visual[base]
	return face

static func _mass(visual: Dictionary) -> Dictionary:
	var result := {"volume_id":"terrain/"+str(visual.face_id),"support_surface_id":visual.surface_id,"top":visual.vertices.duplicate()}
	var base := "bottom_y" if visual.has("bottom_y") else "thickness_y"
	result[base] = visual[base]
	return result

static func _render_geometry_valid(package: Dictionary) -> bool:
	if not package.get("render_layers") is Array or package.render_layers.size() > 4096: return false
	var fields := Schema.FIELDS.layers.duplicate(); fields.erase("name"); fields.erase("locked"); fields.erase("protected_regions")
	var errors: Array = []; var ids := {}; var quads := 0.0
	for layer: Variant in package.render_layers:
		Schema._shape(layer,fields,"render_layer",errors)
		if not errors.is_empty() or layer.columns < 2 or layer.rows < 2 or layer.sample_spacing <= 0 or ids.has(layer.layer_id): return false
		ids[layer.layer_id] = true
		quads += (float(layer.columns)-1.0)*(float(layer.rows)-1.0)
		if quads > MAX_GRID_QUADS or layer.heights.size() != int(layer.columns)*int(layer.rows): return false
		for material: String in layer.material_masks:
			if material not in Materials.IDS or layer.material_masks[material].size() != layer.heights.size(): return false
			for weight: float in layer.material_masks[material]:
				if weight < 0 or weight > 1: return false
	if package.has("grid_quads") and package.grid_quads != quads: return false
	var special: Array = []
	for visual: Dictionary in package.visuals:
		if not visual.special: continue
		var xyz: Array = []
		for point: Vector3 in visual.vertices: xyz.append([point.x,point.y,point.z])
		special.append({"surface_id":visual.source_id,"vertices_xyz":xyz,"headroom":visual.headroom})
	var generated := _collect_geometry({"layers":package.render_layers,"special_surfaces":special})
	return generated.ok and Canonical.encode(generated.visuals) == Canonical.encode(package.visuals)

static func _geometry_metadata_valid(package: Dictionary) -> bool:
	if not package.get("visuals") is Array or package.visuals.is_empty() or package.visuals.size() > MAX_SUPPORTS or not package.get("exposed_sides") is Array or not package.get("boundaries") is Array or not package.get("adjacency") is Array: return false
	if not package.part.get("surfaces") is Array or package.part.surfaces.is_empty() or not package.part.get("solid_prisms") is Array: return false
	var faces: Array = []; var cells: Array = []; var masses: Array = []
	for visual: Variant in package.visuals:
		if not visual is Dictionary or visual.size() != 10 or not visual.has_all(["face_id","surface_id","source_id","vertices","earth_weights","material_weights","special","headroom","walkable"]): return false
		if not visual.surface_id is String or not visual.has("bottom_y") and not visual.has("thickness_y"): return false
		var face := _face(visual)
		if not Topology.valid_face(face) or visual.surface_id != (visual.face_id if visual.walkable else ""): return false
		for point: Vector3 in visual.vertices:
			if maxf(absf(point.x),maxf(absf(point.y),absf(point.z))) > 8192: return false
		if visual.walkable and visual.headroom < PROFILE.height: return false
		if not visual.material_weights is Array or visual.material_weights.size() != visual.vertices.size() or not visual.earth_weights is Array: return false
		if visual.earth_weights.size() != (0 if visual.special else visual.vertices.size()): return false
		for k: int in visual.material_weights.size():
			var weights: Variant = visual.material_weights[k]
			if not weights is Array or weights.size() != 4: return false
			var total := 0.0
			for weight: Variant in weights:
				if not (weight is int or weight is float) or not is_finite(float(weight)) or weight < 0 or weight > 1: return false
				total += float(weight)
			if absf(total-1.0) > 0.000000001: return false
			if not visual.special and visual.earth_weights[k] != weights[1]: return false
		faces.append(face); masses.append(_mass(visual))
		if visual.walkable: cells.append({"surface_id":visual.face_id,"vertices":visual.vertices,"headroom":visual.headroom})
	if Canonical.encode(cells) != Canonical.encode(package.part.surfaces) or Canonical.encode(masses) != Canonical.encode(package.part.solid_prisms): return false
	if not _render_geometry_valid(package): return false
	var rebuilt := Topology.build(faces)
	if not rebuilt.ok or Canonical.encode(rebuilt.exposed_sides) != Canonical.encode(package.exposed_sides) or Canonical.encode(rebuilt.adjacency) != Canonical.encode(package.adjacency): return false
	var endpoints := {}
	for endpoint: Dictionary in package.part.connectors: endpoints[endpoint.connector_id] = endpoint
	for endpoint: Dictionary in rebuilt.connectors:
		if not endpoints.has(endpoint.connector_id) or Canonical.encode(endpoints[endpoint.connector_id]) != Canonical.encode(endpoint): return false
	var closed: Array = package.boundaries.duplicate(true)
	for boundary: Variant in closed:
		if not boundary is Dictionary or not boundary.get("openings") is Array: return false
		boundary.openings = []
		boundary.kind = "support_edge" if boundary.get("closure") == "profile" else "cliff_edge"
	return Canonical.encode(rebuilt.boundaries) == Canonical.encode(closed)

static func validate_package(package: Dictionary) -> bool:
	if var_to_bytes(package).size() > 4*1024*1024: return false
	if package.get("compiler_revision") != REVISION or package.get("format_version") != 5 or not package.has("package_hash"): return false
	# Existing v2 producers may store textual keys as StringName via dot assignment.
	# Keep the same bounded passive-value check used by the source preflight.
	if not _valid_authoring_value(package) or (package.has("objects") and not Objects.validate_records(package.objects)): return false
	if not package.get("profile") is Dictionary or package.profile != PROFILE or not package.get("part") is Dictionary or not Ports.validate_groups(package.part).ok: return false
	if not WorldGeometry._stage_prisms_valid({"surfaces":package.part.surfaces,"solid_prisms":package.part.get("solid_prisms",[])}): return false
	if not _geometry_metadata_valid(package) or not _ports_metadata_valid(package): return false
	var content := package.duplicate(true); content.erase("package_hash")
	return Canonical.digest(content) == package.package_hash and Objects.validate_dependencies(package.get("dependencies",[]),Materials.dependencies())

static func _ports_metadata_valid(package: Dictionary) -> bool:
	for field: String in ["authored_ports","boundaries","adjacency","visuals"]:
		if not package.get(field) is Array: return false
	var part: Dictionary = package.part; var groups := Ports.validate_groups(part)
	if not groups.ok or package.authored_ports.size() != groups.ports.size(): return false
	var cells := {}; var endpoints := {}; var origins := {}; var spans := {}; var openings := {}; var authored_ids := {}; var group_ids := {}
	for cell: Dictionary in part.surfaces: cells[cell.surface_id] = cell
	for endpoint: Dictionary in part.connectors:
		if not Ports._physical(endpoint,part.surfaces).ok: return false
		endpoints[endpoint.connector_id] = endpoint
	for visual: Dictionary in package.visuals:
		if visual.walkable: origins[visual.surface_id] = visual.source_id
	if origins.size() != cells.size(): return false
	for boundary: Variant in package.boundaries:
		# Exact geometry, closure and side ownership were checked by the topology receiver.
		if spans.has(boundary.span_id) or not boundary.openings is Array: return false
		if boundary.closure == "terrain":
			if not boundary.openings.is_empty() or boundary.kind != "cliff_edge": return false
			spans[boundary.span_id] = boundary; continue
		if not cells.has(boundary.surface_id) or boundary.source_id != origins[boundary.surface_id] or boundary.kind != ("support_edge" if boundary.openings.is_empty() else "opening"): return false
		spans[boundary.span_id] = boundary
		for id: Variant in boundary.openings:
			if not id is String or openings.has(id) or not groups.members.has(id) or not endpoints.has(id) or endpoints[id].surface_id != boundary.surface_id or not _opening_fits(endpoints[id],boundary): return false
			openings[id] = boundary.span_id
	if openings.size() != groups.members.size(): return false
	for authored: Variant in package.authored_ports:
		if not authored is Dictionary or not Ports._shape(authored,["connector_id","port_id","surface_id","position","outward","width","headroom","kind","tags","direction","fragments"]) or not Ports._port_schema(authored): return false
		if authored_ids.has(authored.connector_id) or not authored.surface_id is String or not authored.port_id is String or group_ids.has(authored.port_id) or not groups.ports.has(authored.port_id) or not authored.fragments is Array: return false
		authored_ids[authored.connector_id] = true; group_ids[authored.port_id] = true
		for fragment: Variant in authored.fragments:
			if not fragment is Dictionary or not Ports._shape(fragment,["connector_id","span_id","t0","t1"]) or not fragment.get("connector_id") is String or not fragment.get("span_id") is String or not openings.has(fragment.connector_id) or openings[fragment.connector_id] != fragment.span_id: return false
		var position: Vector3 = authored.position; var outward: Vector3 = authored.outward
		var raw := {"connector_id":authored.connector_id,"surface_id":authored.surface_id,"position_xyz":[position.x,position.y,position.z],"normal_xyz":[outward.x,outward.y,outward.z],"width":authored.width,"headroom":authored.headroom,"kind":authored.kind,"tags":authored.tags,"direction":authored.direction}
		var rebuilt := _compile_authored_port(raw,package.boundaries,part.surfaces)
		if not rebuilt.ok or Canonical.encode(rebuilt.authored_port) != Canonical.encode(authored) or Canonical.encode(rebuilt.group) != Canonical.encode(groups.ports[authored.port_id].port): return false
		for endpoint: Dictionary in rebuilt.endpoints:
			if Canonical.encode(endpoint) != Canonical.encode(endpoints[endpoint.connector_id]): return false
	var internal := {}; var link_ids := {}
	for link: Variant in package.adjacency:
		if not link is Dictionary or not Ports._shape(link,["connection_id","a_connector","b_connector","forward","backward"]) or not Ports._text(link.connection_id) or link_ids.has(link.connection_id) or not link.forward is bool or not link.backward is bool or not link.forward or not link.backward: return false
		link_ids[link.connection_id] = true
		for id: Variant in [link.a_connector,link.b_connector]:
			if not id is String or not endpoints.has(id) or internal.has(id) or groups.members.has(id): return false
			internal[id] = true
		var a: Dictionary = endpoints[link.a_connector]; var b: Dictionary = endpoints[link.b_connector]
		if a.position != b.position or Vector3(a.outward).dot(b.outward) > -1.0+EPS or a.width != b.width: return false
	return internal.size()+groups.members.size() == endpoints.size()

static func preview_manifest(package: Dictionary) -> Manifest:
	if not validate_package(package): return null
	var part: Dictionary = package.part
	var stage := {"stage_id":"terrain_preview","biome":"authored","entrance":"","part_instances":[{"part_id":part.part_id,"rotation_quarters":0,"translation":Vector3.ZERO}],"surfaces":part.surfaces.duplicate(true),"connectors":part.connectors.duplicate(true),"connections":package.adjacency.duplicate(true),"sockets":part.sockets.duplicate(true),"volumes":part.solid_volumes.duplicate(true),"solid_prisms":part.get("solid_prisms",[]).duplicate(true)}
	var manifest := Manifest.new()
	manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":[part.duplicate(true)]},"stages":[stage],"traversal":package.profile.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	return manifest
