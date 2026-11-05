extends SceneTree
var draws := 0
var actors: Array[CombatActor] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1280,720),[],0)
	var player := PlayerActor.new(); player.configure(nav,RunState.new(&"mage"))
	for i: int in 96:
		var actor := CombatActor.new(); actor.setup("Carga visual",Color.WHITE,player.stat_breakdown); actor.set_animation_kind(&"gel")
		actor.position = Vector2(80+(i%12)*100,80+(i/12)*80)
		actor.draw.connect(func() -> void: draws += 1)
		root.add_child(actor); actors.append(actor)
	player.free()
	for k: int in 20: await process_frame
	var rows: Array = []
	for pass_index: int in 3:
		draws = 0
		var times: Array[float] = []; var begin := Time.get_ticks_usec(); var last := begin
		var clock_begin := actors[0].character_animation.state.idle_time
		while Time.get_ticks_usec()-begin < 3000000:
			await process_frame
			var now := Time.get_ticks_usec(); times.append((now-last)/1000.0); last = now
		times.sort(); var total := 0.0
		for value: float in times: total += value
		var row := {"pass":pass_index,"actors":actors.size(),"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[int((times.size()-1)*0.95)],"p99_ms":times[int((times.size()-1)*0.99)],"max_ms":times[-1],"draw_callbacks":draws,"animation_seconds":actors[0].character_animation.state.idle_time-clock_begin}
		rows.append(row); print("CROWD_DRAW_SAMPLE ",JSON.stringify(row))
	var path := OS.get_environment("TERRAIN_EVIDENCE").path_join("crowd.png")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CROWD_DRAW_RESULT ",JSON.stringify({"ok":rows.size()==3,"rows":rows,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	quit()
