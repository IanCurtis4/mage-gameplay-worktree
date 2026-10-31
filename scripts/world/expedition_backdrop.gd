extends CanvasLayer
## Checkpoint38/39: themed parallax backdrop behind the expedition world, painted
## with the map art (ground tiles and props). Presentation only (a CanvasLayer, so
## snapshots skip it); the stage biome picks the theme. The ground and its far
## props move with one parallax factor, a sparser near layer moves faster, and a
## haze tints everything toward the theme so the map reads in front.
const LAYER_ORDER := -100
const ART := "res://assets/art/map_authoring/"
const PROPS := {
	"oak": {"path":ART+"props/oak_tree.png","pivot":Vector2(0.53,0.94)},
	"shrub": {"path":ART+"props/woodland_shrub.png","pivot":Vector2(0.5,0.92)},
	"boulder": {"path":ART+"props/moss_boulder.png","pivot":Vector2(0.5,0.88)},
	"pillar": {"path":ART+"props/broken_pillar.png","pivot":Vector2(0.5,0.95)},
	"cactus": {"path":ART+"props/desert_cactus.png","pivot":Vector2(0.5,0.96)},
	"sandstone": {"path":ART+"props/sandstone_boulder.png","pivot":Vector2(0.5,0.85)},
}
# ground: tile texture, tile size on screen, tint. layers: cell spacing, row
# squash, fill chance, prop weights and scales, tint, parallax factor.
const THEMES := {
	"forest": {"ground":{"path":ART+"grass_tile.png","tile":300.0,"tint":Color(0.36,0.48,0.36)},"factor":0.38,
		"layers":[
			{"name":"far","factor":0.38,"cell":110.0,"rows":0.55,"fill":0.92,"tint":Color(0.42,0.54,0.46),"props":[["oak",5,0.13],["shrub",2,0.09],["boulder",1,0.06]]},
			{"name":"near","factor":0.58,"cell":210.0,"rows":0.6,"fill":0.45,"tint":Color(0.62,0.72,0.62),"props":[["oak",4,0.18],["shrub",2,0.12]]}],
		"haze":Color(0.42,0.6,0.52,0.20),"shade":Color(0.02,0.06,0.05,0.55)},
	"ruin": {"ground":{"path":ART+"earth_tile.png","tile":300.0,"tint":Color(0.42,0.38,0.42)},"factor":0.38,
		"layers":[
			{"name":"far","factor":0.38,"cell":120.0,"rows":0.5,"fill":0.7,"tint":Color(0.5,0.46,0.54),"props":[["pillar",3,0.09],["boulder",3,0.07],["shrub",2,0.07],["oak",1,0.11]]},
			{"name":"near","factor":0.58,"cell":240.0,"rows":0.6,"fill":0.4,"tint":Color(0.66,0.62,0.68),"props":[["pillar",3,0.13],["boulder",2,0.09]]}],
		"haze":Color(0.55,0.42,0.55,0.20),"shade":Color(0.05,0.03,0.06,0.55)},
	"desert": {"ground":{"path":ART+"sand_tile.png","tile":320.0,"tint":Color(0.78,0.66,0.52)},"factor":0.38,
		"layers":[
			{"name":"far","factor":0.38,"cell":140.0,"rows":0.5,"fill":0.45,"tint":Color(0.78,0.68,0.58),"props":[["sandstone",3,0.07],["cactus",2,0.08]]},
			{"name":"near","factor":0.58,"cell":260.0,"rows":0.6,"fill":0.3,"tint":Color(0.86,0.78,0.68),"props":[["cactus",2,0.12],["sandstone",3,0.1]]}],
		"haze":Color(0.95,0.78,0.55,0.16),"shade":Color(0.12,0.07,0.03,0.45)},
	"meadow": {"ground":{"path":ART+"grass_tile.png","tile":300.0,"tint":Color(0.6,0.74,0.56)},"factor":0.38,
		"layers":[
			{"name":"far","factor":0.38,"cell":120.0,"rows":0.5,"fill":0.55,"tint":Color(0.66,0.78,0.66),"props":[["shrub",4,0.09],["oak",2,0.12],["boulder",1,0.06]]},
			{"name":"near","factor":0.58,"cell":260.0,"rows":0.6,"fill":0.3,"tint":Color(0.8,0.88,0.78),"props":[["shrub",3,0.13],["oak",1,0.17]]}],
		"haze":Color(0.75,0.88,0.92,0.16),"shade":Color(0.03,0.06,0.05,0.4)},
}
var biome := ""
var _ground: Node2D
var _haze: Node2D
var _layers: Array[Node2D] = []
var _textures := {}
var _last_center := Vector2.INF
var _last_size := Vector2.ZERO
var _last_zoom := Vector2.ZERO

