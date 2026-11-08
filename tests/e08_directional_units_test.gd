extends SceneTree
## Content acceptance exercises real pixels, authored rigs and the unchanged graph.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const F = preload("res://tests/fixtures/e08_directional/content_fixture.gd")
var unit_kind: StringName = &"elementalist"
var manifest := ""
var require_default := false
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	require_default=args.has("--default") or args.is_empty()
	var targets: Array[StringName] = [&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"elementalist",&"spiritualist",&"sentinel",&"hunter",&"geometer"]
	if not args.is_empty():
		targets.clear();targets.append(StringName(args[0]))
	for target: StringName in targets:
		unit_kind=target
		var before := checks
		await validate_unit()
		print("E08 directional unit %s: %d checks" % [unit_kind,checks-before])
	print("E08 directional units: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func validate_unit() -> void:
	check(F.ORIGINS.has(unit_kind),"explicit authorized player identity")
	if not F.ORIGINS.has(unit_kind):return
	manifest=F.stage_path(unit_kind)
	var result := DirectionalAnimationSet.load_manifest(manifest)
	check(result.ok, "complete real selected identity unit validates: "+str(result.get("detail", "")))
	if not result.ok: return
	var bundle: DirectionalAnimationSet = result.bundle
	check(bundle.actor_kind()==unit_kind, "content binds the intended identity")
	var actor := CharacterAnimation.new(); actor.configure(unit_kind)
	if require_default:
		check(actor.render_descriptor().version==2 and actor.atlas.resource_path=="res://assets/art/animations/directional/%s/%s.png" % [unit_kind,"npc_body" if unit_kind==&"archer" else "body"],"active identity automatically consumes promoted unit")
		var promoted := DirectionalAnimationSet.load_manifest(DirectionalAnimationSet.default_path(unit_kind))
		var identical: bool = promoted.ok
		if promoted.ok:
			for index: int in 64:identical=identical and promoted.bundle.frame(index)==bundle.frame(index)
			identical=identical and promoted.bundle.body(false).get_image().get_data()==bundle.body(false).get_image().get_data() and promoted.bundle.body(true).get_image().get_data()==bundle.body(true).get_image().get_data()
		check(identical,"all promoted pixels and64calibrations match reviewed staging")
	check(actor.set_directional_manifest(manifest).ok, "real unit binds atomically")
	for texture: Texture2D in [bundle.body(false),bundle.body(true)]:
		var bitmap := texture.get_image()
		check(bitmap.get_size()==Vector2i(256,1024), "64-cell authored atlas")
		for direction: int in 4:
			for sequence: Vector2i in [Vector2i(4,4),Vector2i(8,4),Vector2i(12,2),Vector2i(14,2)]:
				var signatures: Array[PackedByteArray] = []
				for pose: int in range(sequence.x,sequence.x+sequence.y):
					var index := direction*16+pose
					var pixels := bitmap.get_region(Rect2i(index%4*64,index/4*64,64,64)).get_data()
					if pixels not in signatures: signatures.append(pixels)
				check(signatures.size()>=mini(sequence.y,3), "real distinct animation poses %d/%s" % [direction,sequence])
		for index: int in 64:
			var tile := bitmap.get_region(Rect2i(index%4*64,index/4*64,64,64))
			var bounds := tile.get_used_rect()
			check(bounds.has_area() and bounds.position.x>0 and bounds.end.x<64 and bounds.position.y>0 and bounds.end.y<64, "content fits with transparent gutters %d" % index)
			var frame := bundle.frame(index)
			if index%16<14:
				for slot: String in ["main_hand","off_hand"]:
					var point: Array = frame.slots[slot].point
					var fingers: Array = frame.slots[slot].fingers
					check(tile.get_pixel(point[0],point[1]).a>0.5 and Rect2i(fingers[0],fingers[1],fingers[2],fingers[3]).has_point(Vector2i(point[0],point[1])), "calibrated grip contained in authored finger crop %d/%s" % [index,slot])
		var mirrored := true
		for pose: int in 16:
			var east := bitmap.get_region(Rect2i(pose%4*64,512+pose/4*64,64,64))
			var west := bitmap.get_region(Rect2i(pose%4*64,768+pose/4*64,64,64)); west.flip_x()
			mirrored = mirrored and east.get_data()==west.get_data()
		check(not mirrored, "lateral poses are not a mirrored sheet")
	var loadouts: Array[Dictionary] = [{}]
	for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
		loadouts.append({"main_hand":key,"off_hand":&"shield","arms":&"wooden_beads","head":&"pilot_head"})
	for visual: Dictionary in loadouts:
		actor.set_equipment_visual(visual)
		for direction: int in 4:
			for pose: int in 16:
				actor.state=D.state(direction,pose)
				var descriptor := actor.render_descriptor()
				check(descriptor.version==2 and descriptor.frame==direction*16+pose and not descriptor.flip, "common 64-frame selection")
				check(is_zero_approx(descriptor.origin.y+bundle.frame(descriptor.frame).ground_y), "exact common ground contact")
				if not visual.is_empty():
					check(descriptor.head.view==direction, "helmet shares body direction")
					for placed: Dictionary in descriptor.equipment:
						var raw: Dictionary = bundle.frame(descriptor.frame).slots[String(placed.slot)]
						var expected: Vector2 = descriptor.origin+Vector2(raw.point[0],raw.point[1])
						if not descriptor.dead:
							check(placed.point==expected,"living equipment uses authored anatomical grip")
						else:
							check(is_equal_approx(placed.point.x,expected.x),"dropped equipment preserves authored X")
							var expected_angle: float=raw.get("angle_overrides",{}).get(String(placed.key),float(EquipmentAttachmentVisual.PROFILES[placed.key].angle)+float(raw.angle))
							check(is_equal_approx(placed.angle,expected_angle) and placed.flip==raw.flip,"grounding preserves authored angle and local flip")
							var bottom: float = F.equipment_bottom(placed)
							check(absf(bottom)<0.05 if pose==15 else bottom<=0.05,"death equipment rests on/above the common ground")
		actor.state=D.state(3,10)
		check(actor.death_copy().render_descriptor().direction==3, "death retains real west view")
	for id: StringName in EquipmentArtCatalog.head_ids():
		actor.set_equipment_visual({"head":id,"main_hand":&"staff"})
		check(actor.atlas==bundle.body(true,bundle.has_bare_head()),"known head selects exact optional/base texture")
		for direction: int in 4:
			for pose: int in 16:
				actor.state=D.state(direction,pose);var descriptor := actor.render_descriptor()
				check(descriptor.head.key==id and descriptor.head.view==direction,"14 actual heads share authored direction")
				if pose>=14:check(F.head_bottom(descriptor)<=0.05,"all painted head bounds above corpse ground "+String(unit_kind)+"/"+str(direction*16+pose))
	actor.set_equipment_visual({"main_hand":&"staff","head":&"unknown"})
	check(actor.atlas==bundle.body(true) and actor.render_descriptor().head.is_empty(),"unknown head never removes original fixed hat")
	actor.set_equipment_visual({"main_hand":&"staff"});check(actor.atlas==bundle.body(true),"remove restores exact original atlas")
	if unit_kind in [&"archer",&"hunter",&"sentinel",&"geometer"]:bare_integrity(bundle)
	await integrated()
func integrated() -> void:
	var f := F.make(unit_kind,"content");check(f.ok,"real unit profile fixture");
	if not f.ok:return
	var facade: ProfileFacade = f.facade
	var grant := PlaytestProfileAdmin.grant(facade,"helmet",facade.current_profile().revision,f.a,&"equipment",&"pilot_head")
	check(grant.ok,"owned helmet")
	var started := facade.start_run("start",facade.current_profile().revision)
	check(started.ok,"actual durable run")
	if not started.ok: return
	RunController.pending_run_state=started.run_state; RunController.pending_run_facade=facade
	var host := RunController.new(); root.add_child(host); host.set_process(false); host.player.set_process(false)
	for enemy: CombatActor in host.enemies: enemy.set_process(false)
	host.encounter_active=false
	var intent := host.build_service.context()
	intent.merge({"request_id":"equip","kind":&"equip","slot":&"head","equipment_instance_id":StringName(grant.equipment_instance_id)},true)
	var proposed := host.build_service.preview_change(intent)
	check(proposed.ok and host.build_service.commit_change(proposed.intent).ok,"actual durable helmet equip")
	var animation := host.player.character_animation
	var expected_body: String = "bare_head" if unit_kind in [&"mage",&"archer",&"hunter",&"sentinel",&"geometer"] else "weaponless"
	var world_binding: bool = animation.render_descriptor().version==2 and animation.atlas.resource_path=="res://assets/art/animations/directional/%s/%s.png" % [unit_kind,expected_body] if require_default else animation.set_directional_manifest(manifest).ok
	check(animation.actor_kind==unit_kind and world_binding,"real actor consumes explicit default/staged content")
	var dto := BuildPresentation.describe(host)
	var portrait := InventoryCharacterPreview.new(); host.add_child(portrait); portrait.configure(dto.identity_id,dto.equipment_visual)
	var portrait_binding: bool = portrait._animation.render_descriptor().version==2 and portrait._animation.atlas.resource_path=="res://assets/art/animations/directional/%s/%s.png" % [unit_kind,expected_body] if require_default else portrait._animation.set_directional_manifest(manifest).ok
	check(portrait_binding,"real portrait consumes same explicit default/staged content")
	for direction: int in 4:
		for pose: int in 16:
			animation.state=D.state(direction,pose); portrait._animation.state=D.state(direction,pose)
			check(animation.render_descriptor()==portrait._animation.render_descriptor(),"world/portrait authored content agreement")
	animation.state=D.state(2,9)
	var descriptor := animation.render_descriptor()
	var before := [host.player.health.current_hp,host.player.current_sp,host.player.position,host.rng.state]
	var barrier := SnapshotTickBarrier.new(); paused=true
	check(barrier.acquire(host).ok,"actual snapshot barrier")
	var captured := SnapshotRegistry.new().capture(host,barrier)
	check(captured.ok,"same schema captures real content")
	if captured.ok:
		DirectionalAnimationSet._textures.clear(); DirectionalAnimationSet._manifests.clear()
		var restored := SnapshotRegistry.new().restore(captured.snapshot,facade)
		check(restored.ok,"same schema restores real content cold")
		if restored.ok:
			var copy: RunController = restored.root
			check(copy.player.character_animation.render_descriptor()==descriptor,"cold restore keeps real art/phase/rig/head")
			check(before==[copy.player.health.current_hp,copy.player.current_sp,copy.player.position,copy.rng.state],"presentation preserves simulation state")
			copy.free()
	barrier.release(); paused=false
	host.free(); await process_frame

func bare_integrity(bundle: DirectionalAnimationSet) -> void:
	check(bundle.has_bare_head(),"completed authored bare head present")
	var fit: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/e08_head_fit/%s/calibration.json" % unit_kind))
	var original := bundle.body(true).get_image();var bare := bundle.body(true,true).get_image()
	for index: int in 64:
		var region := Rect2i(index%4*64,index/4*64,64,64);var before := original.get_region(region);var after := bare.get_region(region)
		var record: Dictionary=fit.frames[index];var area: Array=record.head_region;var confined := true
		for y: int in 64:
			for x: int in 64:
				var authorized: bool=x>=area[0] and x<area[2] and y>=area[1] and y<area[3]
				for protected: Array in record.protections:
					if x>=protected[0] and x<protected[2] and y>=protected[1] and y<protected[3]:authorized=false
				if not authorized:
					var a := before.get_pixel(x,y);var b := after.get_pixel(x,y)
					confined=confined and ((a.a==0 and b.a==0) or a==b)
		check(confined,"all changed pixels confined; protected arms intact")
		check(before.get_used_rect().end.y==after.get_used_rect().end.y,"bare ground unchanged")
		if index%16<14:
			for slot: String in ["main_hand","off_hand"]:
				var fingers: Array=bundle.frame(index).slots[slot].fingers;var crop := Rect2i(fingers[0],fingers[1],fingers[2],fingers[3])
				check(before.get_region(crop).get_data()==after.get_region(crop).get_data(),"actual112 finger crops byte-identical")
