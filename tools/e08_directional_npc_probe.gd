extends "res://tools/e08_directional_unit_probe.gd"
## Same renderer/cost scene; non-player samples never infer attachments.
const SPECIES_KINDS := {"e08_forest_stalker":&"warrior","e08_forest_canopy_archer":&"archer","e08_forest_warden":&"beast_master"}
var visual_id := ""
var cost_mode := ""
func run() -> void:
	var args := OS.get_cmdline_user_args()
	visual_id=args[2] if args.size()>2 else "warrior"
	if F.ORIGINS.has(StringName(visual_id)):
		await super.run();return
	folder=args[0];DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,720)
	unit_kind=&"animal_companion" if visual_id in ["e08_forest_wolf","e08_forest_boar"] else (&"archer" if visual_id=="npc_archer" else StringName(visual_id))
	# P5 B1 species units: own visual_id, generic actor_kind of the body.
	if SPECIES_KINDS.has(visual_id):unit_kind=SPECIES_KINDS[visual_id]
	require_default=args.has("--default")
	manifest="res://assets/art/%s/directional/%s/presentation.json" % ["animations" if require_default else ("e08_characters" if visual_id=="npc_archer" else "e08_enemies"),"archer" if visual_id=="npc_archer" else visual_id]
	display_label=visual_id
	if args[1]=="world":await world_native();return
	if args[1]=="mosaic":await mosaic_motion();return
	if args[1].begins_with("cost"):
		cost_mode=args[1];await cost(args[1]);return
	if args[1]=="motion":
		await motion();return
	var loaded := DirectionalAnimationSet.load_manifest(manifest)
	check(loaded.ok,"NPC complete manifest validates")
	if not loaded.ok:print(loaded);quit(1);return
	clear_page(visual_id+" · NPC sem anexos ·64poses ·S/N/E/W")
	for direction: int in 4:
		for pose: int in 16:actor(direction,pose,{},Vector2(70+pose*76,150+direction*165))
	await shot("01_body_64")
	for direction: int in 4:
		clear_page(visual_id+" · calibração ·"+["sul","norte","leste","oeste"][direction])
		for pose: int in 16:actor(direction,pose,{},Vector2(150+(pose%8)*136,290+(pose/8)*290),2.0,true)
		await shot("calibration_"+str(direction))
	clear_page(visual_id+" · mundo/câmera ·UI120")
	var camera := Camera2D.new();camera.position=Vector2(640,360);page.add_child(camera);camera.make_current()
	overlay.scale=Vector2.ONE*1.2
	for direction: int in 4:actor(direction,9,{},Vector2(450+direction*125,410))
	for zoom: float in [0.5,1.0,1.6]:
		camera.zoom=Vector2.ONE*zoom;camera.force_update_scroll();await shot("camera_"+str(int(zoom*100)))
	write_json("result.json",{"checks":checks,"failures":failures,"captures":captures,"visual_id":visual_id,"body_kind":unit_kind,"binding":"default" if require_default else "stage","scope":"real native renderer64poses; NPC no inferred equipment; no mapFPS claim"})
	print("E08 NPC native: %d checks, %d captures, %d failures" % [checks,captures.size(),failures]);quit(1 if failures else 0)
func cost_visual() -> Dictionary:
	if visual_id=="npc_archer":
		var sample := EnemyActor.new()
		sample.character_animation=D.legacy_animation(&"archer")
		if cost_mode=="cost_content":check(sample.character_animation.set_directional_manifest(manifest).ok,"staged NPC archer V2")
		sample.sync_npc_equipment_visual()
		var visual := sample.character_animation.equipment_visual.duplicate(true)
		check(visual.is_empty() and (cost_mode=="cost_control" or sample.character_animation.atlas.resource_path.get_file()=="npc_body.png"),"actual static NPC bow, complete legacy control")
		sample.free();return visual
	return super.cost_visual() if F.ORIGINS.has(unit_kind) and not SPECIES_KINDS.has(visual_id) else {}
