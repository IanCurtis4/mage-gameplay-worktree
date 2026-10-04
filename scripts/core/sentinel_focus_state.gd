class_name SentinelFocusState
extends RefCounted
## Run-only resource and timers. All integration uses effective movement and impacts.

const CAP := SentinelTuning.FOCUS_CAP
const STABLE_DELAY := SentinelTuning.FOCUS_STABILITY_DELAY
const STANCE_DELAY := SentinelTuning.PRECISION_STABILITY_DELAY
const OUT_OF_COMBAT_DELAY := SentinelTuning.FOCUS_OUT_OF_COMBAT_DELAY
const GAIN_PER_SECOND := SentinelTuning.FOCUS_GENERATION_PER_SECOND
const DECAY_PER_SECOND := SentinelTuning.FOCUS_DECAY_PER_SECOND
const MOVEMENT_EPSILON := 0.001

var focus := 0.0
var stable_time := 0.0
var inactive_time := 0.0
var observed_target_id := 0
var observation_remaining := 0.0
var observation_charges := 0
var observation_gain := 0.0
var observation_cooldown := 0.0
var opening_cooldown := 0.0
var absolute_remaining := 0.0
var reserved_focus := 0.0
var reserved_sp := 0.0
var explosive_prepared := false
var _observed_emissions: Dictionary[int, bool] = {}
var _opening_emissions: Dictionary[int, float] = {}

func advance(delta: float, moved: bool, combat_active: bool, paused: bool = false) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		return
	var old_stable := stable_time
	stable_time = 0.0 if moved else stable_time + delta
	observation_cooldown = maxf(0.0, observation_cooldown - delta)
	opening_cooldown = maxf(0.0, opening_cooldown - delta)
	observation_remaining = maxf(0.0, observation_remaining - delta)
	if observation_remaining <= 0.0:
		clear_observation()
	for id: int in _opening_emissions.keys():
		_opening_emissions[id] -= delta
		if _opening_emissions[id] <= 0.0:
			_opening_emissions.erase(id)
	if combat_active:
		inactive_time = 0.0
		if not moved:
			# Split partial frames at stability/buff expiration boundaries.
			var buff_delta := minf(delta, absolute_remaining)
			var ordinary_delta := delta - buff_delta
			var after_delay := maxf(0.0, stable_time - maxf(STABLE_DELAY, old_stable + buff_delta))
			gain(buff_delta * SentinelTuning.ABSOLUTE_GENERATION_PER_SECOND + minf(ordinary_delta, after_delay) * GAIN_PER_SECOND)
	else:
		var previous := inactive_time
		inactive_time += delta
		var decay_time := maxf(0.0, inactive_time - maxf(previous, OUT_OF_COMBAT_DELAY))
		focus = maxf(reserved_focus, focus - decay_time * DECAY_PER_SECOND)
	absolute_remaining = maxf(0.0, absolute_remaining - delta)

func gain(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var previous := focus
	focus = minf(CAP, focus + amount)
	return focus - previous

func free_focus() -> float:
	return maxf(0.0, focus - reserved_focus)

func can_pay(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and free_focus() + 0.00001 >= amount

func spend(amount: float) -> bool:
	if not can_pay(amount):
		return false
	focus = maxf(0.0, focus - amount)
	return true

func observe(target_id: int, rank: int) -> bool:
	if target_id <= 0 or rank < 1 or rank > 5:
		return false
	observed_target_id = target_id
	var tuning := SentinelTuning.values(&"sentinel_observe", rank)
	observation_remaining = float(tuning["duration"])
	observation_charges = int(tuning["hit_count"])
	observation_gain = float(tuning["focus_return"])
	_observed_emissions.clear()
	return true

func direct_impact(emission_id: int, target_id: int, positive_direct_hit: bool, critical: bool, controlled_before_hit: bool, opening_rank: int) -> float:
	if emission_id <= 0 or target_id <= 0 or not positive_direct_hit:
		return 0.0
	var before := focus
	if target_id == observed_target_id and observation_charges > 0 and observation_remaining > 0.0 and observation_cooldown <= 0.0 and not _observed_emissions.has(emission_id):
		_observed_emissions[emission_id] = true
		observation_charges -= 1
		observation_cooldown = SentinelTuning.OBSERVE_INTERNAL_COOLDOWN
		gain(observation_gain)
	if opening_rank >= 1 and opening_rank <= 3 and (critical or controlled_before_hit) and opening_cooldown <= 0.0 and not _opening_emissions.has(emission_id):
		_opening_emissions[emission_id] = 10.0
		opening_cooldown = SentinelTuning.OPENING_INTERNAL_COOLDOWN
		gain(float(SentinelTuning.values(&"sentinel_opening_read", opening_rank)["focus_return"]))
	return focus - before

func clear_observation() -> void:
	observed_target_id = 0
	observation_remaining = 0.0
	observation_charges = 0
	observation_gain = 0.0
	_observed_emissions.clear()

func cancel_preparation() -> void:
	explosive_prepared = false
	reserved_focus = 0.0
	reserved_sp = 0.0

func clear() -> void:
	focus = 0.0
	stable_time = 0.0
	inactive_time = 0.0
	observation_cooldown = 0.0
	opening_cooldown = 0.0
	absolute_remaining = 0.0
	clear_observation()
	_opening_emissions.clear()
	cancel_preparation()
