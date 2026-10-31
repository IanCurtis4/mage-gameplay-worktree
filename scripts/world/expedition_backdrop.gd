extends CanvasLayer
## Checkpoint38: themed parallax backdrop behind the expedition world. Presentation
## only (a CanvasLayer, so snapshots skip it); the stage biome picks the theme.
## Far layers move less than near ones as the camera travels.
const LAYER_ORDER := -100
const PERIOD := 2400.0
const THEMES := {
	"forest": {"sky":[Color("0d1b26"),Color("244a4a")],"haze":Color(0.62,0.82,0.74,0.08),"layers":[
		{"kind":"ridge","color":Color("1b3540"),"factor":0.06,"horizon":0.56,"height":0.16,"seed":3},
		{"kind":"pines","color":Color("15302c"),"factor":0.16,"horizon":0.66,"height":0.12,"seed":7},
		{"kind":"canopy","color":Color("0e221d"),"factor":0.30,"horizon":0.78,"height":0.09,"seed":11}]},
	"ruin": {"sky":[Color("1a1426"),Color("6b4652")],"haze":Color(0.95,0.7,0.6,0.07),"layers":[
		{"kind":"ridge","color":Color("2c2333"),"factor":0.06,"horizon":0.58,"height":0.14,"seed":5},
		{"kind":"columns","color":Color("241c29"),"factor":0.16,"horizon":0.68,"height":0.16,"seed":13},
		{"kind":"rubble","color":Color("17121c"),"factor":0.30,"horizon":0.80,"height":0.06,"seed":17}]},
	"desert": {"sky":[Color("23375a"),Color("d49a6a")],"haze":Color(1.0,0.85,0.6,0.10),"layers":[
		{"kind":"mesas","color":Color("8a5a44"),"factor":0.06,"horizon":0.60,"height":0.14,"seed":19},
		{"kind":"dunes","color":Color("a8754f"),"factor":0.16,"horizon":0.70,"height":0.08,"seed":23},
		{"kind":"dunes","color":Color("7d5238"),"factor":0.30,"horizon":0.80,"height":0.06,"seed":29}]},
	"meadow": {"sky":[Color("2b5a86"),Color("bfe0ea")],"haze":Color(0.9,0.97,1.0,0.10),"layers":[
		{"kind":"ridge","color":Color("5d7f97"),"factor":0.06,"horizon":0.58,"height":0.15,"seed":31},
		{"kind":"hills","color":Color("4f7a55"),"factor":0.16,"horizon":0.70,"height":0.07,"seed":37},
		{"kind":"groves","color":Color("355a3b"),"factor":0.30,"horizon":0.80,"height":0.07,"seed":41}]},
}
var biome := ""
var _sky: Node2D
var _haze: Node2D
var _layers: Array[Node2D] = []
var _last_center := Vector2.INF
var _last_size := Vector2.ZERO

static func theme_id(value: String) -> String:
	return value if THEMES.has(value) else "ruin"

func _init() -> void:
	name = "ExpeditionBackdrop"
	layer = LAYER_ORDER

func configure(value: String) -> void:
	var id := theme_id(value)
	if id == biome and _sky != null: return
	biome = id
	for child: Node in get_children(): child.queue_free()
	_layers.clear()
	var theme: Dictionary = THEMES[id]
	_sky = Node2D.new(); _sky.name = "Sky"; add_child(_sky)
	_sky.draw.connect(_draw_sky.bind(_sky,theme))
	for spec: Dictionary in theme["layers"]:
		var band := Node2D.new(); band.name = "Layer_%s" % spec["kind"]; add_child(band)
		band.set_meta("spec",spec); band.set_meta("scroll",Vector2.ZERO)
		band.draw.connect(_draw_band.bind(band))
		_layers.append(band)
	_haze = Node2D.new(); _haze.name = "Haze"; add_child(_haze)
	_haze.draw.connect(_draw_haze.bind(_haze,theme["haze"]))
	_last_center = Vector2.INF

