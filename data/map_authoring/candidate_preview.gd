extends VBoxContainer
## Disposable local preview of the exported immutable package, never ProfileStore.
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Preview = preload("res://scripts/map_authoring/patrol/patrol_preview.gd")
const Canvas = preload("res://scripts/map_authoring/patrol/patrol_canvas.gd")
var host: PlayerActor
var actors: Array[EnemyActor] = []
var canvas: Control
var status: Label
var package: Dictionary = {}
var paused := false
func _ready() -> void:
	var loaded := Store.load_package("res://data/map_authoring/representative.rpp")
	if not loaded.ok: fail(loaded); return
	package = loaded.package
	var made := Preview.make_actors(package)
	if not made.ok: fail(made); return
	host = made.player; actors.assign(made.actors); add_child(host)
	host.set_process(false)
	for actor: EnemyActor in actors: actor.set_process(false)
	var title := Label.new(); title.text = "Editor de mapas · Clareira, ponte e santuário"; title.add_theme_font_size_override("font_size",22); add_child(title)
	var help := Label.new(); help.text = "Clique para mover o marcador azul. Selecione a superfície para caminhar sob ou sobre a ponte. Perfil descartável."; add_child(help)
	var row := HFlowContainer.new(); add_child(row)
	var pause := Button.new(); pause.text = "Pausar / continuar"; pause.pressed.connect(func() -> void: paused = not paused); row.add_child(pause)
	var surface := OptionButton.new(); surface.add_item("Todas as superfícies visíveis"); row.add_child(surface)
	for cell: Dictionary in package.manifest.stages[0].surfaces: surface.add_item(cell.surface_id)
	surface.item_selected.connect(func(index: int) -> void: canvas.selected_surface = "" if index == 0 else surface.get_item_text(index))
	status = Label.new(); status.text = "Encontros e patrulha usam as autoridades do jogo. A referência de quest é apenas descritiva."; add_child(status)
	canvas = Canvas.new(); canvas.size_flags_vertical = SIZE_EXPAND_FILL; add_child(canvas)
	canvas.set_package(package.population_package.map_package); canvas.geometry = host.world_motion.geometry; canvas.paint_enabled = true
	canvas.painted.connect(func(point: Dictionary) -> void:
		var planned := host.world_motion.plan(Store.Compiler.Population.anchor(point),canvas.geometry.geometry_revision)
		status.text = "Caminhando…" if planned.ok else "Não há rota para o corpo do jogador neste ponto.")
	if "--m8-probe" in OS.get_cmdline_user_args(): probe.call_deferred()
func fail(result: Dictionary) -> void:
	print("M8_RELEASE_RESULT "+JSON.stringify({"ok":false,"count":1,"checks":[{"id":"load","ok":false}],"code":result.get("code","invalid")})); get_tree().quit(1)
func _process(delta: float) -> void:
	if host == null or canvas == null or paused: return
	var dt := minf(delta,0.05)
	if host.world_motion.has_route(): host.world_motion.advance(120*dt)
	for actor: EnemyActor in actors: actor._process(dt)
	refresh_preview()
func refresh_preview() -> void:
	canvas.player_point = host.world_point().to_data(); canvas.actors = []
	for actor: EnemyActor in actors:
		canvas.actors.append({"position":actor.world_point().position,"label":"Patrulha" if not actor.patrol.is_empty() else "Encontro"})
	canvas.redraw()
func probe() -> void:
	paused = true
	await get_tree().process_frame; await get_tree().process_frame
	var world := host.world_motion.geometry
	var checks: Array = []
	checks.append({"id":"new_release_process","ok":not OS.has_feature("editor")})
	checks.append({"id":"immutable_package","ok":Store.Compiler.validate_package(package)})
	checks.append({"id":"seven_real_actors","ok":actors.size() == 7})
	checks.append({"id":"patrol_bound","ok":actors.any(func(actor: EnemyActor) -> bool: return not actor.patrol.is_empty())})
	for destination: Vector3 in [Vector3(100,0,600),Vector3(400,40,600)]:
		var point: ExpeditionWorldPoint
		for cell: Dictionary in world._stage.surfaces:
			if ExpeditionFixtureGeometry.contains(cell,destination): point = ExpeditionWorldPoint.create("map_preview",cell.surface_id,destination); break
		var planned := host.world_motion.plan(point,world.geometry_revision) if point != null else {"ok":false}
		var steps := 0
		while planned.ok and host.world_motion.has_route() and steps < 2000:
			host.world_motion.advance(6); steps += 1
		checks.append({"id":"traverse_"+str(destination.y),"ok":planned.ok and host.world_point().position.distance_to(destination) < 0.1})
	refresh_preview()
	await get_tree().process_frame; await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	if not DisplayServer.get_name() == "headless": image.save_png(OS.get_environment("M8_EVIDENCE").path_join("release.png"))
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M8_RELEASE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"package_hash":package.package_hash,"source_hash":package.source_hash,"engine":Engine.get_version_info().string})); get_tree().quit(0 if ok else 1)
