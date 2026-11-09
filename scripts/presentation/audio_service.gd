class_name PresentationAudioService
extends Control
## Presentation-only child of PresentationEvents (the existing Control snapshot boundary).
signal preferences_changed
signal configuration_error(operation: StringName, error: int)
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
const Preferences = preload("res://scripts/presentation/audio_preferences.gd")
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")
const DEDUP_LIMIT := 2048
## E08 P6 per-event variation (effects only), derived from event_id: never a global RNG.
const PITCH_VARIATION := 0.04
const VOLUME_VARIATION_DB := 1.5
## E08 P6 impact rate limit, applied before the voice pool on the bridge's visual clock
## (frozen while paused). Only impacts with a target identity are grouped.
const IMPACT_TARGET_INTERVAL := 0.10 # Same skill on the same target (multi-projectile bursts).
const DOT_TARGET_INTERVAL := 0.40 # Periodic recipes (DOT/maintenance ticks) on the same target.
const IMPACT_BURST_WINDOW := 0.06 # One skill hitting many targets at once...
const IMPACT_BURST_LIMIT := 3 # ...starts at most this many impact voices per window.
const RATE_MEMORY_LIMIT := 256
const OUTPUT_CEILING_DB := -1.0
const OUTPUT_RELEASE_SECONDS := 0.1
const OUTPUT_LIMITER_MARGIN_DB := 0.01 # Native gain interpolation can slightly overshoot its nominal ceiling.
var preferences := Preferences.new()
var _bridge: PresentationEventBridge
var _buses: Dictionary = {}
var _voices: Array[Dictionary] = []
var _streams: Dictionary = {}
var _seen: Dictionary = {}
var _order: Array[String] = []
var _epoch := -1
var _stage := ""
var _biome := ""
var _sequence := 0
var _ui_sequence := 0
var _configured := false
var _context_pending := false
var _activation_host: WeakRef
var _has_passive_flag := false
var _missing: Dictionary = {}
var _played := 0
var _dropped := 0
var _rate_limited := 0
var _impact_last: Dictionary = {}
var _impact_bursts: Dictionary = {}
var _exists: Dictionary = {}

func _init() -> void:
	name = "PresentationAudio"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(bridge: PresentationEventBridge, preferences_path: String = "user://audio.cfg") -> void:
	if not is_instance_valid(bridge): return
	if _configured and _bridge == bridge and preferences.path == preferences_path: return
	var same_bridge := _bridge == bridge
	_disconnect_bridge()
	if not same_bridge: clear_stage(); _seen.clear(); _order.clear(); _epoch = -1
	_bridge = bridge
	_activation_host = weakref(bridge.get_parent()) if bridge.get_parent() != null else null
	_has_passive_flag = false
	if bridge.get_parent() != null:
		for property: Dictionary in bridge.get_parent().get_property_list():
			if property.name == &"snapshot_passive": _has_passive_flag = true; break
	if not _configured or preferences.path != preferences_path:
		var result := preferences.read(preferences_path)
		if result != OK: configuration_error.emit(&"load", result)
	if _buses.is_empty(): _create_buses()
	if _voices.is_empty(): _create_voices()
	_configured = true
	_apply_preferences()
	_bridge.event_confirmed.connect(_on_event)
	_bridge.world_pause_changed.connect(_pause_world)
	_bridge.tree_exiting.connect(_bridge_exiting)
	_pause_world(_bridge.world_paused())
	if _epoch != _bridge.current_epoch() or _stage != _bridge.stage_id:
		_enter_stage(_bridge.stage_id, _bridge.current_epoch())
	preferences_changed.emit()

func _create_buses() -> void:
	for channel: StringName in Catalog.CHANNELS:
		var bus := StringName("E08_%d_%s" % [get_instance_id(), channel])
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1, bus)
		_buses[channel] = bus
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus), &"Master" if channel == &"general" else _buses[&"general"])

	# Protect the combined private output, not individual samples or the shared Master.
	# A fresh native effect per service keeps gain/release state instance-local.
	var limiter := AudioEffectHardLimiter.new()
	limiter.pre_gain_db = 0.0
	limiter.ceiling_db = OUTPUT_CEILING_DB - OUTPUT_LIMITER_MARGIN_DB
	limiter.release = OUTPUT_RELEASE_SECONDS
	AudioServer.add_bus_effect(AudioServer.get_bus_index(_buses[&"general"]),limiter)

