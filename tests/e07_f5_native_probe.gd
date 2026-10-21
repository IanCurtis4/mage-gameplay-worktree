extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: push_error("explicit output directory required"); quit(1); return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var f := make("native")
	var result := enter(f)
	if not result["ok"]: dispose(f); finish_test(); return
	f["barrier"].release()
	var host: RunController = f["controller"]
	var registry: SnapshotRegistry = result["registry"]
	check(registry.install(result, root)["ok"], "native install of durable F5 world")
	check(host.expedition_view != null and host.expedition_view.geometry == host.player.world_motion.geometry, "restored presentation uses same current geometry")
	check(registry.activate(result)["ok"], "explicit native activation")
	disable(host)
	paused = false
	host.route_camera.position_smoothing_enabled = false
	host.status_label.text = "Expedição de prova · entrada inicial · duas escolhas pendentes"
	host.expedition_view.sync()
	var portal := ExpeditionPortal.new()
	portal.configure(host.campaign_runtime.state.portal_view("entry_to_left"))
	host.add_child(portal)
	host.route_camera.global_position = portal.global_position
	for index: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	check(not captured.is_empty() and captured.save_png(output.path_join("f5_portal_closed.png")) == OK, "native portal capture")
	portal.free() # disposable presentation adapter, outside the campaign snapshot
	paused = true
	f["barrier"] = SnapshotTickBarrier.new()
	f["barrier"].acquire(host)
	check(kill(f, "entry_field", "native_field")["ok"], "native required normal resolved")
	result = kill(f, "entry_boss", "native_boss")
	check(result["ok"], "native memorable/clear durable")
	if not result["ok"]: dispose(f); finish_test(); return
	f["barrier"].release()
	host = f["controller"]
	registry = result["registry"]
	check(registry.install(result, root)["ok"] and registry.activate(result)["ok"], "native reconstruction after durable clear")
	disable(host)
	paused = false
	portal = ExpeditionPortal.new()
	portal.configure(host.campaign_runtime.state.portal_view("entry_to_left"))
	host.add_child(portal)
	host.route_camera.position_smoothing_enabled = false
	host.route_camera.global_position = portal.global_position
	host.status_label.text = "Expedição de prova · estágio limpo · portal de avanço aberto"
	for index: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	captured = root.get_texture().get_image()
	check(portal.open and captured.save_png(output.path_join("f5_portal_open.png")) == OK, "native portal opens after canonical clear")
	var report := {"checks": checks, "failures": failures, "stage": host.campaign_runtime.state.current_stage_id, "entry_choices": host.run_state.pending_choices, "portal_open": portal.open, "source_manifest_sha256": FileAccess.get_sha256("res://source_hashes.json"), "renderer": RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(output.path_join("native.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true)); file.close()
	host.free()
	finish_test()
