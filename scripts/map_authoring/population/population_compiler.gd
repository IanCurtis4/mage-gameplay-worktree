@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Worker = preload("res://scripts/map_authoring/population/population_worker.gd")
const REVISION := "map_population_v1"
const PROFILE := {"profile_id":"ruins_player","revision":1,"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
const STEP := 16.0
var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false
func start(source: Dictionary, operation: String = "compile") -> void:
	var copy := source.duplicate(true)
	_thread = Thread.new(); _thread.start(func() -> Dictionary:
		var cancellation := func() -> bool:
			_mutex.lock(); var cancelled := _cancelled; _mutex.unlock(); return cancelled
		return regenerate(copy,cancellation) if operation == "regenerate" else compile(copy,cancellation))
func ready() -> bool: return _thread != null and not _thread.is_alive()
func cancel() -> void:
	_mutex.lock(); _cancelled = true; _mutex.unlock()
func take(current_hash: String) -> Dictionary:
	var result: Dictionary = _thread.wait_to_finish(); _thread = null
	if _cancelled: return fail("cancelled")
	if result.ok and result.get("input_hash",result.get("base_hash","")) != current_hash: return fail("stale_source")
	return result
func close() -> void:
	if _thread != null: cancel(); _thread.wait_to_finish(); _thread = null
static func fail(code: String, id: String = "", counts: Dictionary = {}, location: Vector3 = Vector3.ZERO) -> Dictionary:
	var messages := {"population_empty":"Importe uma composição e marque a entrada.","entrance_invalid":"A entrada não tem suporte ou folga para o jogador.","species_invalid":"Espécie, categoria ou origem não permitida no catálogo.","policy_unresolved":"A origem não tem política de recompensa publicada.","population_unreachable":"O corpo real não cabe aqui ou não alcança a entrada e o retorno.","population_excluded":"O slot invade uma exclusão, entrada, abertura ou interação.","population_overlap":"Dois corpos não respeitam o espaçamento solicitado.","population_deficit":"Não há espaço para a quota solicitada.","fixed_excess":"Há mais slots fixados que a quota; ajuste explicitamente.","plan_stale":"Prepare e aplique uma nova prévia após alterar a receita.","slot_invalid":"O slot não pertence à receita ou está fora da região.","thematic_site_required":"Memoráveis exigem um palco temático explícito e acessível.","interaction_invalid":"Interação sem destino válido, suporte ou rota de ida e volta.","population_limit":"O encontro excede o orçamento técnico.","cancelled":"Operação cancelada.","stale_source":"A fonte mudou; compile novamente."}
	var message: String = messages.get(code,"Revise os dados do encontro: "+code)
	if not counts.is_empty(): message += " Solicitados: %d; realizados: %d; déficit: %d."%[counts.requested,counts.realized,maxi(0,counts.requested-counts.realized)]
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":id,"field":"population","surface_id":"","location":location,"severity":"error","message":message,"counts":counts,"suggestion":"Selecione o marcador e ajuste a fonte."}]}
static func vector(xyz: Array) -> Vector3: return Vector3(xyz[0],xyz[1],xyz[2])
static func anchor(data: Dictionary) -> ExpeditionWorldPoint: return Point.create("map_preview",data.surface_id,vector(data.position_xyz))
static func xyz(point: Vector3) -> Array: return [point.x,point.y,point.z]
static func distance_xz(a: Vector3, b: Vector3) -> float: return Vector2(a.x-b.x,a.z-b.z).length()
static func same_layer(context: Dictionary, a: String, b: String) -> bool:
	return context.get("families",{}).get(a,a) == context.get("families",{}).get(b,b)
static func _sorted(items: Array, field: String) -> Array:
	var result := items.duplicate(true); result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a[field] < b[field]); return result
