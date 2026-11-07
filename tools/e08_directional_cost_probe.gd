extends SceneTree
## Same script runs against the accepted E08 PCK and the new source. No V2 types.
class CrowdActor extends Node2D:
	var animation: CharacterAnimation
	func _init() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var draw_cpu_us := 0
	func _draw() -> void:
		var began := Time.get_ticks_usec()
		animation.draw_on(self)
		draw_cpu_us=Time.get_ticks_usec()-began
var folder := ""
var mode := "legacy"
var actors: Array[CrowdActor] = []
func _initialize() -> void:run.call_deferred()
func frames(count: int) -> void:
	for i: int in count:await process_frame
func quantile(values: Array[float],fraction: float) -> float:
	var sorted := values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,int(floor((sorted.size()-1)*fraction)))]
func run() -> void:
	folder=OS.get_cmdline_user_args()[0];mode=OS.get_cmdline_user_args()[1]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);root.size=Vector2i(1280,720)
	var before := Performance.get_monitor(Performance.MEMORY_STATIC)
	for i: int in 96:
		var actor := CrowdActor.new();actor.animation=CharacterAnimation.new();actor.animation.configure(&"warrior" if mode.begins_with("unarmed_") else &"mage")
		if not mode.begins_with("unarmed_"):actor.animation.set_equipment_visual({"main_hand":&"staff","off_hand":&"shield","arms":&"wooden_beads"})
		if mode in ["directional","unarmed_directional"]:
			var result: Dictionary = actor.animation.call("set_directional_manifest","res://tests/fixtures/e08_directional/enemy/presentation.json" if mode=="unarmed_directional" else "res://tests/fixtures/e08_directional/presentation.json")
			if not result.get("ok",false):push_error(str(result));quit(1);return
		actor.position=Vector2(45+(i%16)*78,100+(i/16)*100);root.add_child(actor);actors.append(actor)
	await frames(90)
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(folder.path_join("before_motion.png"))!=OK:push_error("cost screenshot failed");quit(1);return
	var windows: Array[Dictionary] = []
	for moving: bool in [true,false]:
		for window: int in 3:
			var samples: Array[float] = [];var draw_samples: Array[float] = [];var began := Time.get_ticks_usec();var previous := began
			while Time.get_ticks_usec()-began<3000000:
				await process_frame
				var now := Time.get_ticks_usec();var elapsed := (now-previous)/1000000.0;samples.append((now-previous)/1000.0);previous=now
				var draw_cpu := 0
				for actor: CrowdActor in actors:
					draw_cpu+=actor.draw_cpu_us
					actor.animation.state.advance(elapsed,Vector2.RIGHT*80.0*elapsed if moving else Vector2.ZERO);actor.queue_redraw()
				draw_samples.append(draw_cpu/1000.0)
			windows.append({"moving":moving,"window":window,"samples_ms":samples,"draw_cpu_samples_ms":draw_samples,"draw_cpu_median_ms":quantile(draw_samples,0.5),"draw_cpu_p95_ms":quantile(draw_samples,0.95),"median_ms":quantile(samples,0.5),"p95_ms":quantile(samples,0.95),"max_ms":samples.max()})
	var loaded := Performance.get_monitor(Performance.MEMORY_STATIC)
	for actor: CrowdActor in actors:actor.free()
	actors.clear();await frames(90)
	var result := {"instrumented_draw_cpu":true,"mode":mode,"actor_count":96,"window_seconds":3,"windows":windows,"static_before":before,"static_loaded":loaded,"static_after_clear":Performance.get_monitor(Performance.MEMORY_STATIC),"device":RenderingServer.get_video_adapter_name(),"synthetic":mode in ["directional","unarmed_directional"],"scope":"forced-redraw renderer harness, including idle; no gameplay/campaign FPS certification"}
	var file := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ",true));file.close()
	print("E08 directional cost: ",mode," windows=",windows.size());quit()
