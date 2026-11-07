extends SceneTree
## Real staged art; visual fixtures do not change equipment eligibility/gameplay.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const MANIFEST := "res://assets/art/e08_characters/directional/spiritualist/presentation.json"
class Preview extends Node2D:
	var animation: CharacterAnimation
	var markers := false
	var draw_cpu_us := 0
	func _init() -> void: texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var began := Time.get_ticks_usec()
		animation.draw_on(self)
		draw_cpu_us=Time.get_ticks_usec()-began
		if markers:
			var descriptor := animation.render_descriptor()
			for placed: Dictionary in descriptor.equipment:
				draw_rect(Rect2(descriptor.origin+placed.finger_rect.position,placed.finger_rect.size),Color.GREEN_YELLOW,false,0.5)
				draw_circle(placed.point,0.7,Color.RED)
			draw_line(Vector2(-12,0),Vector2(12,0),Color.AQUA,0.5)
var folder := ""
var checks := 0
var failures := 0
var captures: Array[String] = []
var page: Node2D
var overlay: CanvasLayer
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func frames(count: int = 5) -> void:
	for i: int in count: await process_frame
func caption(text: String, at: Vector2 = Vector2(16,12)) -> void:
	var label := Label.new();label.text=text;label.position=at;overlay.add_child(label)
func clear_page(title: String) -> void:
	if is_instance_valid(page): page.free()
	if is_instance_valid(overlay): overlay.free()
	page=Node2D.new();root.add_child(page)
	overlay=CanvasLayer.new();root.add_child(overlay)
	var bg := Polygon2D.new(); bg.color=Color("d2c7ab");bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(640,0),Vector2(640,720),Vector2(0,720)]);page.add_child(bg)
	bg=Polygon2D.new();bg.color=Color("1e303b");bg.polygon=PackedVector2Array([Vector2(640,0),Vector2(1280,0),Vector2(1280,720),Vector2(640,720)]);page.add_child(bg)
	caption(title)
func actor(direction: int,pose: int,visual: Dictionary,point: Vector2,scale_value: float = 1.0,markers: bool = false) -> Preview:
	var view := Preview.new();view.animation=CharacterAnimation.new();view.animation.configure(&"spiritualist")
	check(view.animation.set_directional_manifest(MANIFEST).ok,"bind real complete content")
	view.animation.set_equipment_visual(visual);view.animation.state=D.state(direction,pose)
	view.position=point;view.scale=Vector2.ONE*scale_value;view.markers=markers;page.add_child(view)
	check(view.animation.render_descriptor().frame==direction*16+pose,"native authored frame")
	return view
func shot(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"capture "+name)
	captures.append(name+".png")