static func theme_id(value: String) -> String:
	return value if THEMES.has(value) else "ruin"

func _init() -> void:
	name = "ExpeditionBackdrop"
	layer = LAYER_ORDER

func configure(value: String) -> void:
	var id := theme_id(value)
	if id == biome and _ground != null: return
	biome = id
	for child: Node in get_children(): child.queue_free()
	_layers.clear(); _textures.clear()
	var theme: Dictionary = THEMES[id]
	_texture(theme["ground"]["path"])
	for spec: Dictionary in theme["layers"]:
		for prop: Array in spec["props"]: _texture(PROPS[prop[0]]["path"])
	_ground = _canvas("Ground"); _ground.set_meta("scroll",Vector2.ZERO)
	_ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground.draw.connect(_draw_ground.bind(_ground,theme))
	for spec: Dictionary in theme["layers"]:
		var band := _canvas("Layer_%s" % spec["name"])
		band.set_meta("spec",spec); band.set_meta("scroll",Vector2.ZERO)
		band.draw.connect(_draw_props.bind(band))
		_layers.append(band)
	_haze = _canvas("Haze")
	_haze.draw.connect(_draw_haze.bind(_haze,theme))
	_last_center = Vector2.INF

func _canvas(node_name: String) -> Node2D:
	var canvas := Node2D.new(); canvas.name = node_name
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(canvas)
	return canvas

func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[path]

