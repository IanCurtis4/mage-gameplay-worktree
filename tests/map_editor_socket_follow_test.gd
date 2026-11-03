extends SceneTree
## F10 Q1: markers on a layer follow a sculpted ground, and a marker that cannot
## compile is named with its place and the height of the ground.
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_SOCKET_FOLLOW_CHECK "+id+" "+str(ok))
func source(mode: String) -> Dictionary:
	var data: Dictionary = Document.empty("socket_follow")
	var heights: Array = []; heights.resize(9*9); heights.fill(0.0)
	data.layers = [{"layer_id":"ground","name":"Chão","origin_xz":[0.0,0.0],"columns":9,"rows":9,"sample_spacing":64.0,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	if mode == "height_grid": data.layers[0]["surface_mode"] = "height_grid"
	data.sockets = [{"socket_id":"entry","surface_id":"ground","position_xyz":[256.0,0.0,256.0],"kind":"entrance"},
		{"socket_id":"far","surface_id":"ground","position_xyz":[32.0,0.0,32.0],"kind":"exit"}]
	return data
func entry(data: Dictionary) -> Array:
	return data.sockets[0].position_xyz
func hill(data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var merged := {"mode":"rounded_hill","radius":160.0,"strength":30.0,"hardness":0.5}
	merged.merge(options,true)
	return Brush.stroke(data,"ground",[Vector2(256.0,256.0)],merged)
func run() -> void:
	# 1. Ground support, on both triangles of a quad.
	var sloped := {"origin_xz":[0.0,0.0],"sample_spacing":10.0,"columns":2,"rows":2,"heights":[0.0,10.0,30.0,20.0]}
	check("ground_uses_the_drawn_diagonal",is_equal_approx(Brush.ground_y(sloped,sloped.heights,Vector2(7.0,3.0)),10.0) and is_equal_approx(Brush.ground_y(sloped,sloped.heights,Vector2(3.0,7.0)),18.0) and is_nan(Brush.ground_y(sloped,sloped.heights,Vector2(11.0,3.0))))
	for mode: String in ["exact_planes","height_grid"]:
		var sculpted := hill(source(mode))
		var data: Dictionary = sculpted.data
		var ground := Brush.ground_y(data.layers[0],data.layers[0].heights,Vector2(256.0,256.0))
		# 2. The marker follows, the distant one does not move, and the piece compiles.
		check(mode+"_marker_follows",sculpted.followed_sockets == ["entry"] and ground > 20.0 and entry(data)[1] == ground and data.sockets[1].position_xyz[1] == 0.0)
		check(mode+"_compiles_after_sculpting",Compiler.compile(data).ok)
	# 3. Paint moves no ground, and previews never touch the source of a marker.
	var painted := hill(source("exact_planes"),{"mode":"material","material":"earth","strength":1.0})
	check("material_moves_nothing",not painted.has("followed_sockets") and entry(painted.data)[1] == 0.0)
	var preview := Brush.stroke(source("exact_planes"),"ground",[Vector2(256.0,256.0)],{"mode":"raise","radius":160.0,"strength":30.0,"hardness":0.5},true)
	check("preview_does_not_follow",not preview.has("followed_sockets") and entry(preview.data)[1] == 0.0)
	# 4. A marker already off the ground stays there and is named by the compiler.
	var floating := source("exact_planes"); entry(floating)[1] = 90.0
	var kept := hill(floating)
	check("floating_marker_is_kept",kept.followed_sockets.is_empty() and entry(kept.data)[1] == 90.0)
	var named := Compiler.compile(kept.data)
	var diagnostic: Dictionary = named.diagnostics[0] if not named.ok else {}
	var ground_there := Brush.ground_y(kept.data.layers[0],kept.data.layers[0].heights,Vector2(256.0,256.0))
	check("diagnostic_names_the_marker",not named.ok and named.code == "socket_invalid" and diagnostic.entity_id == "entry" and diagnostic.field == "socket" and diagnostic.surface_id == "ground" and diagnostic.position_xyz == [256.0,90.0,256.0] and diagnostic.ground_y == ground_there and "entry" in diagnostic.message and "altura" in diagnostic.message)
	var outside := source("exact_planes"); entry(outside)[0] = 9000.0
	var away := Compiler.compile(outside)
	check("diagnostic_outside_the_layer",not away.ok and "fora da camada" in away.diagnostics[0].message and not away.diagnostics[0].has("ground_y"))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_SOCKET_FOLLOW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
