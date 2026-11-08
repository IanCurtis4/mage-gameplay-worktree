extends SceneTree
## Mechanical composition only: real equipment renderer layers + original body.
## Never paints/removes anatomy, changes palms, or clips overflowing equipment.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const SOURCE := "res://assets/art/e08_characters/directional/archer/presentation.json"
class NoNockAnimation extends CharacterAnimation:
	func render_descriptor() -> Dictionary:
		var descriptor := super.render_descriptor()
		descriptor.arrow_visible=false
		return descriptor
class Layer extends Node2D:
	var animation: CharacterAnimation
	var mode := 0
	var composed_texture: Texture2D
	func _draw() -> void:
		if mode==3:
			var descriptor := animation.render_descriptor()
			draw_texture_rect(composed_texture,descriptor.rect,false);return
		if mode==2:animation.draw_on(self);return
		EquipmentAttachmentVisual.draw_resolved(self,animation.render_descriptor(),Color.WHITE,1.0,mode)
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func straight_alpha(image: Image) -> Image:
	# Viewport readback is premultiplied. Undo only the generated equipment layer
	# before blending with the untouched straight-alpha source body.
	var result := image.duplicate() as Image
	for y: int in result.get_height():
		for x: int in result.get_width():
			var color := result.get_pixel(x,y)
			if color.a>0 and color.a<1:
				color.r=minf(1,color.r/color.a);color.g=minf(1,color.g/color.a);color.b=minf(1,color.b/color.a)
				result.set_pixel(x,y,color)
	return result
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder := OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(folder)
	if OS.get_cmdline_user_args().has("inspect"):
		var path := "res://assets/art/e08_characters/directional/archer/npc_body.png"
		var source := Image.load_from_file(path);source.convert(Image.FORMAT_RGBA8)
		var imported := (load(path) as Texture2D).get_image();imported.convert(Image.FORMAT_RGBA8)
		var differences: Array[Dictionary]=[]
		for y: int in 1024:
			for x: int in 256:
				var a := source.get_pixel(x,y);var b := imported.get_pixel(x,y)
				if (a.a>0 or b.a>0) and a!=b and differences.size()<32:differences.append({"x":x,"y":y,"source":str(a),"imported":str(b)})
		imported.save_png(folder.path_join("imported.png"))
		var file := FileAccess.open(folder.path_join("inspection.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"source_format":source.get_format(),"imported_format":imported.get_format(),"differences":differences},"  ",true));file.close()
		print(JSON.stringify(differences));quit();return
	var animation := NoNockAnimation.new();animation.configure(&"archer")
	check(animation.set_directional_manifest(SOURCE).ok,"complete source")
	animation.set_equipment_visual({"main_hand":&"bow"})
	var original := animation.atlas.get_image()
	var viewport := SubViewport.new();viewport.size=Vector2i(128,128);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var layer := Layer.new();layer.animation=animation;layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(layer)
	var below_atlas := Image.create(256,1024,false,Image.FORMAT_RGBA8)
	var above_atlas := Image.create(256,1024,false,Image.FORMAT_RGBA8)
	var result := Image.create(256,1024,false,Image.FORMAT_RGBA8)
	var records: Array[Dictionary]=[]
	CharacterAnimation._draw_geometry.clear();CharacterAnimation._draw_geometry_order.clear()
	for index: int in 64:
		animation.state=D.state(index/16,index%16)
		var descriptor := animation.render_descriptor()
		layer.position=Vector2(64,32-descriptor.origin.y)
		var images: Array[Image]=[]
		for mode: int in 3:
			layer.mode=mode;layer.queue_redraw()
			await process_frame;await process_frame;await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
		var crop := Rect2i(32,32,64,64)
		var overflow := false
		for mode: int in 2:
			var image := images[mode]
			for y: int in 128:
				for x: int in 128:
					if not crop.has_point(Vector2i(x,y)) and image.get_pixel(x,y).a>0:overflow=true
		check(not overflow,"no bow clipping frame="+str(index))
		var at := Vector2i(index%4*64,index/4*64)
		var before := original.get_region(Rect2i(at,Vector2i(64,64)))
		var below := straight_alpha(images[0].get_region(crop));var above := straight_alpha(images[1].get_region(crop))
		var composed := below.duplicate() as Image
		composed.blend_rect(before,Rect2i(0,0,64,64),Vector2i.ZERO)
		composed.blend_rect(above,Rect2i(0,0,64,64),Vector2i.ZERO)
		# Same final anatomical fingers as the real common renderer.
		var fingers: Array=DirectionalAnimationSet.for_texture(animation.atlas).frame(index).slots.main_hand.fingers
		var finger := Rect2i(fingers[0],fingers[1],fingers[2],fingers[3])
		if not descriptor.dead:composed.blend_rect(before,finger,finger.position)
		var bounds := composed.get_used_rect()
		var gutter := bounds.position.x>0 and bounds.end.x<64 and bounds.position.y>0 and bounds.end.y<64
		check(gutter,"strict1px original cell gutter frame="+str(index))
		var ground_same := bounds.end.y==before.get_used_rect().end.y
		check(ground_same,"exact original ground frame="+str(index))
		var protected := true;var max_difference := 0.0
		var reference := images[2].get_region(crop)
		for y: int in 64:
			for x: int in 64:
				var point := Vector2i(x,y);var a := before.get_pixelv(point);var b := composed.get_pixelv(point)
				if below.get_pixelv(point).a==0 and above.get_pixelv(point).a==0 and a!=b and not (a.a==0 and b.a==0):protected=false
				var native := reference.get_pixelv(point)
				max_difference=maxf(max_difference,maxf(absf(native.a-b.a),maxf(absf(native.r-b.r),maxf(absf(native.g-b.g),absf(native.b-b.b)))))
		check(protected,"body byte-identical outside painted bow support frame="+str(index))
		below_atlas.blit_rect(below,Rect2i(0,0,64,64),at);above_atlas.blit_rect(above,Rect2i(0,0,64,64),at)
		result.blit_rect(composed,Rect2i(0,0,64,64),at)
		images[2].save_png(folder.path_join("reference_%02d.png" % index))
		layer.composed_texture=ImageTexture.create_from_image(composed);layer.mode=3;layer.queue_redraw()
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image();rendered.save_png(folder.path_join("composed_%02d.png" % index))
		var native_difference := 0.0
		for y: int in 128:
			for x: int in 128:
				var a := images[2].get_pixel(x,y);var b := rendered.get_pixel(x,y)
				native_difference=maxf(native_difference,maxf(absf(a.a-b.a),maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))))
		check(native_difference<=3.0/255.0+0.00001,"native composition pixel agreement within rounding frame="+str(index))
		records.append({"index":index,"overflow":overflow,"ground_same":ground_same,"gutter":gutter,"body_protected":protected,"raw_source_vs_premultiplied_reference_difference":max_difference,"rendered_rgba_difference":native_difference})
	below_atlas.save_png(folder.path_join("below.png"));above_atlas.save_png(folder.path_join("above.png"))
	result.save_png(folder.path_join("npc_body.png"))
	var file := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"frames":records,"scope":"mechanical renderer layers, no nock arrow; unarmed player pixels preserved outside bow support; no overflow allowed"},"  ",true));file.close()
	print("NPC Archer composition: ",64," frames, ",failures," failures")
	quit(1 if failures else 0)
