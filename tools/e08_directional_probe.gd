extends SceneTree
## Renderer proof with explicit geometric test assets; no artistic acceptance.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
class Preview extends Node2D:
	var animation: CharacterAnimation
	func _init() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void: animation.draw_on(self)
var folder := ""
var checks := 0
var failures := 0
var captures: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func settle() -> void:
	for i: int in 5:await process_frame
func shot(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK,"capture "+name)
	captures.append(name+".png")
func run() -> void:
	folder=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720)
	var backdrop := CanvasLayer.new();backdrop.layer=-1;root.add_child(backdrop)
	var background := ColorRect.new();background.size=Vector2(1280,720);background.color=Color("304a52");backdrop.add_child(background)
	var world := Node2D.new();root.add_child(world)
	for direction: int in 4:
		for pose: int in 16:
			var preview := Preview.new();preview.animation=D.animation(direction,pose);preview.position=Vector2(40+pose*78,135+direction*150)
			world.add_child(preview)
			check(preview.animation.render_descriptor().frame==direction*16+pose,"64 native resolved poses")
	var ui_layer := CanvasLayer.new();root.add_child(ui_layer)
	var ui := Control.new();ui_layer.add_child(ui);GuiMetrics.set_scale(1.2,ui)
	var title := Label.new();title.text="TESTE GEOMÉTRICO · 64 poses · sul / norte / leste / oeste · não é arte de produto";ui.add_child(title)
	await shot("synthetic_64_poses")
	world.free()
	world=Node2D.new();root.add_child(world)
	var camera := Camera2D.new();camera.position=Vector2(640,360);world.add_child(camera);camera.make_current()
	for direction: int in 4:
		var preview := Preview.new();preview.animation=D.animation(direction,8);preview.position=Vector2(430+direction*140,400);world.add_child(preview)
	var zooms: Array[float] = []
	for zoom: float in [0.5,1.0,1.6]:
		camera.zoom=Vector2.ONE*zoom;camera.force_update_scroll();await settle()
		check(ui.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE*1.2) and ui.get_global_transform_with_canvas().origin.is_zero_approx(),"camera zoom independent of UI120 screen transform")
		zooms.append(camera.zoom.x);await shot("synthetic_camera_%d" % int(zoom*100))
	world.free();ui_layer.free();backdrop.free()
	# Real profile/run/inventory with the existing production Mage and pilot head.
	var f := F.make("directional_native_helmet");var facade: ProfileFacade = f.facade
	var grant := PlaytestProfileAdmin.grant(facade,"helmet",facade.current_profile().revision,f.a,&"equipment",&"pilot_head")
	check(grant.ok,"owned helmet")
	check(PlaytestProfileAdmin.grant(facade,"max",facade.current_profile().revision,f.a,&"max_levels").ok,"explicit admin levels fixture")
	check(PlaytestProfileAdmin.grant(facade,"skills",facade.current_profile().revision,f.a,&"unlock_skills").ok,"explicit admin icons fixture")
	var catalog := ProfileCatalog.pilot();var character := facade.current_profile().character_by_id(f.a)
	var summary := CharacterProgression.summary(character,catalog)
	var snapshot := BuildSnapshot.from_character(character,summary.base_level,summary.job_level,summary.effective_skill_ranks,catalog.skill_ids_for_identity(character.base_class_id,character.evolution_id),catalog)
	var active := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE);var slots := ActionBarLayout.empty()
	for i: int in active.size():slots=ActionBarLayout.assign(slots,active[i],i)
	if not active.is_empty():slots=ActionBarLayout.move(slots,active.size()-1,23)
	check(facade.update_action_slots("layout",facade.current_profile().revision,f.a,slots).ok,"explicit legal icon layout")
	var started := facade.start_run("start",facade.current_profile().revision);check(started.ok,"real run")
	if not started.ok:quit(1);return
	RunController.pending_run_state=started.run_state;RunController.pending_run_facade=facade
	var host := RunController.new();root.add_child(host);host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false;GuiMetrics.set_scale(1.2,host.ui_root)
	var intent := host.build_service.context();intent.merge({"request_id":"equip","kind":&"equip","slot":&"head","equipment_instance_id":StringName(grant.equipment_instance_id)},true)
	var result := host.build_service.preview_change(intent);check(result.ok,"real equip preview")
	if not result.ok:print(result);host.free();quit(1);return
	check(host.build_service.commit_change(result.intent).ok,"real equip commit")
	host._update_hud()
	var panel := RunInventoryPanel.new();host.ui_root.add_child(panel);panel.configure(host);await settle()
	check(panel.character_preview._animation.equipment_visual.head==&"pilot_head","actual inventory uses shared head projection")
	check(host.player.character_animation.render_descriptor().head==panel.character_preview._animation.render_descriptor().head,"actual actor/portrait agree on helmet")
	await shot("production_mage_inventory_helmet_120")
	panel.hide();await shot("production_mage_world_helmet_120")
	host.free();await settle()
	var data := {"checks":checks,"failures":failures,"captures":captures,"camera_zooms":zooms,"ui_scale":1.2,"viewport":[1280,720],"synthetic":true,"production_helmet_fixture":"actual isolated Mage profile; durable equip; production art unchanged"}
	var file := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"  ",true));file.close()
	print("E08 directional native: %d checks, %d captures, %d failures" % [checks,captures.size(),failures])
	quit(1 if failures else 0)
