extends SceneTree
## E08 P5 A2: forest ambience layer (visual) and forest cue (audio). Presentation only.
const Layer = preload("res://scripts/presentation/forest_ambience_layer.gd")
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
const Registry = preload("res://scripts/core/expedition/snapshot/snapshot_registry.gd")
const FOREST_WAV := "res://assets/audio/e08/ambience_forest.wav"
const STAGE_WAV := "res://assets/audio/e08/ambience_stage.wav"
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _frames(count: int = 3) -> void:
	for unused: int in count: await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_test_install_rules()
	_test_bounds_and_determinism()
	await _test_pause()
	_test_batching()
	_test_catalog()
	_test_wav()
	await _test_view_integration()
	print("E08 forest ambience: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_install_rules() -> void:
	var host := Node2D.new(); root.add_child(host)
	for biome: String in ["ruin", "desert", "meadow", "", "unknown"]:
		check(Layer.install(host, biome, 7) == null and host.get_node_or_null(Layer.NODE_NAME) == null, "no layer for biome '%s'" % biome)
	var layer: Variant = Layer.install(host, "forest", 7)
	check(layer != null and layer.get_parent() == host and layer.name == Layer.NODE_NAME, "forest creates the layer")
	check(Layer.install(host, "forest", 7) == layer and host.get_child_count() == 1, "same seed keeps the single layer (idempotent)")
	var replacement: Variant = Layer.install(host, "forest", 8)
	check(replacement != layer and host.get_child_count() == 1 and layer.get_parent() == null, "new stage seed replaces the layer without duplicates")
	check(Layer.install(host, "ruin", 8) == null and host.get_child_count() == 0, "leaving the forest removes the layer")
	check(Layer.install(null, "forest", 1) == null, "invalid host is refused")
	check(Layer.stage_seed("42", "stage_a") == Layer.stage_seed("42", "stage_a") and Layer.stage_seed("42", "stage_a") != Layer.stage_seed("43", "stage_a") and Layer.stage_seed("42", "stage_a") != Layer.stage_seed("42", "stage_b"), "stage seed is stable and depends on seed text and stage")
	host.free()
	# Detached layers are freed by the engine: nothing keeps them alive.
	var orphan: Variant = Layer.install(Node2D.new(), "forest", 1)
	check(orphan != null and orphan.get_parent() != null, "layer lives under its parent only")
	orphan.get_parent().free()

func _test_bounds_and_determinism() -> void:
	var a: Variant = Layer.new()
	var b: Variant = Layer.new()
	var c: Variant = Layer.new()
	a.layer_seed = 99; b.layer_seed = 99; c.layer_seed = 100
	root.add_child(a); root.add_child(b); root.add_child(c)
	check(Layer.particle_count() <= Layer.STATE_CAP and Layer.STATE_CAP <= 48, "particle count %d is within the cap of 48" % Layer.particle_count())
	check(a.state_size() == Layer.STATE_CAP * Layer.FIELDS, "state is a fixed-size block")
	check(a.state_signature() == b.state_signature(), "same seed gives identical state")
	check(a.state_signature() != c.state_signature(), "different seed gives different state")
	var size_before: int = a.state_size()
	var children_before: int = a.get_child_count()
	for unused: int in 600: a.advance(1.0 / 60.0)
	check(a.state_size() == size_before and a.get_child_count() == children_before, "running 10 s neither grows state nor spawns nodes")
	var signature_after: int = a.state_signature()
	for unused: int in 600: b.advance(1.0 / 60.0)
	check(is_equal_approx(a.elapsed, b.elapsed) and signature_after == b.state_signature() and a.state_signature() == signature_after, "same seed and same steps stay identical; state is not mutated by motion")
	a.advance(5.0)
	check(is_equal_approx(a.elapsed, 10.0 + Layer.MAX_STEP), "one huge step is clamped")
	check(Layer.MAX_ALPHA <= 0.5, "ambient alpha stays low")
	a.free(); b.free(); c.free()

func _test_pause() -> void:
	var host := Node2D.new(); root.add_child(host)
	var layer: Variant = Layer.install(host, "forest", 5)
	check(layer.process_mode == Node.PROCESS_MODE_PAUSABLE, "layer pauses with the world even under an always-processing host")
	await _frames(4)
	check(layer.elapsed > 0.0, "layer animates while the world runs")
	paused = true
	var frozen: float = layer.elapsed
	check(not layer.can_process(), "paused tree stops the layer")
	await _frames(5)
	check(layer.elapsed == frozen, "elapsed time is frozen while paused")
	paused = false
	await _frames(4)
	check(layer.elapsed > frozen, "layer resumes after the pause")
	host.free()
	# Rebuilt on resume without saved state: a fresh install starts from time zero.
	var rebuilt: Variant = Layer.install(Node2D.new(), "forest", 5)
	check(rebuilt.elapsed == 0.0, "rebuilt layer starts fresh, nothing is restored")
	rebuilt.get_parent().free()

## P7-C4: the layer is three batched commands (was ~40 primitives) and the particles are unchanged.
func _test_batching() -> void:
	var layer: Variant = Layer.new()
	layer.layer_seed = 99
	root.add_child(layer)
	layer.elapsed = 23.0
	layer._draw()
	check(layer.last_batch_count == Layer.DRAW_BATCHES and Layer.DRAW_BATCHES <= 3, "ambience draws in %d batched commands (was ~40 primitives)" % layer.last_batch_count)
	# Independent copy of the pre-batching formulas: centres must match for every leaf, mote and mist blob.
	var size: Vector2 = layer.get_viewport_rect().size
	var half: Vector2 = size * 0.5
	var t := 23.0
	var s: PackedFloat32Array = layer._state
	var centers: PackedVector2Array = layer.particle_centers()
	check(centers.size() == Layer.LEAVES + Layer.MOTES + Layer.MIST, "centre list covers every leaf, mote and mist blob (%d)" % centers.size())
	var worst := 0.0
	for k: int in Layer.LEAVES:
		var base := k * Layer.FIELDS
		var speed := s[base + 3]
		var sway := sin(t * 0.7 * speed + s[base + 2])
		var x: float = layer._wrap01(s[base] + t * 0.012 * speed + 0.03 * sway) * size.x - half.x
		var y: float = layer._wrap01(s[base + 1] + t * 0.022 * speed) * size.y - half.y
		worst = maxf(worst, centers[k].distance_to(Vector2(x, y)))
	for k: int in Layer.MOTES:
		var base := (Layer.LEAVES + k) * Layer.FIELDS
		var speed := s[base + 3]
		var x: float = layer._wrap01(s[base] + t * 0.004 * speed + 0.015 * sin(t * 0.5 * speed + s[base + 2])) * size.x - half.x
		var y: float = layer._wrap01(s[base + 1] - t * 0.006 * speed) * size.y - half.y
		worst = maxf(worst, centers[Layer.LEAVES + k].distance_to(Vector2(x, y)))
	for k: int in Layer.MIST:
		var base := (Layer.LEAVES + Layer.MOTES + k) * Layer.FIELDS
		var drift: float = layer._wrap01(s[base] + t * 0.006 * s[base + 3])
		var x: float = (drift * 1.6 - 0.3) * size.x - half.x
		var y: float = (0.55 + 0.4 * s[base + 1]) * size.y - half.y
		worst = maxf(worst, centers[Layer.LEAVES + Layer.MOTES + k].distance_to(Vector2(x, y)))
	check(worst < 0.001, "particle positions equal the pre-batching formulas (max error %.6f px)" % worst)
	check(Layer.particle_count() == 39 and Layer.LEAVES == 10 and Layer.MOTES == 20 and Layer.MIST == 5 and Layer.SHAFTS == 4, "particle counts unchanged")
	var other: Variant = Layer.new()
	other.layer_seed = 99
	root.add_child(other)
	other.elapsed = 23.0
	other._draw()
	check(other.particle_centers() == centers, "same seed and time give identical positions")
	var different: Variant = Layer.new()
	different.layer_seed = 100
	root.add_child(different)
	different.elapsed = 23.0
	different._draw()
	check(different.particle_centers() != centers, "different seed gives different positions")
	check(Layer.REDRAW_INTERVAL == 1.0 / 30.0, "30 Hz redraw throttle kept")
	layer.free(); other.free(); different.free()

func _test_catalog() -> void:
	var forest := Catalog.definition(&"ambience.forest")
	check(not forest.is_empty() and forest.channel == &"ambience" and forest.path == FOREST_WAV and forest.priority == 0, "ambience.forest is an ambience-channel cue")
	check(Catalog.definition(&"ambience.stage").path == STAGE_WAV, "generic stage cue unchanged")
	check(Catalog.ambience_for_biome("forest") == &"ambience.forest", "forest biome selects the forest cue")
	for biome: String in ["ruin", "desert", "meadow", "", "unknown", "Forest"]:
		check(Catalog.ambience_for_biome(biome) == &"ambience.stage", "biome '%s' keeps ambience.stage" % biome)
	check(Catalog.for_kind(&"stage_enter") == &"ambience.stage", "stage_enter still maps to the generic bed")
	check(&"ambience.forest" in Catalog.ambience_ids() and &"ambience.forest" in Catalog.ids() and Catalog.LIMITS[&"ambience"] == 4 and Catalog.LIMITS[&"effects"] == 24 and Catalog.LIMITS[&"interface"] == 4, "channel limits unchanged")

func _pcm(path: String) -> PackedInt32Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	var samples := PackedInt32Array()
	var data_at := 44
	samples.resize((bytes.size() - data_at) / 2)
	for index: int in samples.size(): samples[index] = bytes.decode_s16(data_at + index * 2)
	return samples

func _test_wav() -> void:
	check(FileAccess.file_exists(FOREST_WAV), "ambience_forest.wav exists")
	var stream := load(FOREST_WAV) as AudioStreamWAV
	check(stream != null and stream.mix_rate == 44100 and not stream.stereo and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "imported as 44.1 kHz mono PCM16; the service loops a private copy (rate %s stereo %s format %s loop %s)" % [stream.mix_rate if stream != null else -1, stream.stereo if stream != null else "-", stream.format if stream != null else -1, stream.loop_mode if stream != null else -1])
	check(stream != null and absf(stream.get_length() - 12.0) < 0.01, "loop length is 12 s")
	var samples := _pcm(FOREST_WAV)
	var peak := 0; var squares := 0.0; var max_step := 0
	for index: int in samples.size():
		var value := samples[index]
		peak = maxi(peak, absi(value)); squares += float(value) * float(value)
		if index > 0: max_step = maxi(max_step, absi(value - samples[index - 1]))
	var peak_linear := float(peak) / 32768.0
	var rms := sqrt(squares / float(samples.size())) / 32768.0
	check(samples.size() == 529200, "529200 frames")
	check(peak_linear < 0.2 and peak_linear > 0.01, "peak %.4f is far below clipping and audible" % peak_linear)
	var reference := _pcm(STAGE_WAV)
	var reference_squares := 0.0
	for value: int in reference: reference_squares += float(value) * float(value)
	var reference_rms := sqrt(reference_squares / float(reference.size())) / 32768.0
	check(rms > reference_rms * 0.6 and rms < reference_rms * 1.4, "RMS %.4f is consistent with ambience.stage %.4f" % [rms, reference_rms])
	check(absi(samples[0] - samples[samples.size() - 1]) <= max_step, "loop seam is no larger than an ordinary sample step (no click)")
	var provenance := JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/e08/provenance.json")) as Dictionary
	var entry: Dictionary = provenance.get("samples", {}).get("ambience_forest", {})
	check(not entry.is_empty() and entry.sha256 == FileAccess.get_sha256(FOREST_WAV) and int(entry.frames) == samples.size(), "provenance sha256 and frame count match the file")

func _test_view_integration() -> void:
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample)
	await _frames(2)
	var controller: RunController = sample.controller
	var view: ExpeditionGeometryView = sample.view
	check(view.get_node_or_null(Layer.NODE_NAME) == null, "non-forest sample stage has no ambience layer")
	check(controller.presentation_audio().stage_biome() != "forest", "non-forest stage keeps the generic ambience selection")
	sample.world._stage["biome"] = "forest"
	check(controller.attach_expedition_view(view, 36)["ok"], "forest stage attaches")
	var layer: Variant = view.get_node_or_null(Layer.NODE_NAME)
	check(layer != null, "attach creates the layer for the forest biome")
	check(controller.presentation_audio().stage_biome() == "forest", "attach tells the audio service the biome")
	if layer != null:
		var effects: Node2D = view._effects
		check(effects != null and layer.z_index < effects.z_index and not layer.z_as_relative and layer.z_index > 4000, "layer is above every world sprite (<=4000) but below the indicator node")
		check(layer.get_canvas_layer_node() == null, "layer is on the world canvas, below the HUD canvas layers")
		check(Layer.Z_INDEX < Layer.INDICATOR_Z and effects.z_index == Layer.INDICATOR_Z, "constants match the real indicator order")
		var registry := Registry.new()
		check(registry._presentation_target(view), "layer parent is a snapshot presentation target, so the layer is skipped")
		registry._scan_children(controller)
		var visited := false
		for object: Object in registry._objects:
			if object == layer: visited = true
		check(not visited, "snapshot scan never visits the layer")
	sample.world._stage["biome"] = "ruin"
	check(controller.attach_expedition_view(view, 36)["ok"], "stage change attaches")
	check(view.get_node_or_null(Layer.NODE_NAME) == null and controller.presentation_audio().stage_biome() == "ruin", "stage change to another biome frees the layer and switches audio")
	await _frames(2)
	check(layer == null or not is_instance_valid(layer), "old layer is freed after the stage change")
	sample.free()
	await _frames(2)
