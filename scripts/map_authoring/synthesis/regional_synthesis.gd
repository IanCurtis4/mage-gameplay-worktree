@tool
extends RefCounted
## Checkpoint43 (F9-05, P3a): regional synthesis inside one piece. Checkpoint44
## (P3b): map, population and patrol roots pass encounter bodies and patrol legs
## as extra protections (synthesis/root_synthesis.gd). A passive request
## names a layer, a selection (an existing region of that layer or a polygon in its
## local coordinates), a seed and one recipe or "preserve" per channel (terrain,
## materials, objects). prepare() builds the whole new source on a copy, compiles
## it and returns a proposal; apply() commits it in ONE session.apply after the
## base hash check, so one undo restores everything.
## Contract: docs/map_editor/contracts/f9_regional_synthesis.md.
##
## Mask (shared with exchange later): a terrain sample may change only if its whole
## influence (the four grid cells around it, i.e. the square of half side = spacing)
## lies inside the selection and touches no protection: protected regions of the
## layer, regions named in preserve.region_ids, connector openings, and the
## footprint of every object that stays. Objects that cross the selection or touch
## a protection stay whole; scatter only places footprints fully inside.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Compiler = preload("res://scripts/map_authoring/objects/object_compiler.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const REVISION := "regional_v1"
const REQUEST_KEYS := ["algorithm_revision","seed_text","base_hash","target","selection","channels","preserve"]
const TERRAIN_MODES := ["preserve","relief"]
const MATERIAL_MODES := ["preserve","patches"]
const OBJECT_MODES := ["preserve","scatter"]
const MAX_POLYGON := 256
const MAX_DIFF_IDS := 1024

