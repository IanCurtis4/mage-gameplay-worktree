extends SceneTree
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Canvas = preload("res://scripts/map_authoring/patrol/patrol_canvas.gd")
var host: PlayerActor
var actors: Array[EnemyActor] = []
var canvas: Control
var label: Label
var save_path := ""
var frozen := false
var package: Dictionary = {}
var expected_hash := ""
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): quit(1); return
	var loaded := Store.load_package(args[0])
	if not loaded.ok: print(loaded); quit(1); return
	package = loaded.package; save_path = args[0]+".checkpoint"
	if args.size() == 2 and args[1] == "resume":
		if not FileAccess.file_exists(save_path): push_error("Não há teste suspenso para esta revisão."); quit(1); return
		var raw: Variant = bytes_to_var(FileAccess.get_file_as_bytes(save_path))
		var unpacked := ExpeditionCheckpointCodec.unpack(raw) if raw is Dictionary else {"ok":false}
		var restored := SnapshotRegistry.new().restore(unpacked.snapshot) if unpacked.ok else {"ok":false}
		if not restored.ok: push_error("Teste suspenso incompatível; a fonte foi preservada."); quit(1); return
		host = restored.root
		for child: Node in host.get_children():
			if child is EnemyActor: actors.append(child)
		SnapshotRegistry.new().activate(restored)
	else:
		var made := make_actors(package)
		if not made.ok: print(made); quit(1); return
		host = made.player; actors.assign(made.actors)
	root.title = "Teste de patrulhas · descartável"; root.size = Vector2i(1280,800)
	var panel := VBoxContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(panel)
	var row := HBoxContainer.new(); panel.add_child(row)
	for entry: Array in [["Pausar / continuar",func() -> void: frozen = not frozen],["Suspender e fechar",suspend],["Encerrar sem salvar",func() -> void: quit()]]:
		var button := Button.new(); button.text = entry[0]; button.pressed.connect(entry[1]); row.add_child(button)
	label = Label.new(); label.text = "Clique para mover o jogador azul: aproximar gera aggro; afastar inicia o retorno."; panel.add_child(label)
	canvas = Canvas.new(); panel.add_child(canvas); canvas.set_package(package.population_package.map_package); canvas.geometry = host.world_motion.geometry; canvas.paint_enabled = true
	canvas.painted.connect(func(point: Dictionary) -> void:
		var planned := host.world_motion.plan(Compiler.Population.anchor(point),host.world_motion.geometry.geometry_revision)
		if not planned.ok: label.text = "O jogador não tem rota até esse ponto.")
	canvas.source = {}; canvas.patrol_source = {"patrols":[]}
	for slot: Dictionary in package.manifest.population.slots:
		if not slot.has("patrol"): continue
		var route: Dictionary = slot.patrol.duplicate(true); route.waypoints = []
		for p: Dictionary in slot.patrol.waypoints: route.waypoints.append({"position_xyz":Compiler.Population.xyz(p.point.position),"wait_seconds":p.wait_seconds})
		canvas.patrol_source.patrols.append(route)
	root.close_requested.connect(suspend)
	if OS.get_environment("RAGRPG_PATROL_PREVIEW_PROBE") == "1":
		await process_frame; await process_frame
		var ready := FileAccess.open(args[0]+".ready",FileAccess.WRITE)
		ready.store_string(JSON.stringify({"ok":true,"resumed":args.size() == 2 and args[1] == "resume","package_hash":package.package_hash})); ready.close()
		root.get_texture().get_image().save_png(OS.get_environment("M5_EVIDENCE").path_join("preview.png"))
		suspend()
static func make_actors(value: Dictionary) -> Dictionary:
	if not Compiler.validate_package(value): return {"ok":false,"code":"package_invalid"}
	var manifest := Compiler.manifest(value); var loaded := Compiler.Catalog.load_current()
	var planned := ExpeditionPopulationPlanner.build(manifest,loaded.catalog,value.population_package.rules)
	if not planned.ok: return planned
	var world: WorldGeometry = planned.worlds.map_preview
	var nav := ArenaNavigation.new(); nav.configure(Rect2(-10000,-10000,20000,20000),[],18)
	var player := PlayerActor.new(); player.configure(nav,RunState.new(&"mage"))
	var entry: Dictionary = {}
	for socket: Dictionary in manifest._data.stages[0].sockets:
		if socket.socket_id == manifest._data.stages[0].entrance: entry = ExpeditionWorldPoint.create("map_preview",socket.surface_id,socket.position).to_data()
	var bound := player.bind_world_geometry(world,ExpeditionPopulationPlanner.point(entry),value.population_package.profile,"patrol_preview_player")
	if not bound.ok: player.free(); return bound
	var result: Array[EnemyActor] = []
	for slot: Dictionary in planned.slots.values():
		var spawn := MobOccurrence.new(); spawn.occurrence_id = ExpeditionPopulationPlanner.occurrence_id("patrol_preview","map_preview",slot.slot_id,0); spawn.mob_base_id = StringName(slot.species_id); spawn.category_id = StringName(slot.occurrence_category); spawn.origin_id = StringName(slot.origin_id)
		var actor := EnemyActor.new(); var configured := actor.configure_occurrence(spawn,loaded.catalog,nav,player)
		if configured.ok: configured = actor.bind_world_geometry(world,ExpeditionPopulationPlanner.point(slot.home),slot.traversal,slot.slot_id)
		if configured.ok and slot.has("patrol"): configured = actor.bind_patrol(slot.patrol)
		if not configured.ok: actor.free(); player.free(); return configured
		player.add_child(actor); result.append(actor)
	return {"ok":true,"player":player,"actors":result}
func _process(delta: float) -> bool:
	if host == null or canvas == null or frozen: return false
	var dt := minf(delta,0.05)
	if host.world_motion.has_route(): host.world_motion.advance(120*dt)
	for actor: EnemyActor in actors: actor._process(dt)
	canvas.player_point = host.world_point().to_data(); canvas.actors = []
	for actor: EnemyActor in actors:
		var state := "Parado"
		if not actor.patrol.is_empty(): state = {"travel":"Caminhando","wait":"Esperando","interrupted":"Combate / retorno","blocked":"Bloqueado"}.get(actor.patrol.state,"Parado")
		canvas.actors.append({"position":actor.world_point().position,"label":state+" · "+{&"idle":"Sem alvo",&"engaged":"Em combate",&"returning":"Retornando"}.get(actor.engagement_mode,"Sem alvo")})
	canvas.redraw(); return false
func suspend() -> void:
	if host == null: quit(); return
	var barrier := SnapshotTickBarrier.new(); var acquired := barrier.acquire(host)
	var captured := SnapshotRegistry.new().capture(host,barrier) if acquired.ok else acquired
	var packed := ExpeditionCheckpointCodec.pack(captured.snapshot,package.source_hash,{"run_id":"editor_patrol","character_id":"editor_fixture","last_committed_seq":0}) if captured.ok else captured
	barrier.release()
	if not packed.ok: label.text = "Falha ao suspender: "+str(packed.get("error_code","erro")); return
	var file := FileAccess.open(save_path+".pending",FileAccess.WRITE)
	if file == null: label.text = "Falha ao gravar teste suspenso."; return
	file.store_buffer(var_to_bytes(packed.checkpoint)); file.flush(); file.close()
	if DirAccess.rename_absolute(save_path+".pending",save_path) != OK: label.text = "Falha ao confirmar suspensão."; return
	quit()
func _finalize() -> void:
	if is_instance_valid(host): host.free()
