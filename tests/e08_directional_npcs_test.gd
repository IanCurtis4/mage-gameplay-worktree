extends SceneTree
## Actual consumers, immutable catalog, specific fallback and cold graph restore.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const VISUAL = preload("res://scripts/presentation/e08_pilot_visual.gd")
const SPECIES = preload("res://scripts/presentation/species_presentation_catalog.gd")
const NPCS: Array[String] = ["warrior","gel","beast_master","animal_companion","e08_forest_wolf","e08_forest_boar"]
const IDS: Array[StringName] = [&"demo_archer",&"demo_chaser",&"pilot_bulwark_species",&"pilot_echo_species",&"pilot_ember_species",&"pilot_frost_species",&"pilot_precision_species",&"pilot_trail_species",&"test_gel",&"test_beast_master",&"test_animal_companion",&"forest_wolf",&"forest_boar",&"forest_stalker",&"forest_canopy_archer",&"forest_ancient_warden"]
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func spawn(id: StringName,catalog: MobCatalog) -> MobOccurrence:
	var definition := catalog.get_definition(id)
	var occurrence := MobOccurrence.new();occurrence.occurrence_id="directional_"+String(id)
	occurrence.mob_base_id=id;occurrence.category_id=definition.base_category
	occurrence.origin_id=definition.origin_levels.keys()[0] if not definition.origin_levels.is_empty() else &"demo_arena"
	return occurrence
func definition_data(definition: MobDefinition) -> Dictionary:
	var data: Dictionary={}
	for property: Dictionary in definition.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["script"]:data[property.name]=definition.get(property.name)
	return data.duplicate(true)
