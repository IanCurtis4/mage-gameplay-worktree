@tool
extends RefCounted
## Builds a proposal only; the caller commits it once through DocumentSession.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")

static func create(data: Dictionary) -> Dictionary:
	var read := Schema.read(JSON.stringify(data,"",true,true).to_utf8_buffer())
	if not read.ok or not read.valid: return Schema.result(false,"source_invalid")
	for key: String in ["dependencies","layers","special_surfaces","placements","regions","connectors","sockets"]:
		if not data[key].is_empty(): return Schema.result(false,"source_occupied")
	if data.composition != null: return Schema.result(false,"source_occupied")
	var source: Dictionary = read.data
	source.name = "Campo orgânico"
	var heights: Array = []; heights.resize(33 * 33); heights.fill(0.0)
	source.layers.append({"layer_id":"organic_field","name":"Campo orgânico","origin_xz":[0,0],"sample_spacing":50,"columns":33,"rows":33,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]})
	var hill := {"mode":"rounded_hill","shape":"circle","radius":420.0,"strength":110.0,"hardness":0.0}
	for iteration: int in 2:
		var raised := Brush.stroke(source,"organic_field",[Vector2(800,800)],hill)
		if not raised.ok: return raised
		source = raised.data
	var path := {"mode":"material","shape":"circle","material":"earth","radius":120.0,"strength":0.8,"hardness":0.15}
	var painted := Brush.stroke(source,"organic_field",[Vector2(0,350),Vector2(250,390),Vector2(500,480),Vector2(750,610),Vector2(1000,660),Vector2(1300,620),Vector2(1600,500)],path)
	if not painted.ok: return painted
	return painted