func _create_voices() -> void:
	for channel: StringName in Catalog.LIMITS:
		for unused: int in int(Catalog.LIMITS[channel]):
			var player := AudioStreamPlayer.new()
			player.name = "%s_%d" % [channel, _voices.size()]
			player.process_mode = Node.PROCESS_MODE_ALWAYS if channel == &"interface" else Node.PROCESS_MODE_PAUSABLE
			player.bus = _buses[channel]
			player.max_polyphony = 1
			add_child(player)
			player.finished.connect(_finished.bind(_voices.size()))
			_voices.append({"player":player, "channel":channel, "active":false, "priority":0, "sequence":0, "id":&""})

func _disconnect_bridge() -> void:
	if not is_instance_valid(_bridge): return
	if _bridge.event_confirmed.is_connected(_on_event): _bridge.event_confirmed.disconnect(_on_event)
	if _bridge.world_pause_changed.is_connected(_pause_world): _bridge.world_pause_changed.disconnect(_pause_world)
	if _bridge.tree_exiting.is_connected(_bridge_exiting): _bridge.tree_exiting.disconnect(_bridge_exiting)

func _bridge_exiting() -> void:
	clear_stage()
	_disconnect_bridge()
	_bridge = null

func _enter_stage(id: String, epoch: int) -> void:
	clear_stage()
	_impact_last.clear(); _impact_bursts.clear()
	_seen.clear(); _order.clear()
	_epoch = epoch; _stage = id
	_context_pending = not id.is_empty()
	_activate_context()

func _host_active() -> bool:
	if not is_instance_valid(_bridge) or not _bridge.is_inside_tree() or not can_process(): return false
	var host: Node = _activation_host.get_ref() as Node if _activation_host != null else null
	if host == null or host.process_mode == Node.PROCESS_MODE_DISABLED: return false
	if _has_passive_flag and bool(host.get(&"snapshot_passive")): return false
	return true

## Host-provided presentation hint (set before the stage begins); never saved.
func set_stage_biome(biome: String) -> void:
	_biome = biome

func stage_biome() -> String:
	return _biome

func _activate_context() -> void:
	if not _context_pending or not _host_active(): return
	_context_pending = false
	_play(Catalog.ambience_for_biome(_biome)) # Activated current context only, never replay transient state.

func _process(_delta: float) -> void:
	if _configured and _context_pending: _activate_context()

func _on_event(event: Dictionary) -> void:
	if not _configured or not is_instance_valid(_bridge): return
	# Preserve the producer's token. Never substitute the current epoch for a queued event.
	var captured_epoch: int = event.payload.get("presentation_epoch", -1)
	if captured_epoch != _bridge.current_epoch() or event.stage_id != _bridge.stage_id: return
	if _epoch != captured_epoch:
		_enter_stage(event.stage_id, captured_epoch)
	if _seen.has(event.event_id): return
	if _order.size() >= DEDUP_LIMIT: _seen.erase(_order.pop_front())
	_seen[event.event_id] = true; _order.append(event.event_id)
	if event.kind == &"stage_exit": clear_stage(); return
	if event.kind == &"stage_enter":
		if _stage != event.stage_id: _enter_stage(event.stage_id, captured_epoch)
		return
	if not _host_active(): return # Staging drops transients rather than queueing them.
	if _bridge.world_paused() and event.kind not in [&"ui_confirm", &"ui_cancel"]: return
	# P6: a triggered trap already sounded on trap_trigger; its area_end stays silent.
	if event.kind == &"area_end" and str(event.payload.get("reason", "")) == "trigger": return
	var recipe := Recipes.for_event(event)
	if event.kind == &"impact" and _impact_rate_limited(event, recipe): return
	var id := select_cue(event.kind, recipe)
	if id != &"": _play(id, variation_for(String(event.event_id)))