func run() -> void:
	folder=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,720)
	if OS.get_cmdline_user_args().size()>2 and OS.get_cmdline_user_args()[1]=="author":
		await author(OS.get_cmdline_user_args()[2]);return
	if OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1]=="motion":
		await motion();return
	if OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1].begins_with("cost"):
		await cost(OS.get_cmdline_user_args()[1]);return
	var loaded := DirectionalAnimationSet.load_manifest(MANIFEST)
	check(loaded.ok,"real content manifest validates")
	if not loaded.ok: print(loaded);quit(1);return
	clear_page("Espiritualista · arte em staging · 64 poses · sul / norte / leste / oeste · tamanho real")
	for direction: int in 4:
		for pose: int in 16: actor(direction,pose,{},Vector2(42+pose*78,145+direction*160))
	await shot("01_all_64_bare")
	clear_page("Espiritualista · quatro vistas · repouso / caminhada / magia / dano / morte · ampliação 2×")
	var samples: Array[int]=[0,5,9,12,15]
	for direction: int in 4:
		caption(["Sul","Norte","Leste","Oeste"][direction],Vector2(15,135+direction*160))
		for column: int in samples.size():actor(direction,samples[column],{},Vector2(150+column*240,175+direction*160),2.0)
	await shot("01b_four_views_gallery")
	for pose: int in [0,9]:
		clear_page("Espiritualista · anexos existentes · amostra visual (não altera elegibilidade) · pose "+str(pose))
		for row: int in EquipmentAttachmentVisual.SUPPORTED.size():
			var key: StringName = EquipmentAttachmentVisual.SUPPORTED[row]
			for direction: int in 4:
				actor(direction,pose,{"main_hand":key,"off_hand":&"shield","arms":&"wooden_beads","head":&"pilot_head"},Vector2(150+direction*300,145+row*82),1.0)
			caption(String(key),Vector2(12,103+row*82))
		await shot("02_equipment_pose_"+str(pose))
	for direction: int in 4:
		clear_page("Espiritualista · calibração ampliada · "+["sul","norte","leste","oeste"][direction]+" · contorno verde=recorte, vermelho=grip")
		for pose: int in 16:
			actor(direction,pose,{"main_hand":&"staff","off_hand":&"shield","head":&"pilot_head"},Vector2(150+(pose%8)*140,300+(pose/8)*290),2.0,true)
		await shot("03_calibration_"+str(direction))
	clear_page("Espiritualista · zoom real de câmera · UI120 independente")
	var ui := Control.new();overlay.add_child(ui);GuiMetrics.set_scale(1.2,ui)
	var marker := Label.new();marker.text="Interface 120%";marker.position=Vector2(12,42);ui.add_child(marker)
	var camera := Camera2D.new();camera.position=Vector2(640,360);page.add_child(camera);camera.make_current()
	for direction: int in 4: actor(direction,9,{"main_hand":&"staff","off_hand":&"prismatic_focus","head":&"pilot_head"},Vector2(450+direction*125,410))
	for zoom: float in [0.5,1.0,1.6]:
		camera.zoom=Vector2.ONE*zoom;camera.force_update_scroll();await frames()
		check(ui.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE*1.2),"camera independent UI120")
		await shot("04_camera_"+str(int(zoom*100)))
	page.free();overlay.free()
	await real_inventory()
	var data := {"checks":checks,"failures":failures,"captures":captures,"real_content_manifest":MANIFEST,"art_status":"staging, technical visual inspection required","ui_scale":1.2,"scope":"64 poses; supported cosmetic keys; real durable Spiritualist/helmet inventory; not gameplay eligibility or full campaign"}
	write_json("result.json",data)
	print("E08 directional art native: %d checks, %d captures, %d failures" % [checks,captures.size(),failures])
	quit(1 if failures else 0)
