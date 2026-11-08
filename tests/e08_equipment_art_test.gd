extends SceneTree
## Real catalog, PNG geometry, optional body binding and durable transactions.
const F = preload("res://tests/fixtures/e08_directional/content_fixture.gd")
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const MAGE := "res://assets/art/animations/directional/mage/presentation.json"
const INVALID := "res://tests/fixtures/e08_equipment_art/presentation.json"
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	catalog_checks()
	body_checks()
	await transactions()
	print("E08 equipment art: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func catalog_checks() -> void:
	var inventory: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/e08_equipment_redesign/inventory.json"))
	var catalog := BuildContentLoader.pilot()
	var recorded: Array[StringName]=[]
	for row: Dictionary in inventory.heads:recorded.append(StringName(row.id))
	var ids: Array[StringName]=EquipmentArtCatalog.head_ids()
	check(ids.size()==14 and recorded.size()==14,"exact14 existing head IDs")
	ids.pop_back();check(EquipmentArtCatalog.head_ids().size()==14,"detached head ID enumeration")
	for id: StringName in EquipmentArtCatalog.head_ids():
		check(id in recorded,"ID comes from actual inventory "+String(id))
		var definition := catalog.get_definition(&"equipment",id) as EquipmentDefinition
		check(definition!=null and definition.slot==&"head","actual unchanged head definition "+String(id))
		var texture := EquipmentArtCatalog.head_texture(id) as CanvasTexture
		check(texture!=null and texture.get_size()==Vector2(384,96) and texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"four-view head resource/local filter "+String(id))
		if texture==null:continue
		check(texture==EquipmentArtCatalog.head_texture(id),"head cached per resource")
		var image: Image=texture.diffuse_texture.get_image()
		for view: int in 4:
			var cell := image.get_region(Rect2i(view*96,0,96,96));var bounds := cell.get_used_rect()
			check(bounds.has_area() and bounds.size.x/4.0<26.0 and bounds.size.y/4.0<20.0,"painted head smaller than old dome")
		var icon := EquipmentPresentation.icon(definition) as AtlasTexture
		check(icon!=null and icon.atlas==texture and icon.region==Rect2(0,0,96,96),"matching cached front icon")
		var snapshot := BuildSnapshot.new();snapshot.base_class_id=&"mage"
		var item := EquipmentInstance.new();item.instance_id=&"cosmetic_owned";item.definition_id=id
		snapshot.equipment_instances[item.instance_id]=item;snapshot.equipped[&"head"]=item.instance_id
		check(EquipmentAttachmentVisual.describe(snapshot,catalog).head==id,"describe confirmed definition ID; cosmetic fixture does not change eligibility")
		item.definition_id=&"unknown_head"
		check(EquipmentAttachmentVisual.describe(snapshot,catalog).head==&"","unknown confirmed ID is not mapped to pilot")
	for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
		var profile: Dictionary=EquipmentAttachmentVisual.PROFILES[key]
		var texture := EquipmentArtCatalog.prop_texture(key,Vector2(profile.size)) as CanvasTexture
		check(texture!=null and texture.get_size()==Vector2(profile.size)*4.0 and texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"painted prop4x and local filter "+String(key))
		if texture==null:continue
		var image: Image=texture.diffuse_texture.get_image()
		var grip: Vector2i=Vector2i(Vector2(profile.grip)*4.0)
		check(image.get_pixelv(grip).a>0.0,"source alpha at unchanged logical grip")
		check(texture==EquipmentArtCatalog.prop_texture(key,Vector2(profile.size)),"prop texture cached")
		var definition := EquipmentDefinition.new();definition.id=&"icon_fixture";definition.visual_key=key
		check(EquipmentPresentation.icon(definition)==texture,"matching painted prop icon")
	check(not EquipmentArtCatalog.has_head(&"unknown_head") and not EquipmentArtCatalog.has_head(&"apple_arrow_study") and not EquipmentArtCatalog.has_head(&"eggshell_study"),"unknown/studies do not create game head IDs")
	check(EquipmentArtCatalog.head_texture(&"unknown_head")==null,"unknown head has no pilot fallback")
	var missing := "res://assets/art/equipment/headgear/absent_fixture.png"
	check(EquipmentArtCatalog._checked(missing,Vector2(384,96))==null and EquipmentArtCatalog.error_for(missing)=="missing_painted_texture","observable absent-art fallback")
	check(EquipmentArtCatalog._checked(missing,Vector2(384,96))==null,"missing resource cached without repeated load")
	var invalid := "res://tests/fixtures/e08_equipment_art/body.png"
	check(EquipmentArtCatalog._checked(invalid,Vector2(384,96))==null and EquipmentArtCatalog.error_for(invalid)=="invalid_painted_texture","observable invalid-art fallback without guessing a head")
func body_checks() -> void:
	var loaded := DirectionalAnimationSet.load_manifest(MAGE)
	check(loaded.ok,"complete real optional unit validates")
	if not loaded.ok:return
	var bundle: DirectionalAnimationSet=loaded.bundle
	check(bundle.has_bare_head(),"real Mage declares third texture")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MAGE))
	for label: String in ["null","array","hash","outside","missing","shared_body","shared_weaponless"]:
		var bad: Dictionary=raw.duplicate(true)
		match label:
			"null":bad.bare_head=null
			"array":bad.bare_head=[]
			"hash":bad.bare_head.rgba_sha256="0000"
			"outside":bad.bare_head.path="res://outside/bare_head.png"
			"missing":bad.bare_head.path=MAGE.get_base_dir()+"/missing.png"
			"shared_body":bad.bare_head=bad.body.duplicate(true)
			"shared_weaponless":bad.bare_head=bad.weaponless.duplicate(true)
		check(not DirectionalAnimationSet._validate_data(bad,MAGE).ok,"invalid optional rejects whole unit "+label)
	var dependent: Dictionary=raw.duplicate(true);dependent.actor_kind="warrior";dependent.weaponless=null
	check(DirectionalAnimationSet._validate_data(dependent,MAGE).get("detail","")=="bare_head_requires_weaponless","third texture requires equipable body")
	var without: Dictionary=raw.duplicate(true);without.erase("bare_head")
	var accepted := DirectionalAnimationSet._validate_data(without,MAGE)
	check(accepted.ok and not accepted.bundle.has_bare_head() and accepted.bundle.body(true,true)==bundle.body(true),"absent optional preserves complete previous body")
	var actor := CharacterAnimation.new();actor.configure(&"mage");actor.set_equipment_visual({"main_hand":&"staff"})
	var original: Texture2D=actor.atlas;var state: CombatAnimationState=actor.state
	check(original==bundle.body(true),"unequipped Mage uses original hat body")
	actor.set_equipment_visual({"main_hand":&"staff","head":&"unknown_head"})
	check(actor.atlas==original and actor.render_descriptor().head.is_empty(),"unknown head preserves original artwork")
	actor.set_equipment_visual({"main_hand":&"staff","head":&"pilot_head"})
	var bare: Texture2D=actor.atlas
	check(bare==bundle.body(true,true) and bare.resource_path.ends_with("/bare_head.png"),"known head selects bare variant")
	check(not actor.set_directional_manifest(INVALID).ok and actor.atlas==bare and actor.state==state,"actual invalid optional install is atomic")
	var fit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/e08_head_fit/mage/calibration.json"))
	var original_image: Image=original.get_image();var bare_image: Image=bare.get_image()
	for index: int in 64:
		var region := Rect2i(index%4*64,index/4*64,64,64)
		var before := original_image.get_region(region);var after := bare_image.get_region(region)
		var record: Dictionary=fit.frames[index];var area: Array=record.head_region
		var confined := true
		for y: int in 64:
			for x: int in 64:
				var authorized: bool=x>=area[0] and x<area[2] and y>=area[1] and y<area[3]
				for protected: Array in record.protections:
					if x>=protected[0] and x<protected[2] and y>=protected[1] and y<protected[3]:authorized=false
				if not authorized:
					var a := before.get_pixel(x,y);var b := after.get_pixel(x,y)
					confined=confined and ((a.a==0 and b.a==0) or a==b)
		check(confined,"all changed pixels confined to authored head area; protected arms preserved")
		check(before.get_used_rect().end.y==after.get_used_rect().end.y,"bare head preserves exact ground")
		if index%16<14:
			var frame: Dictionary=bundle.frame(index)
			for slot: String in ["main_hand","off_hand"]:
				var fingers: Array=frame.slots[slot].fingers
				var crop := Rect2i(fingers[0],fingers[1],fingers[2],fingers[3])
				check(before.get_region(crop).get_data()==after.get_region(crop).get_data(),"protected actual finger crop byte-identical")
	var portrait := InventoryCharacterPreview.new();root.add_child(portrait)
	for id: StringName in EquipmentArtCatalog.head_ids():
		var visual := {"head":id,"main_hand":&"staff","off_hand":&"shield"}
		actor.set_equipment_visual(visual);portrait.configure(&"mage",visual)
		for direction: int in 4:
			for pose: int in 16:
				actor.state=D.state(direction,pose);portrait._animation.state=D.state(direction,pose)
				var descriptor := actor.render_descriptor()
				check(descriptor==portrait._animation.render_descriptor() and descriptor.head.key==id,"14IDs/64poses shared actual descriptor")
				var transform := EquipmentHeadVisual.resolved_transform(descriptor,1.6)
				check(transform.x.is_equal_approx(Vector2.RIGHT.rotated(float(descriptor.head.angle))*1.6),"authored west view has no second mirror")
				if pose>=14:check(F.head_bottom(descriptor)<=0.05,"all14 painted heads remain above corpse ground")
				for placed: Dictionary in descriptor.equipment:
					if pose>=14:check(absf(F.equipment_bottom(placed))<0.05 if pose==15 else F.equipment_bottom(placed)<=0.05,"painted PNG logical death support")
	check(actor.death_copy().atlas==bare,"death copy keeps selected optional texture")
	DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
	check(DirectionalAnimationSet.for_texture(bare)!=null,"third texture reconstructs catalog by persisted path")
	actor.set_equipment_visual({"main_hand":&"staff"})
	check(actor.atlas==original,"unequip restores exact original atlas")
	portrait.free()
