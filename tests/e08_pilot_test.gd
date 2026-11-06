extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Feedback = preload("res://scripts/presentation/e08_pilot_feedback.gd")
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
class Host extends Node2D:
	var snapshot_passive := false
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func event(bridge: PresentationEventBridge, id: String, kind: StringName) -> Dictionary:
	return {"event_id":id, "kind":kind, "stage_id":bridge.stage_id, "actor_id":"fixture", "skill_id":&"fireball", "position":Vector3.ZERO, "surface_id":"", "duration":0.0, "essential":false, "payload":{"presentation_epoch":bridge.current_epoch(), "position_unavailable":true, "legacy_position_2d":Vector2(50,50)}}
func _run() -> void:
	check(Fixture.sources_current(), "fixture sources match frozen inputs")
	var host := Host.new(); root.add_child(host)
	var bridge := PresentationEventBridge.new(); host.add_child(bridge); bridge.bind_controller(host)
	var feedback := Feedback.new(); bridge.add_child(feedback); feedback.configure(bridge,host)
	bridge.begin_stage("pilot")
	check(bridge.emit_confirmed(event(bridge,"first",&"impact")) and feedback.pulses.size() == 1,"confirmed impact creates one cosmetic pulse")
	bridge.world_advanced.emit(0.1)
	check(feedback.pulses.size() == 1 and is_equal_approx(feedback.pulses[0].age,0.1),"world advance updates visual clock")
	paused = true
	bridge.world_advanced.emit(0.1)
	check(is_equal_approx(feedback.pulses[0].age,0.1),"paused world freezes visual clock")
	paused = false
	bridge.world_advanced.emit(1.0)
	check(feedback.pulses.is_empty(),"expired cosmetics removed")
	for i: int in 60: bridge.emit_confirmed(event(bridge,"cap_%d" % i,&"impact"))
	check(feedback.pulses.size() == Feedback.CAP,"cosmetics bounded independently from essential indicators")
	bridge.begin_stage("next",true)
	check(feedback.pulses.is_empty(),"stage transition and resume do not replay transients")
	host.snapshot_passive = true
	bridge.emit_confirmed(event(bridge,"passive",&"impact"))
	check(feedback.pulses.is_empty(),"passive staging rejects transient")
	host.snapshot_passive = false
	var draws := {"count":0}
	feedback.draw.connect(func() -> void: draws.count += 1)
	bridge.emit_confirmed(event(bridge,"before_dispose",&"impact"))
	await process_frame
	await process_frame
	var drawn_before: int = draws.count
	feedback.dispose()
	await process_frame
	await process_frame
	check(feedback.pulses.is_empty() and bridge.event_confirmed.get_connections().is_empty() and bridge.world_advanced.get_connections().is_empty(), "dispose clears pulses and disconnects both listeners")
	if DisplayServer.get_name() != "headless":
		check(draws.count > drawn_before, "dispose schedules native redraw to clear cached visual")
	var second_bridge := PresentationEventBridge.new(); host.add_child(second_bridge); second_bridge.bind_controller(host); second_bridge.begin_stage("rebound")
	feedback.configure(second_bridge,host); feedback.configure(second_bridge,host)
	check(second_bridge.event_confirmed.get_connections().size() == 1 and second_bridge.world_advanced.get_connections().size() == 1, "rebind is idempotent and keeps one listener per signal")
	bridge.emit_confirmed(event(bridge,"old_bridge",&"impact"))
	check(feedback.pulses.is_empty(), "old bridge cannot replay after rebind")
	second_bridge.emit_confirmed(event(second_bridge,"new_bridge",&"impact"))
	check(feedback.pulses.size() == 1, "new bridge creates exactly one pulse")
	for id: StringName in Catalog.ids():
		var path: String = Catalog.definition(id).path
		var wav := load(path) as AudioStreamWAV
		check(wav != null and wav.mix_rate == 44100 and wav.stereo == false and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "production WAV valid: " + path)
		if wav != null:
			var peak := 0
			for n: int in range(0,wav.data.size()-1,2):
				var value := wav.data.decode_s16(n)
				peak = maxi(peak, absi(value))
			check(peak > 0 and peak < 32767,"audible non-clipped PCM: " + path)
	feedback.dispose(); host.queue_free(); await process_frame
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample); sample.set_process(false)
	var controller: RunController = sample.controller
	var spatial_bridge := controller.presentation_events()
	var spatial_feedback: Control = spatial_bridge.get_node("E08PilotFeedback")
	var lower: Vector3 = sample.lower.world_point().position
	var upper: Vector3 = sample.upper.world_point().position
	check(not sample.view.point_visible(lower) and sample.view.point_visible(upper), "fixture has occluded lower anchor and visible upper anchor")
	var hidden := event(spatial_bridge,"hidden_impact",&"impact")
	hidden.position = lower; hidden.payload.erase("position_unavailable"); hidden.payload.erase("legacy_position_2d")
	var before: int = spatial_feedback.pulses.size()
	spatial_bridge.emit_confirmed(hidden)
	check(spatial_feedback.pulses.size() == before,"hidden confirmed anchor never draws above bridge")
	var visible := event(spatial_bridge,"visible_impact",&"impact")
	visible.position = upper; visible.payload.erase("position_unavailable"); visible.payload.erase("legacy_position_2d")
	spatial_bridge.emit_confirmed(visible)
	check(spatial_feedback.pulses.size() == before+1,"visible confirmed anchor creates pulse")
	sample.queue_free(); await process_frame
	print("E08 PILOT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
