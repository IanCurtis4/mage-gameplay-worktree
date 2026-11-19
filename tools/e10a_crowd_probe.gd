## E10a T13 (C10): the E08 crowd scenario (96 actors, same loop) with an optional Delirium layer.
## Same script on both packs for a paired same-session comparison. The Delirium layer exists only
## when the pack ships the Madness authority (E10a): three real forest mobs enter Delirium (D4 cap)
## through the production authority, and the authority ticks every frame. No FPS claim.
extends SceneTree
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Project = preload("res://scripts/world/expedition_projection.gd")
var actors: Array[CombatActor] = []
var draws := 0
var delirium_rows: Dictionary = {}
var delirium_player: PlayerActor = null
var delirium_authority: RefCounted = null
var delirium_mobs: Array[EnemyActor] = []
var delirium_serial := 0
var delirium_frames := 0
var delirium_active_frames := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var tick_only := "--cpu-tick" in OS.get_cmdline_user_args()
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
	var with_delirium := setup_delirium(player, nav, holder)
	if not with_delirium: player.free()
	if tick_only:
		measure_idle_ticks()
		return
	if "--stable-capture" in OS.get_cmdline_user_args():
		await capture_idle_pose()
		return
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
			advance_delirium(1.0/60.0)
			await process_frame
			var now := Time.get_ticks_usec(); times.append((now-last)/1000.0); last = now
		times.sort(); var total := 0.0
		for value: float in times: total += value
		var row := {"pass":pass_index % 3,"mode":"moving" if pass_index < 3 else "idle","median_ms":times[times.size()/2],"memory_static_bytes":OS.get_static_memory_usage(),"actors":actors.size(),"frames":times.size(),"mean_ms":total/times.size(),"p95_ms":times[int((times.size()-1)*0.95)],"p99_ms":times[int((times.size()-1)*0.99)],"max_ms":times[-1],"draw_callbacks":draws,"animation_seconds":actors[0].character_animation.state.idle_time-clock_begin}
		rows.append(row); print("WORLD_CROWD_SAMPLE ",JSON.stringify(row))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TERRAIN_EVIDENCE").path_join("world_crowd.png"))
	var report := delirium_report()
	cleanup_delirium()
	print("WORLD_CROWD_RESULT ",JSON.stringify({"ok":rows.size()==6,"rows":rows,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"delirium":report})); quit()

## Run the same full actor callback with a fixed delta. Time the 96 actors
## together, with no frame scheduling or renderer work inside the sample.
func measure_idle_ticks() -> void:
	const STEP := 1.0 / 240.0
	const WARMUP_TICKS := 120
	const SAMPLE_TICKS := 360
	var rows: Array[Dictionary] = []
	for window: int in 6:
		var times := PackedFloat64Array()
		times.resize(SAMPLE_TICKS)
		for tick: int in WARMUP_TICKS + SAMPLE_TICKS:
			var begin := Time.get_ticks_usec()
			for actor: CombatActor in actors:
				actor._process(STEP)
			var elapsed := Time.get_ticks_usec() - begin
			if tick >= WARMUP_TICKS:
				times[tick - WARMUP_TICKS] = elapsed / 1000.0
		times.sort()
		rows.append({"pass": window, "mode": "idle_cpu", "actors": actors.size(),
			"ticks": SAMPLE_TICKS, "median_ms": times[SAMPLE_TICKS / 2],
			"p95_ms": times[int((SAMPLE_TICKS - 1) * 0.95)], "max_ms": times[-1]})
	var clock := actors[0].character_animation.state.idle_time
	var expected_clock := STEP * rows.size() * (WARMUP_TICKS + SAMPLE_TICKS)
	print("WORLD_CROWD_RESULT ", JSON.stringify({"ok": is_equal_approx(clock, expected_clock),
		"rows": rows, "animation_seconds": clock, "expected_animation_seconds": expected_clock}))
	quit()

