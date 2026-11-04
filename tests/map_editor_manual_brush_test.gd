extends SceneTree
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var checks: Array[Dictionary] = []
func check(id: String, ok: bool) -> void: checks.append({"id":id,"ok":ok})
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var source := Document.empty("temporal_brush")
	source.layers = [TerrainPanel._layer("floor","Chão",0,0,10,5,5,[])]
	source.layers[0].heights.resize(25); source.layers[0].heights.fill(0.0)
	source.sockets = [{"socket_id":"entry","surface_id":"floor","position_xyz":[20,0,20],"kind":"entrance"}]
	var options := {"mode":"raise","radius":5.0,"strength":6.0,"hardness":1.0}
	var start_hash := Schema.semantic_hash(source)
	var temporal := Brush.temporal_begin(source,"floor",options,Vector2(20,20))
	check("begin",temporal.ok)
	if not temporal.ok: finish(); return
	for i: int in 10: Brush.temporal_sample(temporal,Vector2(20,20),0.1)
	check("hold_progress",is_equal_approx(temporal.data.layers[0].heights[12],6.0))
	Brush.temporal_sample(temporal,Vector2(30,20),0.1)
	check("move_progress",is_equal_approx(temporal.data.layers[0].heights[13],0.6))
	check("cancel_preserves_source",Schema.semantic_hash(source) == start_hash)
	var replay := Brush.temporal_begin(source,"floor",options,Vector2(20,20))
	for i: int in 10: Brush.temporal_sample(replay,Vector2(20,20),0.1)
	Brush.temporal_sample(replay,Vector2(30,20),0.1)
	check("sample_replay",replay.data.layers[0].heights == temporal.data.layers[0].heights)
	var done := Brush.temporal_finish(temporal)
	check("marker_follows",done.ok and is_equal_approx(done.data.sockets[0].position_xyz[1],6.6))
	var session := Session.new(); session.replace(source)
	check("single_commit",session.apply(done.data).ok)
	check("single_undo",session.undo() and session.document().semantic_hash() == start_hash and not session.undo())
	check("single_redo",session.redo() and session.document().to_data().layers[0].heights == done.data.layers[0].heights)
	var locked := source.duplicate(true); locked.layers[0].locked = true
	check("locked",Brush.temporal_begin(locked,"floor",options,Vector2(20,20)).code == "layer_locked")
	var protected := source.duplicate(true)
	protected.regions = [{"region_id":"keep","layer_id":"floor","polygon_xz":[[15,15],[25,15],[25,25],[15,25]],"purpose":"protected"}]
	protected.layers[0].protected_regions = ["keep"]
	var blocked := Brush.temporal_begin(protected,"floor",options,Vector2(20,20))
	Brush.temporal_sample(blocked,Vector2(20,20),0.1)
	check("protected",blocked.data.layers[0].heights[12] == 0.0)
	check("sample_bounded",not Brush.temporal_sample(blocked,Vector2.ZERO,1.0).ok)
	# Each temporal sample uses precisely the existing stroke kernel.
	for mode: String in ["raise","lower","flatten","smooth","material","rounded_hill"]:
		var fixture := source.duplicate(true)
		fixture.layers[0].heights[11] = 9.0
		var settings := {"mode":mode,"radius":15.0,"strength":2.0,"hardness":0.5,"target":4.0,"material":"earth"}
		var one := Brush.temporal_begin(fixture,"floor",settings,Vector2(20,20))
		var sample := Brush.temporal_sample(one,Vector2(20,20),0.1)
		var frozen := settings.duplicate(); frozen.strength = 0.2
		var oracle := Brush.stroke(fixture,"floor",[Vector2(20,20)],frozen,true)
		check("kernel_"+mode,sample.ok and oracle.ok and one.data.layers[0].heights == oracle.data.layers[0].heights and one.data.layers[0].material_masks == oracle.data.layers[0].material_masks)
	var segment := Brush.temporal_begin(source,"floor",options,Vector2(0,20))
	Brush.temporal_sample(segment,Vector2(10,20),0.1)
	check("segment_covers_between_ticks",segment.data.layers[0].heights[10] > 0.0 and segment.data.layers[0].heights[11] > 0.0)
	check("segment_limit",not Brush.temporal_sample(segment,Vector2(40,20),0.1).ok)
	finish()
func finish() -> void:
	var ok := not checks.is_empty()
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("MANUAL_BRUSH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
