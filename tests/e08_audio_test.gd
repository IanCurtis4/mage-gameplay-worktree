extends SceneTree
const Service = preload("res://scripts/presentation/audio_service.gd")
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
const Preferences = preload("res://scripts/presentation/audio_preferences.gd")
const Bridge = preload("res://scripts/presentation/presentation_event_bridge.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
var notices: Array[Dictionary] = []
var ui_events: Array[StringName] = []
class StagingHost extends Node2D:
	var snapshot_passive := true
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _event(bridge: PresentationEventBridge, id: String, kind: StringName = &"impact") -> Dictionary:
	return {"event_id":id, "kind":kind, "stage_id":bridge.stage_id, "actor_id":"fixture", "skill_id":&"fireball", "position":Vector3.ZERO, "surface_id":"", "duration":0.0, "essential":false, "payload":{"presentation_epoch":bridge.current_epoch()}}
func _stream(looped: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050
	var bytes := PackedByteArray(); bytes.resize(4410)
	for index: int in 2205: bytes.encode_s16(index*2, int(sin(float(index)*TAU*440.0/22050.0)*1500.0))
	stream.data = bytes
	if looped: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = 2205
	return stream
func _streams() -> Dictionary:
	var streams := {}
	for id: StringName in Catalog.ids(): streams[id] = _stream(true)
	return streams
func _record(event: Dictionary) -> void:
	if event.kind in [&"ui_confirm", &"ui_cancel"]: ui_events.append(event.kind)
func _frames(count: int = 3) -> void:
	for unused: int in count: await process_frame
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	root.size = Vector2i(1280,720)
	var bus_baseline := AudioServer.bus_count
	var host := Node2D.new(); root.add_child(host)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.bind_controller(host); bridge.begin_stage("audio_one")
	bridge.event_confirmed.connect(_record)
	var service := Service.new(); bridge.add_child(service)
	service.configuration_error.connect(func(operation: StringName, error: int) -> void: notices.append({"operation":operation,"error":error}))
	check(service.install_streams(_streams()), "fixture streams accepted without catalog mutation")
	var directory := "user://e08_audio_fixture"
	DirAccess.make_dir_recursive_absolute(directory)
	var config_path := directory.path_join("audio.cfg")
	if FileAccess.file_exists(config_path): DirAccess.remove_absolute(config_path)
	service.configure(bridge, config_path)
	check(AudioServer.bus_count == bus_baseline+4 and service.diagnostics().capacity == 32, "exactly four private buses and 32 voices")
	check(service.diagnostics().active.ambience == 1 and service.diagnostics().played == 1, "late binding reconstructs only current ambience")
	var bus_names: Dictionary = service._buses.duplicate()
	var connections := bridge.event_confirmed.get_connections().size()
	for unused: int in 5: service.configure(bridge, config_path)
	check(bridge.event_confirmed.get_connections().size() == connections and service.diagnostics().played == 1 and AudioServer.bus_count == bus_baseline+4, "configure idempotent, no replay or bus leak")
	for channel: StringName in Catalog.CHANNELS:
		check(service.set_volume(channel,0.37) == OK and service.set_muted(channel,true) == OK, "independent channel preferences save: "+String(channel))
		var index := AudioServer.get_bus_index(bus_names[channel])
		check(is_equal_approx(AudioServer.get_bus_volume_linear(index),0.37) and AudioServer.is_bus_mute(index), "live channel bus matches linear volume and mute")
		check(AudioServer.get_bus_send(index) == (&"Master" if channel == &"general" else bus_names[&"general"]), "channel routing through general")
	var loaded := Preferences.new()
	check(loaded.read(config_path) == OK, "audio.cfg reloads separately from gameplay save")
	for channel: StringName in Catalog.CHANNELS: check(loaded.value(channel) == {"volume":0.37,"muted":true}, "all channels persist independently")
	check(service.set_volume(&"effects",2.0) == OK and service.preferences.value(&"effects").volume == 1.0, "high volume clamped")
	check(service.set_volume(&"effects",-2.0) == OK and service.preferences.value(&"effects").volume == 0.0, "low volume clamped")
	check(service.set_volume(&"effects",NAN) == ERR_INVALID_PARAMETER and service.set_volume(&"music",0.5) == ERR_INVALID_PARAMETER and service.set_muted(&"music",true) == ERR_INVALID_PARAMETER, "nonfinite and unknown channels rejected")
	check(service.preferences.value(&"effects").muted, "volume changes preserve independent mute")
	var copy := Catalog.definition(&"world.impact"); copy.path = "bad"; copy.priority = -99
	check(Catalog.definition(&"world.impact").priority == 40 and Catalog.definition(&"world.impact").path.ends_with("world_impact.wav"), "catalog copies cannot mutate definitions")
	check(not service.install_streams({&"music":_stream()}), "unknown fixture sample rejected atomically")
	var bad := ConfigFile.new(); bad.set_value("effects","volume","not a number"); bad.set_value("interface","muted",42); bad.set_value("ambience","volume",1.5); bad.save(directory.path_join("invalid.cfg"))
	var invalid := Preferences.new()
	check(invalid.read(directory.path_join("invalid.cfg")) == ERR_INVALID_DATA and invalid.invalid_config, "invalid typed configuration explicitly diagnosed")
	for channel: StringName in [&"effects", &"interface", &"ambience"]: check(invalid.value(channel) == {"volume":1.0,"muted":false}, "invalid channel uses safe defaults")
	var nofile := Preferences.new(); check(nofile.read(directory.path_join("missing/audio.cfg")) == OK and not nofile.invalid_config, "first-run missing file defaults without warning")
	service.configure(bridge,directory.path_join("invalid.cfg"))
	check(notices.back().operation == &"load" and service.preferences.invalid_config, "service reports invalid config load")
	service.configure(bridge,directory.path_join("missing/audio.cfg"))
	check(service.set_volume(&"effects",0.25) != OK and notices.back().operation == &"save" and service.preferences.value(&"effects").volume == 0.25, "write failure observable while live value remains applied")
	service.configure(bridge,config_path)
	service.clear_stage()
	var played: int = service.diagnostics().played
	var event := _event(bridge,"hit")
	check(bridge.emit_confirmed(event), "confirmed impact accepted")
	service._on_event(event); service.configure(bridge,config_path); service._on_event(event)
	check(service.diagnostics().played == played+1, "dedup survives repeated consumer delivery and rebind")
	for index: int in 28: bridge.emit_confirmed(_event(bridge,"impact/%d" % index))
	check(service.diagnostics().active.effects == 24, "effects pool capped at 24")
	var oldest: int = service._voices[0].sequence
	check(bridge.emit_confirmed(_event(bridge,"low_priority",&"projectile_launch")) and service._voices[0].sequence == oldest and service.diagnostics().dropped == 1, "lower priority cannot steal saturated impact voices")
	var victim := 0
	for index: int in 24:
		if service._voices[index].sequence < service._voices[victim].sequence: victim = index
	bridge.emit_confirmed(_event(bridge,"death",&"death"))
	check(service._voices[victim].id == &"world.death", "higher priority steals oldest equal-priority victim deterministically")
	for index: int in 10: bridge.emit_confirmed(_event(bridge,"ui/%d" % index,&"ui_confirm"))
	for unused: int in 7: service._play(&"ambience.stage")
	check(service.diagnostics().active == {&"effects":24,&"interface":4,&"ambience":4} and service.get_child_count() == 32, "32 actual nodes, no cross-channel starvation")
	var stale := _event(bridge,"late_old")
	bridge.begin_stage("audio_two")
	check(service.diagnostics().active == {&"effects":0,&"interface":0,&"ambience":1}, "stage swap stops all old audio and starts one current ambience")
	played = service.diagnostics().played
	service._on_event(stale)
	check(service.diagnostics().played == played and not bridge.emit_confirmed(stale), "old callback conserves captured epoch and is rejected")
	paused = true; bridge._process(0.01)
	check(not bridge.emit_confirmed(_event(bridge,"paused_hit")), "paused world never queues transient audio")
	check(service.confirm_ui() and service.diagnostics().active.interface == 1, "confirmed UI works while paused")
	for voice: Dictionary in service._voices:
		if voice.active: check(voice.player.can_process() == (voice.channel == &"interface") and voice.player.stream_paused == (voice.channel != &"interface"), "world pauses, UI always processes including initial flags")
	var replacement := Service.new(); bridge.add_child(replacement); replacement.install_streams(_streams()); replacement.configure(bridge,directory.path_join("replacement.cfg"))
	check(replacement._voices[28].player.stream_paused, "configure initially paused starts ambience frozen")
	replacement.dispose(); replacement.free()
	paused = false; bridge._process(0.01)
	check(not service._voices[28].player.stream_paused and service.diagnostics().active.effects == 0, "unpause resumes current ambience without historical impacts")
	played = service.diagnostics().played
	bridge.begin_stage("audio_two",true)
	check(service.diagnostics().played == played+1 and service.diagnostics().active.ambience == 1 and service.diagnostics().active.effects == 0, "same-stage resume creates only current ambience once")
	var one_shot_ambience := _stream()
	service.install_streams({&"ambience.stage":one_shot_ambience})
	bridge.begin_stage("audio_loop",true)
	var ambience: AudioStreamWAV = service._voices[28].player.stream
	check(one_shot_ambience.loop_mode == AudioStreamWAV.LOOP_DISABLED and ambience != one_shot_ambience and ambience.loop_mode == AudioStreamWAV.LOOP_FORWARD and ambience.loop_end == 2205, "service guarantees whole-sample WAV loop without mutating source")
	await create_timer(0.5).timeout
	check(service._voices[28].player.playing and service.diagnostics().active.ambience == 1, "ambient sample continues past its one-shot duration")
	paused = true; bridge._process(0.01); await create_timer(0.2).timeout
	check(service._voices[28].player.stream_paused and service.diagnostics().active.ambience == 1, "continuous ambience remains frozen during pause")
	paused = false; bridge._process(0.01); await create_timer(0.2).timeout
	check(not service._voices[28].player.stream_paused and service._voices[28].player.playing, "loop resumes without starting a second ambient voice")
	service.clear_stage(); service.install_streams({&"world.impact":_stream()})
	bridge.emit_confirmed(_event(bridge,"finite"))
	check(service.diagnostics().active.effects == 1, "finite synthetic audio starts")
	var audio_deadline := Time.get_ticks_msec()+3000
	while service.diagnostics().active.effects > 0 and Time.get_ticks_msec() < audio_deadline:
		await create_timer(0.05).timeout
	check(service.diagnostics().active.effects == 0, "native finished notification frees voice and stream")
	service.install_streams(_streams())
	await _test_panel(service,bridge)
	bridge.clear_stage()
	check(service.diagnostics().active == {&"effects":0,&"interface":0,&"ambience":0}, "clear stage releases every voice")
	service.dispose(); service.dispose()
	check(AudioServer.bus_count == bus_baseline and bridge.event_confirmed.get_connections().size() == 1 and service.get_child_count() == 0, "dispose removes all own buses, voices and bridge subscriptions only")
	for unused: int in 3:
		service.configure(bridge,config_path); service.dispose()
		check(AudioServer.bus_count == bus_baseline, "configure/dispose cycles do not leak")
	host.free()
	await _test_staging()
	await _test_controller()
	await _test_mix_protection()
	print("E08 audio: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
func _test_panel(service: PresentationAudioService, bridge: PresentationEventBridge) -> void:
	var ui := Control.new(); root.add_child(ui); GuiMetrics.configure_root(ui); GuiMetrics.set_scale(1.2,ui)
	var controls := BattleControls.new(); ui.add_child(controls); controls.audio_panel.bind_service(service); controls.settings_overlay.show()
	await _frames(6)
	var bounds := Rect2(Vector2.ZERO,Vector2(1280,720))
	check(bounds.encloses(GuiMetrics.visual_rect(controls.settings_panel)), "UI120% modal fits native viewport")
	var scroll := controls.settings_panel.get_child(0).get_child(0) as ScrollContainer
	scroll.ensure_control_visible(controls.audio_panel)
	await _frames(5)
	check(scroll.follow_focus and scroll.get_v_scroll_bar().max_value > scroll.size.y, "settings is scrollable and follows keyboard focus")
	check(GuiMetrics.visual_rect(scroll).encloses(GuiMetrics.visual_rect(controls.audio_panel)), "all four audio rows and status visible together at UI120% after scroll")
	paused = true; bridge._process(0.01)
	service.set_volume(&"effects",0.25)
	var before := ui_events.size()
	var slider: HSlider = controls.audio_panel.sliders[&"effects"]
	slider.grab_focus()
	var key := InputEventKey.new(); key.keycode = KEY_RIGHT; key.physical_keycode = KEY_RIGHT; key.pressed = true
	root.push_input(key,true); await _frames()
	check(service.preferences.value(&"effects").volume > 0.25 and ui_events.size() == before+1, "keyboard volume adjustment persists and confirms during pause")
	var mute: CheckBox = controls.audio_panel.mutes[&"effects"]
	mute.button_pressed = not mute.button_pressed
	check(service.preferences.value(&"effects").muted == mute.button_pressed and ui_events.size() == before+2, "mute control confirms applied state")
	check(slider.focus_mode == Control.FOCUS_ALL and mute.focus_mode == Control.FOCUS_ALL, "audio controls keyboard-focusable")
	service.configure(bridge,"user://e08_audio_fixture/missing/audio.cfg")
	slider.value = 0.42
	check(controls.audio_panel.status.text.contains("não foi possível salvar"), "write failure visible in native panel")
	service.configure(bridge,"user://e08_audio_fixture/audio.cfg")
	controls.audio_panel.bind_service(service); controls.audio_panel.bind_service(service)
	check(service.preferences_changed.get_connections().size() == 1, "panel binding idempotent")
	if "--audio-native" in OS.get_cmdline_user_args():
		slider.grab_focus(); await _frames(5); await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var output := ProjectSettings.globalize_path("res://.godot/verification/e08_p2_ui120.png")
		check(image.save_png(output) == OK, "native renderer screenshot saved")
		print("E08_NATIVE_CAPTURE "+output)
	paused = false; bridge._process(0.01)
	controls.free(); ui.free(); GuiMetrics.scale = GuiMetrics.SCALE
	check(service.preferences_changed.get_connections().is_empty(), "panel removal disconnects preferences observer")
func _test_controller() -> void:
	var controller := RunController.new(); root.add_child(controller); current_scene = controller
	await _frames(4)
	var bridge := controller.presentation_events()
	check(bridge != null and controller.presentation_audio() != null and controller.presentation_audio().get_parent() == bridge, "native controller installs audio below existing Control snapshot exclusion")
	bridge.event_confirmed.connect(_record)
	var before := ui_events.size()
	controller._toggle_settings(true); controller._toggle_settings(true)
	check(paused and ui_events.size() == before+1, "accepted settings open confirms once; redundant request silent")
	controller._toggle_settings(false); controller._toggle_settings(false)
	check(not paused and ui_events.size() == before+2 and ui_events.back() == &"ui_cancel", "real close cancels once; redundant close silent")
	controller.battle_controls.assign_skill(&"not_learned",2)
	check(ui_events.size() == before+2, "refused UI assignment never confirms")
	controller.free(); current_scene = null; paused = false

func _test_staging() -> void:
	var bus_baseline := AudioServer.bus_count
	var host := StagingHost.new(); root.add_child(host)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.bind_controller(host)
	var service := Service.new(); bridge.add_child(service); service.install_streams(_streams())
	service.configure(bridge,"user://e08_audio_fixture/staging.cfg")
	bridge.begin_stage("staging",true)
	check(service.diagnostics().played == 0 and service.diagnostics().active.ambience == 0, "passive install never starts synthetic ambience before freeze")
	bridge.emit_confirmed(_event(bridge,"uncommitted_hit")); service.confirm_ui()
	await _frames(4)
	check(service.diagnostics().played == 0, "writer wait drops all transients and UI without sound")
	host.process_mode = Node.PROCESS_MODE_DISABLED
	bridge.process_mode = Node.PROCESS_MODE_DISABLED
	service.process_mode = Node.PROCESS_MODE_DISABLED
	host.snapshot_passive = false
	service._process(0.01); service._play(&"world.impact")
	check(service.diagnostics().played == 0, "disabled staging cannot start audio even if invoked explicitly")
	host.snapshot_passive = true
	host.process_mode = Node.PROCESS_MODE_ALWAYS; bridge.process_mode = Node.PROCESS_MODE_ALWAYS; service.process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(4)
	check(service.diagnostics().played == 0, "uncertain writer keeps passive graph silent after modes restored")
	host.snapshot_passive = false
	await _frames(4)
	check(service.diagnostics().played == 1 and service.diagnostics().active == {&"effects":0,&"interface":0,&"ambience":1}, "confirmed activation starts only one current ambience, no staged replay")
	await _frames(4)
	check(service.diagnostics().played == 1, "activation is idempotent on later frames")
	host.free()
	check(AudioServer.bus_count == bus_baseline, "activated graph cleanup restores buses")
	var aborted := StagingHost.new(); root.add_child(aborted)
	var aborted_bridge := Bridge.new(); aborted.add_child(aborted_bridge); aborted_bridge.bind_controller(aborted)
	var aborted_service := Service.new(); aborted_bridge.add_child(aborted_service); aborted_service.install_streams(_streams()); aborted_service.configure(aborted_bridge,"user://e08_audio_fixture/abort.cfg")
	aborted_bridge.begin_stage("aborted",true)
	check(aborted_service.diagnostics().played == 0, "failed/aborted install remains silent with samples present")
	root.remove_child(aborted); aborted.free()
	await _frames()
	check(AudioServer.bus_count == bus_baseline, "abort drops pending ambience without leaked buses or deferred replay")

# Output safety oracle is independent of the runtime's effect settings.
const MIX_CEILING := 0.8912509381337456 # -1 dBFS, linear amplitude.
func _assert_mix_effect(service: PresentationAudioService) -> void:
	var general := AudioServer.get_bus_index(service._buses[&"general"])
	check(AudioServer.get_bus_effect_count(general) == 1, "one output protection effect per private general bus")
	if AudioServer.get_bus_effect_count(general) != 1: return
	var effect := AudioServer.get_bus_effect(general,0) as AudioEffectHardLimiter
	check(effect != null and AudioServer.is_bus_effect_enabled(general,0), "native hard limiter enabled after the channel sum")
	if effect != null:
		check(is_equal_approx(effect.ceiling_db,-1.01) and effect.pre_gain_db == 0.0 and is_equal_approx(effect.release,0.1), "unity input gain, -1.01 dB internal ceiling margin and 100 ms release")
	for channel: StringName in [&"effects", &"interface", &"ambience"]:
		check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(service._buses[channel])) == 0, "child channel is unmodified before private output protection")
	service.configure(service._bridge,service.preferences.path)
	check(AudioServer.get_bus_effect_count(general) == 1, "idempotent configure never stacks limiters")
	var other := Service.new(); service._bridge.add_child(other); other.install_streams(_streams()); other.configure(service._bridge,service.preferences.path)
	var other_bus := AudioServer.get_bus_index(other._buses[&"general"])
	if effect != null and AudioServer.get_bus_effect_count(other_bus) == 1:
		check(effect != AudioServer.get_bus_effect(other_bus,0), "limiter state belongs to each service instance")
	other.dispose(); other.free()
func _mix_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 44100
	var bytes := PackedByteArray(); bytes.resize(22050)
	for index: int in 11025: bytes.encode_s16(index*2,roundi(sin(float(index)*TAU*440.0/44100.0)*30000.0))
	stream.data = bytes
	return stream
func _mix_stats(samples: PackedVector2Array) -> Dictionary:
	var peak := 0.0; var above := 0; var above_ceiling := 0; var squares := 0.0; var peak_index := 0
	for index: int in samples.size():
		var frame := samples[index]; var amplitude := maxf(absf(frame.x),absf(frame.y))
		if amplitude > peak: peak = amplitude; peak_index = index
		if amplitude > 1.0: above += 1
		if amplitude > MIX_CEILING+0.00001: above_ceiling += 1
		squares += float(frame.x)*frame.x+float(frame.y)*frame.y
	return {"frames":samples.size(),"peak":peak,"peak_index":peak_index,"frames_above_full_scale":above,"frames_above_ceiling":above_ceiling,"rms":sqrt(squares/maxf(1.0,float(samples.size()*2)))}
func _waveform_difference(raw: PackedVector2Array, output: PackedVector2Array, lag: int) -> float:
	var signal_squared := 0.0; var error_squared := 0.0
	for index: int in raw.size():
		var target := index+lag
		if target < 0 or target >= output.size(): continue
		var error := raw[index]-output[target]
		error_squared += float(error.x)*error.x+float(error.y)*error.y
		signal_squared += float(raw[index].x)*raw[index].x+float(raw[index].y)*raw[index].y
	return sqrt(error_squared/maxf(signal_squared,0.000000000001))
func _save_mix_capture(folder: String, name: String, samples: PackedVector2Array) -> Dictionary:
	var bytes := PackedByteArray(); bytes.resize(samples.size()*8)
	for index: int in samples.size(): bytes.encode_float(index*8,samples[index].x); bytes.encode_float(index*8+4,samples[index].y)
	var path := folder.path_join(name+".f32le")
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file != null, "raw stereo float capture opens: "+name)
	if file == null: return {}
	file.store_buffer(bytes); file.close()
	return {"file":name+".f32le","sha256":FileAccess.get_sha256(path),"format":"interleaved stereo little-endian float32","bytes":bytes.size()}