func real_inventory() -> void:
	var f := F.make("p4_art_inventory");var facade: ProfileFacade=f.facade
	check(PlaytestProfileAdmin.grant(facade,"levels",facade.current_profile().revision,f.a,&"max_levels").ok,"explicit admin levels")
	check(facade.change_evolution("evolve",facade.current_profile().revision,f.a,&"spiritualist").ok,"actual Spiritualist")
	check(PlaytestProfileAdmin.grant(facade,"skills",facade.current_profile().revision,f.a,&"unlock_skills").ok,"explicit admin skill fixture")
	var catalog := ProfileCatalog.pilot();var character := facade.current_profile().character_by_id(f.a)
	var summary := CharacterProgression.summary(character,catalog)
	var snapshot := BuildSnapshot.from_character(character,summary.base_level,summary.job_level,summary.effective_skill_ranks,catalog.skill_ids_for_identity(character.base_class_id,character.evolution_id),catalog)
	var active := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE);var slots := ActionBarLayout.empty()
	for i: int in active.size():slots=ActionBarLayout.assign(slots,active[i],i)
	check(facade.update_action_slots("layout",facade.current_profile().revision,f.a,slots).ok,"explicit legal admin icon layout")
	var grant := PlaytestProfileAdmin.grant(facade,"head",facade.current_profile().revision,f.a,&"equipment",&"pilot_head")
	check(grant.ok,"owned helmet")
	var started := facade.start_run("start",facade.current_profile().revision);check(started.ok,"real run")
	if not started.ok:return
	RunController.pending_run_state=started.run_state;RunController.pending_run_facade=facade
	var host := RunController.new();root.add_child(host);host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false;GuiMetrics.set_scale(1.2,host.ui_root)
	var intent := host.build_service.context();intent.merge({"request_id":"equip","kind":&"equip","slot":&"head","equipment_instance_id":StringName(grant.equipment_instance_id)},true)
	var proposed := host.build_service.preview_change(intent)
	check(proposed.ok and host.build_service.commit_change(proposed.intent).ok,"durable helmet equip")
	check(host.player.character_animation.render_descriptor().version==2,"actual actor automatically consumes promoted art")
	host._update_hud()
	var panel := RunInventoryPanel.new();host.ui_root.add_child(panel);panel.configure(host);await frames()
	check(panel.character_preview._animation.render_descriptor().version==2,"actual inventory automatically consumes promoted art")
	panel.character_preview.queue_redraw();panel.character_preview._sprite.queue_redraw()
	check(host.player.character_animation.render_descriptor().atlas==panel.character_preview._animation.render_descriptor().atlas,"same real unit in world/inventory")
	await shot("05_actual_inventory_ui120");panel.hide();await shot("06_actual_world_ui120")
	intent=host.build_service.context();intent.merge({"request_id":"remove-head","kind":&"unequip","slot":&"head"},true)
	proposed=host.build_service.preview_change(intent)
	check(proposed.ok and host.build_service.commit_change(proposed.intent).ok,"actual helmet unequip")
	panel.free();panel=RunInventoryPanel.new();host.ui_root.add_child(panel);panel.configure(host);await frames()
	check(panel.character_preview._animation.render_descriptor().version==2 and panel.character_preview._animation.render_descriptor().head.is_empty(),"real unequip keeps promoted identity and removes head art")
	await shot("07_actual_inventory_uncovered_ui120");panel.hide();await shot("08_actual_world_uncovered_ui120")
	host.free();await frames()
func write_json(name: String,data: Dictionary) -> void:
	var file := FileAccess.open(folder.path_join(name),FileAccess.WRITE);file.store_string(JSON.stringify(data,"  ",true));file.close()
func quantile(values: Array[float],fraction: float) -> float:
	var sorted := values.duplicate();sorted.sort();return sorted[mini(sorted.size()-1,int(floor((sorted.size()-1)*fraction)))]