func _process(_delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null: return
	var camera := viewport.get_camera_2d()
	var center := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var size := viewport.get_visible_rect().size
	if center == _last_center and size == _last_size and zoom == _last_zoom: return
	_last_center = center; _last_size = size; _last_zoom = zoom
	var theme: Dictionary = THEMES[biome] if THEMES.has(biome) else THEMES["ruin"]
	if _ground != null:
		_ground.set_meta("scroll",center*float(theme["factor"])); _ground.set_meta("zoom",_depth_zoom(zoom.x,float(theme["factor"])))
		_ground.queue_redraw()
	for band: Node2D in _layers:
		var spec: Dictionary = band.get_meta("spec")
		band.set_meta("scroll",center*float(spec["factor"])); band.set_meta("zoom",_depth_zoom(zoom.x,float(spec["factor"])))
		band.queue_redraw()
	if _haze != null: _haze.queue_redraw()

# A far plane follows the camera zoom only partly.
static func _depth_zoom(zoom: float, factor: float) -> float:
	return clampf(lerpf(1.0,zoom,factor),0.25,4.0)

# Zoom about the screen center; returns the visible rect in layer-local pixels.
static func _zoom_frame(canvas: Node2D, size: Vector2, k: float) -> Rect2:
	canvas.draw_set_transform(size*0.5*(1.0-k),0.0,Vector2(k,k))
	return Rect2(size*0.5-size*0.5/k,size/k)

func _draw_ground(canvas: Node2D, theme: Dictionary) -> void:
	var size := canvas.get_viewport_rect().size
	var ground: Dictionary = theme["ground"]
	var tex := _texture(ground["path"])
	if tex == null:
		canvas.draw_rect(Rect2(Vector2.ZERO,size),ground["tint"]); return
	var k := float(canvas.get_meta("zoom",1.0)); var scroll: Vector2 = canvas.get_meta("scroll",Vector2.ZERO)
	var tile := float(ground["tile"]); var s := tile/float(tex.get_width())
	canvas.draw_set_transform(size*0.5*(1.0-k),0.0,Vector2(k,k))
	var view := Rect2(size*0.5-size*0.5/k,size/k)
	var origin := view.position-Vector2(fposmod(view.position.x+scroll.x,tile),fposmod(view.position.y+scroll.y,tile))
	canvas.draw_set_transform(size*0.5*(1.0-k)+origin*k,0.0,Vector2(k*s,k*s))
	canvas.draw_texture_rect(tex,Rect2(Vector2.ZERO,(view.size+Vector2(tile,tile)*2.0)/s),true,ground["tint"])
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

# Deterministic 0..1 value per cell and salt.
static func _hash(i: int, j: int, layer_salt: int, salt: int) -> float:
	var h := (i*73856093) ^ (j*19349663) ^ (layer_salt*83492791) ^ (salt*2654435761)
	h = ((h ^ (h >> 13))*1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF)/16777216.0

static func _pick(props: Array, roll: float) -> Array:
	var total := 0.0
	for prop: Array in props: total += float(prop[1])
	var at := roll*total
	for prop: Array in props:
		at -= float(prop[1])
		if at < 0.0: return prop
	return props[-1]

func _draw_props(band: Node2D) -> void:
	var spec: Dictionary = band.get_meta("spec"); var scroll: Vector2 = band.get_meta("scroll",Vector2.ZERO)
	var size := band.get_viewport_rect().size
	var k := float(band.get_meta("zoom",1.0))
	var view := _zoom_frame(band,size,k)
	var cell := float(spec["cell"]); var row := cell*float(spec["rows"])
	var salt := String(spec["name"]).hash() & 0xFFFF
	var tallest := 0.0
	for prop: Array in spec["props"]:
		var tex := _texture(PROPS[prop[0]]["path"])
		if tex != null: tallest = maxf(tallest,tex.get_height()*float(prop[2])*1.2)
	var left := view.position.x+scroll.x; var top := view.position.y+scroll.y
	var i0 := int(floorf((left-cell)/cell)); var i1 := int(ceilf((left+view.size.x+cell)/cell))
	var j0 := int(floorf((top-row)/row)); var j1 := int(ceilf((top+view.size.y+tallest+row)/row))
	for j: int in range(j0,j1+1):
		for i: int in range(i0,i1+1):
			if _hash(i,j,salt,1) >= float(spec["fill"]): continue
			var prop := _pick(spec["props"],_hash(i,j,salt,2))
			var info: Dictionary = PROPS[prop[0]]
			var tex := _texture(info["path"])
			if tex == null: continue
			var sprite_scale := float(prop[2])*(0.82+0.36*_hash(i,j,salt,3))
			var draw_size := Vector2(tex.get_width(),tex.get_height())*sprite_scale
			var base := Vector2((float(i)+0.5*float(j & 1)+0.6*(_hash(i,j,salt,4)-0.5))*cell,(float(j)+0.5*(_hash(i,j,salt,5)-0.5))*row)-scroll
			var pivot: Vector2 = info["pivot"]
			var shade := 0.85+0.15*_hash(i,j,salt,6)
			var tint: Color = spec["tint"]
			band.draw_texture_rect(tex,Rect2(base-draw_size*pivot,draw_size),false,Color(tint.r*shade,tint.g*shade,tint.b*shade,1.0))
	band.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_haze(canvas: Node2D, theme: Dictionary) -> void:
	var size := canvas.get_viewport_rect().size
	var haze: Color = theme["haze"]; var shade: Color = theme["shade"]
	canvas.draw_rect(Rect2(Vector2.ZERO,size),haze)
	# Darker toward the screen edges so the lit map stands in front.
	var clear := Color(shade,0.0); var band := minf(size.x,size.y)*0.28
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size.x,band),Vector2(0,band)]),PackedColorArray([shade,shade,clear,clear]))
	canvas.draw_polygon(PackedVector2Array([Vector2(0,size.y-band),Vector2(size.x,size.y-band),size,Vector2(0,size.y)]),PackedColorArray([clear,clear,shade,shade]))
	canvas.draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(band,0),Vector2(band,size.y),Vector2(0,size.y)]),PackedColorArray([shade,clear,clear,shade]))
	canvas.draw_polygon(PackedVector2Array([Vector2(size.x-band,0),Vector2(size.x,0),size,Vector2(size.x-band,size.y)]),PackedColorArray([clear,shade,shade,clear]))
