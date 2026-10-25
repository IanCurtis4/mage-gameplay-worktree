extends "res://tests/fixtures/e07/f5/suite.gd"
const Fixture = preload("res://tests/map_editor_patrol_test.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Patrol = preload("res://scripts/core/expedition/patrol/enemy_patrol.gd")
var items: Array = []
func check(value: bool, label: String) -> void:
	items.append({"id":label,"ok":value}); print("M5_RESTART_CHECK "+label+" "+str(value))
func _run() -> void:
	var args := OS.get_cmdline_user_args(); var mode := args[0] if not args.is_empty() else "prepare"
	var directory := ProjectSettings.globalize_path("res://.godot/m5_restart"); DirAccess.make_dir_recursive_absolute(directory)
	var built := Compiler.compile(Fixture.fixture()); check(built.ok,"compiled restart source")
	if not built.ok: print(built); finish_m5(); return
	for state: String in ["wait","travel","blocked","aggro"]:
		var path := directory.path_join(state+".bin")
		if mode == "prepare":
			var made := Fixture.idle_fixture(built.package); check(made.ok,"made "+state)
			if not made.ok: continue
			var player: PlayerActor = made.player; var actor: EnemyActor = made.actors[0]
			if state == "wait": actor._process(0.625)
			else:
				actor.patrol.cursor = 1; actor._process(0.1)
				if state == "blocked":
					actor.world_motion.geometry._temporary["fault"] = AABB(Vector3(280,-5,230),Vector3(40,80,60)); actor.world_motion.geometry.geometry_revision += 1; actor._process(0.1)
				if state == "aggro":
					player.world_motion._point = ExpeditionWorldPoint.create("map_preview",actor.world_point().surface_id,actor.world_point().position+Vector3(60,0,0)); actor._process(0.1)
			var captured := Fixture.cut(player); check(captured.ok,"captured "+state)
			if not captured.ok: print(captured); player.free(); continue
			var packed := ExpeditionCheckpointCodec.pack(captured.snapshot,built.package.source_hash,{"run_id":"m5_restart","character_id":"fixture","last_committed_seq":0}); check(packed.ok,"codec packed "+state)
			var before := fingerprint(actor); actor._process(0.125); var expected := fingerprint(actor)
			var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(var_to_bytes({"checkpoint":packed.checkpoint,"before":before,"expected":expected})); file.close(); player.free()
		else:
			var payload: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
			var unpacked := ExpeditionCheckpointCodec.unpack(payload.checkpoint); check(unpacked.ok,"new process unpacked "+state)
			if not unpacked.ok: print(unpacked); continue
			var restored := SnapshotRegistry.new().restore(unpacked.snapshot); check(restored.ok,"new process restored "+state)
			if not restored.ok: print(restored); continue
			var player: PlayerActor = restored.root; var actor: EnemyActor = player.get_child(0)
			check(fingerprint(actor) == payload.before,"exact state before tick "+state)
			actor._process(0.125); check(fingerprint(actor) == payload.expected,"same next tick as uninterrupted "+state)
			player.free()
	if mode == "prepare": campaign(built.package,directory)
	else: resume_campaign(directory)
	finish_m5()
func fingerprint(actor: EnemyActor) -> Dictionary:
	return {"point":actor.world_point().to_data(),"home":actor._world_home.to_data(),"patrol":actor.patrol.duplicate(true),"engagement":actor.engagement_mode,"cooldown":actor.attack_cooldown,"threat":actor.threat.current_id}
func campaign(package: Dictionary, directory: String) -> void:
	var f := make("m5_campaign")
	var entered: Dictionary = f.service.enter(f.controller,f.barrier,"m5_campaign",Compiler.manifest(package),package.population_package.rules,"enter",f.facade.current_profile().revision)
	check(entered.ok,"canonical campaign consumes patrol manifest")
	if not entered.ok: print(entered); dispose(f); return
	adopt(f,entered)
	var host: RunController = f.controller; var actor: EnemyActor = host.campaign_runtime.actors.guard
	check(not actor.patrol.is_empty(),"canonical spawn binds patrol")
	Fixture.far_player(host.player); actor.engagement_mode = &"idle"; actor.threat.disengage(); actor._process(0.4)
	var before := actor.patrol.duplicate(true); var choices: int = host.run_state.pending_choices
	check(kill(f,"guard","kill").ok,"death while waiting through canonical command")
	host = f.controller; host.campaign_runtime.state.advance(host.campaign_runtime.state.clock.interval)
	check(command(f,{"kind":"events","events":[{"kind":"wave","wave_index":host.campaign_runtime.state.clock.wave_index}]},"wave").ok,"canonical respawn command")
	host = f.controller; actor = host.campaign_runtime.actors.guard
	check(actor.patrol.cursor == 0 and actor.patrol.direction == 1 and actor.patrol.wait_remaining == 0.0,"new generation restarts route")
	check(host.campaign_runtime.state.slots.guard.generation == 1 and host.enemies.size() == 1 and host.run_state.pending_choices == choices,"one birth no entry grant duplicate")
	check(command(f,{"kind":"events","events":[{"kind":"wave","wave_index":host.campaign_runtime.state.clock.wave_index}]},"wave_again").ok,"same wave with living slot")
	host = f.controller; check(host.enemies.size() == 1 and host.campaign_runtime.state.slots.guard.generation == 1,"living slot not duplicated")
	actor = host.campaign_runtime.actors.guard; Fixture.far_player(host.player); actor.engagement_mode = &"idle"; actor.threat.disengage(); actor._process(0.375)
	before = actor.patrol.duplicate(true)
	var saved: Dictionary = f.service.checkpoint(host,f.barrier,"m5_campaign",StringName(Compiler.PREVIEW_PHASE),"suspend",f.facade.current_profile().revision,true)
	check(saved.ok,"canonical profile suspends patrol")
	if saved.ok:
		var file := FileAccess.open(directory.path_join("campaign.bin"),FileAccess.WRITE)
		file.store_buffer(var_to_bytes({"directory":f.directory,"character":host.run_state.character_id,"patrol":before,"choices":host.run_state.pending_choices,"generation":host.campaign_runtime.state.slots.guard.generation})); file.close()
	dispose(f)
func resume_campaign(directory: String) -> void:
	var expected: Variant = bytes_to_var(FileAccess.get_file_as_bytes(directory.path_join("campaign.bin")))
	var store := Fault.FaultStore.new(expected.directory,ProfileCatalog.pilot()); var facade := ProfileFacade.new(store)
	check(facade.open_profile().ok,"new process reopens canonical profile")
	var result := ExpeditionService.new(facade).resume("m5_campaign",expected.character,"resume",facade.current_profile().revision)
	check(result.ok,"new process resumes durable campaign")
	if not result.ok: print(result); return
	var host: RunController = result.root; var actor: EnemyActor = host.campaign_runtime.actors.guard
	check(actor.patrol == expected.patrol,"durable patrol wait and cursor exact")
	check(host.campaign_runtime.state.slots.guard.generation == expected.generation and host.run_state.pending_choices == expected.choices and host.enemies.size() == 1,"durable generation claims and single actor")
	host.free()
func finish_m5() -> void:
	var ok := items.all(func(item: Dictionary) -> bool: return item.ok)
	print("M5_RESTART_RESULT "+JSON.stringify({"ok":ok,"count":items.size(),"checks":items})); quit(0 if ok else 1)