func capture_idle_pose() -> void:
	for actor: CombatActor in actors:
		actor.set_process(false)
		actor.character_animation.state.idle_time = 0.25
		actor.character_animation.state.face(Vector2.RIGHT)
		actor.queue_redraw()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OS.get_environment("TERRAIN_EVIDENCE").path_join("world_crowd.png"))
	print("WORLD_CROWD_RESULT ", JSON.stringify({"ok": error == OK, "rows": []}))
	quit(0 if error == OK else 1)


## Delirium layer (E10a pack only): three real forest mobs enter Delirium through the production
## MadnessAuthority; nothing is simulated. Returns false on the E08 pack (no authority script).
func setup_delirium(player: PlayerActor, nav: ArenaNavigation, holder: Node2D) -> bool:
	var authority_path := "res://scripts/systems/madness/madness_authority.gd"
	if not ResourceLoader.exists(authority_path):
		delirium_rows = {"present": false}
		return false
	delirium_player = player
	holder.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(512, 900)
	delirium_authority = (load(authority_path) as Script).new()
	delirium_authority.configure(player, {})
	var catalog = BuildContentLoader.pilot().mob_catalog()
	var mob_ids: Array[StringName] = [&"forest_wolf", &"forest_boar", &"forest_wolf", &"forest_boar", &"forest_wolf", &"forest_boar"]
	for index: int in mob_ids.size():
		var hostile := EnemyActor.new()
		hostile.global_position = Vector2(300 + index * 70, 700)
		var spawn := MobOccurrence.new()
		spawn.occurrence_id = "t13_crowd_%03d" % index
		spawn.mob_base_id = mob_ids[index]
		spawn.category_id = &"normal"
		spawn.origin_id = &"trial_stage_1"
		var configured: Dictionary = hostile.configure_occurrence(spawn, catalog, nav, player)
		if not configured.get("ok", false):
			delirium_rows = {"present": true, "ok": false, "error": str(configured)}
			hostile.free()
			continue
		holder.add_child(hostile)
		hostile.set_process(false)
		delirium_mobs.append(hostile)
	var entered := 0
	for index: int in delirium_mobs.size():
		var result: Dictionary = delirium_authority.add(delirium_mobs[index], 100.0, "t13_crowd@%d" % index, player, false, delirium_mobs)
		if result.get("entered", &"") == &"delirium": entered += 1
	delirium_rows = {"present": true, "ok": entered > 0, "mobs": delirium_mobs.size(), "entered_delirium": entered, "cap": delirium_authority.delirium_count(player, delirium_mobs)}
	return true

## Gameplay clock of the Delirium layer, as in the madness test: enemy statuses and override
## clocks, then the authority tick. One call per frame inside the sampled loop.
func advance_delirium(delta: float) -> void:
	if delirium_authority == null: return
	for hostile: EnemyActor in delirium_mobs:
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	# Keep up to three enemies in Delirium (D4 cap) for the whole sample: a new event re-enters it.
	for hostile: EnemyActor in delirium_mobs:
		if delirium_authority.delirium_count(delirium_player, delirium_mobs) >= 3: break
		if is_instance_valid(hostile) and hostile.is_alive():
			delirium_serial += 1
			delirium_authority.add(hostile, 100.0, "t13_crowd_again@%d" % delirium_serial, delirium_player, false, delirium_mobs)
	delirium_authority.tick(delirium_player, delta, delirium_mobs)
	delirium_frames += 1
	if delirium_authority.delirium_count(delirium_player, delirium_mobs) > 0: delirium_active_frames += 1

func delirium_report() -> Dictionary:
	if delirium_authority != null:
		delirium_rows["delirium_count_end"] = delirium_authority.delirium_count(delirium_player, delirium_mobs)
		delirium_rows["frames_with_delirium"] = delirium_active_frames
		delirium_rows["frames_ticked"] = delirium_frames
	return delirium_rows

## Free the Delirium layer before quitting so the engine exits without leaked resources.
func cleanup_delirium() -> void:
	delirium_authority = null
	for hostile: EnemyActor in delirium_mobs:
		if is_instance_valid(hostile): hostile.free()
	delirium_mobs.clear()
	if is_instance_valid(delirium_player): delirium_player.free()
	delirium_player = null