## Most specific cue whose sample is available, else the current cue of the kind.
## EVENTS cues are always eligible (a missing EVENTS WAV stays reported as missing).
func select_cue(kind: StringName, recipe: Dictionary) -> StringName:
	for id: StringName in Catalog.candidates(kind, recipe):
		if Catalog.EVENTS.has(id) or _streams.has(id): return id
		if not _exists.has(id): _exists[id] = ResourceLoader.exists(Catalog.definition(id).path)
		if _exists[id]: return id
	return &""

## Deterministic variation from the event identity: x = pitch scale, y = volume dB.
## A private generator seeded by event_id mixes the bits; the global RNG is never touched.
static func variation_for(event_id: String) -> Vector2:
	var local := RandomNumberGenerator.new()
	local.seed = event_id.hash()
	var pitch_unit := local.randf_range(-1.0, 1.0)
	var volume_unit := local.randf_range(-1.0, 1.0)
	return Vector2(1.0 + PITCH_VARIATION * pitch_unit, VOLUME_VARIATION_DB * volume_unit)

func _impact_rate_limited(event: Dictionary, recipe: Dictionary) -> bool:
	var target := str(event.payload.get("target_id", ""))
	if target.is_empty(): return false # Manual/fixture DTOs without target identity are not grouped.
	var now := _bridge.world_time
	var skill := String(event.skill_id)
	var key := skill + "|" + target
	var interval := DOT_TARGET_INTERVAL if bool(recipe.get("periodic", false)) else IMPACT_TARGET_INTERVAL
	if _impact_last.has(key) and now - float(_impact_last[key]) < interval:
		_rate_limited += 1; return true
	var burst: Dictionary = _impact_bursts.get(skill, {})
	if burst.is_empty() or now - float(burst.start) >= IMPACT_BURST_WINDOW: burst = {"start":now, "count":0}
	if int(burst.count) >= IMPACT_BURST_LIMIT:
		_rate_limited += 1; return true
	burst.count = int(burst.count) + 1
	_impact_bursts[skill] = burst
	if _impact_last.size() >= RATE_MEMORY_LIMIT:
		for old: Variant in _impact_last.keys():
			if now - float(_impact_last[old]) >= DOT_TARGET_INTERVAL: _impact_last.erase(old)
		if _impact_last.size() >= RATE_MEMORY_LIMIT: _impact_last.clear()
	_impact_last[key] = now
	return false

func _sample(id: StringName) -> AudioStream:
	if _streams.has(id): return _streams[id] as AudioStream
	var definition := Catalog.definition(id)
	if definition.is_empty(): return null
	if ResourceLoader.exists(definition.path):
		var stream := load(definition.path) as AudioStream
		if stream != null: _streams[id] = stream; return stream
	_missing[id] = true
	return null

## Fixture injection: known IDs only; does not mutate catalog definitions or gameplay.
func install_streams(streams: Dictionary) -> bool:
	for id: Variant in streams:
		if Catalog.definition(StringName(id)).is_empty() or not streams[id] is AudioStream: return false
	_streams = streams.duplicate()
	return true

func _play(id: StringName, variation: Vector2 = Vector2(1.0, 0.0)) -> bool:
	if not _host_active(): return false
	var definition := Catalog.definition(id)
	var stream := _sample(id)
	if stream == null: return false
	if definition.channel == &"ambience" and stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# WAV resources are shared immutable definitions: loop a private copy only.
		var looping := stream.duplicate() as AudioStreamWAV
		looping.loop_begin = 0
		looping.loop_end = maxi(1, roundi(looping.get_length() * looping.mix_rate))
		looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream = looping
		_streams[id] = looping
	var selected := -1
	for index: int in _voices.size():
		var voice := _voices[index]
		if voice.channel != definition.channel: continue
		if not voice.active: selected = index; break
		if selected < 0 or voice.priority < _voices[selected].priority or (voice.priority == _voices[selected].priority and voice.sequence < _voices[selected].sequence): selected = index
	if selected < 0: return false
	if _voices[selected].active and int(definition.priority) < int(_voices[selected].priority): _dropped += 1; return false
	_release(selected)
	_sequence += 1
	var voice := _voices[selected]
	voice.active = true; voice.priority = definition.priority; voice.sequence = _sequence; voice.id = id
	var player: AudioStreamPlayer = voice.player
	player.stream = stream
	# Only world effects vary; interface and ambience keep unity pitch and gain.
	var varied: bool = definition.channel == &"effects"
	player.pitch_scale = clampf(variation.x, 1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION) if varied else 1.0
	player.volume_db = clampf(variation.y, -VOLUME_VARIATION_DB, VOLUME_VARIATION_DB) if varied else 0.0
	player.play()
	player.stream_paused = definition.channel != &"interface" and is_instance_valid(_bridge) and _bridge.world_paused()
	_played += 1
	return true

