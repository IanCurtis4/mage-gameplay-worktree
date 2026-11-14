extends SceneTree
## E08 compact checkpoint (docs/epics/e08_compact_checkpoint.md): format 3
## transport, binding to the published/generated composition, conservative
## eligibility with the exact fallback, and failed resume without durable change.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const Compact = preload("res://scripts/core/expedition/persistence/compact_expedition.gd")
const Ruins = preload("res://data/expedition/phases/ruined_crossing.gd")
var count := 0
var failures := 0

class RefusingRehearsal:
	extends ExpeditionService
	func _rehearse_compact(_controller: RunController, _encoding: PackedByteArray, _profile: ProfileState) -> Dictionary:
		return {"ok": false, "error_code": &"probe_rehearsal_refused"}

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error("E08 compact: " + label)

func repack(record: Dictionary, base: Dictionary) -> Dictionary:
	return ExpeditionCheckpointCodec.pack_compact(var_to_bytes(record), base["owner_digest"], base["session"])["checkpoint"]

func panel_for(lobby: CharacterMenu, character_id: String) -> PhaseSelectionPanel:
	var panel := PhaseSelectionPanel.new()
	lobby.add_child(panel)
	panel.configure(lobby, character_id)
	return panel

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var f := F.make("e08_compact")
	var facade: ProfileFacade = f["facade"]
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	current_scene = menu
	var panel := panel_for(menu, f["a"])
	panel.seed_input.text = "42"
	var entered: Dictionary = await panel.start()
	check(entered.get("ok", false), "entry " + str(entered))
	if not entered.get("ok", false): _finish(); return
	var host := entered["root"] as RunController

	# Transport: format 3 is its own envelope; damaged bytes never reach decode.
	var lock := facade.current_profile().expedition_for_character(f["a"])
	var base: Dictionary = lock.checkpoint.duplicate(true)
	check(base["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "entry writes format 3")
	check(int(Compact.cut_tally.get("compact", 0)) >= 1, "tally counts the accepted entry cut")
	check(ExpeditionCheckpointCodec.unpack(base).get("error_code") == &"checkpoint_version_unavailable", "exact unpack refuses format 3")
	check(ExpeditionService.prepare_compact(base).get("ok", false), "intact checkpoint prepares its composition")
	var truncated := base.duplicate(true)
	truncated["snapshot"] = String(truncated["snapshot"]).substr(0, String(truncated["snapshot"]).length() - 8)
	check(not ExpeditionCheckpointCodec.validate_record(truncated)["ok"], "truncated transport is rejected")
	check(not ExpeditionService.prepare_compact(truncated).get("ok", false), "truncated transport never prepares")
	var raw := Marshalls.base64_to_raw(base["snapshot"])
	raw[raw.size() / 2] = raw[raw.size() / 2] ^ 0x5a
	var flipped := base.duplicate(true)
	flipped["snapshot"] = Marshalls.raw_to_base64(raw)
	check(ExpeditionCheckpointCodec.validate_record(flipped).get("error_code") == &"invalid_checkpoint", "corrupted bytes fail the compressed digest")
	var decoded := Compact.decode(ExpeditionCheckpointCodec.validate_record(base)["bytes"])
	check(decoded.get("ok", false), "intact envelope decodes")
	var record: Dictionary = decoded["record"]

	# Composition binding: same envelope with another seed/hash is not installable.
	var other_seed := record.duplicate(true)
	other_seed["source"]["seed"] = "43"
	check(ExpeditionService.prepare_compact(repack(other_seed, base)).get("error_code") == &"content_revision_unavailable", "another seed fails the composition hash")
	var other_hash := record.duplicate(true)
	other_hash["source"]["hash"] = "a".repeat(64)
	check(ExpeditionService.prepare_compact(repack(other_hash, base)).get("error_code") == &"content_revision_unavailable", "another composition hash is unavailable")
	var extra := record.duplicate(true)
	extra["unexpected"] = true
	check(ExpeditionService.prepare_compact(repack(extra, base)).get("error_code") == &"invalid_checkpoint", "unknown envelope key is rejected")
	var newer := record.duplicate(true)
	newer["version"] = Compact.VERSION + 1
	check(ExpeditionService.prepare_compact(repack(newer, base)).get("error_code") == &"invalid_checkpoint", "unknown compact version is rejected")
	var bad_seed := record.duplicate(true)
	bad_seed["source"]["seed"] = "4x2"
	check(ExpeditionService.prepare_compact(repack(bad_seed, base)).get("error_code") == &"invalid_checkpoint", "non-canonical seed is rejected")

	# Eligibility is conservative and names the reason it kept the exact format.
	paused = true
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(host)["ok"], "barrier for eligibility probes")
	check(Compact.capture(host, barrier).get("ok", false), "idle cut is eligible")
	var shot := Node2D.new()
	shot.add_to_group("enemy_projectiles")
	host.add_child(shot)
	check(Compact.capture(host, barrier).get("detail") == "projectile_or_effect", "live projectile keeps the exact format")
	host.remove_child(shot)
	shot.free()
	host.player._world_dash_remaining = 0.5
	check(Compact.capture(host, barrier).get("detail") == "player_action", "player dash keeps the exact format")
	host.player._world_dash_remaining = 0.0
	var runtime := host.campaign_runtime
	var profile := host.player.world_motion._profile
	check(Compact._homes_clear(runtime, host.player.world_point(), profile), "player away from homes")
	var alive_home: ExpeditionWorldPoint
	for id: String in runtime.state.slots:
		var slot: Dictionary = runtime.state.slots[id]
		if slot["life_state"] == "alive" and slot["stage_id"] == runtime.state.current_stage_id: alive_home = ExpeditionPopulationPlanner.point(slot["home"])
	check(alive_home != null and not Compact._homes_clear(runtime, alive_home, profile), "player standing on a living home is ineligible")
	barrier.release()
	paused = false

	# Rehearsal: a compact cut is restored off-tree before it replaces the base.
	var live := facade.current_profile()
	var rehearsal_service := ExpeditionService.new(facade)
	var queued := host.request_memory_snapshot(true)
	check(queued.get("ok", false), "rehearsal cut queued")
	var cut: Dictionary = await host.memory_snapshot_ready
	check(cut.get("compact", false), "rehearsal cut is compact")
	var rehearsed := rehearsal_service._rehearse_compact(host, cut["encoding"], live)
	check(rehearsed.get("ok", false) and int(rehearsed.get("rehearsal_usec", -1)) >= 0, "eligible cut rehearses its resume " + str(rehearsed))
	var tampered: Dictionary = bytes_to_var(cut["encoding"])
	tampered["source"]["hash"] = "b".repeat(64)
	check(rehearsal_service._rehearse_compact(host, var_to_bytes(tampered), live).get("error_code") == &"content_revision_unavailable", "rehearsal refuses another composition")
	var refusing := RefusingRehearsal.new(facade)
	var lock_before := facade.current_profile().expedition_for_character(f["a"])
	var tally_before := int(Compact.cut_tally.get("rehearsal_failed", 0))
	var kept_exact := refusing.checkpoint(host, host._memory_snapshot_barrier, lock_before.expedition_id, lock_before.phase_id, "e08_compact_rehearsal_refused", live.revision, false, cut)
	check(kept_exact.get("ok", false), "failed rehearsal still checkpoints " + str(kept_exact))
	var after_refusal := facade.current_profile().expedition_for_character(f["a"])
	check(after_refusal.checkpoint["format"] == ExpeditionCheckpointCodec.FORMAT and after_refusal.lifecycle == &"active", "failed rehearsal writes the exact format")
	check(int(Compact.cut_tally.get("rehearsal_failed", 0)) == tally_before + 1, "tally counts the failed rehearsal")
	var accepted := rehearsal_service.checkpoint(host, host._memory_snapshot_barrier, lock_before.expedition_id, lock_before.phase_id, "e08_compact_rehearsal_ok", facade.current_profile().revision, false, cut)
	check(not accepted.get("ok", false) and accepted.get("error_code") == &"stale_revision", "a frozen cut is not reused after the base changed")
	host.release_memory_snapshot()
	queued = host.request_memory_snapshot(true)
	cut = await host.memory_snapshot_ready
	accepted = rehearsal_service.checkpoint(host, host._memory_snapshot_barrier, lock_before.expedition_id, lock_before.phase_id, "e08_compact_rehearsal_ok", facade.current_profile().revision, false, cut)
	check(accepted.get("ok", false) and facade.current_profile().expedition_for_character(f["a"]).checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "rehearsed cut writes format 3 " + str(accepted))
	host.release_memory_snapshot()
	await process_frame

	# Exact fallback: an ineligible suspension keeps enemy state exactly.
	var hurt := host.enemies[0] as EnemyActor
	var hurt_slot := runtime.slot_for_actor(hurt)
	hurt.health.current_hp = hurt.health.max_hp * 0.5
	# The player on a vacated living home is a supported, ineligible cut.
	var start_point := host.player.world_point()
	var home := ExpeditionPopulationPlanner.point(runtime.state.slots[hurt_slot]["home"])
	var geometry := hurt.world_motion.geometry
	var moved := {"ok": false}
	for offset: Vector2 in [Vector2(160, 0), Vector2(-160, 0), Vector2(0, 160), Vector2(0, -160), Vector2(240, 240), Vector2(-240, -240)]:
		var support := geometry.support_at(home.surface_id, Vector2(home.position.x, home.position.z) + offset, geometry.geometry_revision)
		if not support["ok"]: continue
		moved = hurt.world_motion.teleport(ExpeditionPopulationPlanner.point(support["data"]["point"]), 1.0e20, geometry.geometry_revision)
		if moved["ok"]: break
	check(moved["ok"], "enemy leaves its home " + str(moved))
	var stood := host.player.world_motion.teleport(home, 1.0e20, geometry.geometry_revision)
	check(stood.get("ok", false), "player stands on the vacated home " + str(stood))
	await process_frame
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	var closed: Dictionary = await status.run_action({"kind": "suspend"})
	check(closed.get("ok", false), "fallback suspension " + str(closed))
	if not closed.get("ok", false): _finish(); return
	var lobby := current_scene as CharacterMenu
	lock = facade.current_profile().expedition_for_character(f["a"])
	check(lock.checkpoint["format"] == ExpeditionCheckpointCodec.FORMAT, "ineligible suspension writes the exact format")
	var resumed: Dictionary = await panel_for(lobby, f["a"]).start()
	check(resumed.get("ok", false), "exact resume " + str(resumed))
	if not resumed.get("ok", false): _finish(); return
	host = resumed["root"]
	var kept := host.campaign_runtime.actors.get(hurt_slot) as EnemyActor
	check(kept != null and kept.health.current_hp < kept.health.max_hp * 0.75, "exact format keeps the enemy damage")
	check(kept != null and kept.world_point().to_data() != host.campaign_runtime.state.slots[hurt_slot]["home"], "exact format keeps the enemy away from home")

	# Compact suspension conserves the player; living enemies return home healed.
	var back := host.player.world_motion.teleport(start_point, 1.0e20, host.player.world_motion.geometry.geometry_revision)
	check(back.get("ok", false), "player leaves the living home " + str(back))
	await process_frame
	kept.health.current_hp = kept.health.max_hp * 0.25
	host.player.current_sp = host.player.max_sp * 0.4
	host.player.attack_cooldown = 1.5
	var sp := host.player.current_sp
	var hp := host.player.health.current_hp
	var point := host.player.world_point().to_data()
	var choices := host.run_state.pending_choices
	status = host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	closed = await status.run_action({"kind": "suspend"})
	check(closed.get("ok", false), "compact suspension " + str(closed))
	if not closed.get("ok", false): _finish(); return
	lobby = current_scene as CharacterMenu
	var profile_state := facade.current_profile()
	lock = profile_state.expedition_for_character(f["a"])
	check(lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "eligible suspension writes format 3")

	# A prepared composition for another seed fails before any durable change.
	var foreign := ExpeditionAssembler.build(Ruins.input("43"))
	var foreign_manifest: ExpeditionManifest = foreign["data"]["manifest"]
	var wrong := {"ok": true, "manifest": foreign_manifest, "rules": Ruins.rules(foreign_manifest)}
	var revision := profile_state.revision
	var checkpoint_before: Dictionary = lock.checkpoint.duplicate(true)
	var refused := ExpeditionService.new(facade).resume(lock.expedition_id, f["a"], "e08_compact_wrong", revision, wrong)
	check(refused.get("error_code") == &"content_revision_unavailable", "foreign composition is refused " + str(refused))
	var after := facade.current_profile()
	var lock_after := after.expedition_for_character(f["a"])
	check(after.revision == revision and lock_after.lifecycle == &"suspended" and lock_after.checkpoint == checkpoint_before, "refused resume leaves the profile untouched")

	resumed = await panel_for(lobby, f["a"]).start()
	check(resumed.get("ok", false), "compact resume " + str(resumed))
	if not resumed.get("ok", false): _finish(); return
	host = resumed["root"]
	check(host.player.world_point().to_data() == point, "player keeps position")
	check(is_equal_approx(host.player.health.current_hp, hp) and is_equal_approx(host.player.current_sp, sp), "player keeps HP and SP")
	check(is_equal_approx(host.player.attack_cooldown, 1.5) and host.run_state.pending_choices == choices, "player keeps cooldown and offers")
	var healed := host.campaign_runtime.actors.get(hurt_slot) as EnemyActor
	check(healed != null and is_equal_approx(healed.health.current_hp, healed.health.max_hp), "living enemy returns with full HP")
	check(healed != null and healed.world_point().to_data() == host.campaign_runtime.state.slots[hurt_slot]["home"], "living enemy returns to its home")
	check(host.campaign_runtime.valid(), "restored population is valid")
	host.queue_free()
	_finish()

func _finish() -> void:
	shot_cleanup()
	print("E08 compact checkpoint: %d checks, %d failures" % [count, failures])
	print("E08_COMPACT_TALLY " + JSON.stringify(Compact.cut_tally))
	quit(1 if failures > 0 or count == 0 else 0)

func shot_cleanup() -> void:
	for node: Node in get_nodes_in_group("enemy_projectiles"):
		if node.get_script() == null: node.queue_free()
