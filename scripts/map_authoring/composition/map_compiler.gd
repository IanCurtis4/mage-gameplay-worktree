@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const SolidPrism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const Ports = preload("res://scripts/core/expedition/generation/connector_partition.gd")
const REVISION := "map_composition_v4"
const EPS := 0.0001
var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false
func start(source: Dictionary) -> void:
	var copy := source.duplicate(true)
	_thread = Thread.new(); _thread.start(func() -> Dictionary: return compile(copy,func(_p: float) -> bool:
		_mutex.lock(); var cancelled := _cancelled; _mutex.unlock(); return cancelled))
func ready() -> bool: return _thread != null and not _thread.is_alive()
func cancel() -> void:
	_mutex.lock(); _cancelled = true; _mutex.unlock()
func take(current_hash: String) -> Dictionary:
	var result: Dictionary = _thread.wait_to_finish(); _thread = null
	if _cancelled: return fail("cancelled")
	if result.ok and result.input_hash != current_hash: return fail("stale_source")
	return result
func close() -> void:
	if _thread != null: cancel(); _thread.wait_to_finish(); _thread = null

static func fail(code: String, entity: String = "", location: Vector3 = Vector3.ZERO) -> Dictionary:
	var messages := {"map_empty":"Adicione uma peça ao mapa.","piece_invalid":"A peça não pôde ser compilada.","profile_missing":"Não há perfil de barreira publicado para este bioma. Use a ruína técnica ou mantenha rascunho.","connector_missing":"O vínculo aponta para uma abertura ausente.","connector_reused":"Uma abertura só pode participar de um vínculo.","opening_unlinked":"Esta abertura não tem destino. Vincule-a ou remova-a na peça.","seam_position":"As aberturas não coincidem. Revise posição e altura.","seam_orientation":"As aberturas precisam apontar em sentidos opostos.","seam_dimensions":"Largura ou folga incompatível na emenda.","seam_tags":"Os tipos ou tags das aberturas não são compatíveis.","seam_direction":"Os sentidos das aberturas não permitem travessia.","geometry_overlap":"Duas peças têm suporte sobreposto.","barrier_unsupported":"Este perfil de ruína requer bordas alinhadas aos eixos.","route_unreachable":"Há uma região inacessível ao corpo de teste.","map_limit":"A composição excede o orçamento técnico.","recipe_tree":"A receita precisa ser uma árvore conectada a partir da primeira instância.","cancelled":"Compilação cancelada.","stale_source":"O mapa mudou; compile novamente."}
	messages.merge({"navigation_budget_exceeded":"A validação atingiu o orçamento técnico; nenhum pacote foi publicado.","stale_geometry":"A geometria mudou durante a validação. Compile novamente.","geometry_invalid":"A geometria recebida é inválida.","connector_invalid":"A abertura contém dados ou referências inválidos.","connector_coverage":"Os fragmentos não cobrem toda a abertura.","connector_ambiguous":"Mais de um fragmento ocupa o mesmo trecho da abertura.","geometry_precision_limit":"Este trecho excede a precisão geométrica disponível.","insufficient_headroom":"A abertura não oferece folga suficiente ao corpo de teste."})
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":entity,"field":"composition","location":location,"severity":"error","message":messages.get(code,"Revise os dados do mapa: "+code),"suggestion":"Selecione a região indicada e corrija a fonte."}]}

static func _vector(xyz: Array) -> Vector3: return Vector3(xyz[0],xyz[1],xyz[2])
static func _port_id(instance: String, authored: String) -> String: return instance+"/port_"+authored.sha256_text().substr(0,20)
static func _find(items: Array, key: String, id: String) -> Dictionary:
	for item: Dictionary in items:
		if item[key] == id: return item
	return {}
static func _center(cell: Dictionary) -> Vector3:
	var center := Vector3.ZERO
	for vertex: Vector3 in cell.vertices: center += vertex
	return center/float(cell.vertices.size())

