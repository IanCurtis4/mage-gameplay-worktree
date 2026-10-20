extends SceneTree
## Native renderer capture and factual outcomes. Run only in the isolated imported project.
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var output := ""
var sample: Node2D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: push_error("explicit output directory required"); quit(1); return
	output = args[0]; DirAccess.make_dir_recursive_absolute(output)
	sample = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample)
	var c: RunController = sample.controller; var view: ExpeditionGeometryView = sample.view
	c.player.set_process(false); c.route_camera.position_smoothing_enabled = false
	await _capture("01_bridge.png")
	var destination := Fixture.point("landing",Vector3(750,120,150))
	var route := c.player.move_world_to(Fixture.point("slope",Vector3(450,60,150)),sample.world.geometry_revision)
	if not route["ok"] or not c.player.advance_world(10000)["ok"]: push_error("native ramp route failed"); quit(1); return
	view.sync(); var onward: Dictionary = sample.world.path(c.player.world_point(),destination,sample.profile,sample.world.geometry_revision)
	view.indicate(destination,onward["ok"],onward["data"].get("points",[]))
	sample.notice.text = "RAMPA · apoio contínuo em altura\nMarcador no andar superior; caminho real pela conexão."
	await _capture("02_ramp_marker.png")
	var under := Fixture.point("root",Vector3(180,0,440)); route = c.player.move_world_to(under,sample.world.geometry_revision)
	if not route["ok"] or not c.player.advance_world(10000)["ok"]: push_error("native underpass route failed"); quit(1); return
	view.sync()
	var sp := c.player.current_sp; var hp: float = sample.upper.health.current_hp
	var pixel := view.project(sample.upper.world_point().position)+Vector2(0,-24)
	var preview := c.spatial_pointer_skill(&"fire_spear",pixel,true)
	var commit := c.spatial_pointer_skill(&"fire_spear",pixel,false)
	if preview["ok"] or commit["ok"] or c.player.current_sp != sp or sample.upper.health.current_hp != hp: push_error("native blocked cast invariant failed"); quit(1); return
	sample.notice.text = "LAJE SÓLIDA · ataque entre andares recusado\nSem dano, custo ou recarga; colisão independe da aparência."
	await _capture("03_blocked_attack.png")
	var roofs: Array[String] = [sample.upper.world_point().surface_id]
	view.hide_surfaces(roofs); view.sync()
	sample.notice.text = "TETO OCULTO · passagem inferior visível\nA laje mantém a colisão: o ataque entre pisos continua bloqueado."
	var collision: Dictionary = sample.world.query_attack({"geometry_rule_id":&"direct_volume","range":1000},under,sample.upper.world_point(),sample.world.geometry_revision)
	if collision["data"]["hit"]: push_error("cutaway disabled collision"); quit(1); return
	await _capture("04_cutaway_collision.png")
	var record := {"seed":"711","scale":3,"bridge":true,"ramp":true,"underpass":true,"cutaway_collision_preserved":true,"blocked_preview":not preview["ok"],"blocked_commit":not commit["ok"],"sp_preserved":c.player.current_sp==sp,"target_hp_preserved":sample.upper.health.current_hp==hp,"source_manifest_sha256":FileAccess.get_sha256("res://source_hashes.json"),"renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE); file.store_string(JSON.stringify(record,"  ",true)); file.close()
	print("E07 F1 native presentation capture PASS: bridge,ramp,marker,underpass,blocked preview/commit; seed=711")
	sample.queue_free(); await process_frame; quit(0)
func _capture(name: String) -> void:
	for index: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.is_empty() or image.save_png(output.path_join(name)) != OK: push_error("native capture failed"); quit(1)