func run() -> void:
	for id: String in NPCS:
		var path := "res://assets/art/e08_enemies/directional/%s/presentation.json" % id
		var loaded := DirectionalAnimationSet.load_manifest(path);check(loaded.ok,id+" complete stage")
		if not loaded.ok:continue
		var kind: StringName=&"animal_companion" if id.begins_with("e08_forest_") else StringName(id)
		var animation := CharacterAnimation.new();animation.configure(kind)
		check(animation.set_directional_manifest(path).ok,id+" exact NPC kind")
		check(animation.equipment_visual.is_empty() and not loaded.bundle.has_bare_head(),id+" unadorned NPC")
		var bitmap: Image=animation.atlas.get_image()
		for direction: int in 4:
			for pose: int in 16:
				animation.state=D.state(direction,pose);var desc := animation.render_descriptor()
				var pixels := bitmap.get_region(Rect2i(desc.region));var bounds := pixels.get_used_rect()
				check(desc.version==2 and desc.frame==direction*16+pose and not desc.flip,id+" authored direction")
				check(desc.equipment.is_empty() and desc.head.is_empty(),id+" no fabricated attachments")
				check(bounds.has_area() and is_zero_approx(desc.origin.y+bounds.end.y-1),id+" exact opaque ground")
		var before := animation.render_descriptor();var clock := animation.state
		check(not animation.set_directional_manifest("res://tests/fixtures/e08_directional/invalid/presentation.json").ok and animation.state==clock and animation.render_descriptor()==before,id+" invalid atomic")
	var armed := EnemyActor.new();armed.character_animation=CharacterAnimation.new();armed.character_animation.configure(&"archer")
	check(armed.character_animation.set_directional_manifest("res://assets/art/e08_characters/directional/archer/presentation.json").ok,"approved NPC body bundle")
	armed.sync_npc_equipment_visual()
	check(armed.character_animation.equipment_visual.is_empty() and armed.character_animation.atlas.resource_path=="res://assets/art/e08_characters/directional/archer/npc_body.png","approved exact body has one baked bow")
	var unknown := EnemyActor.new();unknown.character_animation=CharacterAnimation.new();unknown.character_animation.configure(&"archer")
	check(unknown.character_animation.set_directional_manifest("res://tests/fixtures/e08_directional/npc_archer_unarmed/presentation.json").ok,"valid homonymous unknown body bundle")
	unknown.sync_npc_equipment_visual()
	check(unknown.character_animation.equipment_visual.get("main_hand",&"")==&"bow" and unknown.character_animation.render_descriptor().equipment.size()==1,"same basename in other folder never infers baked bow")
	unknown.character_animation.configure(&"warrior");unknown.sync_npc_equipment_visual()
	check(unknown.character_animation.equipment_visual.is_empty(),"kind switch clears actual dynamic bow")
	armed.free();unknown.free()
	if OS.get_cmdline_user_args().has("--stage"):
		print("E08 directional NPCs: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0);return
	await actual_consumers()
	print("E08 directional NPCs: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
func actual_consumers() -> void:
	RunController.selected_class_id=&"mage"
	var host := RunController.new();root.add_child(host);host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false
	var catalog := BuildContentLoader.pilot().mob_catalog()
	check(catalog.ids().size()==16,"exact existing16MobDefinitions; no inferred friendlypet")
	var original: Dictionary={};var samples: Array[EnemyActor]=[]
	for id: StringName in IDS:
		original[id]=definition_data(catalog.get_definition(id))
		var occurrence := spawn(id,catalog);var actor := EnemyActor.new()
		check(actor.configure_occurrence(occurrence,catalog,host.navigation,host.player).ok,"actual occurrence "+String(id))
		host.add_child(actor);host.enemies.append(actor);actor.set_process(false);samples.append(actor)
		var definition := catalog.get_definition(id)
		# Forest species own a default unit (P5 B1): the catalog's visual_id and plain body.png.
		var own := VISUAL.has_species_presentation(id)
		var visual_id := String(SPECIES.visual_id(id)) if own else String(definition.animation_kind)
		var expected := "res://assets/art/animations/directional/%s/%s.png" % [visual_id,"npc_body" if definition.animation_kind==&"archer" and not own else "body"]
		check(actor.character_animation.atlas.resource_path==expected,"actual precise default/override "+String(id))
		var visual := actor.character_animation.equipment_visual
		check(visual.is_empty(),"one static bow in verified NPCArcher body; otherNPCs unadorned "+String(id))
		actor.character_animation.state=D.state(3,9)
		check(actor.character_animation.death_copy().atlas==actor.character_animation.atlas,"death retains own species "+String(id))
		check(original[id]==definition_data(catalog.get_definition(id)),"catalog immutable "+String(id))
	# Existing same object switches kinds and discards derived bow before override.
	var switched := samples[0]
	check(switched.configure_occurrence(spawn(&"demo_chaser",catalog),catalog,host.navigation,host.player).ok and switched.character_animation.equipment_visual.is_empty(),"Archer to warrior clears derived bow")
	check(switched.configure_occurrence(spawn(&"forest_boar",catalog),catalog,host.navigation,host.player).ok and switched.character_animation.atlas.resource_path.contains("/e08_forest_boar/") and switched.character_animation.equipment_visual.is_empty(),"reconfigure existingNPC installs specific boar")
	# Complete specific fallback even when generic default exists; no temporary resource edits.
	for id: String in ["e08_forest_wolf","e08_forest_boar"]:
		var animation := CharacterAnimation.new();animation.configure(&"animal_companion")
		var legacy := load("res://assets/art/animations/%s.png" % id) as Texture2D;var clock := animation.state
		check(VISUAL.install_directional_or_legacy(animation,"res://absent/presentation.json",legacy) and animation.atlas==legacy and animation.state==clock,"missing specific fallback complete "+id)
		check(VISUAL.install_directional_or_legacy(animation,"res://tests/fixtures/e08_equipment_art/presentation.json",legacy) and animation.atlas==legacy,"invalid specific fallback complete "+id)
		var valid := DirectionalAnimationSet.default_path(StringName(id))
		check(VISUAL.install_directional_or_legacy(animation,valid,legacy) and animation.atlas.resource_path==valid.get_base_dir()+"/body.png","specific valid overrides own legacy "+id)
	var archer_path := DirectionalAnimationSet.default_path(&"archer");var cached: Variant=DirectionalAnimationSet._manifests.get(archer_path)
	DirectionalAnimationSet._manifests[archer_path]={"ok":false,"detail":"forced negative fixture"}
	var fallback := EnemyActor.new()
	check(fallback.configure_occurrence(spawn(&"demo_archer",catalog),catalog,host.navigation,host.player).ok and fallback.character_animation.atlas.resource_path=="res://assets/art/animations/archer.png" and fallback.character_animation.equipment_visual.is_empty(),"invalid ArcherV2 preserves baked bow and empty projection")
	fallback.free();DirectionalAnimationSet._manifests[archer_path]=cached
	# Real beast_master summon consumer, not an invented friendly pet.
	var master := samples[IDS.find(&"test_beast_master")]
	master.position=Vector2(500,400);master.set_meta("admin_spawn",true)
	var count := host.enemies.size();host._on_companion_requested(master)
	check(host.enemies.size()==count+1 and host.enemies.back().character_animation.actor_kind==&"animal_companion" and host.enemies.back().character_animation.render_descriptor().version==2,"real master companion consumes V2")
	if host.enemies.size()>count:host.enemies.back().set_process(false)
	var descriptors: Array[Dictionary]=[]
	for actor: EnemyActor in samples:descriptors.append(actor.character_animation.render_descriptor())
	var before := [host.player.health.current_hp,host.player.current_sp,host.player.position,host.rng.state]
	var barrier := SnapshotTickBarrier.new();paused=true;check(barrier.acquire(host).ok,"NPC snapshot barrier")
	var captured := SnapshotRegistry.new().capture(host,barrier);check(captured.ok,"same graph captures all actual consumers")
	if captured.ok:
		DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
		var restored := SnapshotRegistry.new().restore(captured.snapshot);check(restored.ok,"actual cold graph restore allNPCs")
		if restored.ok:
			var copy: RunController=restored.root
			for i: int in samples.size():
				var actor: EnemyActor=copy.enemies[host.enemies.find(samples[i])]
				check(actor.character_animation.render_descriptor()==descriptors[i],"cold path/override/bow/direction exact "+String(IDS[i]))
			check(before==[copy.player.health.current_hp,copy.player.current_sp,copy.player.position,copy.rng.state],"presentation changes no simulation state")
			copy.free()
	barrier.release();paused=false;host.free();await process_frame
