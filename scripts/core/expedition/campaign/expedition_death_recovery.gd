class_name ExpeditionDeathRecovery
extends RefCounted
## Approved D04 policy. This is never used for travel, clear or suspension.
static func prepare(host: RunController) -> void:
	var player := host.player
	var cooldowns: Dictionary = {}
	for property: Dictionary in player.get_property_list():
		var field: String = property["name"]
		if field.ends_with("cooldown") or field.ends_with("cooldowns"):
			var value: Variant = player.get(field)
			cooldowns[field] = value.duplicate(true) if value is Dictionary else value
	var sentinel_cooldowns := [player.sentinel_state.observation_cooldown, player.sentinel_state.opening_cooldown, player.sentinel_state.intrinsic_cooldown]
	var hunter_cooldown := player.hunter_state.step_cooldown
	var hunter_claims := [player.hunter_state._activations.duplicate(true), player.hunter_state._emissions.duplicate(true)]
	var sentinel_claims := [player.sentinel_state._opening_emissions.duplicate(true), player.sentinel_state._intrinsic_emissions.duplicate(true)]
	var element_claims := player._elementalist_refunded_emissions.duplicate(true)
	var spirit_claims := player._spiritualist_refunded_emissions.duplicate(true)
	player.cancel_active_cast()
	player.clear_shield_stance()
	player.clear_perseverance()
	player.clear_fury()
	player.clear_defender_state()
	player.clear_berserker_state()
	player.clear_elementalist_state()
	player.clear_spiritualist_state()
	player.clear_sentinel_state()
	player.clear_hunter_state()
	player.clear_foliage_shelters()
	player.clear_statuses()
	player.extended_aim_remaining = 0.0
	player.velocity = Vector2.ZERO
	player._path.clear()
	player._has_path_goal = false
	player.target = null
	player._stop_dash()
	player._stop_world_travel(true)
	player._attack_recovery = 0.0
	for field: String in cooldowns: player.set(field, cooldowns[field])
	player.sentinel_state.observation_cooldown = sentinel_cooldowns[0]
	player.sentinel_state.opening_cooldown = sentinel_cooldowns[1]
	player.sentinel_state.intrinsic_cooldown = sentinel_cooldowns[2]
	player.sentinel_state._opening_emissions = sentinel_claims[0]
	player.sentinel_state._intrinsic_emissions = sentinel_claims[1]
	player.hunter_state.step_cooldown = hunter_cooldown
	player.hunter_state._activations = hunter_claims[0]
	player.hunter_state._emissions = hunter_claims[1]
	player._elementalist_refunded_emissions = element_claims
	player._spiritualist_refunded_emissions = spirit_claims
	if host.trap_registry != null: host.trap_registry.clear_owner(player.get_instance_id())
	# All stage-local future actions owned by the dead player are retired. Applied
	# enemy HP/statuses and causal claims are not rolled back.
	var runtimes: Array[Dictionary] = [{"fields": {"geometer_casting": host.geometer_casting, "spiritualist_echo_state": host.spiritualist_echo_state, "spiritualist_drain_state": host.spiritualist_drain_state, "spiritualist_veil_state": host.spiritualist_veil_state, "spiritualist_procession_state": host.spiritualist_procession_state, "_defender_slowed_enemies": host._defender_slowed_enemies, "_spiritualist_veil_members": host._spiritualist_veil_members}}]
	for record: Dictionary in host.campaign_runtime.records.values():
		if not record["fields"].is_empty(): runtimes.append(record)
	for record: Dictionary in runtimes:
		var fields: Dictionary = record["fields"]
		if fields.get("trap_registry") != null: fields["trap_registry"].clear_owner(player.get_instance_id())
		var geometer: GeometerCasting = fields["geometer_casting"]
		if is_instance_valid(geometer): geometer.clear_construction()
		var echoes: SpiritualistEchoState = fields["spiritualist_echo_state"]
		var next_wave := echoes.next_wave_id
		echoes.clear()
		echoes.next_wave_id = next_wave
		fields["spiritualist_drain_state"].cancel()
		fields["spiritualist_veil_state"].clear()
		for enemy: CombatActor in fields["_spiritualist_veil_members"].values():
			if is_instance_valid(enemy): enemy.remove_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil")
		fields["_spiritualist_veil_members"].clear()
		fields["spiritualist_veil_fraction"] = 0.0
		fields["spiritualist_procession_state"].cancel()
		for enemy: CombatActor in fields["_defender_slowed_enemies"].values():
			if is_instance_valid(enemy): enemy.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"defender_anchor")
		fields["_defender_slowed_enemies"].clear()
	host.spiritualist_veil_fraction = 0.0
	_retire_actions(host)
	# Cached stage membership must not keep freed future actions as graph roots.
	for record: Dictionary in host.campaign_runtime.records.values():
		record["nodes"] = record["nodes"].filter(func(node: Variant) -> bool: return is_instance_valid(node))
		for node: Variant in record["modes"].keys():
			if not is_instance_valid(node): record["modes"].erase(node)

static func _retire_actions(root: Node) -> void:
	for child: Node in root.get_children():
		if child.is_in_group("player_projectiles") or child.is_in_group("player_effects"):
			# Immediate retirement is required before the next snapshot barrier.
			child.free()
		else: _retire_actions(child)

static func revive(player: PlayerActor, policy: Dictionary) -> void:
	player.health._death_emitted = false
	player.health.current_hp = player.health.max_hp * float(policy["hp_fraction"])
	player.current_sp = player.max_sp * float(policy["sp_fraction"])
	# Checkpoint39: the death pose is presentation state captured with the actor;
	# without this the revived player kept the corpse sprite.
	if player.character_animation != null: player.character_animation.state.revive()
	player.show()
	player.queue_redraw()
