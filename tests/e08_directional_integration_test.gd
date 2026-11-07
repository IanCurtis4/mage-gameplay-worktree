extends SceneTree
## Real transactions and graph restore; no new snapshot field or schema.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)
func run() -> void:
	var f := F.make("directional_producer")
	var facade: ProfileFacade = f.facade
	var grant := PlaytestProfileAdmin.grant(facade,"head",facade.current_profile().revision,f.a,&"equipment",&"pilot_head")
	check(grant.ok,"owned helmet granted through actual admin command")
	var started := facade.start_run("start",facade.current_profile().revision)
	check(started.ok,"actual durable run started")
	if not started.ok:quit(1);return
	RunController.pending_run_state=started.run_state;RunController.pending_run_facade=facade
	var host := RunController.new();root.add_child(host)
	host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false
	var before := [host.player.health.current_hp,host.player.current_sp,host.player.position,host.rng.state]
	var intent := host.build_service.context()
	intent.merge({"request_id":"equip-head","kind":&"equip","slot":&"head","equipment_instance_id":StringName(grant.equipment_instance_id)},true)
	var proposed := host.build_service.preview_change(intent)
	check(proposed.ok,"actual helmet equip preview")
	if not proposed.ok: print(proposed);host.free();quit(1);return
	check(host.build_service.commit_change(proposed.intent).ok,"actual durable helmet equip")
	var animation := host.player.character_animation
	check(animation.equipment_visual.get("head")==&"pilot_head","player receives confirmed head projection")
	var dto := BuildPresentation.describe(host)
	check(dto.ok and dto.equipment_visual.head==&"pilot_head","inventory receives same confirmed head projection")
	var portrait := InventoryCharacterPreview.new();host.add_child(portrait)
	portrait.configure(dto.identity_id,dto.equipment_visual)
	check(not portrait._animation.render_descriptor().head.is_empty(),"legacy portrait now has shared helmet descriptor")
	check(animation.set_directional_manifest(D.MANIFEST).ok,"player V2 producer accepts complete unit")
	check(portrait._animation.set_directional_manifest(D.MANIFEST).ok,"same unit works in real portrait")
	for direction: int in 4:
		for pose: int in 16:
			animation.state=D.state(direction,pose);portrait._animation.state=D.state(direction,pose)
			var world := animation.render_descriptor();var ui := portrait._animation.render_descriptor()
			check(world==ui,"world/portrait share all resolved commands %d/%d" % [direction,pose])
	animation.state=D.state(3,10)
	var enemy: CombatActor = host.enemies[0];enemy.set_animation_kind(&"warrior")
	check(enemy.character_animation.set_directional_manifest("res://tests/fixtures/e08_directional/enemy/presentation.json").ok,"enemy V2 override uses same producer")
	enemy.character_animation.state=D.state(2,6)
	check(before==[host.player.health.current_hp,host.player.current_sp,host.player.position,host.rng.state],"presentation and equip do not heal/move/consume RNG")
	var descriptor := animation.render_descriptor();var enemy_descriptor := enemy.character_animation.render_descriptor()
	var barrier := SnapshotTickBarrier.new();paused=true
	check(barrier.acquire(host).ok,"real snapshot barrier")
	var registry := SnapshotRegistry.new();var captured := registry.capture(host,barrier)
	check(captured.ok,"unchanged graph schema captures V2: "+str(captured.get("detail","")))
	if captured.ok:
		# Drop every process-local metadata cache before restore to prove path binding.
		DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
		var restored := SnapshotRegistry.new().restore(captured.snapshot,facade)
		check(restored.ok,"unchanged graph schema restores V2: "+str(restored if not restored.ok else "ok"))
		if restored.ok:
			var copy: RunController = restored.root
			check(copy.player.character_animation.render_descriptor()==descriptor,"cold restored player keeps phase/view/rig/head/body")
			check(copy.enemies[0].character_animation.render_descriptor()==enemy_descriptor,"cold restored enemy keeps same complete unit")
			var death := copy.player.character_animation.death_copy()
			check(death.state.direction_index()==3 and death.render_descriptor().version==2,"restored death copy preserves V2 west")
			copy.free()
	barrier.release();paused=false
	var unequip := host.build_service.context()
	unequip.merge({"request_id":"unequip-head","kind":&"unequip","slot":&"head"},true)
	proposed=host.build_service.preview_change(unequip)
	check(proposed.ok and host.build_service.commit_change(proposed.intent).ok,"real unequip succeeds after presentation swap")
	check(animation.render_descriptor().head.is_empty(),"unequip removes shared world helmet")
	dto=BuildPresentation.describe(host);portrait.configure(dto.identity_id,dto.equipment_visual)
	check(portrait._animation.render_descriptor().head.is_empty(),"unequip removes portrait helmet")
	host.free();await process_frame
	print("E08 directional integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
