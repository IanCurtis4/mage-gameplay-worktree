extends SceneTree
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Project = preload("res://scripts/world/expedition_projection.gd")
var actors: Array[CombatActor] = []
var draws := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var heights: Array = []; heights.resize(17*17); heights.fill(0.0)
	var grid := {"origin_xz":[0.0,0.0],"sample_spacing":64.0,"columns":17,"rows":17,"heights":heights}
	var surface := {"surface_id":"floor","headroom":200.0,"vertices":Grid.corners(Grid.view(grid)),"height_grid":grid}
	var stage := {"stage_id":"crowd","biome":"ruin","entrance":"","part_instances":[],"surfaces":[surface],"connectors":[],"connections":[],"sockets":[],"volumes":[],"solid_prisms":[]}
	var manifest := ExpeditionManifest.new()
	manifest._data = {"manifest_revision":1,"geometry_revision":1,"input":{"parts":[]},"stages":[stage],"portals":[],"objectives":[],"population":{"slots":[]}}
	var world := WorldGeometry.new()
	if not world.configure(manifest,"crowd").ok: quit(1); return
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,1024,1024),[],0)
	var player := PlayerActor.new(); player.configure(nav,RunState.new(&"mage"))
	var holder := Node2D.new(); holder.position = Vector2(540,60); holder.scale = Vector2.ONE*0.8; root.add_child(holder)
	for i: int in 96:
		var actor := CombatActor.new(); actor.setup("Carga visual móvel",Color.WHITE,player.stat_breakdown); actor.set_animation_kind(&"gel")
		holder.add_child(actor)
		var point := ExpeditionWorldPoint.create("crowd","floor",Vector3(32+(i%12)*64,0,32+(i/12)*64))
		if not actor.bind_world_geometry(world,point,{"radius":18.0,"height":40.0,"connector_kinds":["walk"]},"crowd_%d"%i).ok: quit(1); return
		actor.position = Project.project(point.position); actor.draw.connect(func() -> void: draws += 1); actors.append(actor)
	player.free()
	for k: int in 12: await process_frame
	var rows: Array = []
	for pass_index: int in 6:
		draws = 0; var times: Array[float] = []; var begin := Time.get_ticks_usec(); var last := begin
		var clock_begin := actors[0].character_animation.state.idle_time
		while Time.get_ticks_usec()-begin < 3000000:
			# Controlled known-safe positions isolate rendering from AI/pathfinding.
			# Every footprint stays in its original flat quad, including shadows.
			var offset := sin(float(Time.get_ticks_usec())/200000.0)*8.0 if pass_index < 3 else 0.0
			for i: int in actors.size():
				var point := Vector3(32+(i%12)*64+offset,0,32+(i/12)*64)
				actors[i].world_motion._point.position = point; actors[i].position = Project.project(point)
			await process_frame
			var now := Time.get_ticks_usec(); times.append((now-last)/1000.0); last = now
		times.sort(); var total := 0.0
		for value: float in times: total += value
		var row := {"pass":pass_index % 3,"mode":"moving" if pass_index < 3 else "idle","median_ms":times[times.size()/2],"memory_static_bytes":OS.get_static_memory_usage(),"actors":actors.size(),"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[int((times.size()-1)*0.95)],"p99_ms":times[int((times.size()-1)*0.99)],"max_ms":times[-1],"draw_callbacks":draws,"animation_seconds":actors[0].character_animation.state.idle_time-clock_begin}
		rows.append(row); print("WORLD_CROWD_SAMPLE ",JSON.stringify(row))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TERRAIN_EVIDENCE").path_join("world_crowd.png"))
	print("WORLD_CROWD_RESULT ",JSON.stringify({"ok":rows.size()==6,"rows":rows,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})); quit()


