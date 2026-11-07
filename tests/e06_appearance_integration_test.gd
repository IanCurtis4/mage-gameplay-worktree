extends SceneTree
## Actual player/run transactions, death copies and shared artwork; isolated profiles.
const DIRECTIONAL_KINDS: Array[StringName] = [&"spiritualist", &"elementalist", &"mage", &"swordsman"]
var checks := 0
var failures := 0
const IDENTITIES := {&"swordsman":&"swordsman",&"mage":&"mage",&"archer":&"archer",&"defender":&"swordsman",&"berserker":&"swordsman",&"elementalist":&"mage",&"spiritualist":&"mage",&"sentinel":&"archer",&"hunter":&"archer",&"mg_ar":&"mage"}
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	for identity: StringName in IDENTITIES:
		var origin: StringName = IDENTITIES[identity]
		var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_playtest_fixes/appearance_%s_%d" % [identity,Time.get_ticks_usec()])
		var store := ProfileStore.new(directory,ProfileCatalog.pilot())
		var facade := ProfileFacade.new(store)
		check(facade.create_character("create",0,"Aparência",origin)["ok"],"isolated character "+String(identity))
		var profile := facade.current_profile()
		if identity != origin:
			profile.characters[0].evolution_id = identity
			profile.characters[0].base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
			profile.characters[0].job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
			check(store.commit(profile)["ok"] and facade.open_profile()["ok"],"valid evolution fixture "+String(identity))
		var started := facade.start_run("start",facade.current_profile().revision)
		check(started["ok"],"actual start "+String(identity))
		if not started["ok"]: print(started); continue
		RunController.pending_run_state = started["run_state"]
		RunController.pending_run_facade = facade
		RunController.pending_gameplay_extension = false
		var controller := RunController.new()
		root.add_child(controller)
		controller.set_process(false);controller.player.set_process(false)
		for enemy: CombatActor in controller.enemies: enemy.set_process(false)
		controller.encounter_active = false
		var actor_kind := &"geometer" if identity == &"mg_ar" else identity
		var animation := controller.player.character_animation
		var directional := actor_kind in DIRECTIONAL_KINDS
		var expected := "res://assets/art/animations/directional/%s/weaponless.png" % actor_kind if directional else "res://assets/art/animations/%s_weaponless.png" % actor_kind
		check(animation.actor_kind == actor_kind and animation.atlas.resource_path == expected,"player bridge selects body without baked weapon "+String(identity))
		check(not StringName(animation.equipment_visual["main_hand"]).is_empty(),"starter weapon appears "+String(identity))
		var independent := CharacterAnimation.new()
		independent.configure(actor_kind)
		independent.set_equipment_visual(animation.equipment_visual)
		check(is_same(independent.atlas,animation.atlas),"atlas shared by player and portrait "+String(identity))
		var intent := controller.build_service.context()
		intent.merge({"request_id":"remove-weapon","kind":&"unequip","slot":&"main_hand"},true)
		var proposed := controller.build_service.preview_change(intent)
		check(proposed["ok"] and controller.build_service.commit_change(proposed["intent"])["ok"],"real durable unequip "+String(identity))
		check(animation.equipment_visual["main_hand"]==&"" and animation.atlas.resource_path == expected,"empty hand stays weaponless "+String(identity))
		var dead := animation.death_copy()
		check(is_same(dead.atlas,animation.atlas) and dead.state.dead and not animation.state.dead and dead.equipment_visual==animation.equipment_visual,"death keeps body and separate animation state "+String(identity))
		dead.equipment_visual["main_hand"] = &"axe"
		check(animation.equipment_visual["main_hand"]==&"","death gear mutation cannot alter player "+String(identity))
		independent.set_equipment_visual({})
		var base_path := "res://assets/art/animations/directional/%s/body.png" % actor_kind if directional else "res://assets/art/animations/%s.png" % actor_kind
		check(independent.atlas.resource_path==base_path,"active base atlas remains available "+String(identity))
		controller.queue_free()
		await process_frame
	for kind: StringName in [&"gel",&"beast_master",&"animal_companion"]:
		var live := CharacterAnimation.new();live.configure(kind)
		var dead := live.death_copy()
		check(dead.actor_kind == kind and is_same(dead.atlas,live.atlas),"mob death preserves species "+String(kind))
		var bitmap := live.atlas.get_image()
		for frame: int in 32:
			var image := bitmap.get_region(Rect2i(frame%4*64,frame/4*64,64,64))
			check(image.get_used_rect().has_area() and image.get_pixel(0,0).a==0.0,"species frame has content and real alpha %s/%d" % [kind,frame])
	print("E06 appearance integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
