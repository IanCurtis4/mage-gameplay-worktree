extends SceneTree
## F10 Q2 (contracts/f10_phase_rules.md): first play per character, portals by
## clearing on the first play and by objective on a replay (guardians first),
## guardian brushes and stage objectives in authoring, and the charger burst.
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Operations = preload("res://scripts/map_authoring/population/population_operations.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_PHASE_RULES_CHECK "+id+" "+str(ok))
func slot(stage: String, guardian: bool) -> Dictionary:
	var value := {"stage_id":stage,"blocks_clear":true,"initial_resolved":false}
	if guardian: value["guardian"] = true
	return value
func state(replay: bool, unlock: bool) -> ExpeditionCampaignState:
	var made := ExpeditionCampaignState.new()
	made.replay = replay
	made.stages = {"field":{"visited":true,"cleared_once":false},"lair":{"visited":false,"cleared_once":false}}
	made.slots = {"a":slot("field",false),"b":slot("field",true),"c":slot("lair",false)}
	made.manifest_data = {"portals":[{"portal_id":"to_lair","kind":"travel","from_stage":"field","to_stage":"lair"}],"objectives":[]}
	if unlock: made.manifest_data.objectives.append({"objective_id":"shrine","stage_id":"field","outcome":"stage_unlock","required":false})
	return made
func lock(character: String, phase: String, lifecycle: StringName) -> ExpeditionAssetLock:
	var made := ExpeditionAssetLock.new()
	made.expedition_id = character+"_"+phase+"_"+String(lifecycle); made.character_id = character; made.phase_id = StringName(phase); made.lifecycle = lifecycle
	return made
func run() -> void:
	# 1. First play belongs to the character and comes from completed history.
	var profile := ProfileState.new()
	for item: ExpeditionAssetLock in [lock("hero","forest",&"completed"),lock("alt","forest",&"suspended"),lock("alt","caves",&"completed")]: profile.expeditions[item.expedition_id] = item
	check("completion_is_per_character_and_phase",ExpeditionService.phase_completed(profile,"hero",&"forest") and not ExpeditionService.phase_completed(profile,"alt",&"forest") and ExpeditionService.phase_completed(profile,"alt",&"caves") and not ExpeditionService.phase_completed(profile,"hero",&"caves"))
	# 2. First play: clearing opens the portal, as before.
	var first := state(false,false)
	check("first_play_waits_for_the_clear",not first.portal_view("to_lair").open)
	first.stages.field.cleared_once = true
	check("first_play_opens_on_the_clear",first.portal_view("to_lair").open)
	# 3. Replay without a stage objective: the guardian alone opens it.
	var plain := state(true,false)
	check("replay_waits_for_the_guardian",not plain.portal_view("to_lair").open and not plain.guardians_resolved("field"))
	plain.slots.b.initial_resolved = true
	check("replay_opens_after_the_guardian_without_clearing",plain.portal_view("to_lair").open and not plain.stages.field.cleared_once)
	# 4. Replay with a stage objective: guardian first, then the objective.
	var shrine := state(true,true)
	shrine.slots.b.initial_resolved = true
	check("replay_with_objective_waits_for_it",not shrine.portal_view("to_lair").open)
	shrine.objectives["shrine"] = true
	check("replay_opens_on_the_objective",shrine.portal_view("to_lair").open)
	var no_guardian := state(true,false); no_guardian.slots.erase("b")
	check("replay_stage_without_guardian_or_objective_is_open",no_guardian.portal_view("to_lair").open)
	# 5. Authoring: guardian brushes and stage objectives, earlier hashes intact.
	var data := Document.empty("phase_rules")
	var brush := Document.brush("guard","s",Vector3.ZERO,{"species_id":"x","category":"elite","origin_id":"o","weight":1})
	var plain_data := data.duplicate(true); plain_data.brushes.append(brush.duplicate(true))
	var marked := brush.duplicate(true); marked["guardian"] = true
	var proposed := Operations.propose(data,"brush/upsert",marked)
	var wrong := marked.duplicate(true); wrong.guardian = "yes"
	check("guardian_brush_is_accepted_and_typed",proposed.ok and proposed.data.brushes[0].guardian == true and not Operations.propose(data,"brush/upsert",wrong).ok and Document.validate(plain_data).ok)
	var unmarked := marked.duplicate(true); unmarked.erase("guardian")
	var with_flag := data.duplicate(true); with_flag.brushes.append(marked)
	check("guardian_changes_the_hash_only_when_present",Document.hash_source(plain_data) == Document.hash_source(Operations.propose(data,"brush/upsert",unmarked).data) and Document.hash_source(with_flag) != Document.hash_source(plain_data))
	var objective := Operations.propose(data,"interaction/upsert",{"interaction_id":"shrine","kind":"stage_unlock","surface_id":"s","position_xyz":[0.0,0.0,0.0],"target_id":""})
	check("stage_objective_is_an_interaction",objective.ok and not Operations.propose(data,"interaction/upsert",{"interaction_id":"bad","kind":"switch","surface_id":"s","position_xyz":[0.0,0.0,0.0],"target_id":""}).ok)
	# 6. Charger: a burst within its range, then a cooldown.
	var charger := EnemyActor.new()
	charger._try_charge(300.0)
	var bursting := charger._charge_factor() > 1.0
	charger._charge_remaining = 0.0; charger._try_charge(300.0)
	var cooled := charger._charge_factor() == 1.0
	charger._charge_cooldown = 0.0; charger._try_charge(60.0)
	check("charger_bursts_in_range_then_cools_down",bursting and cooled and charger._charge_factor() == 1.0)
	charger.free()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_PHASE_RULES_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