static func compile(source: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var validated := Document.validate(source)
	if not validated.ok: return validated
	if source.instances.is_empty(): return fail("map_empty")
	if source.barrier_profile != "ruin_envelope_v1": return fail("profile_missing")
	for instance: Dictionary in source.instances:
		var eligible := Context.eligible(source,instance,_find(source.pieces,"piece_hash",instance.piece_hash).source)
		if not eligible.ok: return eligible
	var packages: Dictionary = {}; var definitions: Array = []; var render: Array = []
	var all_dependencies: Array = []
	var pieces: Array = source.pieces.duplicate(true); pieces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.piece_hash < b.piece_hash)
	for piece: Dictionary in pieces:
		if cancellation.is_valid() and cancellation.call(0.1): return fail("cancelled")
		var built := Terrain.compile(piece.source,cancellation)
		if not built.ok:
			built.diagnostics[0].entity_id = piece.source.document_id+"/"+str(built.diagnostics[0].entity_id); return built
		packages[piece.piece_hash] = built.package
		for dependency: Dictionary in built.package.dependencies:
			if dependency not in all_dependencies: all_dependencies.append(dependency.duplicate(true))
	var instances: Array = source.instances.duplicate(true)
	# Array order is not identity. Recipe root is the lexicographically first instance.
	instances.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	var links: Array = source.links.duplicate(true); links.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.link_id < b.link_id)
	if source.mode == "recipe":
		if links.size() != instances.size()-1: return fail("recipe_tree")
		var fixed := {instances[0].instance_id:true}; var changed := true
		while changed:
			changed = false
			for link: Dictionary in links:
				if fixed.has(link.a_instance) == fixed.has(link.b_instance): continue
				var known_a: bool = fixed.has(link.a_instance)
				var parent := _find(instances,"instance_id",link.a_instance if known_a else link.b_instance)
				var child := _find(instances,"instance_id",link.b_instance if known_a else link.a_instance)
				var parent_resolved := Ports.resolve_port(packages[parent.piece_hash].part,_port_id("",link.a_connector if known_a else link.b_connector).trim_prefix("/"))
				var child_resolved := Ports.resolve_port(packages[child.piece_hash].part,_port_id("",link.b_connector if known_a else link.a_connector).trim_prefix("/"))
				if not parent_resolved.ok or not child_resolved.ok: return fail("connector_missing",link.link_id)
				var parent_port: Dictionary = parent_resolved.port; var child_port: Dictionary = child_resolved.port
				var offset := Kernel.rotate(parent_port.position,int(parent.rotation_quarters))+_vector(parent.position_xyz)-Kernel.rotate(child_port.position,int(child.rotation_quarters))
				if absf(offset.y) > EPS: return fail("seam_position",link.link_id,offset)
				child.position_xyz = [offset.x,offset.y,offset.z]; fixed[child.instance_id] = true; changed = true
		if fixed.size() != instances.size(): return fail("recipe_tree")
	var stage := {"stage_id":"map_preview","biome":"ruin","entrance":"","part_instances":[],"surfaces":[],"connectors":[],"connections":[],"sockets":[],"volumes":[],"solid_prisms":[]}
	var boundaries: Array = []; var endpoints: Dictionary = {}; var provenance: Dictionary = {}; var instantiated: Dictionary = {}; var logical_ports: Array = []
	for instance: Dictionary in instances:
		var package: Dictionary = packages[instance.piece_hash]; var part: Dictionary = package.part.duplicate(true)
		# Unique definition IDs avoid collisions when different source revisions share document_id.
		part.part_id = "piece_"+instance.piece_hash
		if _find(definitions,"part_id",part.part_id).is_empty(): definitions.append(part)
		var prefix: String = instance.instance_id+"/"; var q := int(instance.rotation_quarters); var offset := _vector(instance.position_xyz)
		var physical := {"surfaces":[],"connectors":[],"connector_groups":[]}
		stage.part_instances.append({"instance_id":instance.instance_id,"part_id":part.part_id,"rotation_quarters":q,"translation":offset})
		for cell: Dictionary in part.surfaces:
			var copy := cell.duplicate(true); copy.surface_id = prefix+cell.surface_id
			for i: int in copy.vertices.size():
				copy.vertices[i] = Kernel.rotate(copy.vertices[i],q)+offset
				if Vector3(copy.vertices[i]).length() > 32768: return fail("map_limit",instance.instance_id)
			for other: Dictionary in stage.surfaces:
				if provenance[other.surface_id] != instance.instance_id and Kernel.cells_overlap(copy,other): return fail("geometry_overlap",instance.instance_id,_center(copy))
			stage.surfaces.append(copy); physical.surfaces.append(copy); provenance[copy.surface_id] = instance.instance_id
		for port: Dictionary in part.connectors:
			var copy := port.duplicate(true); copy.connector_id = prefix+port.connector_id; copy.surface_id = prefix+port.surface_id
			copy.position = Kernel.rotate(port.position,q)+offset; copy.outward = Kernel.rotate(port.outward,q)
			stage.connectors.append(copy); physical.connectors.append(copy); endpoints[copy.connector_id] = copy
		for group: Dictionary in part.get("connector_groups",[]): physical.connector_groups.append(Ports.transform_group(group,q,offset,prefix))
		instantiated[instance.instance_id] = physical
		for authored: Dictionary in package.authored_ports:
			logical_ports.append({"instance_id":instance.instance_id,"connector_id":authored.connector_id,"port_id":prefix+str(authored.port_id),"position":Kernel.rotate(authored.position,q)+offset,"outward":Kernel.rotate(authored.outward,q),"width":authored.width,"headroom":authored.headroom,"kind":authored.kind,"tags":authored.tags.duplicate(),"direction":authored.direction})
		for adjacency: Dictionary in package.adjacency:
			var copy := adjacency.duplicate(true); copy.connection_id = prefix+copy.connection_id; copy.a_connector = prefix+copy.a_connector; copy.b_connector = prefix+copy.b_connector; stage.connections.append(copy)
		for socket: Dictionary in part.sockets:
			var copy := socket.duplicate(true); copy.socket_id = prefix+copy.socket_id; copy.surface_id = prefix+copy.surface_id; copy.position = Kernel.rotate(copy.position,q)+offset; stage.sockets.append(copy)
		for volume: AABB in part.solid_volumes: stage.volumes.append(Kernel.transform_volume(volume,q,offset))
		for prism: Dictionary in part.get("solid_prisms",[]):
			var transformed := SolidPrism.transformed(prism,q,offset,prefix,prefix)
			for point: Vector3 in transformed.top:
				if point.length() > 32768: return fail("map_limit",instance.instance_id)
			stage.solid_prisms.append(transformed)
		for boundary: Dictionary in package.boundaries:
			var copy := boundary.duplicate(true); copy.span_id = prefix+copy.span_id; copy.face_id = prefix+copy.face_id
			copy.surface_id = prefix+copy.surface_id if not copy.surface_id.is_empty() else ""
			if not copy.adjacent_face_id.is_empty(): copy.adjacent_face_id = prefix+copy.adjacent_face_id
			copy.a = Kernel.rotate(copy.a,q)+offset; copy.b = Kernel.rotate(copy.b,q)+offset
			copy.outward = Kernel.rotate(copy.outward,q)
			for i: int in copy.openings.size(): copy.openings[i] = prefix+copy.openings[i]
			boundaries.append(copy)
		var presentation := {"instance_id":instance.instance_id,"rotation_quarters":q,"translation":offset,"layers":package.render_layers.duplicate(true),"visuals":package.visuals.duplicate(true),"exposed_sides":package.exposed_sides.duplicate(true),"boundaries":package.boundaries.duplicate(true),"adjacency":package.adjacency.duplicate(true),"authored_ports":package.authored_ports.duplicate(true)}
		if package.has("objects"):
			presentation["objects"] = []
			for object: Dictionary in package.objects:
				var copy := object.duplicate(true)
				copy.placement_id = prefix+copy.placement_id; copy.surface_id = prefix+copy.surface_id
				copy.position = Kernel.rotate(copy.position,q)+offset
				copy.rotation_y = fposmod(float(copy.rotation_y)+float(q)*90.0,360.0)
				if copy.has("body_volume"): copy.body_volume = Kernel.transform_volume(copy.body_volume,q,offset)
				presentation.objects.append(copy)
		render.append(presentation)
	if stage.surfaces.size() > 1024 or stage.solid_prisms.size() > 2048: return fail("map_limit")
	var used: Dictionary = {}; var realized_links: Array = []
	for link: Dictionary in links:
		var aid := _port_id(link.a_instance,link.a_connector); var bid := _port_id(link.b_instance,link.b_connector)
		var a := Ports.resolve_port(instantiated[link.a_instance],aid); var b := Ports.resolve_port(instantiated[link.b_instance],bid)
		if not a.ok or not b.ok: return fail("connector_missing",link.link_id)
		if used.has(aid) or used.has(bid): return fail("connector_reused",link.link_id,a.port.position)
		var partition := Ports.partition_link(a,b,link.link_id,Terrain.PROFILE)
		if not partition.ok: return fail(partition.code,link.link_id,a.port.position)
		stage.connectors = stage.connectors.filter(func(port: Dictionary) -> bool: return port.connector_id not in partition.consumed)
		stage.connectors.append_array(partition.endpoints); stage.connections.append_array(partition.connections)
		for old: String in partition.consumed: endpoints.erase(old)
		for endpoint: Dictionary in partition.endpoints: endpoints[endpoint.connector_id] = endpoint; used[endpoint.connector_id] = true
		for boundary: Dictionary in boundaries:
			var rewritten: Array = []
			for original: String in boundary.openings: rewritten.append_array(partition.remap.get(original,[original]))
			boundary.openings = rewritten
		realized_links.append({"link_id":link.link_id,"a_instance":link.a_instance,"a_connector":link.a_connector,"b_instance":link.b_instance,"b_connector":link.b_connector,"fragments":partition.provenance.duplicate(true)})
		used[aid] = true; used[bid] = true
	for port: Dictionary in logical_ports:
		if not used.has(port.port_id): return fail("opening_unlinked",str(port.instance_id)+"/"+str(port.connector_id),port.position)
	var barriers: Array = []; var wall_keys: Dictionary = {}
	for boundary: Dictionary in boundaries:
		if boundary.closure == "terrain": continue
		var a: Vector3 = boundary.a; var b: Vector3 = boundary.b; var delta := b-a
		var dx := float(b.x)-float(a.x); var dz := float(b.z)-float(a.z); var length := sqrt(dx*dx+dz*dz)
		if absf(delta.x) > EPS and absf(delta.z) > EPS: return fail("barrier_unsupported",boundary.span_id,a)
		var gaps: Array = []
		for port_id: String in boundary.openings:
			if not used.has(port_id): return fail("opening_unlinked",port_id,endpoints[port_id].position)
			var port: Dictionary = endpoints[port_id]
			var t := ((float(port.position.x)-float(a.x))*dx+(float(port.position.z)-float(a.z))*dz)/length
			var half_width: float = float(port.width)*0.5
			gaps.append([maxf(0,t-half_width),minf(length,t+half_width)])
		gaps.sort_custom(func(x: Array,y: Array) -> bool: return x[0] < y[0])
		var cursor := 0.0
		for gap: Array in gaps:
			if gap[0] < cursor-EPS: return fail("seam_dimensions",boundary.span_id,a)
			_add_wall(barriers,wall_keys,_span_point(a,b,cursor/length),_span_point(a,b,float(gap[0])/length),boundary.span_id)
			cursor = gap[1]
		_add_wall(barriers,wall_keys,_span_point(a,b,cursor/length),b,boundary.span_id)
	barriers = _normalize_walls(barriers)
	for barrier: Dictionary in barriers: stage.volumes.append(barrier.volume)
	var manifest := Manifest.new(); manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":definitions},"stages":[stage],"traversal":Terrain.PROFILE.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	var world := World.new(); var configured := world.configure(manifest,"map_preview")
	if not configured.ok: return fail("geometry_invalid")
	var root := _walkable_point(world,stage.surfaces[0],Terrain.PROFILE)
	if root == null: return fail("route_unreachable",stage.surfaces[0].surface_id)
	var destinations: Array[ExpeditionWorldPoint] = []
	for cell: Dictionary in stage.surfaces:
		if cancellation.is_valid() and cancellation.call(0.9): return fail("cancelled")
		var destination := _walkable_point(world,cell,Terrain.PROFILE)
		if destination == null: return fail("route_unreachable",cell.surface_id,_center(cell))
		destinations.append(destination)
	var cancelled := func() -> bool: return cancellation.is_valid() and bool(cancellation.call(0.95))
	var certified := world.connectivity_batch(root,destinations,Terrain.PROFILE,world.geometry_revision,cancelled)
	if not certified.ok:
		var failure := fail(str(certified.error_code))
		failure["geometry_diagnostic"] = certified.data.duplicate(true)
		return failure
	if not certified.data.complete: return fail("navigation_budget_exceeded")
	if not certified.data.all_reachable:
		for target: Dictionary in certified.data.targets:
			if target.outward_reachable and target.inward_reachable: continue
			var failure := fail("route_unreachable",target.point.surface_id,target.point.position)
			failure["geometry_diagnostic"] = {"from":root.to_data(),"to":target.point,"outward_code":"" if target.outward_reachable else "unreachable","inward_code":"" if target.inward_reachable else "unreachable","metrics":certified.data.metrics}
			return failure
	if Document.hash_source(source) != validated.output_hash: return fail("stale_source")
	var output := {"format_version":4,"compiler_revision":REVISION,"source_hash":validated.output_hash,"dependencies":all_dependencies,"profile":Terrain.PROFILE.duplicate(true),"manifest":manifest.to_data(),"render_instances":render,"barriers":barriers,"realized_instances":instances,"piece_count":instances.size(),"logical_ports":logical_ports,"realized_links":realized_links}
	if source.has("context"): output["authoring_context"] = source.context.duplicate(true)
	var piece_contexts := {}
	for instance: Dictionary in instances:
		var piece := _find(source.pieces,"piece_hash",instance.piece_hash)
		if piece.source.has("context"): piece_contexts[instance.instance_id] = piece.source.context.duplicate(true)
	if not piece_contexts.is_empty(): output["piece_contexts"] = piece_contexts
	output["package_hash"] = Canonical.digest(output)
	if var_to_bytes(output).size() > 4*1024*1024: return fail("map_limit")
	return {"ok":true,"code":"","diagnostics":Context.warnings(source),"input_hash":validated.output_hash,"output_hash":output.package_hash,"package":output,"metrics":{"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"navigation":certified.data.metrics.duplicate(true)}}

static func _span_point(a: Vector3, b: Vector3, t: float) -> Vector3:
	if t == 0.0: return a
	if t == 1.0: return b
	return Vector3(float(a.x)+(float(b.x)-float(a.x))*t,float(a.y)+(float(b.y)-float(a.y))*t,float(a.z)+(float(b.z)-float(a.z))*t)

static func _add_wall(barriers: Array, keys: Dictionary, a: Vector3, b: Vector3, owner: String) -> void:
	if a.distance_to(b) < EPS: return
	var ends := [Canonical.encode(a),Canonical.encode(b)]; ends.sort()
	var key: String = "|".join(ends)
	if keys.has(key): return
	keys[key] = true
	var low := Vector3(minf(a.x,b.x),minf(a.y,b.y)-4,minf(a.z,b.z))
	var high := Vector3(maxf(a.x,b.x),maxf(a.y,b.y)+20,maxf(a.z,b.z))
	# A single centered envelope is both rendered and consumed by WorldGeometry.
	if absf(high.x-low.x) < EPS: low.x -= 1; high.x += 1
	if absf(high.z-low.z) < EPS: low.z -= 1; high.z += 1
	barriers.append({"barrier_id":"wall_"+key.sha256_text().substr(0,20),"owner":owner,"a":a,"b":b,"volume":AABB(low,high-low),"profile":"ruin_envelope_v1"})

static func _normalize_walls(raw: Array) -> Array:
	# Split shared collinear spans at original endpoints before assigning one owner.
	# This handles a small room adjoining only part of a larger piece's boundary.
	var output: Array = []; var keys: Dictionary = {}
	for wall: Dictionary in raw:
		var a: Vector3 = wall.a; var b: Vector3 = wall.b; var delta := b-a
		var cuts: Array = [{"t":0.0,"point":a},{"t":1.0,"point":b}]
		for other: Dictionary in raw:
			for point: Vector3 in [other.a,other.b]:
				var t := (point-a).dot(delta)/delta.length_squared()
				if t > EPS and t < 1.0-EPS and (a+delta*t).distance_to(point) < EPS:
					var exists := false
					for cut: Dictionary in cuts:
						if Vector3(cut.point).distance_to(point) < EPS: exists = true
					if not exists: cuts.append({"t":t,"point":point})
		cuts.sort_custom(func(x: Dictionary,y: Dictionary) -> bool: return x.t < y.t)
		for i: int in range(1,cuts.size()): _add_wall(output,keys,cuts[i-1].point,cuts[i].point,wall.owner)
	return output

static func validate_package(package: Dictionary) -> bool:
	if package.get("format_version") != 4 or package.get("compiler_revision") != REVISION or not package.has("package_hash"): return false
	if not Canonical.valid(package) or not package.has_all(["source_hash","dependencies","profile","manifest","render_instances","barriers","realized_instances","piece_count"]): return false
	if not package.profile is Dictionary or package.profile != Terrain.PROFILE: return false
	if not package.manifest is Dictionary or not package.render_instances is Array or not package.barriers is Array: return false
	for instance: Variant in package.render_instances:
		if not instance is Dictionary or (instance.has("objects") and not Objects.validate_records(instance.objects)): return false
	if not package.manifest.has_all(["input","stages","traversal","population","objectives","portals","witnesses"]): return false
	if not package.manifest.traversal is Dictionary or package.manifest.traversal != Terrain.PROFILE or not package.manifest.stages is Array: return false
	for stage: Variant in package.manifest.stages:
		if not stage is Dictionary or not World._stage_prisms_valid(stage): return false
	if not package.manifest.input is Dictionary or not package.manifest.input.get("parts") is Array: return false
	for part: Variant in package.manifest.input.parts:
		if not part is Dictionary or not Ports.validate_groups(part).ok: return false
	if not _logical_metadata_valid(package) or not _terrain_metadata_valid(package): return false
	var content := package.duplicate(true); content.erase("package_hash")
	return Canonical.digest(content) == package.package_hash and Objects.validate_dependencies(package.get("dependencies",[]),preload("res://scripts/map_authoring/terrain/terrain_material.gd").dependencies())

static func _terrain_metadata_valid(package: Dictionary) -> bool:
	# A render record remains in piece coordinates. Rebuild its terrain topology,
	# then compare the transformed physical masses with the actual stage.
	var definitions := {}; var instances := {}; var seen := {}; var masses: Array = []
	for part: Dictionary in package.manifest.input.parts: definitions[part.part_id] = part
	var stage: Dictionary = package.manifest.stages[0]
	for instance: Dictionary in stage.part_instances: instances[instance.instance_id] = instance
	if package.render_instances.size() != instances.size(): return false
	for render: Variant in package.render_instances:
		if not render is Dictionary or not render.get("instance_id") is String or not instances.has(render.instance_id) or seen.has(render.instance_id): return false
		seen[render.instance_id] = true
		var instance: Dictionary = instances[render.instance_id]
		if render.get("rotation_quarters") != instance.rotation_quarters or render.get("translation") != instance.translation: return false
		var local: Dictionary = render.duplicate(true); local["part"] = definitions[instance.part_id]; local["render_layers"] = render.get("layers")
		if not Terrain._geometry_metadata_valid(local) or not Terrain._ports_metadata_valid(local): return false
		var prefix: String = render.instance_id+"/"
		for mass: Dictionary in local.part.solid_prisms: masses.append(SolidPrism.transformed(mass,instance.rotation_quarters,instance.translation,prefix,prefix))
	return Canonical.encode(masses) == Canonical.encode(stage.get("solid_prisms",[]))

static func _logical_metadata_valid(package: Dictionary) -> bool:
	if not package.get("logical_ports") is Array or not package.get("realized_links") is Array or not package.manifest.stages is Array or package.manifest.stages.size() != 1: return false
	var stage: Dictionary = package.manifest.stages[0]
	for field: String in ["part_instances","surfaces","connectors","connections"]:
		if not stage.get(field) is Array: return false
	var definitions := {}; var pieces := {}; var expected := {}; var expected_links := {}; var logical := {}; var used := {}
	for definition: Dictionary in package.manifest.input.parts:
		if not definition.get("part_id") is String or definitions.has(definition.part_id): return false
		definitions[definition.part_id] = definition
	for instance: Variant in stage.part_instances:
		if not instance is Dictionary or not instance.get("instance_id") is String or pieces.has(instance.instance_id) or not instance.get("part_id") is String or not definitions.has(instance.part_id) or not instance.get("rotation_quarters") is int or instance.rotation_quarters < 0 or instance.rotation_quarters > 3 or not instance.get("translation") is Vector3 or not instance.translation.is_finite(): return false
		var part: Dictionary = definitions[instance.part_id]; var prefix: String = instance.instance_id+"/"; var q: int = instance.rotation_quarters; var offset: Vector3 = instance.translation
		var physical := {"surfaces":[],"connectors":[],"connector_groups":[]}
		for cell: Dictionary in part.surfaces:
			var copy := cell.duplicate(true); copy.surface_id = prefix+cell.surface_id
			for k: int in copy.vertices.size(): copy.vertices[k] = Kernel.rotate(copy.vertices[k],q)+offset
			physical.surfaces.append(copy)
		for endpoint: Dictionary in part.connectors:
			var copy := endpoint.duplicate(true); copy.connector_id = prefix+endpoint.connector_id; copy.surface_id = prefix+endpoint.surface_id; copy.position = Kernel.rotate(endpoint.position,q)+offset; copy.outward = Kernel.rotate(endpoint.outward,q)
			if expected.has(copy.connector_id): return false
			expected[copy.connector_id] = copy; physical.connectors.append(copy)
		for group: Dictionary in part.get("connector_groups",[]): physical.connector_groups.append(Ports.transform_group(group,q,offset,prefix))
		pieces[instance.instance_id] = physical
	var group_count := 0
	var expected_cells := {}
	for physical: Dictionary in pieces.values(): group_count += physical.connector_groups.size()
	for physical: Dictionary in pieces.values():
		for cell: Dictionary in physical.surfaces: expected_cells[cell.surface_id] = cell
	if stage.surfaces.size() != expected_cells.size(): return false
	var actual_cells := {}
	for cell: Variant in stage.surfaces:
		if not cell is Dictionary or not cell.get("surface_id") is String or actual_cells.has(cell.surface_id) or not expected_cells.has(cell.surface_id) or Canonical.encode(cell) != Canonical.encode(expected_cells[cell.surface_id]): return false
		actual_cells[cell.surface_id] = true
	if package.logical_ports.size() != group_count: return false
	for port: Variant in package.logical_ports:
		if not port is Dictionary or not Ports._shape(port,["instance_id","connector_id","port_id","position","outward","width","headroom","kind","tags","direction"]) or not Ports._port_schema(port) or not port.instance_id is String or not pieces.has(port.instance_id) or not port.port_id is String or logical.has(port.port_id) or port.port_id != _port_id(port.instance_id,port.connector_id): return false
		var resolved := Ports.resolve_port(pieces[port.instance_id],port.port_id)
		if not resolved.ok or not resolved.grouped: return false
		var actual: Dictionary = port.duplicate(true); actual.erase("instance_id"); actual.erase("port_id"); actual.connector_id = port.port_id
		var reference: Dictionary = resolved.port.duplicate(true); reference.erase("fragments")
		if Canonical.encode(actual) != Canonical.encode(reference): return false
		logical[port.port_id] = true
	var link_ids := {}
	for link: Variant in package.realized_links:
		if not link is Dictionary or not Ports._shape(link,["link_id","a_instance","a_connector","b_instance","b_connector","fragments"]) or not Ports._text(link.link_id) or link_ids.has(link.link_id) or not link.a_instance is String or not pieces.has(link.a_instance) or not link.b_instance is String or not pieces.has(link.b_instance) or not link.a_connector is String or not link.b_connector is String: return false
		link_ids[link.link_id] = true
		var aid := _port_id(link.a_instance,link.a_connector); var bid := _port_id(link.b_instance,link.b_connector)
		if not logical.has(aid) or not logical.has(bid) or used.has(aid) or used.has(bid) or aid == bid: return false
		var partition := Ports.partition_link(Ports.resolve_port(pieces[link.a_instance],aid),Ports.resolve_port(pieces[link.b_instance],bid),link.link_id,package.profile)
		if not partition.ok or Canonical.encode(partition.provenance) != Canonical.encode(link.fragments): return false
		for id: String in partition.consumed: expected.erase(id)
		for endpoint: Dictionary in partition.endpoints:
			if expected.has(endpoint.connector_id): return false
			expected[endpoint.connector_id] = endpoint
		for connection: Dictionary in partition.connections:
			if expected_links.has(connection.connection_id): return false
			expected_links[connection.connection_id] = connection
		used[aid] = true; used[bid] = true
	if used.size() != logical.size() or stage.connectors.size() != expected.size(): return false
	var actual_ports := {}; var referenced := {}; var actual_links := {}
	for port: Variant in stage.connectors:
		if not port is Dictionary or not port.get("connector_id") is String or actual_ports.has(port.connector_id) or not expected.has(port.connector_id) or Canonical.encode(port) != Canonical.encode(expected[port.connector_id]): return false
		actual_ports[port.connector_id] = port
	for link: Variant in stage.connections:
		if not link is Dictionary or not Ports._shape(link,["connection_id","a_connector","b_connector","forward","backward"]) or not link.connection_id is String or actual_links.has(link.connection_id) or not link.forward is bool or not link.backward is bool: return false
		actual_links[link.connection_id] = true
		for id: Variant in [link.a_connector,link.b_connector]:
			if not id is String or not actual_ports.has(id) or referenced.has(id): return false
			referenced[id] = true
		var a: Dictionary = actual_ports[link.a_connector]; var b: Dictionary = actual_ports[link.b_connector]
		if a.position != b.position or Vector3(a.outward).dot(b.outward) > -1.0+EPS: return false
		if expected_links.has(link.connection_id) and Canonical.encode(link) != Canonical.encode(expected_links[link.connection_id]): return false
	for id: String in expected_links:
		if not actual_links.has(id): return false
	return referenced.size() == actual_ports.size()

static func _walkable_point(world: WorldGeometry, cell: Dictionary, profile: Dictionary, stage_id: String = "map_preview") -> ExpeditionWorldPoint:
	var center := Kernel.support_y(cell,_center(cell))
	var candidates: Array[Vector3] = [center]
	for vertex: Vector3 in cell.vertices:
		for amount: float in [0.05,0.15,0.35,0.65]: candidates.append(Kernel.support_y(cell,vertex.lerp(center,amount)))
	for box: AABB in world._volumes():
		for x: float in [box.position.x-float(profile.radius)-EPS,box.end.x+float(profile.radius)+EPS]:
			for z: float in [box.position.z-float(profile.radius)-EPS,box.end.z+float(profile.radius)+EPS]: candidates.append(Kernel.support_y(cell,Vector3(x,0,z)))
	for position: Vector3 in candidates:
		var point := Point.create(stage_id,cell.surface_id,position)
		if world.position_query(point,profile,world.geometry_revision).ok: return point
	return null
static func manifest(package: Dictionary) -> Manifest:
	if not validate_package(package): return null
	var result := Manifest.new(); result._data = package.manifest.duplicate(true); return result
