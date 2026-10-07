extends SceneTree
## Intrinsic resource contract. These clock/resource rotations are not actor DPS,
## AI pathing, player input or a substitute for the user's solo gameplay test.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_intrinsic_boundaries()
	_additional_procs()
	_bounded_ledger()
	_cleanup_and_reservations()
	for hz: int in [30, 60, 144]:
		_clock_matrix(hz)
		_moving_resource_rotation(hz)
	print("Sentinel solo Focus: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _intrinsic_boundaries() -> void:
	var state := SentinelFocusState.new()
	_check(state.focus == 0.0 and state.intrinsic_cooldown == 0.0, "run starts empty without an intrinsic initial tick")
	for emission: int in [-1, 0]:
		_close(state.intrinsic_direct_impact(emission, true), 0.0, "invalid emission identity cannot pay")
	for reason: String in ["miss", "zero", "DoT", "secondary", "foreign source", "dead player", "outside combat", "paused"]:
		_close(state.intrinsic_direct_impact(10, false), 0.0, reason + " supplied as ineligible cannot pay")
	_check(state._intrinsic_emissions.is_empty(), "ineligible result does not consume an identity or ICD")
	_close(state.intrinsic_direct_impact(10, true), 4.0, "positive own direct damage returns four without passive or mark")
	_close(state.intrinsic_direct_impact(11, true), 0.0, "new emission during shared ICD is rejected")
	state.advance(0.499, true, true)
	_close(state.intrinsic_direct_impact(12, true), 0.0, "0.499 seconds is not the cooldown boundary")
	state.advance(0.001, true, true)
	_close(state.intrinsic_direct_impact(11, true), 0.0, "ICD-rejected emission cannot pay on a delayed second victim")
	_close(state.intrinsic_direct_impact(12, true), 0.0, "near-boundary rejected identity cannot retry after ICD")
	_close(state.intrinsic_direct_impact(13, true), 4.0, "new action at exact 0.5 seconds qualifies")
	for _victim: int in 1000:
		state.intrinsic_direct_impact(13, true)
	_close(state.focus, 8.0, "one 1000-victim emission returns four once, not per victim")
	state.advance(1.0, true, true)
	_close(state.intrinsic_direct_impact(13, true), 0.0, "piercing victim arriving after ICD still deduplicates")
	_close(state.intrinsic_direct_impact(14, true), 4.0, "lethal eligible direct application has no target-alive dependency")
	state.focus = 98.0
	state.advance(0.5, true, true)
	_close(state.intrinsic_direct_impact(15, true), 2.0, "intrinsic return reports actual cap-limited gain")
	state.advance(0.5, true, true)
	_close(state.intrinsic_direct_impact(16, true), 0.0, "full resource still records action and cooldown without overflow")
	_check(state.spend(4.0), "resource can subsequently be spent")
	state.advance(0.5, true, true)
	_close(state.intrinsic_direct_impact(16, true), 0.0, "action applied at cap cannot pay again after spending")

func _additional_procs() -> void:
	var state := SentinelFocusState.new()
	_check(state.observe(7, 5), "mark is available independently")
	_close(state.direct_impact(1, 7, true, true, true, 3), 14.0, "legacy mark plus Opening retain independent gains")
	_close(state.intrinsic_direct_impact(1, true), 4.0, "intrinsic return adds to mark and Opening for same action")
	_close(state.focus, 18.0, "all three legitimate channels sum once")
	state.advance(0.5, true, true)
	_close(state.direct_impact(2, 7, true, true, true, 3), 10.0, "mark recovers at 0.5 seconds while Opening keeps 1-second ICD")
	_close(state.intrinsic_direct_impact(2, true), 4.0, "intrinsic timer does not inherit Opening's longer ICD")
	_close(state.focus, 32.0, "channels do not multiply each other")
	state.advance(0.5, true, true)
	_close(state.direct_impact(3, 7, true, true, true, 3), 14.0, "third marked action exhausts mark and pays Opening")
	_close(state.intrinsic_direct_impact(3, true), 4.0, "mark exhaustion does not remove intrinsic resource")
	state.advance(1.0, true, true)
	_close(state.direct_impact(4, 7, true, false, false, 0), 0.0, "no mark charges/passive means no additional return")
	_close(state.intrinsic_direct_impact(4, true), 4.0, "intrinsic remains independent of late passive/job gates")
	_close(state.focus, 54.0, "expected actual resource after independent gains")

func _bounded_ledger() -> void:
	var state := SentinelFocusState.new()
	for emission: int in range(1, SentinelTuning.DIRECT_FOCUS_EMISSION_CAP + 1):
		state.intrinsic_direct_impact(emission, true)
	_check(state._intrinsic_emissions.size() == 256, "abnormal same-frame action flood has a hard 256-entry cap")
	_close(state.focus, 4.0, "action flood cannot bypass shared cadence")
	state.advance(0.5, true, true)
	_close(state.intrinsic_direct_impact(257, true), 0.0, "saturation fails closed instead of evicting a live emission")
	_close(state.intrinsic_direct_impact(1, true), 0.0, "oldest live identity survives saturation and cannot repeat")
	_check(state._intrinsic_emissions.size() == 256, "rejections cannot grow the ledger")
	state.advance(9.6, true, true)
	_check(state._intrinsic_emissions.is_empty(), "10-second lifetime retires identities beyond maximum projectile travel")
	_close(state.intrinsic_direct_impact(258, true), 4.0, "fresh legal emission is admitted after retirement")

func _cleanup_and_reservations() -> void:
	var state := SentinelFocusState.new()
	state.focus = 30.0
	state.reserved_focus = 25.0
	state.reserved_sp = 20.0
	state.explosive_prepared = true
	_close(state.intrinsic_direct_impact(1, true), 4.0, "intrinsic gains do not spend or duplicate prepared ammunition")
	_close(state.free_focus(), 9.0, "new gains remain separate from reserved 25 Focus")
	_check(not state.spend(10.0), "other skill cannot borrow reserved ammunition cost")
	state.advance(5.0, true, true, true)
	_close(state.intrinsic_cooldown, 0.5, "pause freezes shared intrinsic cooldown")
	_close(state._intrinsic_emissions[1], 10.0, "pause freezes dedup retirement")
	_close(state.intrinsic_direct_impact(2, false), 0.0, "caller rejects impacts while paused")
	state.advance(3.0, true, false)
	_close(state.focus, 34.0, "out-of-combat grace unchanged")
	state.advance(1.0, true, false)
	_close(state.focus, 24.0, "decay remains 10 per second")
	_check(not state.explosive_prepared and state.reserved_focus == 0.0 and state.reserved_sp == 0.0, "decay frees an underfunded reservation without a resource floor")
	state.clear()
	_check(state.focus == 0.0 and state.intrinsic_cooldown == 0.0 and state._intrinsic_emissions.is_empty(), "death/fim/restart cleanup clears intrinsic gain and dedup state")
	_close(state.intrinsic_direct_impact(1, true), 4.0, "new run can reuse its own emission numbering after cleanup")

func _clock_matrix(hz: int) -> void:
	var state := SentinelFocusState.new()
	var returned := 0.0
	var serial := 0
	for frame: int in hz * 10:
		state.advance(1.0 / hz, true, true)
		if frame % (hz >> 1) == 0:
			serial += 1
			returned += state.intrinsic_direct_impact(serial, true)
	_close(returned, 80.0, "%d Hz exact half-second action cadence pays 20 times" % hz)
	_close(state.focus, 80.0, "%d Hz moving never adds stationary generation" % hz)
	_close(state.stable_time, 0.0, "%d Hz resource supply does not rewrite movement/stability rules" % hz)
	state.advance(2.0, false, true)
	_close(state.focus, 95.0, "%d Hz stationary 10/s after 0.5s remains additive" % hz)

func _moving_resource_rotation(hz: int) -> void:
	var legacy := SentinelFocusState.new()
	var state := SentinelFocusState.new()
	var returned := 0.0
	var spent := 0.0
	var headshots := 0
	var empty_requests := 0
	var serial := 0
	for frame: int in hz * 60:
		legacy.advance(1.0 / hz, true, true)
		state.advance(1.0 / hz, true, true)
		if frame % hz == 0:
			serial += 1
			# Resource-only baseline: one applied auto/skill each second, no mark
			# or passive; damage quantities/ASPD/global movespeed are not modified.
			returned += state.intrinsic_direct_impact(serial, true)
		if frame % (hz * 6) == 0:
			if state.spend(30.0):
				spent += 30.0
				headshots += 1
			else:
				empty_requests += 1
	_close(legacy.focus, 0.0, "%d Hz old moving/no-mark/no-passive loop reproduces zero supply" % hz)
	_close(returned, 240.0, "%d Hz sixty applied direct actions produce exactly 240 resource" % hz)
	_check(headshots == 7 and empty_requests == 3, "%d Hz moving baseline funds seven 30-Focus requests on a 6-second schedule, not all ten" % hz)
	_close(spent, 210.0, "%d Hz paid requests consume the real resource budget" % hz)
	_close(state.focus, returned - spent, "%d Hz no infinite resource or free casts in resource-only rotation" % hz)
	_close(state.focus, 30.0, "%d Hz final budget agrees with other frame rates" % hz)
	print("Solo moving resource model %d Hz: 60 actions, %.0f gained, %d funded requests, %.0f spent, %.0f remaining" % [hz, returned, headshots, spent, state.focus])

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (%.6f vs %.6f)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Sentinel solo Focus: " + label)
