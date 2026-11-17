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
	painted_icon_checks()
	body_checks()
	head_fit_checks()
	await transactions()
	print("E08 equipment art: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
## E08 C1-art (14/11): every piece cut from the second Codex batch resolves to its own painted
## icon for the real catalog definition; heads/props keep priority; unknown ids keep the SVG.
func painted_icon_checks() -> void:
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/icons/equipment/painted/manifest.json"))
	check(manifest is Dictionary and (manifest as Dictionary).get("items") is Array,"painted icon manifest parses")
	if not manifest is Dictionary:return
	var catalog := BuildContentLoader.pilot()
	var items: Array=manifest.items
	check(items.size()==44,"44 painted equipment icons (%d)" % items.size())
	var seen: Dictionary={}
	for row: Dictionary in items:
		var id := StringName(row.id)
		check(not seen.has(id),"painted icon listed once "+String(id));seen[id]=true
		var path := "res://assets/art/icons/equipment/painted/%s.png" % id
		check(FileAccess.get_sha256(path)==String(row.png_sha256),"painted icon hash "+String(id))
		var definition := catalog.get_definition(&"equipment",id) as EquipmentDefinition
		check(definition!=null and definition.slot!=&"head" and definition.slot!=&"main_hand","painted icon names a real non-head item "+String(id))
		if definition==null:continue
		var icon := EquipmentPresentation.icon(definition)
		check(icon!=null and icon==EquipmentPresentation.painted_icon(id) and icon.get_size()==Vector2(128,128),"item shows its painted 128px icon "+String(id))
	for legacy: StringName in EquipmentPresentation.PAINTED_ICON_ALIASES:
		var target: StringName=EquipmentPresentation.PAINTED_ICON_ALIASES[legacy]
		check(seen.has(target) and EquipmentPresentation.painted_icon(legacy)==EquipmentPresentation.painted_icon(target),"legacy item reuses its arena icon "+String(legacy))
	var stray := EquipmentDefinition.new();stray.id=&"icon_fixture_without_art";stray.item_kind=&"armor";stray.slot=&"torso"
	check(EquipmentPresentation.painted_icon(stray.id)==null and EquipmentPresentation.icon(stray)==load("res://assets/art/icons/equipment/plate.svg"),"item without painted art keeps the surface SVG")
	var head := catalog.get_definition(&"equipment",&"pilot_head") as EquipmentDefinition
	check(head!=null and EquipmentPresentation.icon(head) is AtlasTexture,"heads keep their four-view icon")
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
				# P7-C6: the crown-seat fit scales the piece to the measured head (Terra C6), so the x basis is
				# the rotated unit vector times 1.6 times the fitted horizontal scale. The pin still proves the
				# authored west view has no second mirror (positive x scale, no flip).
				var fitted_x := float(EquipmentHeadVisual.fit(descriptor).scale.x)
				check(fitted_x>0.0 and transform.x.is_equal_approx(Vector2.RIGHT.rotated(float(descriptor.head.angle))*1.6*fitted_x),"authored west view has no second mirror")
				# The old oracle F.head_bottom models the legacy anchor; the fitted equivalent uses the same source-PNG bounds.
				if pose>=14:check(head_bottom_fitted(descriptor)<=0.05,"all14 painted heads remain above corpse ground")
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

## Source-PNG oracle of the lowest painted head pixel under the fitted placement (relative to the ground pivot).
static func head_bottom_fitted(descriptor: Dictionary) -> float:
	var head: Dictionary=descriptor.head
	var texture := load("res://assets/art/equipment/headgear/%s.png" % head.key) as Texture2D
	var pixels := texture.get_image().get_region(Rect2i(int(head.view)*96,0,96,96)).get_used_rect()
	var bounds := Rect2(Vector2(pixels.position)/4.0,Vector2(pixels.size)/4.0)
	var seat: Vector2=EquipmentHeadVisual.fit(descriptor).seat
	var matrix := EquipmentHeadVisual.resolved_transform(descriptor,1.0)
	var bottom := -INF
	for corner: Vector2 in [bounds.position,bounds.end,Vector2(bounds.position.x,bounds.end.y),Vector2(bounds.end.x,bounds.position.y)]:
		bottom=maxf(bottom,(matrix*(corner-seat)).y)
	return bottom
static var _atlas_images: Dictionary = {}
## Independent head-top oracle: first body row with a >=4 px opaque run near the fitted head centre.
static func atlas_head_top(descriptor: Dictionary,centre: float) -> int:
	var path: String=descriptor.atlas.resource_path
	if not _atlas_images.has(path):_atlas_images[path]=(descriptor.atlas as Texture2D).get_image()
	var image: Image=_atlas_images[path]
	var cell := Vector2i(descriptor.region.position)
	for row: int in 50:
		var run := 0
		for column: int in range(maxi(0,int(centre)-12),mini(64,int(centre)+13)):
			if image.get_pixel(cell.x+column,cell.y+row).a>0.25:
				run+=1
				if run>=4:return row
			else:run=0
	return -1
func head_fit_checks() -> void:
	## P7-C6 invariants (every class x every head piece x 64 frames): the piece is seated on the crown,
	## scaled to the measured head, follows the head per frame and is drawn in front of the body.
	var kinds: Array[StringName]=[&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"elementalist",&"spiritualist",&"sentinel",&"hunter",&"geometer",&"paladin",&"thaumaturge",&"duelist",&"arcane_blade"]
	var data: Dictionary=EquipmentHeadVisual.fit_data()
	check(data.classes.size()==14 and data.pieces.size()==14,"head-fit table covers 14 classes (10 + the four E09 hybrid bodies) and the 14 real head IDs only")
	check(not data.pieces.has("apple_arrow_study") and not data.pieces.has("eggshell_study"),"study pieces stay outside the fit table")
	var legacy_checked := false
	for kind: StringName in kinds:
		var actor := CharacterAnimation.new();actor.configure(kind)
		for id: StringName in EquipmentArtCatalog.head_ids():
			actor.set_equipment_visual({"head":id})
			var piece: Dictionary=data.pieces[String(id)]
			var drops: Dictionary={}
			for direction: int in 4:
				for pose: int in 16:
					actor.state=D.state(direction,pose)
					var descriptor := actor.render_descriptor()
					var placed := EquipmentHeadVisual.fit(descriptor)
					var label := "%s/%s/%d" % [kind,id,direction*16+pose]
					if placed.is_empty():check(false,"fit available for V2 body "+label);continue
					check(descriptor.head.depth==1 and descriptor.head.visible,"head piece drawn in front of the body "+label)
					var view: Dictionary=piece.views[direction]
					var ratio: float=placed.scale.x*float(view.w)/float(placed.head_width)
					check(ratio>=1.0 and ratio<=1.3,"piece width is 1.0-1.3 of the measured head width "+label)
					check(placed.scale.y/placed.scale.x>=0.65 and placed.scale.y/placed.scale.x<=1.3,"piece aspect only mildly adjusted "+label)
					if pose<14:
						var row: Array=data.classes[String(kind)].frames[direction*16+pose]
						var top := atlas_head_top(descriptor,float(row[0]))
						check(absf(float(top)-float(row[1]))<=1.0,"measured head top matches the drawn body pixels "+label)
						# the seat follows the head: the offset from the real head top is the piece's constant, never the old fixed anchor
						var expected: float=top+float(piece.drop)*float(row[2])
						check(absf(placed.origin.y-expected)<=1.01,"anchor follows the head bob/recoil "+label)
						if piece.mode=="cover":check(placed.origin.y<=float(top)+1.0,"cover piece reaches the crown rows "+label)
						check(absf(float(placed.origin.x)-float(row[0]))<=0.01,"piece centred on the head "+label)
					else:
						check(head_bottom_fitted(descriptor)<=0.05,"fitted head stays above corpse ground "+label)
					if not drops.has(direction):drops[direction]=[]
			EquipmentHeadVisual.fit_enabled=false
			if not legacy_checked:
				actor.state=D.state(0,0)
				var original := actor.render_descriptor()
				check(EquipmentHeadVisual.fit(original).is_empty(),"switch off restores the legacy anchor path")
				check(EquipmentHeadVisual.resolved_transform(original,1.0).x.is_equal_approx(Vector2.RIGHT),"legacy transform keeps unit scale")
				legacy_checked=true
			EquipmentHeadVisual.fit_enabled=true
