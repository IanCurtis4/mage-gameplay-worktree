extends SceneTree
## Checkpoint37 (J1): journal codec. Chain, sequence, payload shape and the JSON
## round trip of the profile file. The live/replay equality is in GameplayNative.
const Journal = preload("res://scripts/core/expedition/persistence/expedition_journal_codec.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_JOURNAL_CHECK "+id+" "+str(ok))
static func payload(index: int) -> Dictionary:
	var ticket := {"ok":true,"error_code":&"","ticket_id":"reward-x-%d" % index,"event_id":"mob:occ_%d" % index,"reward_id":&"mob_drop","sequence":index,"payload":{"base_xp":3,"job_xp":1,"equipment_ids":[],"equipment_drops":[],"stat_increments":{},"card_id":&""},"mob_ticket":true,"delivered":false}
	return {"events":[{"kind":"mob_death","slot_id":"slot_%d" % index,"generation":0,"event_id":"death_occ_%d" % index}],"tickets":[ticket],"rng_state":123456789+index,"next_sequence":index+1}
static func chain(checkpoint: Dictionary, count: int) -> Array:
	var journal: Array = []
	for index: int in count:
		var made := Journal.make_entry(journal,checkpoint,"events_%056d" % index,payload(index))
		if not made.ok: return []
		journal.append(made.entry)
	return journal
func run() -> void:
	var checkpoint := {"sha256":"a".repeat(64)}
	var journal := chain(checkpoint,3)
	var decoded := Journal.validate(journal,checkpoint)
	check("three_entries_chain_from_the_base_checkpoint",journal.size() == 3 and journal[0].prev == checkpoint.sha256 and journal[1].prev == Journal.entry_digest(journal[0]) and decoded.ok)
	check("payloads_decode_with_exact_types",decoded.ok and decoded.payloads[1] == payload(1) and typeof(decoded.payloads[1].tickets[0].reward_id) == TYPE_STRING_NAME and typeof(decoded.payloads[1].rng_state) == TYPE_INT)
	var parsed: Variant = JSON.parse_string(JSON.stringify(journal))
	var reloaded := Journal.validate(parsed,checkpoint)
	check("profile_json_round_trip_restores_integers",reloaded.ok and reloaded.entries == journal and typeof(reloaded.entries[2].seq) == TYPE_INT)
	check("another_base_breaks_the_chain",not Journal.validate(journal,{"sha256":"b".repeat(64)}).ok)
	var tampered := journal.duplicate(true); tampered[1].payload = Marshalls.raw_to_base64(var_to_bytes(payload(7)))
	check("tampered_payload_is_refused",not Journal.validate(tampered,checkpoint).ok)
	var reordered := [journal[1],journal[0],journal[2]]
	check("reordered_entries_are_refused",not Journal.validate(reordered,checkpoint).ok)
	var truncated := [journal[0],journal[2]]
	check("missing_middle_entry_is_refused",not Journal.validate(truncated,checkpoint).ok)
	var extra := journal.duplicate(true); extra[0]["extra"] = 1
	check("unknown_entry_field_is_refused",not Journal.validate(extra,checkpoint).ok)
	var wave := payload(0); wave.events = [{"kind":"wave","wave_index":1}]
	check("only_mob_deaths_are_journaled",not Journal.validate_payload(wave).ok)
	var twice := payload(0); twice.events.append(twice.events[0].duplicate())
	check("duplicate_death_in_one_entry_is_refused",not Journal.validate_payload(twice).ok)
	var delivered := payload(0); delivered.tickets[0].delivered = true
	check("delivered_ticket_cannot_be_journaled",not Journal.validate_payload(delivered).ok)
	# bytes_to_var never decodes objects (engine guarantee); a payload that decodes
	# to anything but the payload dictionary is refused.
	var bytes := var_to_bytes([payload(0)])
	var forged := journal.duplicate(true); forged[0].payload = Marshalls.raw_to_base64(bytes); forged[0].sha256 = ExpeditionCheckpointCodec.digest_bytes(bytes)
	check("non_dictionary_payload_is_refused",not Journal.validate(forged,checkpoint).ok)
	# Checkpoint38: collection entries carry the reward session and owner digest.
	var collect := {"kind":"collect","delivered":[{"ticket_id":"reward-x-0","card_instance_id":&""}],"session":{"run_id":"run_a","character_id":"char_a","last_committed_seq":4},"owner_digest":"c".repeat(64)}
	var mixed := journal.duplicate(true)
	var appended := Journal.make_entry(mixed,checkpoint,"collect_%056d" % 1,collect)
	if appended.ok: mixed.append(appended.entry)
	var effective := Journal.effective(mixed,{"session":{"run_id":"run_a","character_id":"char_a","last_committed_seq":1},"owner_digest":"d".repeat(64),"sha256":checkpoint.sha256})
	check("collect_entry_names_session_and_owner_digest",appended.ok and Journal.validate(mixed,checkpoint).ok and effective.session.last_committed_seq == 4 and effective.owner_digest == "c".repeat(64))
	var without := Journal.effective(journal,{"session":{"last_committed_seq":1},"owner_digest":"d".repeat(64)})
	check("death_entries_keep_the_checkpoint_session",without.session.last_committed_seq == 1 and without.owner_digest == "d".repeat(64))
	var broken := collect.duplicate(true); broken.delivered.append(broken.delivered[0].duplicate())
	var bad_digest := collect.duplicate(true); bad_digest.owner_digest = "x"
	check("malformed_collection_is_refused",not Journal.validate_payload(broken).ok and not Journal.validate_payload(bad_digest).ok)
	# Checkpoint39: the player's death rides a deaths entry; revive names it and
	# carries the wave clock after the penalty.
	var fall := {"events":[{"kind":"player_death","event_id":"player_death_1"}],"tickets":[],"rng_state":7,"next_sequence":1}
	var fall_extra := fall.duplicate(true); fall_extra.events[0]["slot_id"] = "slot_0"
	check("player_death_rides_a_deaths_entry",Journal.validate_payload(fall).ok and not Journal.validate_payload(fall_extra).ok)
	var revive := {"kind":"revive","event_id":"player_death_1","clock":[true,12.5,30.0,2]}
	var revived := Journal.make_entry(journal,checkpoint,"revive_%056d" % 1,revive)
	var with_revive := journal.duplicate(true)
	if revived.ok: with_revive.append(revived.entry)
	var decoded_revive := Journal.validate(with_revive,checkpoint)
	check("revive_entry_round_trips",revived.ok and decoded_revive.ok and decoded_revive.payloads[-1] == revive and Journal.effective(with_revive,{"session":{"last_committed_seq":1},"owner_digest":"d".repeat(64)}).session.last_committed_seq == 1)
	var bad_clock := revive.duplicate(true); bad_clock.clock = [true,INF,30.0,2]
	var short_clock := revive.duplicate(true); short_clock.clock = [true,12.5,30.0]
	var no_death := revive.duplicate(true); no_death.event_id = ""
	check("malformed_revive_is_refused",not Journal.validate_payload(bad_clock).ok and not Journal.validate_payload(short_clock).ok and not Journal.validate_payload(no_death).ok)
	var full := chain(checkpoint,Journal.MAX_ENTRIES)
	check("journal_is_bounded",full.size() == Journal.MAX_ENTRIES and Journal.make_entry(full,checkpoint,"events_%056d" % 999,payload(999)).get("error_code") == &"journal_full")
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_JOURNAL_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
