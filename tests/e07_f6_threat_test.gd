extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	var ledger := ThreatService.new()
	ledger.enemy_id = "hostile_a"
	for id: String in ["tank", "healer", "pet"]:
		check(ledger.register(id, "tank" if id == "pet" else id, "party")["ok"], "register explicit source/owner " + id)
	check(ledger.register("pet", "other", "party").get("error_code") == &"request_conflict", "source cannot change owner")
	check(ledger.observe("hit1", &"damage", "tank", 100.0)["ok"] and ledger.current_id == "tank", "confirmed damage selects actual source")
	check(ledger.observe("pet1", &"damage", "pet", 110.0)["ok"] and ledger.current_id == "tank", "exact 110 percent cannot switch")
	check(ledger.observe("pet2", &"damage", "pet", 0.01)["ok"] and ledger.current_id == "pet", "strictly above threshold switches")
	check(ledger.amounts["pet"] == 110.01 and ledger.amounts["tank"] == 100.0, "pet gets its own amount, not owner duplicate")
	var revision := ledger.revision
	check(ledger.observe("pet2", &"damage", "pet", 0.01).get("already_applied", false) and ledger.revision == revision, "event replay is inert")
	check(ledger.observe("pet2", &"damage", "pet", 10.0).get("error_code") == &"request_conflict" and ledger.revision == revision, "conflicting replay fails without mutation")
	check(ledger.observe("dot1", &"damage", "tank", 1.0)["ok"] and ledger.observe("dot2", &"damage", "tank", 1.0)["ok"] and ledger.amounts["tank"] == 102.0, "each confirmed DoT tick contributes once")
	check(ledger.observe("overheal", &"heal", "healer", 0.0, 2)["ok"] and ledger.amounts["healer"] == 0.0, "overheal never generates threat")
	check(ledger.observe("heal1", &"heal", "healer", 80.0, 2)["ok"] and ledger.amounts["healer"] == 20.0, "literal 80 effective / 2 enemies * 0.5 = 20")
	var other := ThreatService.new(); other.register("healer", "healer", "party"); other.engage()
	other.observe("heal1", &"heal", "healer", 80.0, 2)
	check(ledger.amounts["healer"] + other.amounts["healer"] == 40.0, "healing budget conserved across engaged enemies")
	check(ledger.observe("immune", &"taunt", "tank", 0.0, 1, 3.0, true)["ok"] and ledger.forced_id.is_empty() and ledger.current_id == "pet", "existing immunity vetoes forced target")
	check(ledger.observe("taunt1", &"taunt", "tank", 0.0, 1, 3.0)["ok"] and ledger.current_id == "tank" and ledger.amounts["tank"] == 110.01, "taunt equals maximum and fixes source")
	ledger.observe("healer_hit", &"damage", "healer", 1000.0)
	check(ledger.current_id == "tank", "forced target ignores normal threshold during taunt")
	ledger.advance(100.0, true)
	check(ledger.forced_remaining == 3.0, "pause freezes fixation")
	ledger.advance(2.75); check(ledger.current_id == "tank", "fixation before boundary")
	ledger.advance(0.25); check(ledger.current_id == "healer" and ledger.forced_id.is_empty(), "expiration resumes normal threshold")
	ledger.observe("reduce", &"reduce", "healer", 0.0, 1, 1.0)
	check(ledger.amounts["healer"] == 0.0 and ledger.current_id == "pet" and ledger.linked("party"), "reduction changes selection without ending party link")
	ledger.eligibility("pet", true, false)
	check(ledger.current_id == "tank" and ledger.amounts["pet"] == 110.01, "occlusion removes target eligibility, retaining ledger")
	ledger.eligibility("pet", true, true)
	check(ledger.current_id == "tank", "visibility restoration respects threshold")
	ledger.eligibility("tank", false, false)
	check(ledger.current_id == "pet" and ledger.claims.has("taunt1"), "death removes eligibility, retaining claims")
	var dto := ledger.view(); dto.entries[0]["amount"] = -900.0
	check(ledger.amounts["healer"] == 0.0, "ThreatView is a detached projection")
	ledger.disengage()
	check(not ledger.linked("party") and ledger.current_id.is_empty() and ledger.amounts["pet"] == 110.01 and ledger.claims.has("pet1"), "leash removes combat link without erasing credit/claims")
	var tie := ThreatService.new(); tie.register("z", "z", "party"); tie.register("a", "a", "party")
	tie.amounts["a"] = 100.0; tie.amounts["z"] = 100.0; tie.engage()
	check(tie.current_id == "a", "stable identity breaks initial equal maximum")
	tie.current_id = "z"; tie._choose(); check(tie.current_id == "z", "equal challenger preserves current")
	var before := tie.revision
	for bad: Dictionary in [{"value": NAN, "divisor": 1}, {"value": -1.0, "divisor": 1}, {"value": 1.0, "divisor": 0}]:
		check(not tie.observe("bad", &"heal", "a", bad["value"], bad["divisor"])["ok"] and tie.revision == before, "bad input cannot claim or mutate")
	check(tie.observe("bad_reduce", &"reduce", "a", 0.0, 1, 1.1).get("error_code") == &"invalid_payload", "reduction outside zero to one rejected")
	check(tie.observe("unknown", &"support", "a", 10.0).get("error_code") == &"unsupported_threat_rule", "unsupported effect has no invented coefficient")
	ledger.eligibility("pet", false, false)
	var dead_amount: float = ledger.amounts["pet"]
	check(ledger.observe("late_dot", &"damage", "pet", 2.0)["ok"] and ledger.amounts["pet"] == dead_amount + 2.0 and ledger.current_id != "pet", "already emitted DoT retains dead source credit without target eligibility")
	check(ledger.observe("late_dot", &"damage", "pet", 2.0).get("already_applied", false), "dead source delayed effect is still claimed")
	check(ledger.valid() and other.valid() and tie.valid(), "ledger invariants hold")
	var isolation := ThreatService.new(); isolation.register("local", "local", "local_party"); isolation.register("foreign", "foreign", "other_party")
	isolation.engage("foreign")
	check(isolation.linked("other_party") and not isolation.linked("local_party"), "registration alone cannot engage an unrelated group")
	isolation.observe("local_hit", &"damage", "local", 1.0)
	check(isolation.linked("local_party") and isolation.linked("other_party"), "confirmed hostile contribution admits its actual group")
	check(isolation.valid(), "group links are valid snapshot state")
	var malformed := ThreatService.new(); malformed.register("x", "x", "party"); malformed.participants["x"] = {"bad": true}
	check(not malformed.valid(), "malformed participant is rejected without property access errors")
	var combat := CombatParticipation.new(); combat.observe({"hostile_pet": true}, 0.0)
	combat.observe({}, 4.999); check(combat.active(), "party grace follows last hostile link")
	combat.observe({}, 100.0, true); check(combat.active(), "suspension freezes exit grace")
	combat.observe({}, 0.0011); check(not combat.active(), "party exits after five seconds")
	print("E07 F6 threat: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