func equip(host: RunController,instance_id: StringName,request: String) -> Dictionary:
	var intent := host.build_service.context();intent.merge({"request_id":request,"kind":&"equip","slot":&"head","equipment_instance_id":instance_id},true)
	return host.build_service.preview_change(intent)
func transactions() -> void:
	var f := F.make(&"mage","painted_gear");check(f.ok,"isolated real Mage profile")
	if not f.ok:return
	var facade: ProfileFacade=f.facade
	var helmet := PlaytestProfileAdmin.grant(facade,"head",facade.current_profile().revision,f.a,&"equipment",&"pilot_head")
	var illegal := PlaytestProfileAdmin.grant(facade,"other_origin",facade.current_profile().revision,f.a,&"equipment",&"class_set_swordsman_head")
	check(helmet.ok and illegal.ok,"owned legal and origin-ineligible fixtures granted explicitly")
	var started := facade.start_run("start",facade.current_profile().revision);check(started.ok,"real durable run")
	if not started.ok:return
	RunController.pending_run_state=started.run_state;RunController.pending_run_facade=facade
	var host := RunController.new();root.add_child(host);host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false
	var original: Texture2D=host.player.character_animation.atlas
	var before := [host.player.health.current_hp,host.player.current_sp,host.rng.state,host.player.position]
	var denied: Dictionary=equip(host,StringName(illegal.equipment_instance_id),"illegal_equip")
	check(not denied.ok and host.player.character_animation.atlas==original,"cosmetic art cannot grant gameplay eligibility")
	var proposal: Dictionary=equip(host,StringName(helmet.equipment_instance_id),"equip")
	check(proposal.ok and host.build_service.commit_change(proposal.intent).ok,"actual durable equip")
	var actor: CharacterAnimation=host.player.character_animation;actor.state=D.state(3,9)
	check(actor.atlas.resource_path.ends_with("/bare_head.png") and actor.render_descriptor().head.key==&"pilot_head","actual equipped body/head/action bridge")
	var descriptor := actor.render_descriptor()
	var barrier := SnapshotTickBarrier.new();paused=true
	check(barrier.acquire(host).ok,"real snapshot barrier")
	var captured := SnapshotRegistry.new().capture(host,barrier);check(captured.ok,"existing schema captures optional body")
	if captured.ok:
		DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
		var restored := SnapshotRegistry.new().restore(captured.snapshot,facade);check(restored.ok,"cold restore resolves optional texture by path")
		if restored.ok:
			var copy: RunController=restored.root
			check(copy.player.character_animation.render_descriptor()==descriptor,"cold restored head/body/phase/direction exact")
			check(copy.player.character_animation.death_copy().atlas==actor.atlas and copy.player.character_animation.death_copy().state.direction_index()==3,"restored death copy keeps optional body and west")
			copy.free()
	barrier.release();paused=false
	var intent := host.build_service.context();intent.merge({"request_id":"remove","kind":&"unequip","slot":&"head"},true)
	proposal=host.build_service.preview_change(intent)
	check(proposal.ok and host.build_service.commit_change(proposal.intent).ok,"actual durable unequip")
	check(host.player.character_animation.atlas==original and host.player.character_animation.render_descriptor().head.is_empty(),"real removal restores original appearance")
	check(before==[host.player.health.current_hp,host.player.current_sp,host.rng.state,host.player.position],"cosmetic transactions preserve simulation state")
	host.free();await process_frame
