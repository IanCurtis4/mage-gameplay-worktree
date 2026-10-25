@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const REVISION := "map_composition_v1"
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
	var validated := Document.validate(source)
	if not validated.ok: return validated
	if source.instances.is_empty(): return fail("map_empty")
	if source.barrier_profile != "ruin_envelope_v1": return fail("profile_missing")
	var packages: Dictionary = {}; var definitions: Array = []; var render: Array = []
	var pieces: Array = source.pieces.duplicate(true); pieces.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.piece_hash < b.piece_hash)
	for piece: Dictionary in pieces:
		if cancellation.is_valid() and cancellation.call(0.1): return fail("cancelled")
		var built := Terrain.compile(piece.source,cancellation)
		if not built.ok:
			built.diagnostics[0].entity_id = piece.source.document_id+"/"+str(built.diagnostics[0].entity_id); return built
		packages[piece.piece_hash] = built.package
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
				var parent_port := _find(packages[parent.piece_hash].part.connectors,"connector_id",_port_id("",link.a_connector if known_a else link.b_connector).trim_prefix("/"))
				var child_port := _find(packages[child.piece_hash].part.connectors,"connector_id",_port_id("",link.b_connector if known_a else link.a_connector).trim_prefix("/"))
				if parent_port.is_empty() or child_port.is_empty(): return fail("connector_missing",link.link_id)
				var offset := Kernel.rotate(parent_port.position,int(parent.rotation_quarters))+_vector(parent.position_xyz)-Kernel.rotate(child_port.position,int(child.rotation_quarters))
				if absf(offset.y) > EPS: return fail("seam_position",link.link_id,offset)
				child.position_xyz = [offset.x,offset.y,offset.z]; fixed[child.instance_id] = true; changed = true
		if fixed.size() != instances.size(): return fail("recipe_tree")
	var stage := {"stage_id":"map_preview","biome":"ruin","entrance":"","part_instances":[],"surfaces":[],"connectors":[],"connections":[],"sockets":[],"volumes":[]}
	var boundaries: Array = []; var endpoints: Dictionary = {}; var provenance: Dictionary = {}
	for instance: Dictionary in instances:
		var package: Dictionary = packages[instance.piece_hash]; var part: Dictionary = package.part.duplicate(true)
		# Unique definition IDs avoid collisions when different source revisions share document_id.
		part.part_id = "piece_"+instance.piece_hash
		if _find(definitions,"part_id",part.part_id).is_empty(): definitions.append(part)
		var prefix: String = instance.instance_id+"/"; var q := int(instance.rotation_quarters); var offset := _vector(instance.position_xyz)
		stage.part_instances.append({"instance_id":instance.instance_id,"part_id":part.part_id,"rotation_quarters":q,"translation":offset})
		for cell: Dictionary in part.surfaces:
			var copy := cell.duplicate(true); copy.surface_id = prefix+cell.surface_id
			for i: int in copy.vertices.size():
				copy.vertices[i] = Kernel.rotate(copy.vertices[i],q)+offset
				if Vector3(copy.vertices[i]).length() > 32768: return fail("map_limit",instance.instance_id)
			for other: Dictionary in stage.surfaces:
				if provenance[other.surface_id] != instance.instance_id and Kernel.cells_overlap(copy,other): return fail("geometry_overlap",instance.instance_id,_center(copy))
			stage.surfaces.append(copy); provenance[copy.surface_id] = instance.instance_id
		for port: Dictionary in part.connectors:
			var copy := port.duplicate(true); copy.connector_id = prefix+port.connector_id; copy.surface_id = prefix+port.surface_id
			copy.position = Kernel.rotate(port.position,q)+offset; copy.outward = Kernel.rotate(port.outward,q)
			stage.connectors.append(copy); endpoints[copy.connector_id] = copy
		for adjacency: Dictionary in package.adjacency:
			var copy := adjacency.duplicate(true); copy.connection_id = prefix+copy.connection_id; copy.a_connector = prefix+copy.a_connector; copy.b_connector = prefix+copy.b_connector; stage.connections.append(copy)
		for socket: Dictionary in part.sockets:
			var copy := socket.duplicate(true); copy.socket_id = prefix+copy.socket_id; copy.surface_id = prefix+copy.surface_id; copy.position = Kernel.rotate(copy.position,q)+offset; stage.sockets.append(copy)
		for volume: AABB in part.solid_volumes: stage.volumes.append(Kernel.transform_volume(volume,q,offset))
		for boundary: Dictionary in package.boundaries:
			var copy := boundary.duplicate(true); copy.span_id = prefix+copy.span_id; copy.surface_id = prefix+copy.surface_id
			copy.a = Kernel.rotate(copy.a,q)+offset; copy.b = Kernel.rotate(copy.b,q)+offset
			for i: int in copy.openings.size(): copy.openings[i] = prefix+copy.openings[i]
			boundaries.append(copy)
		render.append({"instance_id":instance.instance_id,"rotation_quarters":q,"translation":offset,"layers":package.render_layers.duplicate(true),"visuals":package.visuals.duplicate(true)})
	if stage.surfaces.size() > 1024: return fail("map_limit")
	var used: Dictionary = {}
	for link: Dictionary in links:
		var aid := _port_id(link.a_instance,link.a_connector); var bid := _port_id(link.b_instance,link.b_connector)
		if not endpoints.has(aid) or not endpoints.has(bid): return fail("connector_missing",link.link_id)
		var a: Dictionary = endpoints[aid]; var b: Dictionary = endpoints[bid]
		if used.has(aid) or used.has(bid): return fail("connector_reused",link.link_id,a.position)
		if Vector3(a.position).distance_to(b.position) > EPS: return fail("seam_position",link.link_id,a.position)
		if Vector3(a.outward).dot(b.outward) > -1.0+EPS: return fail("seam_orientation",link.link_id,a.position)
		if absf(a.width-b.width) > EPS or absf(a.headroom-b.headroom) > EPS: return fail("seam_dimensions",link.link_id,a.position)
		var shared := false
		for tag: String in a.tags:
			if tag in b.tags: shared = true
		if a.kind != b.kind or not shared: return fail("seam_tags",link.link_id,a.position)
		var forward: bool = a.direction in ["both","out"] and b.direction in ["both","in"]
		var backward: bool = b.direction in ["both","out"] and a.direction in ["both","in"]
		if not forward and not backward: return fail("seam_direction",link.link_id,a.position)
		stage.connections.append({"connection_id":link.link_id,"a_connector":aid,"b_connector":bid,"forward":forward,"backward":backward})
		used[aid] = true; used[bid] = true
	var barriers: Array = []; var wall_keys: Dictionary = {}
	for boundary: Dictionary in boundaries:
		var a: Vector3 = boundary.a; var b: Vector3 = boundary.b; var delta := b-a; var length := delta.length()
		if absf(delta.x) > EPS and absf(delta.z) > EPS: return fail("barrier_unsupported",boundary.span_id,a)
		var gaps: Array = []
		for port_id: String in boundary.openings:
			if not used.has(port_id): return fail("opening_unlinked",port_id,endpoints[port_id].position)
			var port: Dictionary = endpoints[port_id]; var t := (Vector3(port.position)-a).dot(delta.normalized())
			var half_width: float = float(port.width)*0.5*length/Vector2(delta.x,delta.z).length()
			gaps.append([maxf(0,t-half_width),minf(length,t+half_width)])
		gaps.sort_custom(func(x: Array,y: Array) -> bool: return x[0] < y[0])
		var cursor := 0.0
		for gap: Array in gaps:
			if gap[0] < cursor-EPS: return fail("seam_dimensions",boundary.span_id,a)
			_add_wall(barriers,wall_keys,a+delta.normalized()*cursor,a+delta.normalized()*gap[0],boundary.span_id)
			cursor = gap[1]
		_add_wall(barriers,wall_keys,a+delta.normalized()*cursor,b,boundary.span_id)
	barriers = _normalize_walls(barriers)
	for barrier: Dictionary in barriers: stage.volumes.append(barrier.volume)
	var manifest := Manifest.new(); manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":definitions},"stages":[stage],"traversal":Terrain.PROFILE.duplicate(true),"population":{"slots":[]},"objectives":[],"portals":[],"witnesses":{}}
	var world := World.new(); world.configure(manifest,"map_preview")
	var root := Point.create("map_preview",stage.surfaces[0].surface_id,_center(stage.surfaces[0]))
	for cell: Dictionary in stage.surfaces:
		if cancellation.is_valid() and cancellation.call(0.9): return fail("cancelled")
		var destination := Point.create("map_preview",cell.surface_id,_center(cell))
		if not world.path(root,destination,Terrain.PROFILE,world.geometry_revision).ok or not world.path(destination,root,Terrain.PROFILE,world.geometry_revision).ok: return fail("route_unreachable",cell.surface_id,destination.position)
	var output := {"format_version":1,"compiler_revision":REVISION,"source_hash":validated.output_hash,"dependencies":packages.values()[0].dependencies.duplicate(true),"profile":Terrain.PROFILE.duplicate(true),"manifest":manifest.to_data(),"render_instances":render,"barriers":barriers,"realized_instances":instances,"piece_count":instances.size()}
	output["package_hash"] = Canonical.digest(output)
	if var_to_bytes(output).size() > 4*1024*1024: return fail("map_limit")
	return {"ok":true,"code":"","diagnostics":[],"input_hash":validated.output_hash,"output_hash":output.package_hash,"package":output}

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
	if package.get("format_version") != 1 or package.get("compiler_revision") != REVISION or not package.has("package_hash"): return false
	if not Canonical.valid(package) or not package.has_all(["source_hash","dependencies","profile","manifest","render_instances","barriers","realized_instances","piece_count"]): return false
	if not package.manifest is Dictionary or not package.render_instances is Array or not package.barriers is Array: return false
	if not package.manifest.has_all(["input","stages","traversal","population","objectives","portals","witnesses"]): return false
	var content := package.duplicate(true); content.erase("package_hash")
	return Canonical.digest(content) == package.package_hash and package.get("dependencies") == preload("res://scripts/map_authoring/terrain/terrain_material.gd").dependencies()
static func manifest(package: Dictionary) -> Manifest:
	if not validate_package(package): return null
	var result := Manifest.new(); result._data = package.manifest.duplicate(true); return result
