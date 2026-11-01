extends "res://tests/fixtures/e07/f5/suite.gd"
## Checkpoint40 (J3): waves and the births they admit, and a revive that admits a
## birth, are journal entries on the same host; base + journal restores them.
# The live host creates journal births one per frame; off-tree, the frames are
# simulated by draining the queue after each write.
func journal(f: Dictionary, events: Array, request: String) -> Dictionary:
	var host: RunController = f["controller"]
	var result: Dictionary = f["service"].journal_events(host, f["barrier"], events, request, f["facade"].current_profile().revision)
	return settle(host, result)
func settle(host: RunController, result: Dictionary) -> Dictionary:
	result["queued"] = host.campaign_runtime.birth_queue.size()
	result["drained"] = host.campaign_runtime.drain_births(host, 64).get("ok", false) and host.campaign_runtime.birth_queue.is_empty()
	return result
func wave_event(f: Dictionary) -> Dictionary:
	return {"kind": "wave", "wave_index": f["controller"].campaign_runtime.state.clock.wave_index}
func journal_kill(f: Dictionary, id: String, request: String) -> Dictionary:
	var host: RunController = f["controller"]
	var actor: EnemyActor = host.campaign_runtime.actors[id]
	actor.health.current_hp = 0.0
	actor.health._death_emitted = true
	host._on_enemy_died(actor)
	return journal(f, host.campaign_runtime.pending_events.duplicate(true), request)
func payloads(f: Dictionary) -> Array:
	var lock: ExpeditionAssetLock = f["facade"].current_profile().expedition_for_character(f["controller"].run_state.character_id)
	return ExpeditionService.Journal.decode(lock.journal, lock.checkpoint).get("payloads", [])
func alive_enemies(host: RunController) -> int:
	return host.enemies.filter(func(actor: CombatActor) -> bool: return is_instance_valid(actor) and actor.is_alive()).size()
# Base + journal on a fresh restore gives the live campaign state.
func replay_matches(f: Dictionary) -> bool:
	var host: RunController = f["controller"]
	var lock: ExpeditionAssetLock = f["facade"].current_profile().expedition_for_character(host.run_state.character_id)
	var restored: Dictionary = ExpeditionService.new(f["facade"])._restore(lock)
	if not restored.get("ok", false): print("replay failed ", restored.get("error_code")); return false
	var copy: RunController = restored["root"]
	var state := copy.campaign_runtime.state
	var live := host.campaign_runtime.state
	var same: bool = state.slots == live.slots and state.stages == live.stages and state.clock.wave_index == live.clock.wave_index and alive_enemies(copy) == alive_enemies(host) and copy.campaign_runtime.actors.keys() == host.campaign_runtime.actors.keys()
	if not same: print("replay differs ", JSON.stringify({"copy": state.slots, "live": live.slots}).substr(0, 1500))
	copy.free()
	return same
func _run() -> void:
	var f := make("waves_journal")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	check(kill(f, "entry_field", "entry_field")["ok"] and kill(f, "entry_boss", "entry_boss")["ok"], "entry clear")
	check(travel_to(f, "entry_to_left", "left")["ok"], "first branch")
	check(kill(f, "left_field", "left_field")["ok"] and kill(f, "left_boss", "left_boss")["ok"], "second stage clear")
	check(travel_to(f, "left_to_entry", "back")["ok"], "return before global wave (new base)")
	var host: RunController = f["controller"]
	check(host.campaign_runtime.state.advance(900.0), "one global clock considers both cleared stages")
	var waved := journal(f, [wave_event(f)], "wave1")
	check(waved.get("ok", false) and f["controller"] == host and waved.queued == 1 and waved.drained, "wave is a journal entry on the same host; the birth is queued for the next frame")
	var written := payloads(f)
	check(written.size() == 1 and ExpeditionService.Journal.is_wave(written[0]) and written[0].admitted.size() == 1 and written[0].admitted[0].slot_id == "entry_field" and written[0].pending.size() == 2, "entry names both waiting slots and the one birth")
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 1 and host.campaign_runtime.state.slots["entry_field"]["life_state"] == "alive" and alive_enemies(host) == 1, "active stage gets its replacement live")
	check(host.campaign_runtime.state.slots["left_field"]["life_state"] == "respawn_pending" and host.campaign_runtime.state.slots["left_field"]["generation"] == 0 and host.campaign_runtime.pending_events.is_empty(), "unloaded stage keeps one intent; the wave leaves the queue")
	check(replay_matches(f), "base + journal restores the wave and its birth")
	relocate(f, host.campaign_runtime.state.slots["entry_field"]["home"])
	check(journal_kill(f, "entry_field", "replacement_death")["ok"], "generation-one death is journaled")
	host.campaign_runtime.state.advance(900.0)
	check(journal(f, [wave_event(f)], "blocked_wave")["ok"], "occupied home still writes the waiting intent")
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 1 and host.campaign_runtime.state.slots["entry_field"]["life_state"] == "respawn_pending" and payloads(f)[-1].admitted.is_empty(), "player occupancy admits no birth")
	relocate(f, host.campaign_runtime.state.entrance("entry"))
	check(journal(f, [wave_event(f)], "arrival_safe")["ok"] and host.campaign_runtime.state.slots["entry_field"]["generation"] == 2 and alive_enemies(host) == 1, "vacated home admits the second generation")
	check(replay_matches(f), "base + deaths + waves replay to the live state")
	# A death, a wave queued by the clock (no wave flush yet), the player falls,
	# then the revive admits the waiting birth in its own entry.
	relocate(f, host.campaign_runtime.state.slots["entry_field"]["home"])
	check(journal_kill(f, "entry_field", "third_death")["ok"], "generation-two death is journaled")
	relocate(f, host.campaign_runtime.state.entrance("entry"))
	host.campaign_runtime.state.advance(900.0)
	host.player.health.current_hp = 0.0
	host.player.health._death_emitted = true
	host.campaign_runtime.pending_events.append({"kind": "player_death", "event_id": "player_death_waves"})
	var fell := journal(f, host.campaign_runtime.pending_events.duplicate(true), "player_fell")
	check(fell.get("ok", false) and host.campaign_runtime.state.lifecycle == "recovering" and host.campaign_runtime.state.slots["entry_field"]["life_state"] == "respawn_pending", "player death is journaled while the birth waits")
	var lock: ExpeditionAssetLock = f["facade"].current_profile().expedition_for_character(host.run_state.character_id)
	check(lock.lifecycle == &"recovering", "reservation is in recovery")
	var revived: Dictionary = settle(host, f["service"].journal_revive(host, f["barrier"], "player_death_waves", "revive_waves", f["facade"].current_profile().revision))
	check(revived.get("ok", false) and f["controller"] == host and host.player.is_alive(), "revive with a pending birth is a journal entry")
	check(ExpeditionService.Journal.is_revive(payloads(f)[-1]) and payloads(f)[-1].admitted.size() == 1 and host.campaign_runtime.state.slots["entry_field"]["generation"] == 3 and alive_enemies(host) == 1 and host.campaign_runtime.state.lifecycle == "active", "revive entry admits the birth and the run resumes")
	check(replay_matches(f), "base + journal replays the revive and its births")
	dispose(f)
	finish_test()
