extends SceneTree
## Independent V1 API oracle for preserved S/N bodies, directional geometry for E/W.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const F = preload("res://tests/fixtures/e08_directional/content_fixture.gd")
const NATIVE: Array[StringName] = [&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"hunter",&"sentinel",&"geometer"]
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func run() -> void:
	for kind: StringName in NATIVE:
		var loaded := DirectionalAnimationSet.load_manifest(F.stage_path(kind))
		check(loaded.ok,"native unit validates "+String(kind))
		if not loaded.ok:continue
		var old_body := load("res://assets/art/animations/%s_weaponless.png" % kind) as Texture2D
		var body: Image=loaded.bundle.body(true).get_image();var legacy: Image=old_body.get_image()
		for direction: int in 2:
			for pose: int in 14:
				var state := D.state(direction,pose)
				var frame: Dictionary=loaded.bundle.frame(direction*16+pose)
				var index := direction*16+pose;var old_index := state.frame_index()
				var a := body.get_region(Rect2i(index%4*64,index/4*64,64,64))
				var b := legacy.get_region(Rect2i(old_index%4*64,old_index/4*64,64,64))
				var same := true
				for y: int in 64:
					for x: int in 64:
						var pa := a.get_pixel(x,y);var pb := b.get_pixel(x,y)
						same=same and ((pa.a==0 and pb.a==0) or pa==pb)
				check(same,"all28 living native image cells preserved "+String(kind)+"/"+str(index))
				for slot: StringName in [&"main_hand",&"off_hand",&"arms"]:
					for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
						var old := EquipmentAttachmentVisual.placement(kind,state,key,slot,Vector2.ZERO)
						var resolved := EquipmentAttachmentVisual.resolve_equipment(kind,state,{slot:key},Vector2.ZERO,frame)
						var now: Dictionary=resolved[0]
						var label := "%s/%d/%s/%s" % [kind,direction*16+pose,slot,key]
						check(now.point==old.point,label+" preserved anatomical native palm")
						check(now.finger_rect==old.finger_rect,label+" preserved native fingers")
						check(is_equal_approx(now.angle,old.angle),label+" independent V1 angle")
						check(now.depth==old.depth,label+" independent V1 occlusion")
						check(not now.flip,label+" native S/N local flip unchanged")
	for kind: StringName in F.ORIGINS:
		var animation := CharacterAnimation.new();animation.configure(kind)
		check(animation.set_directional_manifest(F.stage_path(kind)).ok,"explicit lateral unit")
		animation.set_equipment_visual({"main_hand":&"bow","head":&"pilot_head"})
		for direction: int in [2,3]:
			for pose: int in range(8,11):
				animation.state=D.state(direction,pose)
				var descriptor := animation.render_descriptor()
				var placed: Dictionary=descriptor.equipment[0]
				var transform := EquipmentAttachmentVisual.resolved_transform(placed,1.0,false)
				var arrow_delta := transform*Vector2(25,0)-transform*Vector2(-11,0)
				check(descriptor.arrow_visible,"launch phase has arrow")
				check(arrow_delta.x>10.0 if direction==2 else arrow_delta.x < -10.0,"arrow faces authored target, not opposite "+String(kind)+"/"+str(direction*16+pose))
	# The weapon hand leads toward the target in BOTH profile views. An arrow
	# pointing the right way from a bow held by the trailing hand crosses the
	# body; that passed the direction check above while being visibly wrong.
	# Casters keep their authored staff hand because the other palm casts.
	const LEADING := {&"archer":[8,9,10],&"sentinel":[8,9,10],&"hunter":[8,9,10],&"swordsman":[8,9,10],&"defender":[8,9,10],&"berserker":[10]}
	for kind: StringName in LEADING:
		for path: String in [F.stage_path(kind),DirectionalAnimationSet.default_path(kind)]:
			var loaded := DirectionalAnimationSet.load_manifest(path)
			check(loaded.ok,"lateral lead manifest "+path)
			if not loaded.ok:continue
			for direction: int in [2,3]:
				for pose: int in LEADING[kind]:
					var slots: Dictionary=loaded.bundle.frame(direction*16+pose).slots
					var lead: float=(1.0 if direction==2 else -1.0)*(float(slots.main_hand.point[0])-float(slots.off_hand.point[0]))
					check(lead>0.0,"weapon hand leads toward target %s/%d %s" % [kind,direction*16+pose,path])
	# The internal cache uses exactly the public authority, including all discrete
	# phase/gear inputs, and never exposes its dictionary through the public API.
	for kind: StringName in F.ORIGINS:
		var animation := CharacterAnimation.new();animation.configure(kind)
		check(animation.set_directional_manifest(F.stage_path(kind)).ok,"cache unit")
		for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
			animation.set_equipment_visual({"main_hand":key,"off_hand":&"shield","head":&"pilot_head"})
			for direction: int in 4:
				for pose: int in 16:
					animation.state=D.state(direction,pose)
					var cached := animation._descriptor_for_draw();var public := animation.render_descriptor()
					check(cached==public,"cached geometry equals authoritative descriptor")
					check(is_same(cached,animation._descriptor_for_draw()),"same discrete key reuses immutable geometry")
					public.equipment[0].point=Vector2.INF
					check(animation._descriptor_for_draw()==animation.render_descriptor(),"public DTO mutation cannot poison shared draw data")
					check(CharacterAnimation._draw_geometry.size()<=CharacterAnimation.DRAW_GEOMETRY_LIMIT,"draw geometry retention bounded")
	print("E08 directional rig compatibility: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