func configure_cost_override(animation: CharacterAnimation,mode: String) -> void:
	if mode=="cost_control" and visual_id in ["e08_forest_wolf","e08_forest_boar"]:
		check(animation.set_body_atlas(load("res://assets/art/animations/%s.png" % visual_id) as Texture2D),"specific NPC V1 control")
func bind_animation(animation: CharacterAnimation,label: String) -> void:
	# Species ids always take the NPC path, even when their kind (archer) is a player kind.
	if F.ORIGINS.has(unit_kind) and not SPECIES_KINDS.has(visual_id):super.bind_animation(animation,label);return
	check(animation.actor_kind==unit_kind,label+" body kind")
	check(animation.set_directional_manifest(manifest).ok,label+" specific NPC complete binding")
	if SPECIES_KINDS.has(visual_id):check(animation.atlas.resource_path.begins_with(manifest.get_base_dir()+"/") and manifest.contains("/"+visual_id+"/"),label+" species atlas bound from its own folder")
	check(animation.equipment_visual.is_empty(),"unadorned NPC")

func world_native() -> void:
	const W = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
	var sample: Node2D=load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample);sample.set_process(false)
	var host: RunController=sample.controller
	var world: WorldGeometry=sample.world
	var view: ExpeditionGeometryView=sample.view
	host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var ids: Array[StringName]=[&"forest_wolf",&"forest_boar",&"test_gel",&"test_beast_master",&"test_animal_companion",&"forest_stalker",&"forest_canopy_archer"]
	var records: Array[Dictionary]=[]
	for index: int in ids.size():
		var definition := catalog.get_definition(ids[index])
		var point := W.point("root",Vector3(40+(index%4)*60,0,180+(index/4)*80))
		var created := host.spawn_world_enemy({"species":ids[index],"category":definition.base_category},point,sample.profile,world.geometry_revision,1,sample.profile)
		check(created.ok,"actual world spawn factory")
		if not created.ok:continue
		var actor: EnemyActor=created.data.actor
		actor.set_process(false)
		view.observe(actor);actor.character_animation.state=D.state(index%4,9);actor.queue_redraw()
		check(actor.character_animation.render_descriptor().version==2,"native actual NPC default/override")
		check(actor.character_animation.equipment_visual.is_empty(),"native NPC no duplicated bow")
		records.append({"id":ids[index],"path":actor.character_animation.atlas.resource_path,"point":str(point.position),"tint":str(definition.tint)})
	var simulation := [host.player.health.current_hp,host.player.current_sp,host.rng.state]
	paused=true
	host.route_camera.position_smoothing_enabled=false;host.control_preferences.ui_scale=1.2
	host._apply_interface_preferences();host._update_hud()
	unit_kind=&"mage";host.player.character_animation.set_equipment_visual(super.cost_visual())
	for row: Array in [["root","root",Vector3(90,0,150)],["ramp","slope",Vector3(340,16,150)],["bridge","bridge",Vector3(120,120,440)]]:
		var point := W.point(row[1],row[2])
		if host.player.world_point().position!=point.position:
			var moved := host.player.move_world_to(point,world.geometry_revision);check(moved.ok,"native canonical route "+String(row[0]))
			if moved.ok:host.player.advance_world(10000.0)
		host.player.character_animation.state=D.state(2,9);host.player.queue_redraw()
		view.sync();host.route_camera.force_update_scroll()
		sample.notice.text="P4 · corpos V2 · lobo/javali/NPCs reais · UI120 · "+String(row[0])+"\nAmostra técnica F1; não publica população."
		await shot("world_"+String(row[0]))
	check(not view.point_visible(sample.lower.world_point().position) and view.point_visible(sample.upper.world_point().position),"native bridge occludes lower floor, upper remains visible")
	var names: Array[StringName]=[&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"elementalist",&"spiritualist",&"sentinel",&"hunter",&"geometer"]
	for index: int in names.size():
		unit_kind=names[index];host.player.set_animation_kind(unit_kind)
		host.player.character_animation.set_equipment_visual(super.cost_visual())
		host.player.character_animation.state=D.state(index%4,9);host.player.queue_redraw()
		sample.notice.text="P4 · corpo "+String(unit_kind)+" sobre ponte · NPCs reais\nAmostra cosmética; transações legais provadas em inventário separado."
		check(host.player.character_animation.render_descriptor().version==2,"world active player body")
		view.sync();host.route_camera.force_update_scroll()
		await shot("world_body_"+String(unit_kind))
	for zoom: float in [0.5,1.0,1.6]:
		host.route_camera.zoom=Vector2.ONE*zoom;host.route_camera.force_update_scroll()
		await shot("world_zoom_"+str(int(zoom*100)))
	check(simulation==[host.player.health.current_hp,host.player.current_sp,host.rng.state],"native body presentation never changes HP/SP/RNG")
	write_json("result.json",{"checks":checks,"failures":failures,"captures":captures,"NPCs":records,"scope":"actual default bodies/occurrences on canonical F1 root/ramp/bridge+occlusion; UI120 and camera50/100/160; cosmetic body samples, not legal equipment grants or mapFPS"})
	paused=false;sample.free();await frames()
	print("E08 final native world: %d checks, %d captures, %d failures" % [checks,captures.size(),failures])
	quit(1 if failures else 0)

