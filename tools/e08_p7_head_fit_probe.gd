extends "res://tools/e08_directional_unit_probe.gd"
## E08 P7-C6 native evidence: the real CharacterAnimation/EquipmentHeadVisual renderer, windowed,
## on grass. Per class with its class head piece: 4 directions x (idle, walk mid, action, hurt, corpse).
## Args: <folder> <before|after> [zoom]. "before" switches the C6 crown-seat fit off (legacy anchor).
## zoom 160 (default) is the in-game camera zoom; 260 is an enlarged reading sheet.
const CLASS_PIECE := {&"swordsman":&"class_set_swordsman_head",&"mage":&"class_set_mage_head",&"archer":&"class_set_archer_head",&"defender":&"class_set_defender_head",&"berserker":&"class_set_berserker_head",&"elementalist":&"class_set_elementalist_head",&"spiritualist":&"class_set_spiritualist_head",&"sentinel":&"class_set_sentinel_head",&"hunter":&"class_set_hunter_head",&"geometer":&"class_set_mg_ar_head"}
const POSES: Array[int] = [0,5,9,12,15]
func grass() -> void:
	var bg := Polygon2D.new();bg.color=Color("5d8a3c");bg.polygon=PackedVector2Array([Vector2(0,0),Vector2(1280,0),Vector2(1280,720),Vector2(0,720)]);page.add_child(bg)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	folder=args[0];DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,720)
	var variant: String = args[1] if args.size()>1 else "after"
	var zoom := float(args[2])/100.0 if args.size()>2 else 1.6
	var big := zoom>2.0
	var tag := variant+("_z"+args[2] if args.size()>2 else "")
	EquipmentHeadVisual.fit_enabled=variant!="before"
	require_default=true
	for kind: StringName in CLASS_PIECE:
		unit_kind=kind;manifest=F.stage_path(kind)
		clear_page(String(kind)+" · "+String(CLASS_PIECE[kind])+" · "+tag)
		grass()
		for direction: int in 4:
			for column: int in POSES.size():
				var visual := {"head":CLASS_PIECE[kind],"main_hand":&"bow" if kind==&"archer" else &"staff"}
				actor(direction,POSES[column],visual,Vector2((130 if big else 120)+column*(240 if big else 130),(150 if big else 110)+direction*(180 if big else 160)),zoom)
		await shot(tag+"_"+String(kind))
	# every head piece on every class (idle, four directions): the any-piece-any-class guarantee
	for id: StringName in EquipmentArtCatalog.head_ids():
		clear_page("todas as classes · "+String(id)+" · "+tag)
		grass()
		var column := 0
		for kind: StringName in CLASS_PIECE:
			unit_kind=kind;manifest=F.stage_path(kind)
			for direction: int in 4:
				actor(direction,0,{"head":id},Vector2(60+column*120,110+direction*160),1.8)
			column+=1
		await shot(tag+"_piece_"+String(id))
	print("HEAD_FIT_PROBE ",JSON.stringify({"variant":variant,"checks":checks,"failures":failures}))
	quit(1 if failures>0 else 0)
