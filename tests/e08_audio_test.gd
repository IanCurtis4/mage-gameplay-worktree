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