func _finished(index: int) -> void:
	if index < _voices.size() and not _voices[index].player.playing: _release(index)

func _release(index: int) -> void:
	var voice := _voices[index]
	voice.player.stop(); voice.player.stream = null
	voice.active = false; voice.id = &""

func _pause_world(paused: bool) -> void:
	for voice: Dictionary in _voices:
		if voice.channel != &"interface" and voice.active: voice.player.stream_paused = paused

func clear_stage() -> void:
	for index: int in _voices.size():
		_release(index)
	_stage = ""; _context_pending = false

func _apply_preferences() -> void:
	for channel: StringName in _buses:
		var index := AudioServer.get_bus_index(_buses[channel])
		var value := preferences.value(channel)
		AudioServer.set_bus_volume_linear(index, value.volume)
		AudioServer.set_bus_mute(index, value.muted)

func set_volume(channel: StringName, linear: float) -> Error:
	if channel not in Catalog.CHANNELS or not is_finite(linear): return ERR_INVALID_PARAMETER
	var result := preferences.set_volume(channel, linear)
	_apply_preferences(); preferences_changed.emit()
	if result != OK: configuration_error.emit(&"save", result)
	return result

func set_muted(channel: StringName, muted: bool) -> Error:
	if channel not in Catalog.CHANNELS: return ERR_INVALID_PARAMETER
	var result := preferences.set_muted(channel, muted)
	_apply_preferences(); preferences_changed.emit()
	if result != OK: configuration_error.emit(&"save", result)
	return result

## Call only after a real UI state change/cancellation; synchronous token capture.
func confirm_ui(cancelled: bool = false) -> bool:
	if not is_instance_valid(_bridge) or _bridge.stage_id.is_empty(): return false
	_ui_sequence += 1
	var captured_epoch := _bridge.current_epoch()
	return _bridge.emit_confirmed({"event_id":"audio_ui/%d/%d" % [get_instance_id(), _ui_sequence], "kind":&"ui_cancel" if cancelled else &"ui_confirm", "stage_id":_bridge.stage_id, "actor_id":"", "skill_id":&"", "position":Vector3.ZERO, "surface_id":"", "duration":0.0, "essential":false, "payload":{"presentation_epoch":captured_epoch}})

func diagnostics() -> Dictionary:
	var counts := {&"effects":0, &"interface":0, &"ambience":0}
	for voice: Dictionary in _voices:
		if voice.active: counts[voice.channel] += 1
	return {"active":counts, "capacity":_voices.size(), "played":_played, "dropped":_dropped, "rate_limited":_rate_limited, "missing_samples":_missing.keys(), "seen":_seen.size(), "epoch":_epoch, "stage_id":_stage}

func dispose() -> void:
	_disconnect_bridge(); _bridge = null; _activation_host = null
	for index: int in _voices.size(): _release(index)
	for voice: Dictionary in _voices: voice.player.free()
	_voices.clear(); _streams.clear(); _seen.clear(); _order.clear(); _missing.clear()
	_impact_last.clear(); _impact_bursts.clear(); _exists.clear()
	for channel: StringName in [&"effects", &"interface", &"ambience", &"general"]:
		if _buses.has(channel):
			var index := AudioServer.get_bus_index(_buses[channel])
			if index > 0: AudioServer.remove_bus(index)
	_buses.clear(); _configured = false; _epoch = -1; _stage = ""

func _exit_tree() -> void: dispose()