func cost(mode: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var crowd: Array[Preview]=[]
	for i: int in 96:
		var view := Preview.new();view.animation=CharacterAnimation.new();view.animation.configure(&"spiritualist")
		if mode=="cost_content":
			var applied := view.animation.set_directional_manifest(MANIFEST)
			if not applied.ok:push_error(str(applied));quit(1);return
		view.animation.set_equipment_visual({"main_hand":&"staff","off_hand":&"wooden_beads","head":&"pilot_head"})
		view.position=Vector2(45+(i%16)*78,100+(i/16)*100);root.add_child(view);crowd.append(view)
	await frames(90)
	var windows: Array[Dictionary]=[]
	for moving: bool in [true,false]:
		for window: int in 3:
			var samples: Array[float]=[];var cpu: Array[float]=[];var began := Time.get_ticks_usec();var previous := began
			while Time.get_ticks_usec()-began<3000000:
				await process_frame
				var now := Time.get_ticks_usec();var elapsed := (now-previous)/1000000.0;samples.append((now-previous)/1000.0);previous=now
				var draw_cpu := 0
				for view: Preview in crowd:
					draw_cpu+=view.draw_cpu_us;view.animation.state.advance(elapsed,Vector2.RIGHT*80.0*elapsed if moving else Vector2.ZERO);view.queue_redraw()
				cpu.append(draw_cpu/1000.0)
			windows.append({"moving":moving,"window":window,"samples_ms":samples,"draw_cpu_samples_ms":cpu,"median_ms":quantile(samples,0.5),"p95_ms":quantile(samples,0.95),"max_ms":samples.max(),"cpu_median_ms":quantile(cpu,0.5),"cpu_p95_ms":quantile(cpu,0.95)})
	var loaded := Performance.get_monitor(Performance.MEMORY_STATIC)
	for view: Preview in crowd:view.free()
	crowd.clear();await frames(90)
	write_json("result.json",{"mode":mode,"actors":96,"windows":windows,"static_before":before,"static_loaded":loaded,"static_after_clear":Performance.get_monitor(Performance.MEMORY_STATIC),"device":RenderingServer.get_video_adapter_name(),"scope":"same runtime/engine/fixture, forced redraw; no map FPS certification"})
	print("Art cost ",mode," windows=",windows.size());quit()

func author(source_png: String) -> void:
	# Authoring contact sheet only: exact source raster, no pixel changes or approval.
	root.content_scale_size=Vector2i(1100,1000);root.size=Vector2i(1100,1000)
	var texture := ImageTexture.create_from_image(Image.load_from_file(source_png))
	for direction: int in 4:
		if is_instance_valid(page):page.free()
		if is_instance_valid(overlay):overlay.free()
		page=Node2D.new();root.add_child(page);overlay=CanvasLayer.new();root.add_child(overlay)
		var bg := ColorRect.new();bg.size=Vector2(1100,1000);bg.color=Color("263340");overlay.add_child(bg)
		caption("Autoria de encaixes · "+["sul","norte","leste","oeste"][direction]+" · pixels reais ampliados 3× · sem aprovação",Vector2(15,8))
		for pose: int in 16:
			var origin := Vector2(50+(pose%4)*260,65+(pose/4)*230)
			var crop := AtlasTexture.new();crop.atlas=texture;crop.region=Rect2(pose%4*64,(direction*4+pose/4)*64,64,64)
			var view := TextureRect.new();view.texture=crop;view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;view.position=origin;view.size=Vector2(192,192);view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;overlay.add_child(view)
			caption("frame %d" % (direction*16+pose),origin+Vector2(0,-24))
			for tick: int in range(0,64,8):
				var line := ColorRect.new();line.color=Color(0.5,0.8,1,0.12);line.position=origin+Vector2(tick*3,0);line.size=Vector2(1,192);overlay.add_child(line)
				line=ColorRect.new();line.color=Color(0.5,0.8,1,0.12);line.position=origin+Vector2(0,tick*3);line.size=Vector2(192,1);overlay.add_child(line)
				caption(str(tick),origin+Vector2(tick*3,-12))
				caption(str(tick),origin+Vector2(-25,tick*3-6))
		await shot("author_"+str(direction))
	write_json("result.json",{"scope":"authorship magnification only, not validated gameplay","captures":captures})
	quit()

func motion() -> void:
	clear_page("Espiritualista · prévia do relógio visual · repouso, caminhada, magia, dano e morte")
	var views: Array[Preview]=[]
	for direction: int in 4:
		views.append(actor(direction,0,{},Vector2(180+direction*300,430),3.0))
		caption(["Sul","Norte","Leste","Oeste"][direction],Vector2(160+direction*300,470))
	for step: int in 64:
		for direction: int in 4:
			var state := views[direction].animation.state
			if step==34:state.trigger(&"cast",D.DIRECTIONS[direction],0.8)
			elif step==44:state.trigger(&"hurt")
			elif step==48:state.trigger(&"death")
			views[direction].queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder.path_join("motion_%03d.png" % step))==OK,"motion renderer frame")
		for direction: int in 4:
			views[direction].animation.state.advance(0.1,D.DIRECTIONS[direction]*8.0 if step>=10 and step<34 else Vector2.ZERO)
	write_json("result.json",{"frames":64,"duration_ms_per_frame":100,"checks":checks,"failures":failures,"scope":"same visual clock advanced in 0.1s steps; PNGs from native renderer; animation preview, not map FPS measurement"})
	print("Art motion: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
