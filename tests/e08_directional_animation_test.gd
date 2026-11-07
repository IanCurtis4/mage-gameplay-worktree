extends SceneTree
const F = preload("res://tests/fixtures/e08_directional/fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func run() -> void:
	var original := JSON.parse_string(FileAccess.get_file_as_string(F.MANIFEST)) as Dictionary
	var loaded := DirectionalAnimationSet.load_manifest(F.MANIFEST)
	check(loaded.ok,"complete fixture validated")
	if not loaded.ok: print(loaded); quit(1); return
	for direction: int in 4:
		for pose: int in 16:
			var animation := F.animation(direction,pose)
			var before := [animation.state.facing,animation.state.walk_distance,animation.state.action_remaining,animation.state.death_time]
			var descriptor := animation.render_descriptor()
			check(descriptor.version==2 and descriptor.frame==direction*16+pose,"64 explicit source frames %d/%d" % [direction,pose])
			check(descriptor.region==Rect2((descriptor.frame%4)*64,(descriptor.frame/4)*64,64,64),"integer source crop")
			check(descriptor.rect.position.y+57==0 and not descriptor.flip,"grounded independent view, no global mirror")
			check(descriptor.equipment.size()==3 and descriptor.head.view==direction,"all components use resolved view")
			for placed: Dictionary in descriptor.equipment:
				var matrix := EquipmentAttachmentVisual.resolved_transform(placed,1.6,descriptor.flip)
				check(matrix.origin.is_equal_approx(Vector2(placed.point)*1.6),"equipment mirror cannot move anchor")
			check(before==[animation.state.facing,animation.state.walk_distance,animation.state.action_remaining,animation.state.death_time],"rendering is read-only to simulation/presentation clock")
			var copy := animation.death_copy()
			check(copy.atlas==animation.atlas and copy.state!=animation.state and copy.state.direction_index()==direction and copy.state.dead,"death copy preserves unit and view")
			copy.state.face(Vector2.ONE)
			check(copy.state.direction_index()==direction,"death direction frozen")
			copy.state.revive(); check(not copy.state.dead and copy.render_descriptor().version==2,"revive preserves presentation set")
	for direction: int in 4:
		for pose: int in 16:
			var bare := F.animation(direction,pose,false).render_descriptor()
			check(bare.version==2 and bare.frame==direction*16+pose and bare.equipment.is_empty() and bare.head.is_empty(),"bare V2 keeps same frame without unused rig")
	var clock := CombatAnimationState.new()
	clock.face(Vector2.LEFT); clock.face(Vector2.ZERO); check(clock.direction_index()==3,"zero preserves facing")
	clock.face(Vector2(-1,-1)); check(clock.direction_index()==1,"exact diagonal tie deterministic north")
	clock.face(Vector2(1,1)); check(clock.direction_index()==0,"exact diagonal tie deterministic south")
	clock.trigger(&"cast",Vector2.RIGHT,0.6);clock.advance(0.2,Vector2.LEFT*20)
	check(clock.direction_index()==2 and clock.action_remaining>0,"movement cannot rotate active action")
	clock.trigger(&"cast_cancel");clock.advance(0.0,Vector2.LEFT)
	check(clock.direction_index()==3,"cancel returns to locomotion")
	clock.trigger(&"hurt",Vector2.UP);check(clock.direction_index()==3,"hurt trigger cannot rotate actor")
	var facing := clock.facing; clock.face(Vector2(NAN,0));check(clock.facing==facing,"nonfinite visual direction ignored")
	var selected := F.animation(2,9); var key := selected.draw_key();selected.state=F.state(3,9)
	check(key!=selected.draw_key(),"east/west invalidates same-phase draw cache")
	var atlas := selected.atlas; var state := selected.state; var offsets := selected.destination_rect(60)
	check(not selected.set_directional_manifest("res://missing/presentation.json").ok and selected.atlas==atlas and selected.state==state and selected.destination_rect(60)==offsets,"rejected install is atomic")
	var wrong := CharacterAnimation.new();wrong.configure(&"archer");var old := wrong.atlas
	check(not wrong.set_directional_manifest(F.MANIFEST).ok and wrong.atlas==old,"identity mismatch refused")
	selected.set_equipment_visual({});check(selected.atlas.resource_path.ends_with("/body.png"),"base V2 body selected")
	selected.set_equipment_visual({"head":&"pilot_head"});check(selected.atlas.resource_path.ends_with("/weaponless.png"),"head-only player contract uses weaponless V2")
	var detached: Dictionary = loaded.bundle.frame(0);detached.slots.main_hand.point[0]=0
	check(loaded.bundle.frame(0).slots.main_hand.point[0]==24,"catalog calibration cannot be mutated through a descriptor")
	# Negative validations use the same validator, never rewrite an existing fixture.
	for label: String in ["format","count","ground","grip","crop","angle","depth","head","missing","hash","body_path"]:
		var bad := original.duplicate(true)
		match label:
			"format":bad.format="unknown"
			"count":bad.frames.pop_back()
			"ground":bad.frames[0].ground_y=56
			"grip":bad.frames[0].slots.main_hand.point=[0,0]
			"crop":bad.frames[0].slots.off_hand.fingers=[63,63,4,4]
			"angle":bad.frames[0].slots.main_hand.angle=NAN
			"depth":bad.frames[0].slots.main_hand.depth=2
			"head":bad.frames[0].head.erase("visible")
			"missing":bad.weaponless=null
			"hash":bad.body.rgba_sha256="0000"
			"body_path":bad.body.path="res://outside/body.png"
		check(not DirectionalAnimationSet._validate_data(bad,F.MANIFEST).ok,"invalid unit rejected: "+label)
	# Both sides of cold lookup reconstruct from the already saved texture path.
	DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
	check(selected.render_descriptor().version==2 and selected.state==state,"cold catalog lookup preserves current animation state")
	for kind: StringName in CharacterAnimation.WEAPONLESS_KINDS:
		var legacy := CharacterAnimation.new();legacy.configure(kind);legacy.set_equipment_visual({"main_hand":&"staff","head":&"pilot_head"})
		check(legacy.render_descriptor().version==1 and legacy.atlas.get_size()==Vector2(256,512),"legacy full body and rig untouched "+String(kind))
		check(not legacy.render_descriptor().head.is_empty(),"shared legacy helmet descriptor "+String(kind))
	print("E08 directional animation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