func _mix_case(label: String, effects: int, interface_count: int, ambient: int, synthetic: bool, folder: String) -> Dictionary:
	var bus_baseline := AudioServer.bus_count
	var host := Node2D.new(); root.add_child(host)
	var bridge := Bridge.new(); host.add_child(bridge); bridge.bind_controller(host)
	var service := Service.new(); bridge.add_child(service)
	if synthetic:
		var streams := {}; for id: StringName in Catalog.ids(): streams[id] = _mix_stream()
		service.install_streams(streams)
	DirAccess.make_dir_recursive_absolute("user://e08_audio_mix_fixture")
	service.configure(bridge,"user://e08_audio_mix_fixture/audio.cfg")
	_assert_mix_effect(service)
	for channel: StringName in Catalog.CHANNELS:
		check(service.set_volume(channel,1.0) == OK and service.set_muted(channel,false) == OK, "mix at exactly 100 percent, unmuted: "+String(channel))
	var general := AudioServer.get_bus_index(service._buses[&"general"])
	var raw_bus := AudioServer.get_bus_index(service._buses[&"effects"])
	var raw_effects := AudioEffectCapture.new(); raw_effects.buffer_length = 2.0
	var raw_sum := AudioEffectCapture.new(); raw_sum.buffer_length = 2.0
	var protected := AudioEffectCapture.new(); protected.buffer_length = 2.0
	AudioServer.add_bus_effect(raw_bus,raw_effects)
	AudioServer.add_bus_effect(general,raw_sum,0) # Before the limiter: sum of every child channel.
	AudioServer.add_bus_effect(general,protected) # After limiter, before general fader (fixed at 1).
	bridge.begin_stage("mix_"+label); service.clear_stage()
	await create_timer(0.15).timeout
	raw_effects.clear_buffer(); raw_sum.clear_buffer(); protected.clear_buffer()
	var played: int = service.diagnostics().played
	for index: int in effects: check(bridge.emit_confirmed(_event(bridge,label+"/impact/%d" % index)), "confirmed real/synthetic impact admitted")
	for index: int in interface_count: check(bridge.emit_confirmed(_event(bridge,label+"/ui/%d" % index,&"ui_confirm")), "confirmed UI admitted to full mix")
	for unused: int in ambient: check(service._play(&"ambience.stage"), "current ambience admitted to full mix")
	var immediate := service.diagnostics()
	check(immediate.active == {&"effects":effects,&"interface":interface_count,&"ambience":ambient} and immediate.played == played+effects+interface_count+ambient and immediate.dropped == 0 and immediate.missing_samples.is_empty(), "all requested voices actually active, no drops or missing samples")
	await create_timer(0.8).timeout
	var effects_samples := raw_effects.get_buffer(raw_effects.get_frames_available())
	var sum_samples := raw_sum.get_buffer(raw_sum.get_frames_available())
	var output_samples := protected.get_buffer(protected.get_frames_available())
	var raw_stats := _mix_stats(effects_samples); var sum_stats := _mix_stats(sum_samples); var output_stats := _mix_stats(output_samples)
	check(output_stats.frames >= 10000 and output_stats.peak > 0.01 and output_stats.rms > 0.001, "nonempty useful-level protected output, never a silent success")
	check(output_stats.frames_above_full_scale == 0 and output_stats.frames_above_ceiling == 0 and output_stats.peak <= MIX_CEILING+0.00001, "summed private output never exceeds the -1 dB safety ceiling")
	if effects == 24:
		check(raw_stats.peak > 1.0 and sum_stats.peak > 1.0, "stress input still overloads raw Effects and General sum; no gain reduction or voice culling hides it")
		check(output_stats.peak > 0.4, "limited dense mix retains a useful output level")
	var lag: int = int(output_stats.peak_index)-int(sum_stats.peak_index)
	var difference := _waveform_difference(sum_samples,output_samples,lag)
	if effects == 1:
		check(sum_stats.peak < MIX_CEILING and absf(output_stats.peak-sum_stats.peak) < 0.0001 and difference < 0.001, "single real impact below threshold preserves level and waveform after latency alignment")
	var record := {"case":label,"synthetic":synthetic,"requested_active":{&"effects":effects,&"interface":interface_count,&"ambience":ambient},"immediate_diagnostics":immediate,"final_diagnostics":service.diagnostics(),"all_channel_volumes":1.0,"all_channel_mutes":false,"driver":AudioServer.get_driver_name(),"mix_rate":AudioServer.get_mix_rate(),"ceiling_linear":MIX_CEILING,"raw_effects":raw_stats,"raw_general_sum":sum_stats,"protected_general":output_stats,"single_waveform_lag_frames":lag,"aligned_relative_waveform_error":difference,"capture_points":{"raw_effects":"Effects bus before send to General","raw_general_sum":"General effect slot0, before limiter, all channels summed","protected_general":"General last effect, after limiter and sum; General fader unity"},"capture_files":{}}
	if not folder.is_empty():
		record.capture_files.raw_effects = _save_mix_capture(folder,label+"_raw_effects",effects_samples)
		record.capture_files.raw_general_sum = _save_mix_capture(folder,label+"_raw_general_sum",sum_samples)
		record.capture_files.protected_general = _save_mix_capture(folder,label+"_protected_general",output_samples)
	print("E08_OUTPUT_MIX "+JSON.stringify(record))
	service.dispose(); host.free()
	check(AudioServer.bus_count == bus_baseline, "capture and limiter buses cleaned after mix case")
	return record
func _test_mix_protection() -> void:
	var folder := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-mix-output="): folder = argument.trim_prefix("--audio-mix-output=")
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	var cases: Array[Dictionary] = []
	cases.append(await _mix_case("synthetic_full_pools",24,4,4,true,folder))
	if "--audio-mix-native" in OS.get_cmdline_user_args():
		check(AudioServer.get_driver_name() != "Dummy", "real sample proof uses a native audio driver")
		for id: StringName in Catalog.ids(): check(ResourceLoader.exists(Catalog.definition(id).path), "real P3 WAV required for native proof: "+String(id))
		cases.append(await _mix_case("real_single_impact",1,0,0,false,folder))
		cases.append(await _mix_case("real_24_impacts",24,0,0,false,folder))
		cases.append(await _mix_case("real_full_pools",24,4,4,false,folder))
	if not folder.is_empty():
		var file := FileAccess.open(folder.path_join("mix_metrics.json"),FileAccess.WRITE)
		check(file != null,"mix metrics file opens")
		if file != null: file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"cases":cases,"failures":failures},"  ",true)); file.close()
