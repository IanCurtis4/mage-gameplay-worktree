extends SceneTree
## F10 H6 (contracts/f10_height_grid.md): a ~10 240 u synthetic field end to
## end, with the budget measured: compile the piece and the map (certified per
## walkable component), route across it (synchronous and in the background),
## draw it, populate it with 40-70 monsters and save/restore a session on it.
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const PackageView = preload("res://scripts/world/map_package_view.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
## Measured budget (Windows, the delivery machine), with headroom; a step over
## its budget fails the stage.
const BUDGET_MS := {"piece":10000.0,"map":60000.0,"route_cold":10000.0,"view":15000.0,"population":90000.0,"campaign":15000.0,"snapshot":10000.0}
var checks: Array[Dictionary] = []
var timing: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_FIELD_CHECK "+id+" "+str(ok))
func frames(count: int = 2) -> void:
	for i: int in count: await process_frame
## F10 H6: a deterministic ~10 240 u field (161 x 161 samples at 64 u, origin
## centred): rolling relief, a mesa with cliffs and one ramp, a ridge wall with
## two passes, a smooth basin and scattered rock spikes.
const FIELD_SAMPLES := 161
const FIELD_ORIGIN := -5120.0
static func ridge_x(gz: int) -> int: return int(round(48.0+6.0*sin(float(gz)*0.08)))
static func in_ramp(gx: int, gz: int) -> bool: return absi(gx-115) <= 3 and gz >= 44 and gz <= 70
static func field_height(gx: int, gz: int) -> float:
	var x := float(gx)/160.0; var z := float(gz)/160.0
	var h := 60.0*sin(x*7.1+0.6)*cos(z*5.3-0.4)+35.0*sin(x*13.7+z*9.1)+14.0*cos(x*23.0-z*17.0)
	var dx := (x-0.25)/0.12; var dz := (z-0.75)/0.12
	h -= 50.0*maxf(0.0,1.0-(dx*dx+dz*dz))
	var mx := (x-0.72)/0.12; var mz := (z-0.24)/0.09
	var d := sqrt(mx*mx+mz*mz)
	if d <= 1.0: h += 170.0
	elif in_ramp(gx,gz) and z > 0.24: h += 170.0*clampf(1.0-(d-1.0)/0.55,0.0,1.0)
	var rx := ridge_x(gz)
	if gz >= 24 and gz <= 136 and gx == rx and not (gz >= 52 and gz <= 58) and not (gz >= 104 and gz <= 110): h += 150.0
	if _spike(gx,gz): h += 100.0
	return snappedf(h,0.25)
static func _spike(gx: int, gz: int) -> bool:
	if gx < 4 or gz < 4 or gx > 156 or gz > 156 or in_ramp(gx,gz) or absi(gx-ridge_x(gz)) <= 4: return false
	var key := (gx*73856093) ^ (gz*19349663)
	return posmod(key,997) < 3
static func field_source(id: String) -> Dictionary:
	var source := Piece.empty(id,"Campo aberto")
	var heights: Array = []; var grass: Array = []; var earth: Array = []; var stone: Array = []
	for gz: int in FIELD_SAMPLES:
		for gx: int in FIELD_SAMPLES:
			var h := field_height(gx,gz); heights.append(h)
			var rocky := _spike(gx,gz) or (gx == ridge_x(gz) and gz >= 24 and gz <= 136)
			var path := in_ramp(gx,gz) or absi(gz-55) <= 1 or absi(gz-107) <= 1
			stone.append(1.0 if rocky else 0.0); earth.append(0.6 if path and not rocky else 0.0); grass.append(0.0 if rocky else (0.4 if path else 1.0))
	source.layers = [{"layer_id":"ground","name":"Campo","origin_xz":[FIELD_ORIGIN,FIELD_ORIGIN],"sample_spacing":64,"columns":FIELD_SAMPLES,"rows":FIELD_SAMPLES,"heights":heights,"material_masks":{"grass":grass,"earth":earth,"stone":stone},"locked":false,"protected_regions":[],"surface_mode":"height_grid"}]
	source.sockets = [{"socket_id":"entry","surface_id":"ground","position_xyz":[FIELD_ORIGIN+640.0,field_height(10,80),FIELD_ORIGIN+80.0*64.0],"kind":"entrance"}]
	return source

static func field_point(gx: float, gz: float) -> Vector2: return Vector2(FIELD_ORIGIN+gx*64.0,FIELD_ORIGIN+gz*64.0)
static func map_of(source: Dictionary) -> Dictionary:
	var data := MapDocument.empty("grid_field"); data.name = "Campo aberto"
	var digest := Schema.semantic_hash(source)
	data.pieces = [{"piece_hash":digest,"source":source}]
	data.instances = [{"instance_id":"field","piece_hash":digest,"position_xyz":[0,0,0],"rotation_quarters":0}]
	return data
## A valid state for `profile` on the stretch under (x, z), searched outwards
## on a 16 u ring pattern; null when none within 256 u.
static func spot(world: WorldGeometry, stage: Dictionary, at: Vector2, profile: Dictionary) -> ExpeditionWorldPoint:
	for ring: int in 17:
		for dz: int in range(-ring,ring+1):
			for dx: int in range(-ring,ring+1):
				if maxi(absi(dx),absi(dz)) != ring: continue
				var p := at+Vector2(dx,dz)*16.0
				for cell: Dictionary in stage.surfaces:
					if not cell.has("height_grid"): continue
					var view := HeightGrid.view(cell.height_grid)
					if HeightGrid.triangle_at(view,p.x,p.y) < 0: continue
					var point := ExpeditionWorldPoint.create(stage.stage_id,cell.surface_id,Vector3(p.x,HeightGrid.support_y(view,p.x,p.y),p.y))
					if world.position_query(point,profile,world.geometry_revision).ok: return point
	return null
func elapsed(started: int) -> float: return snappedf((Time.get_ticks_usec()-started)/1000.0,0.1)
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	root.size = Vector2i(1280,720)
	# 1. The piece: 100 stretches, under the package limit, rebuilt by its receiver.
	var piece := field_source("grid_field_piece")
	var started := Time.get_ticks_usec()
	var compiled := Terrain.compile(piece)
	timing["piece_ms"] = elapsed(started)
	started = Time.get_ticks_usec()
	var received: bool = compiled.ok and Terrain.validate_package(compiled.package)
	timing["piece_validate_ms"] = elapsed(started)
	timing["piece_bytes"] = var_to_bytes(compiled.get("package",{})).size()
	check("field_piece_compiles_in_budget",compiled.ok and received and compiled.package.part.surfaces.size() == 100 and int(timing.piece_bytes) <= 4*1024*1024 and float(timing.piece_ms) < BUDGET_MS.piece)
	# 2. The map: certified per walkable component (mesa by its ramp, ridge by its passes).
	started = Time.get_ticks_usec()
	var map := MapCompiler.compile(map_of(piece))
	timing["map_ms"] = elapsed(started)
	if not map.ok: print("F10_GRID_FIELD_CODE "+str(map.code)+" "+JSON.stringify(map.get("geometry_diagnostic",{})).left(800)); finish(); return
	started = Time.get_ticks_usec()
	var map_received := MapCompiler.validate_package(map.package)
	timing["map_validate_ms"] = elapsed(started)
	timing["map_bytes"] = var_to_bytes(map.package).size()
	timing["certification"] = map.metrics.navigation
	check("field_map_certifies_in_budget",map_received and map.package.manifest.stages[0].surfaces.size() == 100 and int(timing.map_bytes) <= 4*1024*1024 and float(timing.map_ms) < BUDGET_MS.map)
	var stage: Dictionary = map.package.manifest.stages[0]
	var profile: Dictionary = map.package.profile
	var world := WorldGeometry.new(); world.configure(MapCompiler.manifest(map.package),"map_preview")
	var entry := spot(world,stage,field_point(10,80),profile)
	var mesa := spot(world,stage,field_point(115,36),profile)
	var east := spot(world,stage,field_point(150,100),profile)
	var basin := spot(world,stage,field_point(40,120),profile)
	check("field_spots_are_supported",entry != null and mesa != null and east != null and basin != null and mesa.position.y > 120.0)
	if entry == null or mesa == null or east == null or basin == null: finish(); return
	# 3. Routes across the ridge and up the ramp: cold, then warm.
	started = Time.get_ticks_usec()
	var up := world.path(entry,mesa,profile,world.geometry_revision)
	timing["route_cold_ms"] = elapsed(started)
	started = Time.get_ticks_usec()
	var again := world.path(entry,mesa,profile,world.geometry_revision)
	timing["route_warm_ms"] = elapsed(started)
	var across := world.path(entry,east,profile,world.geometry_revision)
	var down := world.path(mesa,basin,profile,world.geometry_revision)
	var climbed := false
	if up.ok:
		var points: Array = up.data.points
		climbed = points[-1].surface_id == mesa.surface_id and points.size() > 2
	check("routes_cross_the_field",up.ok and climbed and again.ok and again.data.points == up.data.points and across.ok and down.ok and float(timing.route_cold_ms) < BUDGET_MS.route_cold)
	timing["route_points"] = up.data.points.size() if up.ok else 0
	# 4. The same route in the background: the main loop keeps its frames.
	var background := WorldGeometry.new(); background.configure(MapCompiler.manifest(map.package),"map_preview"); background.navigation_async = true
	started = Time.get_ticks_usec()
	var request := background.request_path(entry,mesa,profile,background.geometry_revision)
	var worst := 0; var waited := 0
	while background.navigation_pending() > 0 and waited < 60000:
		await process_frame
		var t := Time.get_ticks_usec(); background.navigation_pump(); worst = maxi(worst,Time.get_ticks_usec()-t)
		waited = int((Time.get_ticks_usec()-started)/1000)
	timing["route_background_ms"] = elapsed(started); timing["route_background_worst_pump_ms"] = snappedf(worst/1000.0,0.01)
	check("background_route_keeps_frames",request.done() and request.result.ok and up.ok and request.result.data.points == up.data.points and worst < 50000)
	# 5. Drawn per stretch; frames over the whole field and over one corner.
	var view := PackageView.new(); root.add_child(view)
	started = Time.get_ticks_usec()
	var configured: Dictionary = view.configure(map.package)
	timing["view_ms"] = elapsed(started)
	var meshes := 0
	for child: Node in view.get_children():
		if child is MeshInstance2D and child.has_meta("grid_stretch"): meshes += 1
	var camera := Camera2D.new(); view.add_child(camera); camera.make_current()
	var whole := await measure(camera,Vector2(0,0),0.06)
	var corner := await measure(camera,Vector2(entry.position.x,entry.position.z),1.0)
	timing["frames_whole"] = whole; timing["frames_corner"] = corner
	check("field_is_drawn_per_stretch",configured.ok and meshes == 100 and whole.worst_ms < 250.0 and corner.worst_ms < 250.0 and corner.draw_calls < whole.draw_calls and float(timing.view_ms) < BUDGET_MS.view)
	view.queue_free(); await frames()
	# 6. Population: a dominant species, two secondaries and a guardian (40-70).
	# The editor compiles with its cache on: the map is compiled once more here
	# (first population after a map edit), then reused by the compilation.
	OS.set_environment("RAGRPG_COMPILE_CACHE","1")
	var population := populate(map_of(piece),stage,world,profile,entry,mesa)
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	check("field_population_compiles_in_budget",population.ok)
	# 7. A session on the field: snapshot under its limit, restored and supported.
	var nav := ArenaNavigation.new(); nav.configure(Rect2(-5120,-5120,10240,10240),[],2.0)
	var hero := PlayerActor.new(); hero.configure(nav,RunState.new(&"mage"))
	var bound: bool = hero.bind_world_geometry(world,entry,profile,"field_snapshot").ok
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(hero)
	started = Time.get_ticks_usec()
	var captured := SnapshotRegistry.new().capture(hero,barrier)
	timing["snapshot_capture_ms"] = elapsed(started)
	timing["snapshot_bytes"] = int(captured.get("bytes",-1))
	started = Time.get_ticks_usec()
	var restored := SnapshotRegistry.new().restore(captured.snapshot) if captured.get("ok",false) else {"ok":false}
	timing["snapshot_restore_ms"] = elapsed(started)
	var resumed := false
	if restored.ok:
		var copy: PlayerActor = restored.root
		resumed = copy.world_motion.geometry._stage.surfaces.size() == 100 and copy.world_motion.geometry.position_query(copy.world_point(),profile,copy.world_motion.geometry.geometry_revision).ok
		copy.free()
	barrier.release(); hero.free()
	check("session_snapshot_fits_and_resumes",bound and captured.get("ok",false) and resumed and float(timing.snapshot_capture_ms)+float(timing.snapshot_restore_ms) < BUDGET_MS.snapshot)
	finish()
## Brushes over the field; the plan is drawn, then compiled (slots certified).
func populate(map: Dictionary, stage: Dictionary, world: WorldGeometry, profile: Dictionary, entry: ExpeditionWorldPoint, mesa: ExpeditionWorldPoint) -> Dictionary:
	var loaded := Catalog.load_current()
	if not loaded.ok: return {"ok":false}
	var normal: Array = []; var guardian: Dictionary = {}
	for option: Dictionary in Catalog.options(loaded.catalog):
		if option.origin_id != "trial_stage_1": continue
		if option.category == "normal" and normal.filter(func(o: Dictionary) -> bool: return o.species_id == option.species_id).is_empty(): normal.append(option)
		if option.category == "elite" and guardian.is_empty(): guardian = option
	if normal.size() < 3 or guardian.is_empty(): print("F10_GRID_FIELD_SPECIES "+str(normal.size())+" "+str(not guardian.is_empty())); return {"ok":false}
	var source := PopulationDocument.empty("field_encounters"); source.map = [map]
	source.entrance = [{"surface_id":entry.surface_id,"position_xyz":[entry.position.x,entry.position.y,entry.position.z]}]
	var layout := [["dominant_west",0,25,40,12],["dominant_centre",0,80,90,12],["dominant_east",0,135,120,12],["second_basin",1,40,120,6],["second_north",1,70,20,6],["third_east",2,140,75,6]]
	for item: Array in layout:
		var at := spot(world,stage,field_point(item[2],item[3]),profile)
		if at == null: return {"ok":false}
		var spec: Dictionary = normal[item[1]].duplicate(); spec.erase("label")
		var brush := PopulationDocument.brush(item[0],at.surface_id,at.position,spec); brush.radius = 192; brush.group_radius = 160; brush.quantity = item[4]
		source.brushes.append(brush)
	var boss: Dictionary = guardian.duplicate(); boss.erase("label")
	var lair := PopulationDocument.brush("guardian",mesa.surface_id,mesa.position,boss); lair.radius = 96; lair.group_radius = 64; lair.quantity = 1; lair.mode = "concentrated"
	source.brushes.append(lair)
	var finish_at := spot(world,stage,field_point(118,32),profile); var rest_at := spot(world,stage,field_point(12,84),profile)
	if finish_at == null or rest_at == null: return {"ok":false}
	source.interactions = [{"interaction_id":"finish","kind":"phase_completion","surface_id":finish_at.surface_id,"position_xyz":[finish_at.position.x,finish_at.position.y,finish_at.position.z],"target_id":""},{"interaction_id":"rest","kind":"early_exit","surface_id":rest_at.surface_id,"position_xyz":[rest_at.position.x,rest_at.position.y,rest_at.position.z],"target_id":""}]
	var started := Time.get_ticks_usec()
	var planned := Population.regenerate(source)
	timing["population_plan_ms"] = elapsed(started)
	if not planned.ok: print("F10_GRID_FIELD_POPULATION "+JSON.stringify(planned).left(800)); return {"ok":false}
	var slots: Array = planned.data.slots
	started = Time.get_ticks_usec()
	var built := Population.compile(planned.data)
	timing["population_compile_ms"] = elapsed(started)
	timing["population_slots"] = slots.size()
	if not built.ok: print("F10_GRID_FIELD_POPULATION "+JSON.stringify(built).left(800)); return {"ok":false}
	timing["population_bytes"] = var_to_bytes(built.package).size()
	# The play session starts from the package (the editor's "Jogar").
	started = Time.get_ticks_usec()
	var campaign := Population.make_campaign(built.package)
	timing["campaign_ms"] = elapsed(started)
	var count: int = built.package.manifest.population.slots.size()
	var ok: bool = count >= 40 and count <= 70 and count == slots.size() and float(timing.population_plan_ms)+float(timing.population_compile_ms) < BUDGET_MS.population and campaign.get("ok",false) and float(timing.campaign_ms) < BUDGET_MS.campaign
	return {"ok":ok}
## Average and worst frame over 20 frames at one camera placement.
func measure(camera: Camera2D, at: Vector2, zoom: float) -> Dictionary:
	camera.position = at; camera.zoom = Vector2.ONE*zoom
	await frames(4)
	var worst := 0.0; var total := 0.0; var draws := 0
	for i: int in 20:
		var started := Time.get_ticks_usec()
		await process_frame
		var spent := (Time.get_ticks_usec()-started)/1000.0
		worst = maxf(worst,spent); total += spent
		draws = maxi(draws,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"average_ms":snappedf(total/20.0,0.01),"worst_ms":snappedf(worst,0.01),"draw_calls":draws}
func finish() -> void:
	print("F10_GRID_FIELD_TIMING "+JSON.stringify(timing))
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_FIELD_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