func mosaic_motion() -> void:
	root.size=Vector2i(1920,1080)
	root.content_scale_size=Vector2i(1920,1080)
	await process_frame
	check(root.get_visible_rect().size==Vector2(1920,1080),"actual virtual canvas matches capture extent")
	clear_page("P4 · relógio compartilhado ·17 apresentações ·4vistas · repouso/caminhada/ação/dano/morte")
	for child: Node in page.get_children():
		if child is Polygon2D:child.scale=Vector2.ONE*1.5
	var cases: Array[String]=["swordsman","mage","archer","defender","berserker","elementalist","spiritualist","sentinel","hunter","geometer","warrior","gel","beast_master","animal_companion","e08_forest_wolf","e08_forest_boar","npc_archer"]
	var labels: Array[String]=["Espadachim","Mago","Arqueiro","Defendente","Berserker","Elementalista","Espiritualista","Sentinela","Caçadora","Geômetra","Guerreiro NPC","Gelatina NPC","Mestre das Feras NPC","Companheiro invocado","Lobo","Javali","Arqueiro NPC"]
	var views: Array[Dictionary]=[]
	require_default=true
	for row: int in cases.size():
		visual_id=cases[row]
		unit_kind=&"animal_companion" if visual_id in ["e08_forest_wolf","e08_forest_boar"] else (&"archer" if visual_id=="npc_archer" else StringName(visual_id))
		var name := "archer" if visual_id=="npc_archer" else visual_id
		manifest=DirectionalAnimationSet.default_path(StringName(name))
		var visual: Dictionary=super.cost_visual() if row<10 else {}
		caption(labels[row],Vector2(12,68+row*58))
		for direction: int in 4:
			var node := actor(direction,0,visual,Vector2(360+direction*430,110+row*58),1.0)
			views.append({"view":node,"direction":direction})
	for entry: Dictionary in views:
		var node: Preview=entry.view
		var box := node.get_global_transform_with_canvas()*Rect2(-60,-84,120,100)
		check(root.get_visible_rect().encloses(box),"all68 body/attachment extents visible in captured viewport")
	for step: int in 64:
		for entry: Dictionary in views:
			var view: Preview=entry.view;var direction: int=entry.direction
			if step==34:view.animation.state.trigger(&"cast",D.DIRECTIONS[direction],0.8)
			elif step==44:view.animation.state.trigger(&"hurt")
			elif step==48:view.animation.state.trigger(&"death")
			view.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder.path_join("motion_%03d.png" % step))==OK,"actual mixed body motion frame")
		for entry: Dictionary in views:
			var view: Preview=entry.view
			view.animation.state.advance(0.1,D.DIRECTIONS[entry.direction]*8.0 if step>=10 and step<34 else Vector2.ZERO)
	write_json("result.json",{"checks":checks,"failures":failures,"frames":64,"duration_ms_per_frame":100,"bodies":cases,"views_each":4,"scope":"68actual default animations on same visual clock; player equipment cosmetic samples, NPCs baked/unadorned; not mapFPS"})
	print("E08 final motion mosaic: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
