extends SceneTree
var checks := 0
var failures := 0
var catalog := ProfileCatalog.pilot()
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	_check(catalog.is_valid(), "approved DAG catalog is valid")
	var count := 0
	for base: StringName in [&"swordsman", &"mage", &"archer"]:
		for id: StringName in catalog.skill_ids_for_identity(base, &""):
			count += 1
			_check(catalog.skill_metadata(id)["wallet"] == &"base", "base nodes retain their own wallet")
	for pair: Array in [[&"swordsman",&"defender"],[&"swordsman",&"berserker"],[&"mage",&"elementalist"],[&"mage",&"spiritualist"],[&"mage",&"mg_ar"],[&"archer",&"sentinel"],[&"archer",&"hunter"]]:
		var options := _options(pair[0], pair[1])
		for option: Dictionary in options:
			if not StringName(option["metadata"]["required_evolution_id"]).is_empty(): count += 1
			var inspected := SkillDependencyRules.inspect(option["skill_id"], options, _summary())
			_check(inspected["valid"], "all prerequisites belong to the actual identity: %s" % option["skill_id"])
			if int(option["metadata"]["free_rank"]) > 0:
				_check(inspected["requirements"].is_empty(), "evolution entry stays free and independent")
	_check(count == 93, "all93 production skills covered exactly once")
	var result := SkillDependencyRules.inspect(&"sentinel_piercing_shot",_options(&"archer",&"sentinel"),_summary())
	_check(result["missing_by_wallet"] == {&"base":4,&"evolution":0} and result["purchase_by_wallet"][&"evolution"]==1, "cross-job route counts both unique base ancestors before its own purchase")
	_check(result["required_job"] == 25, "job gate remains independent from prerequisite points")
	result = SkillDependencyRules.inspect(&"geometer_rewrite",_options(&"mage",&"mg_ar"),_summary())
	_check(result["missing_by_wallet"] == {&"base":2,&"evolution":2} and result["purchase_by_wallet"][&"evolution"]==1, "geometer uses own Mage ancestry, split budgets")
	result = SkillDependencyRules.inspect(&"geometer_rewrite",_options(&"mage",&"mg_ar",{&"teleport":2,&"geometer_translation":2}),_summary())
	_check(result["ancestors"].size()==2 and result["missing_by_wallet"][&"base"]==0 and result["missing_by_wallet"][&"evolution"]==0, "complete chain remains visible when already learned, without charging it again")
	var options := _options(&"swordsman",&"berserker",{&"fury":2})
	result = SkillDependencyRules.inspect(&"berserker_obstinacy",options,_summary())
	_check(result["missing_by_wallet"][&"base"]==1 and result["requirements"][0]["learned_rank"]==2, "permanent ranks discount the true remaining investment")
	for option: Dictionary in options:
		if option["skill_id"] == &"fury": option["item_rank"] = 5
	result = SkillDependencyRules.inspect(&"berserker_obstinacy",options,_summary())
	_check(not result["prerequisites_met"] and result["missing_by_wallet"][&"base"]==1, "equipment rank cannot satisfy investment")
	result = SkillDependencyRules.inspect(&"berserker_obstinacy",_options(&"swordsman",&"berserker",{&"fury":3}),_summary(40,0,20))
	_check(result["prerequisites_met"] and result["points_met"], "permanent grants count and an exhausted unrelated wallet does not block legal purchase")
	result = SkillDependencyRules.inspect(&"geometer_rewrite",_options(&"mage",&"mg_ar"),_summary(25,19,20))
	_check(not result["job_met"] and result["points_met"], "enough points never bypass job level")
	result = SkillDependencyRules.inspect(&"geometer_rewrite",_options(&"mage",&"mg_ar"),_summary(40,0,20))
	_check(not result["points_met"], "evolution surplus cannot pay base ancestors")
	options = _options(&"archer",&"sentinel")
	# A conjunction shares Duplo2 with the path to Perfurante2; it must cost four, not six.
	for option: Dictionary in options:
		if option["skill_id"] == &"sentinel_piercing_shot":
			for req: Dictionary in option["metadata"]["rank_requirements"].values(): req["skill_ranks"] = {&"piercing_arrow":2,&"double_shot":2}
	result = SkillDependencyRules.inspect(&"sentinel_piercing_shot",options,_summary())
	_check(result["missing_by_wallet"][&"base"]==4, "shared ancestors deduplicate by greatest needed rank")
	result = SkillDependencyRules.inspect(&"fireball",_options(&"mage",&"",{&"fireball":5}),_summary())
	_check(result["maximum"] and result["purchase_by_wallet"][&"base"]==0, "maxed skills never advertise another purchase")
	var c := CharacterState.new("deps-character","Teste",&"mage")
	c.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(not CharacterProgression.learn_skill(c,catalog,&"fire_spear")["ok"], "cannot buy gated skill first")
	_check(CharacterProgression.learn_skill(c,catalog,&"fire_wall")["ok"] and CharacterProgression.learn_skill(c,catalog,&"fire_wall")["ok"] and CharacterProgression.learn_skill(c,catalog,&"fire_spear")["ok"], "real learning accepts the approved ordered path")
	var old := catalog.pre_all_skill_dependencies_catalog()
	_check(old.skill_metadata(&"fire_spear")["rank_requirements"][1]["skill_ranks"].is_empty() and catalog.skill_metadata(&"fire_spear")["rank_requirements"][1]["skill_ranks"] == {&"fire_wall":2}, "historical catalog copy cannot mutate current requirements")
	var retained := ActionBarLayout.assign(ActionBarLayout.empty(),&"fire_spear",0,1)
	retained = ActionBarLayout.assign(retained,&"fireball",1)
	var controls := BattleControls.new()
	root.add_child(controls)
	controls.set_action_bar([&"fireball"],retained,ControlPreferences.new())
	await process_frame
	_check(controls.action_slots==retained and controls.action_editor.action_slots==retained, "unlearned retained reference never clears other slots in editor or combat")
	_check(controls.slot_buttons[0].disabled and not controls.slot_buttons[1].disabled, "retained unavailable skill stays visibly disabled beside learned skill")
	_check(ActionBarLayout.valid_preserving(ActionBarLayout.move(retained,0,4),[&"fireball"],retained), "existing disabled reference may move without granting execution")
	_check(not ActionBarLayout.valid_preserving(ActionBarLayout.assign(retained,&"fire_spear",5,2),[&"fireball"],retained), "new unlearned rank variant cannot be smuggled through preserved reference")
	_check(not ActionBarLayout.valid_preserving(ActionBarLayout.assign(retained,&"ice_spear",3),[&"fireball"],retained), "a different unlearned skill cannot be assigned")
	controls.free()
	_approved_builds()
	print("E06 skill dependencies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _summary(job: int=40, base_points: int=19, evo_points: int=20) -> Dictionary:
	return {"job_level":job,"base_skill_points_available":base_points,"evolution_skill_points_available":evo_points}
func _options(base: StringName, evo: StringName, ranks: Dictionary={}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in catalog.skill_ids_for_identity(base,evo):
		var meta := catalog.skill_metadata(id)
		result.append({"skill_id":id,"metadata":meta,"available":true,"rank":maxi(int(meta["free_rank"]),int(ranks.get(id,0))),"maximum_rank":int(meta["free_rank"])+int(meta["max_purchased_rank"])})
	return result
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func _approved_builds() -> void:
	# Independently authored approval examples; totals include ancestors exactly once.
	var examples: Array[Array] = [
		[&"swordsman",&"",13,0,{&"slash":2,&"brutal_strike":2,&"concentrated_rage":3,&"fury":2,&"blood_thirst":2,&"dash":2}],
		[&"mage",&"",15,0,{&"lightning":2,&"electric_discharge":2,&"lightning_wall":3,&"ice_spear":2,&"ice_wall":2,&"teleport":2,&"mage_mana_regeneration":2}],
		[&"archer",&"",15,0,{&"double_shot":2,&"piercing_arrow":2,&"arrow_rain":3,&"snare_trap":2,&"trap_technique":2,&"extended_aim":2,&"archer_precision":2}],
		[&"swordsman",&"defender",2,15,{&"shield_wall":2,&"defender_counterstroke":3,&"defender_anchor":3,&"defender_line_lock":3,&"defender_guard_return":2,&"defender_riposte":3,&"defender_watch":2}],
		[&"swordsman",&"berserker",3,12,{&"fury":3,&"berserker_rupture":3,&"berserker_execution":3,&"berserker_pursuit":2,&"berserker_breath_steal":3,&"berserker_obstinacy":2}],
		[&"mage",&"elementalist",4,14,{&"ice_spear":2,&"lightning":2,&"elementalist_flame_burst":3,&"elementalist_prismatic_focus":2,&"elementalist_glacial_ring":2,&"elementalist_lightning_arc":3,&"elementalist_prismatic_resonance":2,&"elementalist_tri_nova":3}],
		[&"mage",&"spiritualist",2,14,{&"phantom_barrier":2,&"spiritualist_echo_curse":3,&"spiritualist_echo_recovery":2,&"spiritualist_soul_drain":3,&"spiritualist_spectral_veil":2,&"spiritualist_channel_focus":2,&"spiritualist_dissipation":3}],
		[&"archer",&"sentinel",6,14,{&"double_shot":2,&"piercing_arrow":2,&"extended_aim":2,&"sentinel_headshot":3,&"sentinel_observe":2,&"sentinel_precision_stance":2,&"sentinel_piercing_shot":3,&"sentinel_opening_read":2,&"sentinel_absolute_focus":3}],
		[&"archer",&"hunter",4,15,{&"double_shot":2,&"slowing_arrow":2,&"hunter_freezing_trap":3,&"hunter_tar_trap":2,&"hunter_thorn_trap":3,&"hunter_mark":2,&"hunter_shooting_discipline":2,&"hunter_covering_shot":2,&"hunter_easy_prey":2}],
		[&"mage",&"mg_ar",2,16,{&"teleport":2,&"geometer_trace":3,&"geometer_incidence":2,&"geometer_translation":2,&"geometer_triangulation":2,&"geometer_vector_memory":2,&"geometer_collapse":3,&"geometer_rewrite":3}],
	]
	for example: Array in examples:
		var paid: Dictionary[StringName,int] = {}
		for id: StringName in example[4]:
			var purchased := int(example[4][id]) - int(catalog.skill_metadata(id)["free_rank"])
			if purchased > 0: paid[id] = purchased
		_check(catalog.validate_purchased_ranks(example[0],example[1],40,paid)["ok"], "approved complete route is legal: %s/%s" % [example[0],example[1]])
		_check(catalog.skill_points_spent(paid,&"base")==example[2] and catalog.skill_points_spent(paid,&"evolution")==example[3] and example[2]<=19 and example[3]<=20, "approved route fits separate point budgets: %s/%s" % [example[0],example[1]])
