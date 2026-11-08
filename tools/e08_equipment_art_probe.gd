extends "res://tools/e08_directional_unit_probe.gd"
## Native evidence consumes the same renderer and descriptor; no gameplay eligibility bypass.
func run() -> void:
	folder=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);unit_kind=&"mage";require_default=true
	manifest=F.stage_path(unit_kind);display_label="Mago"
	if OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1]=="motion":
		await gear_motion();return
	var loaded := DirectionalAnimationSet.load_manifest(DirectionalAnimationSet.default_path(&"mage"))
	check(loaded.ok and loaded.bundle.has_bare_head(),"real default optional body")
	if not loaded.ok:quit(1);return
	clear_page("Mago · original com chapéu, sem equipamento de cabeça · 64 poses")
	for direction: int in 4:
		for pose: int in 16:actor(direction,pose,{},Vector2(42+pose*78,145+direction*160))
	await shot("01_original_64")
	# A diagnostic body quad uses the actual equipped descriptor's texture, crop and origin.
	# It exposes hair under the accessory; it does not introduce another selection policy.
	clear_page("Mago · base de cabelo da variante equipada · descriptor real · 64 poses")
	for direction: int in 4:
		for pose: int in 16:
			var animation := CharacterAnimation.new();animation.configure(&"mage");animation.set_equipment_visual({"head":&"pilot_head"});animation.state=D.state(direction,pose)
			var descriptor := animation.render_descriptor()
			var texture := AtlasTexture.new();texture.atlas=descriptor.atlas;texture.region=descriptor.region
			var sprite := Sprite2D.new();sprite.texture=texture;sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position=Vector2(42+pose*78,145+direction*160)+descriptor.rect.position;page.add_child(sprite)
			check(descriptor.atlas.resource_path.ends_with("/bare_head.png"),"diagnostic from actual optional binding")
	await shot("02_bare_head_64")
	for id: StringName in EquipmentArtCatalog.head_ids():
		clear_page("Mago · "+String(id)+" · 64 poses · quatro desenhos de cabeça próprios · tamanho real")
		for direction: int in 4:
			for pose: int in 16:
				var view := actor(direction,pose,{"head":id,"main_hand":&"staff"},Vector2(42+pose*78,145+direction*160))
				check(view.animation.atlas.resource_path.ends_with("/bare_head.png") and view.animation.render_descriptor().head.key==id,"real head ID selects hair and authored graphic")
		await shot("head_"+String(id)+"_64")
	for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
		clear_page("Mago · "+String(key)+" pintado · 64 poses · mesmo grip e tamanho lógicos")
		for direction: int in 4:
			for pose: int in 16:actor(direction,pose,{"head":&"pilot_head","main_hand":key,"off_hand":&"shield","arms":&"wooden_beads"},Vector2(42+pose*78,145+direction*160))
		await shot("prop_"+String(key)+"_64")
	for direction: int in 4:
		clear_page("Mago · calibração ampliada · "+["sul","norte","leste","oeste"][direction]+" · cajado/escudo/elmo")
		for pose: int in 16:
			var view := actor(direction,pose,{"head":&"pilot_head","main_hand":&"staff","off_hand":&"shield"},Vector2(150+(pose%8)*140,300+(pose/8)*290),2.0,true)
			check(view.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"body canvas remains nearest; accessories use own filter")
		await shot("calibration_"+str(direction))
	clear_page("Espiritualista · controle com cabelo exposto · sem terceira textura")
	unit_kind=&"spiritualist"
	for direction: int in 4:
		for column: int in 5:actor(direction,[0,5,9,14,15][column],{"head":&"pilot_head","main_hand":&"staff"},Vector2(150+column*240,175+direction*160),2.0)
	await shot("spiritualist_control")
	unit_kind=&"mage"
	clear_page("Mago · câmera50/100/160 · UI120 independente · anexos com filtro local")
	var ui := Control.new();overlay.add_child(ui);GuiMetrics.set_scale(1.2,ui)
	var label := Label.new();label.text="Interface 120%";label.position=Vector2(12,42);ui.add_child(label)
	var camera := Camera2D.new();camera.position=Vector2(640,360);page.add_child(camera);camera.make_current()
	for direction: int in 4:actor(direction,9,{"head":&"pilot_head","main_hand":&"staff","off_hand":&"prismatic_focus"},Vector2(450+direction*125,410))
	for zoom: float in [0.5,1.0,1.6]:
		camera.zoom=Vector2.ONE*zoom;camera.force_update_scroll();await frames()
		check(ui.get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2.ONE*1.2),"UI120 independent of actual camera")
		await shot("camera_"+str(int(zoom*100)))
	page.free();overlay.free();await real_inventory()
	write_json("result.json",{"checks":checks,"failures":failures,"captures":captures,"head_ids":14,"prop_keys":7,"poses_each":64,"binding":"default Mage bare head when known head equipped; original restored on removal","scope":"native renderer/body/filter/heads/props/death/real owned profile+inventory; gallery IDs are cosmetic samples, not eligibility grants"})
	print("Equipment native: %d checks, %d captures, %d failures" % [checks,captures.size(),failures]);quit(1 if failures else 0)
func gear_motion() -> void:
	clear_page("Mago · troca cosmética de cabeça no mesmo relógio · original, elmo e capuz próprio")
	var views: Array[Preview]=[]
	for direction: int in 4:views.append(actor(direction,0,{"head":&"pilot_head","main_hand":&"staff"},Vector2(180+direction*300,430),3.0))
	for step: int in 64:
		for direction: int in 4:
			var animation: CharacterAnimation=views[direction].animation
			if step==12:animation.set_equipment_visual({"head":&"class_set_mage_head","main_hand":&"staff"})
			elif step==24:animation.set_equipment_visual({"main_hand":&"staff"})
			elif step==32:animation.set_equipment_visual({"head":&"pilot_head","main_hand":&"staff"})
			if step==34:animation.state.trigger(&"cast",D.DIRECTIONS[direction],0.8)
			elif step==44:animation.state.trigger(&"hurt")
			elif step==48:animation.state.trigger(&"death")
			views[direction].queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder.path_join("motion_%03d.png" % step))==OK,"native motion frame")
		for direction: int in 4:views[direction].animation.state.advance(0.1,D.DIRECTIONS[direction]*8.0 if step>=10 and step<34 else Vector2.ZERO)
	write_json("result.json",{"frames":64,"duration_ms_per_frame":100,"checks":checks,"failures":failures,"scope":"native frames from same visual clock; equipment transitions; no map FPS claim"})
	print("Equipment motion: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