static func _spec(spec: Dictionary, catalog: MobCatalog) -> Dictionary:
	var occurrence := MobOccurrence.new(); occurrence.occurrence_id = "editor_validation"; occurrence.mob_base_id = StringName(spec.species_id); occurrence.category_id = StringName(spec.category); occurrence.origin_id = StringName(spec.origin_id)
	var checked := occurrence.validate(catalog)
	if not checked.ok or spec.species_id == "animal_companion": return fail("species_invalid")
	if checked.definition.visual_kind == &"companion": return fail("species_invalid")
	var rule := Catalog.rule(spec)
	if rule.is_empty(): return fail("policy_unresolved")
	var profile := PROFILE.duplicate(true); profile.radius = maxf(PROFILE.radius,checked.definition.collision_radius)
	return {"ok":true,"profile":profile,"rule":rule}
static func _path(world: WorldGeometry, entry: ExpeditionWorldPoint, destination: ExpeditionWorldPoint, profile: Dictionary) -> bool:
	return world.position_query(destination,profile,world.geometry_revision).ok and world.path(entry,destination,profile,world.geometry_revision).ok and world.path(destination,entry,profile,world.geometry_revision).ok
static func prepare(source: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	var checked := Document.validate(source)
	if not checked.ok: return checked
	if source.map.is_empty() or source.entrance.is_empty(): return fail("population_empty")
	if cancel.is_valid() and cancel.call(): return fail("cancelled")
	var built := MapCompiler.compile(source.map[0],func(_p: float) -> bool: return cancel.is_valid() and cancel.call())
	if not built.ok: return built
	var loaded := Catalog.load_current()
	if not loaded.ok: return loaded
	var manifest := MapCompiler.manifest(built.package); var stage: Dictionary = manifest._data.stages[0]
	manifest._data.input["traversal"] = PROFILE.duplicate(true); manifest._data.traversal = PROFILE.duplicate(true); manifest._data.input["entry_stage_id"] = "map_preview"
	stage.entrance = "authored_entry"; stage.sockets.append({"socket_id":"authored_entry","kind":"entrance","tags":[],"surface_id":source.entrance[0].surface_id,"position":vector(source.entrance[0].position_xyz)})
	var world := WorldGeometry.new(); var configured := world.configure(manifest,"map_preview")
	if not configured.ok: return fail("entrance_invalid")
	var entry := anchor(source.entrance[0])
	if not world.position_query(entry,PROFILE,world.geometry_revision).ok: return fail("entrance_invalid")
	var ids: Dictionary = {}; var completion_count := 0
	for interaction: Dictionary in source.interactions:
		ids[interaction.interaction_id] = interaction
		if interaction.kind == "phase_completion":
			completion_count += 1
			# The existing service requires every other required objective before
			# completion. Two terminal required exits cannot satisfy one another.
			if completion_count > 1:
				var invalid := fail("interaction_invalid",interaction.interaction_id)
				invalid.diagnostics[0].message = "Este protótipo admite uma saída de conclusão por mapa. Mantenha as demais como saídas antecipadas ou rascunho."
				return invalid
	for interaction: Dictionary in _sorted(source.interactions,"interaction_id"):
		if not _path(world,entry,anchor(interaction),PROFILE): return fail("interaction_invalid",interaction.interaction_id,{},vector(interaction.position_xyz))
		var socket_id: String = "interaction_"+interaction.interaction_id
		stage.sockets.append({"socket_id":socket_id,"kind":"portal" if interaction.kind == "portal" else ("thematic_encounter" if interaction.kind == "thematic_encounter" else "exit"),"tags":[],"surface_id":interaction.surface_id,"position":vector(interaction.position_xyz)})
		if interaction.kind == "portal":
			if not ids.has(interaction.target_id) or interaction.target_id == interaction.interaction_id or ids[interaction.target_id].kind != "portal": return fail("interaction_invalid",interaction.interaction_id)
			manifest._data.portals.append({"portal_id":interaction.interaction_id,"kind":"local","from_stage":"map_preview","to_stage":"map_preview","from_socket":socket_id,"to_socket":"interaction_"+interaction.target_id,"from_anchor":anchor(interaction).to_data(),"to_anchor":anchor(ids[interaction.target_id]).to_data()})
		elif interaction.kind != "thematic_encounter":
			if interaction.target_id != "": return fail("interaction_invalid",interaction.interaction_id)
			manifest._data.objectives.append({"objective_id":interaction.interaction_id,"revision":1,"stage_id":"map_preview","instance_id":"authored","socket_id":socket_id,"required_tags":[],"outcome":interaction.kind,"required":interaction.kind == "phase_completion","point":anchor(interaction).to_data()})
		manifest._data.witnesses["interaction/"+interaction.interaction_id] = {"point":anchor(interaction).to_data()}
	# Reconfigure after adding sockets, keeping the same authoritative geometry.
	world.configure(manifest,"map_preview")
	var families: Dictionary = {}; var family_cells: Dictionary = {}
	for instance: Dictionary in built.package.render_instances:
		for visual: Dictionary in instance.visuals:
			families[instance.instance_id+"/"+visual.surface_id] = instance.instance_id+("/special/" if visual.special else "/layer/")+visual.source_id
	for cell: Dictionary in _sorted(stage.surfaces,"surface_id"):
		var family: String = families.get(cell.surface_id,cell.surface_id)
		if not family_cells.has(family): family_cells[family] = []
		family_cells[family].append(cell)
	var protected_areas: Array = []
	for instance: Dictionary in built.package.realized_instances:
		var piece := MapCompiler._find(source.map[0].pieces,"piece_hash",instance.piece_hash)
		for region: Dictionary in piece.source.regions:
			if region.purpose not in ["path","route","population_exclusion"]: continue
			var layer := MapCompiler._find(piece.source.layers,"layer_id",region.layer_id)
			if layer.is_empty() or region.region_id not in layer.protected_regions: continue
			var polygon := PackedVector2Array()
			for pair: Array in region.polygon_xz:
				var transformed := Kernel.rotate(Vector3(pair[0],0,pair[1]),int(instance.rotation_quarters))+vector(instance.position_xyz)
				polygon.append(Vector2(transformed.x,transformed.z))
			protected_areas.append({"family":instance.instance_id+"/layer/"+region.layer_id,"polygon":polygon})
	return {"ok":true,"world":world,"entry":entry,"manifest":manifest,"map_package":built.package,"catalog":loaded.catalog,"catalog_hash":loaded.hash,"policy_hash":loaded.policy_hash,"families":families,"family_cells":family_cells,"protected_areas":protected_areas}
static func excluded(source: Dictionary, point: ExpeditionWorldPoint, radius: float, site: String = "", context: Dictionary = {}) -> bool:
	var entry := anchor(source.entrance[0])
	if absf(point.position.y-entry.position.y) < PROFILE.height and distance_xz(point.position,entry.position) < radius+PROFILE.radius+16: return true
	for region: Dictionary in source.exclusions:
		if same_layer(context,region.surface_id,point.surface_id) and distance_xz(point.position,vector(region.center_xyz)) < region.radius+radius: return true
	for interaction: Dictionary in source.interactions:
		if interaction.kind == "thematic_encounter" and interaction.interaction_id == site: continue
		if same_layer(context,interaction.surface_id,point.surface_id) and distance_xz(point.position,vector(interaction.position_xyz)) < radius+PROFILE.radius+8: return true
	return false
static func _legal(source: Dictionary, context: Dictionary, point: ExpeditionWorldPoint, profile: Dictionary, site: String = "") -> bool:
	return placement_code(source,context,point,profile,site) == ""
static func placement_code(source: Dictionary, context: Dictionary, point: ExpeditionWorldPoint, profile: Dictionary, site: String = "") -> String:
	if excluded(source,point,profile.radius,site,context): return "population_excluded"
	for area: Dictionary in context.protected_areas:
		if context.families.get(point.surface_id,point.surface_id) != area.family: continue
		var at := Vector2(point.position.x,point.position.z); var polygon: PackedVector2Array = area.polygon
		if Geometry2D.is_point_in_polygon(at,polygon): return "population_excluded"
		for i: int in polygon.size():
			if Geometry2D.get_closest_point_to_segment(at,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(at) < profile.radius: return "population_excluded"
	for endpoint: Dictionary in context.world._stage.connectors:
		if "/port_" not in endpoint.connector_id: continue
		if same_layer(context,endpoint.surface_id,point.surface_id) and point.position.distance_to(endpoint.position) < endpoint.width*0.5+profile.radius: return "population_excluded"
	return "" if _path(context.world,context.entry,point,profile) else "population_unreachable"
static func _separated(point: ExpeditionWorldPoint, radius: float, spacing: float, accepted: Array) -> bool:
	for other: Dictionary in accepted:
		# Separate floors may overlap horizontally; check occupied vertical intervals.
		if point.position.y+PROFILE.height <= other.point.position.y or other.point.position.y+PROFILE.height <= point.position.y: continue
		if Vector2(point.position.x,point.position.z).distance_to(Vector2(other.point.position.x,other.point.position.z)) < radius+other.radius+maxf(spacing,other.spacing): return false
	return true
static func pool(source: Dictionary, context: Dictionary, brush: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	var profile := PROFILE.duplicate(true)
	for spec: Dictionary in brush.species:
		var checked := _spec(spec,context.catalog)
		if not checked.ok: return checked
		profile.radius = maxf(profile.radius,checked.profile.radius)
	var family: String = context.families.get(brush.surface_id,brush.surface_id)
	var cells: Array = context.family_cells.get(family,[])
	if cells.is_empty(): return fail("population_unreachable",brush.brush_id)
	var center := vector(brush.center_xyz)
	var candidates: Array = []; var count := 0; var rejected := {"population_excluded":0,"population_unreachable":0,"outside_support":0}
	var first_x := int(floor((center.x-brush.radius)/STEP)); var last_x := int(ceil((center.x+brush.radius)/STEP))
	var first_z := int(floor((center.z-brush.radius)/STEP)); var last_z := int(ceil((center.z+brush.radius)/STEP))
	for iz: int in range(first_z,last_z):
		for ix: int in range(first_x,last_x):
			if cancel.is_valid() and cancel.call(): return fail("cancelled")
			var x := (ix+0.5)*STEP; var z := (iz+0.5)*STEP
			if Vector2(x-center.x,z-center.z).length() > brush.radius: continue
			var contained := false
			for cell: Dictionary in cells:
				var normal := Kernel.plane_normal(cell.vertices)
				if absf(normal.y) < 0.001: continue
				var position := Kernel.support_y(cell,Vector3(x,0,z))
				if not Kernel.contains(cell,position): continue
				contained = true
				var point := Point.create("map_preview",cell.surface_id,position)
				var code := placement_code(source,context,point,profile)
				if code != "": rejected[code] += 1; continue
				count += 1; candidates.append(point); break
			if not contained: rejected.outside_support += 1
	var quota := int(brush.quantity) if brush.quota_mode == "count" else int(floor(count*STEP*STEP*brush.density/10000.0))
	if quota > 128: return fail("population_limit",brush.brush_id)
	return {"ok":true,"candidates":candidates,"quota":quota,"sampled_area":count*STEP*STEP,"profile":profile,"rejected":rejected}
static func regenerate(source: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if Engine.is_editor_hint(): return Worker.request({"operation":"regenerate","source":source},cancel)
	var context := prepare(source,cancel)
	if not context.ok: return context
	var realized: Array = []; var occupied: Array = []; var metrics: Array = []
	# All pins reserve space before any brush draws candidates.
	for slot: Dictionary in _sorted(source.slots,"slot_id"):
		if not slot.fixed: continue
		var valid := validate_slot(source,context,slot,occupied)
		if not valid.ok: return valid
		realized.append(slot.duplicate(true)); occupied.append(valid.reservation)
	for brush: Dictionary in _sorted(source.brushes,"brush_id"):
		var sampled := pool(source,context,brush,cancel)
		if not sampled.ok: return sampled
		var fixed := 0
		for slot: Dictionary in realized:
			if slot.brush_id == brush.brush_id: fixed += 1
		if fixed > sampled.quota: return fail("fixed_excess",brush.brush_id,{"requested":sampled.quota,"realized":fixed})
		var candidates: Array = sampled.candidates; var stream: String = brush.seed+":"+str(int(brush.round))+":"+brush.brush_id
		candidates.sort_custom(func(a: ExpeditionWorldPoint,b: ExpeditionWorldPoint) -> bool: return (stream+Canonical.encode(a.position)).sha256_text() < (stream+Canonical.encode(b.position)).sha256_text())
		var cluster := vector(brush.center_xyz)
		if brush.mode == "concentrated" and not candidates.is_empty(): cluster = candidates[0].position
		var species: Array = brush.species.duplicate(true); species.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return Schema.semantic_hash(a) < Schema.semantic_hash(b))
		var total_weight := 0
		for spec: Dictionary in species: total_weight += int(spec.weight)
		var made := fixed
		var spacing_rejections := 0; var group_rejections := 0
		for point: ExpeditionWorldPoint in candidates:
			if made == sampled.quota: break
			if brush.mode == "concentrated" and distance_xz(point.position,cluster) > brush.group_radius: group_rejections += 1; continue
			var draw: int = (stream+":species:"+str(made)).sha256_text().substr(0,7).hex_to_int()%total_weight
			var chosen: Dictionary = species[0]
			for spec: Dictionary in species:
				draw -= int(spec.weight)
				if draw < 0: chosen = spec; break
			# Memorable occurrences are authored as fixed slots at an explicit site.
			if chosen.category not in ["normal","elite"]: return fail("thematic_site_required",brush.brush_id)
			var valid := _spec(chosen,context.catalog)
			if not _separated(point,valid.profile.radius,brush.spacing,occupied): spacing_rejections += 1; continue
			var slot := {"slot_id":"slot_"+(stream+":"+Canonical.encode(point.position)).sha256_text().substr(0,40),"brush_id":brush.brush_id,"surface_id":point.surface_id,"position_xyz":xyz(point.position),"species_id":chosen.species_id,"category":chosen.category,"origin_id":chosen.origin_id,"fixed":false,"site_id":""}
			realized.append(slot); occupied.append({"point":point,"radius":valid.profile.radius,"spacing":brush.spacing}); made += 1
		if made < sampled.quota:
			var failure := fail("population_deficit",brush.brush_id,{"requested":sampled.quota,"realized":made},vector(brush.center_xyz))
			var causes: Dictionary = sampled.rejected.duplicate(true); causes["spacing"] = spacing_rejections; causes["group_radius"] = group_rejections
			failure.diagnostics[0]["causes"] = causes
			failure.diagnostics[0].message += " Tentativas recusadas: áreas reservadas %d; corpo/rota %d; sem suporte %d; espaçamento %d; fora do grupo %d."%[causes.population_excluded,causes.population_unreachable,causes.outside_support,causes.spacing,causes.group_radius]
			return failure
		metrics.append({"brush_id":brush.brush_id,"quantity":made,"sampled_area":sampled.sampled_area})
	if realized.size() > 128: return fail("population_limit")
	var proposed := source.duplicate(true); proposed.slots = _sorted(realized,"slot_id"); proposed.plan_hash = Document.recipe_hash(source)
	var previous: Dictionary = {}; var next: Dictionary = {}
	for slot: Dictionary in source.slots: previous[slot.slot_id] = slot
	for slot: Dictionary in realized: next[slot.slot_id] = slot
	var diff := {"added":[],"removed":[],"changed":[],"preserved":[]}
	for id: String in next:
		if not previous.has(id): diff.added.append(id)
		elif Schema.semantic_hash(previous[id]) == Schema.semantic_hash(next[id]): diff.preserved.append(id)
		else: diff.changed.append(id)
	for id: String in previous:
		if not next.has(id): diff.removed.append(id)
	for field: String in diff: diff[field].sort()
	return {"ok":true,"code":"","data":proposed,"base_hash":Document.hash_source(source),"diff":diff,"metrics":metrics}
static func validate_slot(source: Dictionary, context: Dictionary, slot: Dictionary, occupied: Array) -> Dictionary:
	var spec := _spec(slot,context.catalog)
	if not spec.ok: return spec
	var brush := MapCompiler._find(source.brushes,"brush_id",slot.brush_id)
	if brush.is_empty(): return fail("slot_invalid",slot.slot_id)
	var point := anchor(slot)
	if not slot.fixed and (not same_layer(context,slot.surface_id,brush.surface_id) or distance_xz(point.position,vector(brush.center_xyz)) > brush.radius+0.001): return fail("slot_invalid",slot.slot_id)
	if not slot.fixed:
		var matches := false
		for choice: Dictionary in brush.species:
			if choice.species_id == slot.species_id and choice.category == slot.category and choice.origin_id == slot.origin_id: matches = true
		if not matches: return fail("slot_invalid",slot.slot_id)
	if slot.category not in ["normal","elite"]:
		var site := MapCompiler._find(source.interactions,"interaction_id",slot.site_id)
		if not slot.fixed or site.is_empty() or site.kind != "thematic_encounter" or site.surface_id != slot.surface_id or vector(site.position_xyz).distance_to(point.position) > 0.001: return fail("thematic_site_required",slot.slot_id)
	var code := placement_code(source,context,point,spec.profile,slot.site_id)
	if code != "": return fail(code,slot.slot_id,{},point.position)
	if not _separated(point,spec.profile.radius,brush.spacing,occupied): return fail("population_overlap",slot.slot_id,{},point.position)
	return {"ok":true,"reservation":{"point":point,"radius":spec.profile.radius,"spacing":brush.spacing},"rule":spec.rule}
static func compile(source: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if Engine.is_editor_hint(): return Worker.request({"operation":"compile","source":source},cancel)
	var context := prepare(source,cancel)
	if not context.ok: return context
	if source.plan_hash != Document.recipe_hash(source): return fail("plan_stale")
	var occupied: Array = []; var rules: Dictionary = {}; var counts: Dictionary = {}
	var manifest: ExpeditionManifest = context.manifest
	for slot: Dictionary in _sorted(source.slots,"slot_id"):
		if cancel.is_valid() and cancel.call(): return fail("cancelled")
		var checked := validate_slot(source,context,slot,occupied)
		if not checked.ok: return checked
		occupied.append(checked.reservation); counts[slot.brush_id] = counts.get(slot.brush_id,0)+1
		var point := anchor(slot); var socket_id: String = "population_"+slot.slot_id
		manifest._data.stages[0].sockets.append({"socket_id":socket_id,"surface_id":point.surface_id,"position":point.position,"kind":"population","tags":[]})
		manifest._data.population.slots.append({"slot_id":slot.slot_id,"stage_id":"map_preview","species_id":slot.species_id,"occurrence_category":slot.category,"origin_id":slot.origin_id,"instance_id":point.surface_id.get_slice("/",0),"socket_id":socket_id,"required_tags":[],"respawn_policy_id":"ruins_respawn","reward_policy_id":"ruins_rewards","blocks_clear":true,"home":point.to_data()})
		manifest._data.witnesses["population/"+slot.slot_id] = {"point":point.to_data()}; rules[slot.slot_id] = checked.rule
	for brush: Dictionary in _sorted(source.brushes,"brush_id"):
		var sampled := pool(source,context,brush,cancel)
		if not sampled.ok: return sampled
		if counts.get(brush.brush_id,0) != sampled.quota: return fail("population_deficit",brush.brush_id,{"requested":sampled.quota,"realized":counts.get(brush.brush_id,0)})
	var planned := ExpeditionPopulationPlanner.build(manifest,context.catalog,rules)
	if not planned.ok: return fail("population_unreachable")
	var package := {"format_version":1,"compiler_revision":REVISION,"source_hash":Document.hash_source(source),"catalog_hash":context.catalog_hash,"policy_hash":context.policy_hash,"map_package":context.map_package,"manifest":manifest.to_data(),"rules":rules,"profile":PROFILE.duplicate(true)}
	package["package_hash"] = Canonical.digest(package)
	if var_to_bytes(package).size() > 4*1024*1024: return fail("population_limit")
	return {"ok":true,"code":"","diagnostics":[],"input_hash":package.source_hash,"output_hash":package.package_hash,"package":package}
static func validate_package(package: Dictionary) -> bool:
	if not package.has_all(["format_version","compiler_revision","source_hash","catalog_hash","policy_hash","map_package","manifest","rules","profile","package_hash"]) or not Canonical.valid(package): return false
	if not package.map_package is Dictionary or not package.manifest is Dictionary or not package.rules is Dictionary or not package.profile is Dictionary: return false
	if not package.manifest.has_all(["input","stages","traversal","population","objectives","portals","witnesses"]): return false
	if not package.manifest.input is Dictionary or not package.manifest.stages is Array or package.manifest.stages.size() != 1 or not package.manifest.population is Dictionary or not package.manifest.population.get("slots") is Array: return false
	if not package.manifest.objectives is Array or not package.manifest.portals is Array or not package.manifest.witnesses is Dictionary: return false
	if package.profile != PROFILE or package.manifest.population.slots.size() > 128: return false
	for field: String in ["source_hash","catalog_hash","policy_hash","package_hash"]:
		if not Schema._type(package[field],"hash"): return false
	if package.format_version != 1 or package.compiler_revision != REVISION or not MapCompiler.validate_package(package.map_package): return false
	var copy := package.duplicate(true); copy.erase("package_hash")
	if Canonical.digest(copy) != package.package_hash: return false
	if Engine.is_editor_hint(): return _package_worker("validate",package).ok
	var loaded := Catalog.load_current()
	return loaded.ok and loaded.hash == package.catalog_hash and loaded.policy_hash == package.policy_hash
static func _package_worker(operation: String, package: Dictionary) -> Dictionary:
	var root := ProjectSettings.globalize_path("res://.godot/map_authoring/jobs")
	DirAccess.make_dir_recursive_absolute(root)
	var path := root.path_join(Crypto.new().generate_random_bytes(12).hex_encode()+".bin")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return Worker.failure("worker_io")
	file.store_buffer(var_to_bytes(package)); file.close()
	return Worker.request({"operation":operation,"package_path":path})
static func make_campaign(package: Dictionary) -> Dictionary:
	if Engine.is_editor_hint():
		var result := _package_worker("campaign",package)
		if not result.ok: return result
		var state := ExpeditionCampaignState.new()
		for field: String in result.state_data: state.set(field,result.state_data[field])
		state.clock.interval = result.clock_interval
		return {"ok":state.valid(),"state":state}
	var loaded := Catalog.load_current()
	if not loaded.ok: return loaded
	var parsed := manifest(package)
	if parsed == null: return fail("population_unreachable")
	return ExpeditionCampaignState.create("editor_population_test","discardable_character",parsed,loaded.catalog,package.rules)
static func manifest(package: Dictionary) -> ExpeditionManifest:
	if not validate_package(package): return null
	var result := ExpeditionManifest.new(); result._data = package.manifest.duplicate(true); return result