func _process(_delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null: return
	var camera := viewport.get_camera_2d()
	var center := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var size := viewport.get_visible_rect().size
	if center == _last_center and size == _last_size: return
	_last_center = center; _last_size = size
	for band: Node2D in _layers:
		var spec: Dictionary = band.get_meta("spec")
		band.set_meta("scroll",Vector2(center.x*float(spec["factor"]),center.y*float(spec["factor"])*0.35))
		band.queue_redraw()
	if _sky != null: _sky.queue_redraw()
	if _haze != null: _haze.queue_redraw()

func _draw_sky(canvas: Node2D, theme: Dictionary) -> void:
	var size := canvas.get_viewport_rect().size
	var top: Color = theme["sky"][0]; var bottom: Color = theme["sky"][1]
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size.x,size.y),Vector2(0,size.y)]),PackedColorArray([top,top,bottom,bottom]))

func _draw_haze(canvas: Node2D, color: Color) -> void:
	var size := canvas.get_viewport_rect().size
	var clear := Color(color,0.0)
	canvas.draw_polygon(PackedVector2Array([Vector2(0,size.y*0.45),Vector2(size.x,size.y*0.45),Vector2(size.x,size.y),Vector2(0,size.y)]),PackedColorArray([clear,clear,color,color]))

# Deterministic, periodic profile: the band repeats every PERIOD pixels.
static func _wave(x: float, seed: int) -> float:
	var t := TAU*x/PERIOD
	return 0.55*sin(t*2.0+seed)+0.30*sin(t*5.0+seed*1.7)+0.15*sin(t*11.0+seed*0.3)

func _draw_band(band: Node2D) -> void:
	var spec: Dictionary = band.get_meta("spec"); var scroll: Vector2 = band.get_meta("scroll")
	var size := band.get_viewport_rect().size
	var horizon := clampf(size.y*float(spec["horizon"])-scroll.y,size.y*0.3,size.y*0.95)
	var height := size.y*float(spec["height"]); var seed := int(spec["seed"]); var color: Color = spec["color"]
	var start := -fposmod(scroll.x,PERIOD)-PERIOD
	var points := PackedVector2Array()
	var step := 12.0
	var x := start
	while x <= size.x+PERIOD:
		var world_x := x+scroll.x
		var y := horizon-height*_profile(String(spec["kind"]),world_x,seed)
		points.append(Vector2(x,y)); x += step
	points.append(Vector2(x,size.y)); points.append(Vector2(start,size.y))
	band.draw_colored_polygon(points,color)
	if spec["kind"] == "columns": _draw_columns(band,spec,scroll,horizon,height,color,size)

# 0..1 height of the silhouette at world_x for each kind.
static func _profile(kind: String, x: float, seed: int) -> float:
	var base := 0.5+0.5*_wave(x,seed)
	match kind:
		"ridge", "mesas":
			var shaped := clampf(base*1.25-0.1,0.0,1.0)
			return snappedf(shaped,0.25) if kind == "mesas" else shaped
		"pines":
			var tooth := absf(fposmod(x,46.0)-23.0)/23.0
			return clampf(0.35+0.45*base+0.35*(1.0-tooth),0.0,1.0)
		"canopy", "groves":
			var bump := sin(PI*fposmod(x,90.0)/90.0)
			return clampf(0.25+0.35*base+0.4*bump*(1.0 if kind == "canopy" or fposmod(floorf(x/90.0)*7.0+seed,3.0) < 1.0 else 0.2),0.0,1.0)
		"dunes", "hills":
			return clampf(0.3+0.7*(0.5+0.5*sin(TAU*x/700.0+seed)*0.6+0.4*_wave(x,seed)*0.5),0.0,1.0)
		"rubble":
			return clampf(0.2+0.5*base+0.1*float(posmod(int(floorf(x/37.0)),3)),0.0,1.0)
		"columns":
			return clampf(0.15+0.25*base,0.0,1.0)
	return base

# Broken columns and an occasional arch standing on the ruin band.
func _draw_columns(band: Node2D, spec: Dictionary, scroll: Vector2, horizon: float, height: float, color: Color, size: Vector2) -> void:
	var spacing := 150.0
	var first := floorf((scroll.x-spacing)/spacing)*spacing
	var x := first
	while x-scroll.x <= size.x+spacing:
		var lot := fposmod(x*0.37+int(spec["seed"])*11.0,10.0)
		if lot < 6.0:
			var screen_x := x-scroll.x
			var column := height*(1.2+0.25*lot)
			band.draw_rect(Rect2(screen_x,horizon-column,22,column+4),color)
			band.draw_rect(Rect2(screen_x-5,horizon-column-8,32,8),color)
			if lot < 1.5: band.draw_arc(Vector2(screen_x+56,horizon-column+4),45,PI,TAU,18,color,14.0)
		x += spacing