static func fail(code: String, entity: String = "", field: String = "synthesis") -> Dictionary:
	var messages := {"synthesis_request_invalid":"O pedido de variação regional está incompleto ou mal formado.","synthesis_channel_missing":"Cada canal (terreno, materiais, objetos) precisa dizer \"preservar\" ou trazer uma receita.","synthesis_seed_invalid":"A seed precisa ser um inteiro decimal de 64 bits.","base_diverged":"A peça mudou desde o pedido; refaça a prévia.","source_reference_missing":"A camada ou região indicada não existe nesta peça.","synthesis_selection_layer":"A região escolhida pertence a outra camada.","layer_locked":"A camada está travada.","synthesis_selection_invalid":"A seleção precisa ser um polígono simples com pelo menos três pontos.","synthesis_empty":"Nenhuma amostra ou objeto pode mudar nesta seleção: ela é pequena demais ou está toda protegida.","object_scatter_deficit":"Não coube a quantidade pedida de objetos dentro da seleção.","cancelled":"Operação cancelada.","synthesis_stale_proposal":"A proposta não corresponde mais à peça aberta."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":field,"message":messages.get(code,"Variação regional recusada: "+code)}]}

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func valid_seed(value: Variant) -> bool:
	return value is String and not String(value).is_empty() and String(value) == str(String(value).to_int())

## Shape of the passive request; channel recipes are checked here too.
static func validate_request(request: Variant) -> Dictionary:
	if not request is Dictionary or request.size() != REQUEST_KEYS.size() or not request.has_all(REQUEST_KEYS): return fail("synthesis_request_invalid")
	if request.algorithm_revision != REVISION: return fail("synthesis_request_invalid","","algorithm_revision")
	if not valid_seed(request.seed_text): return fail("synthesis_seed_invalid","","seed_text")
	if not Schema._type(request.base_hash,"hash"): return fail("synthesis_request_invalid","","base_hash")
	if not request.target is Dictionary or request.target.size() != 1 or not Schema._type(request.target.get("layer_id"),"id"): return fail("synthesis_request_invalid","","target")
	var selection: Variant = request.selection
	if not selection is Dictionary or selection.size() != 1: return fail("synthesis_request_invalid","","selection")
	if selection.has("region_id"):
		if not Schema._type(selection.region_id,"id"): return fail("synthesis_request_invalid","","selection")
	elif selection.has("polygon_xz"):
		if not Schema._type(selection.polygon_xz,"points2") or selection.polygon_xz.size() < 3 or selection.polygon_xz.size() > MAX_POLYGON: return fail("synthesis_selection_invalid","","selection")
	else: return fail("synthesis_request_invalid","","selection")
	var channels: Variant = request.channels
	if not channels is Dictionary or channels.size() != 3 or not channels.has_all(["terrain","materials","objects"]): return fail("synthesis_channel_missing","","channels")
	var checked := _valid_channel(channels.terrain,TERRAIN_MODES,{"relief":{"amplitude":[0.0,512.0],"feature_size":[8.0,4096.0],"roughness":[0.0,1.0],"falloff":[0.0,4096.0]}})
	if not checked: return fail("synthesis_request_invalid","","channels.terrain")
	checked = _valid_channel(channels.materials,MATERIAL_MODES,{"patches":{"coverage":[0.0,1.0],"feature_size":[8.0,4096.0]}},{"patches":["material"]})
	if not checked or (channels.materials.mode == "patches" and channels.materials.material not in Materials.IDS): return fail("synthesis_request_invalid","","channels.materials")
	checked = _valid_channel(channels.objects,OBJECT_MODES,{"scatter":{"count":[0.0,1024.0],"spacing":[0.0,8192.0]}},{"scatter":["definition_id","replace"]})
	if not checked or (channels.objects.mode == "scatter" and (not Schema._type(channels.objects.definition_id,"id") or not channels.objects.replace is bool or float(channels.objects.count) != floor(float(channels.objects.count)))): return fail("synthesis_request_invalid","","channels.objects")
	if channels.terrain.mode == "preserve" and channels.materials.mode == "preserve" and channels.objects.mode == "preserve": return fail("synthesis_empty","","channels")
	var preserve: Variant = request.preserve
	if not preserve is Dictionary or preserve.size() != 2 or not Schema._type(preserve.get("entity_ids"),"strings") or not Schema._type(preserve.get("region_ids"),"strings") or preserve.entity_ids.size() > 4096 or preserve.region_ids.size() > 4096: return fail("synthesis_request_invalid","","preserve")
	return {"ok":true}

# A channel is {"mode":"preserve"} or {"mode":<recipe>, numbers..., extras...}.
static func _valid_channel(channel: Variant, modes: Array, numbers: Dictionary, extras: Dictionary = {}) -> bool:
	if not channel is Dictionary or channel.get("mode") not in modes: return false
	if channel.mode == "preserve": return channel.size() == 1
	var fields: Dictionary = numbers.get(channel.mode,{})
	var others: Array = extras.get(channel.mode,[])
	if channel.size() != 1+fields.size()+others.size(): return false
	for key: String in fields:
		if not channel.has(key) or not _number(channel[key],fields[key][0],fields[key][1]): return false
	for key: String in others:
		if not channel.has(key): return false
	return true

static func request_hash(request: Dictionary) -> String: return Schema.semantic_hash(request)

static func _polygon(points: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for xz: Array in points: polygon.append(Vector2(float(xz[0]),float(xz[1])))
	return polygon

# Simple polygon: no two non-adjacent edges intersect, non-zero area.
static func _simple(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3 or absf(_area(polygon)) < 0.0001: return false
	var n := polygon.size()
	for i: int in n:
		for j: int in range(i+1,n):
			if j == i or (j+1)%n == i or (i+1)%n == j: continue
			if Geometry2D.segment_intersects_segment(polygon[i],polygon[(i+1)%n],polygon[j],polygon[(j+1)%n]) != null: return false
	return true

static func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i: int in polygon.size(): total += polygon[i].cross(polygon[(i+1)%polygon.size()])
	return total*0.5

static func _square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(-half,-half),center+Vector2(half,-half),center+Vector2(half,half),center+Vector2(-half,half)])

# Shape A lies fully inside polygon P (P may be concave).
static func _inside(shape: PackedVector2Array, polygon: PackedVector2Array) -> bool:
	for point: Vector2 in shape:
		if not Geometry2D.is_point_in_polygon(point,polygon): return false
	for point: Vector2 in polygon:
		if Geometry2D.is_point_in_polygon(point,shape): return false
	return not _edges_cross(shape,polygon)

static func _touches(shape: PackedVector2Array, polygon: PackedVector2Array) -> bool:
	for point: Vector2 in shape:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	for point: Vector2 in polygon:
		if Geometry2D.is_point_in_polygon(point,shape): return true
	return _edges_cross(shape,polygon)

static func _edges_cross(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for i: int in a.size():
		for j: int in b.size():
			if Geometry2D.segment_intersects_segment(a[i],a[(i+1)%a.size()],b[j],b[(j+1)%b.size()]) != null: return true
	return false

static func _disk_touches(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(center,polygon): return true
	for i: int in polygon.size():
		if Geometry2D.get_closest_point_to_segment(center,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(center) < radius: return true
	return false

static func _disk_inside(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(center,polygon) and not _disk_touches_edge(center,radius,polygon)

static func _disk_touches_edge(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	for i: int in polygon.size():
		if Geometry2D.get_closest_point_to_segment(center,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(center) < radius: return true
	return false

# Deterministic value noise: lattice values from the seed, smooth interpolation,
# octaves halving the feature size; result in [-1, 1].
static func _lattice(seed_text: String, channel: String, octave: int, ix: int, iz: int) -> float:
	var digest := ("synthesis/%s/%s/%s/%d/%d/%d" % [REVISION,seed_text,channel,octave,ix,iz]).sha256_text()
	return float(digest.substr(0,12).hex_to_int())/281474976710655.0*2.0-1.0

static func noise(seed_text: String, channel: String, x: float, z: float, feature: float, roughness: float, octaves: int = 4) -> float:
	var total := 0.0; var weight := 1.0; var norm := 0.0; var size := feature
	for octave: int in octaves:
		var u := x/size; var v := z/size
		var ix := floori(u); var iz := floori(v)
		var fx := u-ix; var fz := v-iz
		fx = fx*fx*(3.0-2.0*fx); fz = fz*fz*(3.0-2.0*fz)
		var a := lerpf(_lattice(seed_text,channel,octave,ix,iz),_lattice(seed_text,channel,octave,ix+1,iz),fx)
		var b := lerpf(_lattice(seed_text,channel,octave,ix,iz+1),_lattice(seed_text,channel,octave,ix+1,iz+1),fx)
		total += lerpf(a,b,fz)*weight; norm += weight
		weight *= roughness; size *= 0.5
		if weight <= 0.0: break
	return total/norm if norm > 0.0 else 0.0

## The mask for one layer: selection polygon, protections and per-sample verdicts.
## staying: discs {center, radius, id} in piece coordinates; segments: capsules
## {a, b, radius, id} (patrol legs) that must keep the terrain under them.
static func mask(data: Dictionary, request: Dictionary, staying: Array = [], segments: Array = []) -> Dictionary:
	var layer := _find(data.layers,"layer_id",request.target.layer_id)
	if layer.is_empty(): return fail("source_reference_missing",request.target.layer_id,"target")
	if layer.locked: return fail("layer_locked",layer.layer_id,"target")
	var selection := PackedVector2Array()
	if request.selection.has("region_id"):
		var region := _find(data.regions,"region_id",request.selection.region_id)
		if region.is_empty(): return fail("source_reference_missing",request.selection.region_id,"selection")
		if region.layer_id != layer.layer_id: return fail("synthesis_selection_layer",region.region_id,"selection")
		selection = _polygon(region.polygon_xz)
	else: selection = _polygon(request.selection.polygon_xz)
	if not _simple(selection): return fail("synthesis_selection_invalid","","selection")
	var protections: Array = []
	for region: Dictionary in data.regions:
		if region.layer_id != layer.layer_id: continue
		if region.region_id in layer.protected_regions or region.region_id in request.preserve.region_ids:
			if request.selection.get("region_id","") == region.region_id and region.region_id not in layer.protected_regions: continue
			protections.append({"polygon":_polygon(region.polygon_xz),"id":region.region_id})
	var discs: Array = []
	for connector: Dictionary in data.connectors:
		if connector.surface_id == layer.layer_id: discs.append({"center":Vector2(connector.position_xyz[0],connector.position_xyz[2]),"radius":float(connector.width)*0.5,"id":connector.connector_id})
	for item: Dictionary in staying: discs.append(item)
	var spacing := float(layer.sample_spacing)
	var free: Array[bool] = []; var count := 0
	for z: int in int(layer.rows):
		for x: int in int(layer.columns):
			var at := Vector2(layer.origin_xz[0],layer.origin_xz[1])+Vector2(x,z)*spacing
			var influence := _square(at,spacing)
			var ok := _inside(influence,selection)
			if ok:
				for protection: Dictionary in protections:
					if _touches(influence,protection.polygon): ok = false; break
			if ok:
				for disc: Dictionary in discs:
					if _disk_touches(disc.center,float(disc.radius),influence): ok = false; break
			if ok:
				for segment: Dictionary in segments:
					if _segment_touches(segment.a,segment.b,float(segment.radius),influence): ok = false; break
			free.append(ok)
			if ok: count += 1
	return {"ok":true,"layer":layer,"selection":selection,"protections":protections,"discs":discs,"segments":segments,"free":free,"free_count":count}

## Checkpoint45 (P3c): the one mask authority shared with the exchange. The samples
## of a layer whose influence square (half side = spacing) touches one of its
## protected regions: neither a variation nor an imported proposal may change them.
static func protected_samples(data: Dictionary, layer: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var polygons: Array = []
	for region: Dictionary in data.get("regions",[]):
		if region.layer_id == layer.layer_id and region.region_id in layer.protected_regions: polygons.append(_polygon(region.polygon_xz))
	if polygons.is_empty(): return result
	var spacing := float(layer.sample_spacing)
	for z: int in int(layer.rows):
		for x: int in int(layer.columns):
			var square := _square(Vector2(layer.origin_xz[0],layer.origin_xz[1])+Vector2(x,z)*spacing,spacing)
			for polygon: PackedVector2Array in polygons:
				if _touches(square,polygon): result.append(z*int(layer.columns)+x); break
	return result

# A capsule (segment a-b widened by radius) touches the polygon.
static func _segment_touches(a: Vector2, b: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(a,polygon) or Geometry2D.is_point_in_polygon(b,polygon): return true
	for i: int in polygon.size():
		var p := polygon[i]; var q := polygon[(i+1)%polygon.size()]
		if Geometry2D.segment_intersects_segment(a,b,p,q) != null: return true
		var gap := minf(minf(Geometry2D.get_closest_point_to_segment(a,p,q).distance_to(a),Geometry2D.get_closest_point_to_segment(b,p,q).distance_to(b)),minf(Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p),Geometry2D.get_closest_point_to_segment(q,a,b).distance_to(q)))
		if gap < radius: return true
	return false

# Distance from a point to the nearest boundary the change must fade into.
static func _edge_distance(at: Vector2, built: Dictionary) -> float:
	var best := INF
	var selection: PackedVector2Array = built.selection
	for i: int in selection.size(): best = minf(best,Geometry2D.get_closest_point_to_segment(at,selection[i],selection[(i+1)%selection.size()]).distance_to(at))
	for protection: Dictionary in built.protections:
		var polygon: PackedVector2Array = protection.polygon
		for i: int in polygon.size(): best = minf(best,Geometry2D.get_closest_point_to_segment(at,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(at))
	for disc: Dictionary in built.discs: best = minf(best,maxf(0.0,at.distance_to(disc.center)-float(disc.radius)))
	for segment: Dictionary in built.get("segments",[]): best = minf(best,maxf(0.0,Geometry2D.get_closest_point_to_segment(at,segment.a,segment.b).distance_to(at)-float(segment.radius)))
	return best

## Builds the proposal; never mutates the session. extra (from a map, population
## or patrol root): {"discs":[...], "segments":[...]} in piece coordinates for
## encounter bodies and patrol legs that stay on this piece.
static func prepare(source: Dictionary, request: Dictionary, cancellation: Callable = Callable(), extra: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var checked := validate_request(request)
	if not checked.ok: return checked
	var read := Schema.read(JSON.stringify(source,"",true,true).to_utf8_buffer())
	if not read.ok or not read.valid: return fail("source_invalid")
	if read.output_hash != request.base_hash: return fail("base_diverged","","base_hash")
	var data: Dictionary = read.data
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return catalog
	var objects_channel: Dictionary = request.channels.objects
	# Objects that stay: everything except unlocked, unpreserved placements of the
	# target layer whose whole footprint is inside the selection, when scatter
	# replaces. Their footprints protect the terrain under them.
	var probe := mask(data,request)
	if not probe.ok: return probe
	var removed: Array[String] = []; var staying: Array = []
	for placement: Dictionary in data.placements:
		var definition: Dictionary = catalog.definitions.get(placement.definition_id,{})
		var radius := float(definition.get("footprint_radius",0.0))
		var center := Vector2(placement.position_xyz[0],placement.position_xyz[2])
		var on_layer: bool = _layer_of(data,placement.surface_id) == probe.layer.layer_id
		var replaceable: bool = objects_channel.mode == "scatter" and objects_channel.replace and on_layer and placement.placement_id not in request.preserve.entity_ids and not Metadata.locked(data,placement) and _disk_inside(center,radius,probe.selection)
		if replaceable:
			for protection: Dictionary in probe.protections:
				if _disk_touches(center,radius,protection.polygon): replaceable = false; break
		if replaceable: removed.append(placement.placement_id)
		elif on_layer: staying.append({"center":center,"radius":radius,"id":placement.placement_id})
	var built := mask(data,request,staying+extra.get("discs",[]),extra.get("segments",[]))
	if not built.ok: return built
	var layer: Dictionary = built.layer
	var spacing := float(layer.sample_spacing)
	var seed: String = request.seed_text
	var terrain_changed: Array[int] = []; var material_changed: Array[int] = []
	var terrain_channel: Dictionary = request.channels.terrain
	var material_channel: Dictionary = request.channels.materials
	var columns := int(layer.columns)
	var visited := 0
	for index: int in built.free.size():
		if not built.free[index]: continue
		if cancellation.is_valid() and visited % 16 == 0 and cancellation.call(float(index)/built.free.size()*0.5): return fail("cancelled")
		visited += 1
		var at := Vector2(layer.origin_xz[0],layer.origin_xz[1])+Vector2(index % columns,index / columns)*spacing
		var fade := 1.0
		var falloff := float(terrain_channel.get("falloff",spacing*2.0))
		var distance := _edge_distance(at,built)-spacing
		if falloff > 0.0: fade = clampf(distance/falloff,0.0,1.0); fade = fade*fade*(3.0-2.0*fade)
		if terrain_channel.mode == "relief" and fade > 0.0:
			var delta := float(terrain_channel.amplitude)*noise(seed,"terrain",at.x,at.y,float(terrain_channel.feature_size),float(terrain_channel.roughness))*fade
			var next := float(layer.heights[index])+delta
			if not is_finite(next): return fail("source_non_finite")
			if next != float(layer.heights[index]): layer.heights[index] = next; terrain_changed.append(index)
		if material_channel.mode == "patches":
			var value := 0.5+0.5*noise(seed,"materials",at.x,at.y,float(material_channel.feature_size),0.5)
			var threshold := 1.0-float(material_channel.coverage)
			var alpha := clampf((value-threshold)/0.1,0.0,1.0)*clampf(fade if falloff > 0.0 else 1.0,0.0,1.0)
			if alpha > 0.0 and _paint(layer,index,String(material_channel.material),alpha): material_changed.append(index)
	var added: Array[String] = []
	if objects_channel.mode == "scatter":
		data.placements = data.placements.filter(func(p: Dictionary) -> bool: return p.placement_id not in removed)
		if data.has("objects"): data.objects.states = data.objects.states.filter(func(s: Dictionary) -> bool: return s.placement_id not in removed)
		var scattered := _scatter(data,request,built,catalog,cancellation)
		if not scattered.ok: return scattered
		added = scattered.added
	else: removed.clear()
	if terrain_changed.is_empty() and material_changed.is_empty() and added.is_empty() and removed.is_empty(): return fail("synthesis_empty")
	if cancellation.is_valid() and cancellation.call(0.9): return fail("cancelled")
	var proposal := Objects._proposal(source,data)
	if not proposal.ok: return proposal
	var compiled := Terrain.compile(proposal.data)
	if not compiled.ok: return compiled
	var polygon_points: Array = []
	for point: Vector2 in built.selection: polygon_points.append([point.x,point.y])
	return {"ok":true,"code":"","algorithm_revision":REVISION,"base_hash":request.base_hash,"request_hash":request_hash(request),"source":proposal.data,"source_hash":proposal.output_hash,"compiled_hash":compiled.output_hash,"package":compiled.package,
		"diff":{"layer_id":layer.layer_id,"selection_hash":Schema.semantic_hash({"polygon_xz":polygon_points}),"terrain_samples":terrain_changed,"material_samples":material_changed,"objects_added":added,"objects_removed":removed},
		"diagnostics":[],"metrics":{"free_samples":built.free_count,"samples":built.free.size(),"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0}}

## Commits the proposal as one undoable change, after the base check.
static func apply(proposal: Dictionary, session: RefCounted, expected_hash: String) -> Dictionary:
	if not proposal.get("ok",false) or session == null or session.document() == null: return fail("synthesis_stale_proposal")
	var current: String = session.document().semantic_hash()
	if current != expected_hash or current != proposal.base_hash: return fail("base_diverged")
	var applied: Dictionary = session.apply(proposal.source)
	if not applied.ok: return applied
	applied["proposal_hash"] = proposal.source_hash
	return applied

# Same blend as Brush "material": weights move toward the material by alpha.
static func _paint(layer: Dictionary, index: int, material: String, alpha: float) -> bool:
	var previous: Array[float] = Materials.weights(layer,index)
	var selected := Materials.IDS.find(material)
	var next := previous.duplicate()
	for k: int in next.size(): next[k] = previous[k]*(1.0-alpha)+(alpha if k == selected else 0.0)
	if previous == next: return false
	for k: int in next.size():
		var id: String = Materials.IDS[k]
		var implicit := 1.0 if id == "grass" else 0.0
		if not layer.material_masks.has(id) and next[k] != implicit:
			var values: Array = []; values.resize(layer.heights.size()); values.fill(implicit)
			layer.material_masks[id] = values
		if layer.material_masks.has(id): layer.material_masks[id][index] = next[k]
	return true

# Seeded candidates inside the selection's bounds; a footprint must be fully inside
# the selection, clear of every protection and of every other footprint.
static func _scatter(data: Dictionary, request: Dictionary, built: Dictionary, catalog: Dictionary, cancellation: Callable) -> Dictionary:
	var channel: Dictionary = request.channels.objects
	var count := int(channel.count)
	if count == 0: return {"ok":true,"added":[] as Array[String]}
	var resolved := Catalog.definition(channel.definition_id,catalog)
	if not resolved.ok: return resolved
	var definition: Dictionary = resolved.definition
	if data.placements.size()+count > Compiler.MAX_OBJECTS: return fail("object_limit")
	var base := data.duplicate(true); base.placements = []; base.dependencies = []; base.erase("objects")
	var terrain := Terrain.compile(base)
	if not terrain.ok: return terrain
	var world := WorldGeometry.new(); world.configure(Terrain.preview_manifest(terrain.package),"terrain_preview")
	var selection: PackedVector2Array = built.selection
	var bounds := Rect2(selection[0],Vector2.ZERO)
	for point: Vector2 in selection: bounds = bounds.expand(point)
	var radius := float(definition.footprint_radius); var spacing := float(channel.spacing)
	var added: Array[String] = []; var attempts := 0; var budget := mini(65536,count*128)
	var seed: String = request.seed_text
	while added.size() < count and attempts < budget:
		var index := attempts; attempts += 1
		if cancellation.is_valid() and index % 32 == 0 and cancellation.call(0.5+0.4*float(added.size())/count): return fail("cancelled")
		var p := bounds.position+Vector2(Objects.random_unit("regional/"+seed,index,"x")*bounds.size.x,Objects.random_unit("regional/"+seed,index,"z")*bounds.size.y)
		if not _disk_inside(p,radius,selection): continue
		var blocked := false
		for protection: Dictionary in built.protections:
			if _disk_touches(p,radius,protection.polygon): blocked = true; break
		if blocked: continue
		for disc: Dictionary in built.discs:
			if p.distance_to(disc.center) < radius+float(disc.radius)+spacing: blocked = true; break
		if blocked: continue
		for segment: Dictionary in built.segments:
			if Geometry2D.get_closest_point_to_segment(p,segment.a,segment.b).distance_to(p) < radius+float(segment.radius)+spacing: blocked = true; break
		if blocked: continue
		for other: Dictionary in data.placements:
			if _layer_of(data,other.surface_id) != built.layer.layer_id: continue
			var other_radius := float(catalog.definitions.get(other.definition_id,{}).get("footprint_radius",0.0))
			if p.distance_to(Vector2(other.position_xyz[0],other.position_xyz[2])) < radius+other_radius+spacing: blocked = true; break
		if blocked: continue
		var rotations: Array = definition.allowed_rotations
		var rotation: float = float(rotations[int(Objects.random_unit("regional/"+seed,index,"rotation")*rotations.size()) % rotations.size()])
		var placement := {"placement_id":"object_"+("regional/%s/%s/%d" % [request_hash(request),seed,index]).sha256_text().substr(0,24),"definition_id":definition.definition_id,"revision":int(definition.revision),"position_xyz":[p.x,0,p.y],"rotation_y":rotation,"surface_id":built.layer.layer_id}
		if not Objects._settle(placement,definition,terrain.package,world,0).ok: continue
		if Compiler.protection(data,placement.surface_id,Vector3(p.x,placement.position_xyz[1],p.y),radius) != "": continue
		data.placements.append(placement); added.append(placement.placement_id)
	if added.size() != count:
		var failure := fail("object_scatter_deficit")
		failure["requested"] = count; failure["realized"] = added.size(); failure["attempts"] = attempts
		return failure
	Objects._dependency(data,definition)
	return {"ok":true,"added":added}

# Background preparation for the GUI: the very same prepare() on copies, in a
# thread, with progress and cancellation. AX and CLI call prepare() directly.
var _thread: Thread
var _mutex := Mutex.new()
var _progress := 0.0
var _stop := false
var _done := false
var _result: Dictionary = {}

func start(source: Dictionary, request: Dictionary) -> void:
	var data := source.duplicate(true); var copy := request.duplicate(true)
	_thread = Thread.new()
	_thread.start(func() -> void:
		var outcome := prepare(data,copy,_tick)
		_mutex.lock(); _result = outcome; _done = true; _mutex.unlock())

func _tick(value: float) -> bool:
	_mutex.lock(); _progress = value; var stop := _stop; _mutex.unlock()
	return stop

func progress() -> float:
	_mutex.lock(); var value := _progress; _mutex.unlock()
	return value

func ready() -> bool:
	_mutex.lock(); var value := _done; _mutex.unlock()
	return value

func cancel() -> void:
	_mutex.lock(); _stop = true; _mutex.unlock()

func take() -> Dictionary:
	if _thread != null: _thread.wait_to_finish(); _thread = null
	_mutex.lock(); var value := _result; _mutex.unlock()
	return value

func close() -> void:
	cancel()
	if _thread != null: _thread.wait_to_finish(); _thread = null

static func _layer_of(data: Dictionary, surface_id: String) -> String:
	for special: Dictionary in data.special_surfaces:
		if special.surface_id == surface_id: return special.layer_id
	return surface_id

static func _find(values: Array, key: String, value: Variant) -> Dictionary:
	for item: Dictionary in values:
		if item.get(key) == value: return item
	return {}
