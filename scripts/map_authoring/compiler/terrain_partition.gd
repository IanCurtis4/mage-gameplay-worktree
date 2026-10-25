@tool
extends RefCounted
## Exact coplanar rectangular regions generated from height samples, never authored tiles.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const EPS := 0.00001

static func point(layer: Dictionary, x: int, z: int) -> Vector3:
	return Vector3(float(layer.origin_xz[0])+x*float(layer.sample_spacing),float(layer.heights[z*int(layer.columns)+x]),float(layer.origin_xz[1])+z*float(layer.sample_spacing))

static func build(layer: Dictionary, cancellation: Callable = Callable()) -> Array:
	var columns: int = int(layer.columns)-1; var rows: int = int(layer.rows)-1
	var used := PackedByteArray(); used.resize(columns*rows)
	var patches: Array = []
	for z: int in rows:
		if cancellation.is_valid() and cancellation.call(): return []
		for x: int in columns:
			if used[z*columns+x]: continue
			var a := point(layer,x,z); var b := point(layer,x+1,z); var c := point(layer,x+1,z+1); var d := point(layer,x,z+1)
			var normal := (b-a).cross(c-a).normalized()
			if absf((d-a).dot(normal)) > EPS:
				used[z*columns+x] = 1
				patches.append({"x":x,"z":z,"width":1,"height":1,"triangles":true})
				if patches.size() > 1024: return patches
				continue
			var width := 1
			while x+width < columns and not used[z*columns+x+width] and _quad_on_plane(layer,x+width,z,a,normal): width += 1
			var height := 1
			while z+height < rows:
				var legal := true
				for dx: int in width:
					if used[(z+height)*columns+x+dx] or not _quad_on_plane(layer,x+dx,z+height,a,normal): legal = false; break
				if not legal: break
				height += 1
			for dz: int in height:
				for dx: int in width: used[(z+dz)*columns+x+dx] = 1
			patches.append({"x":x,"z":z,"width":width,"height":height,"triangles":false})
			if patches.size() > 1024: return patches
	return patches

static func _quad_on_plane(layer: Dictionary, x: int, z: int, anchor: Vector3, normal: Vector3) -> bool:
	for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
		if absf((point(layer,x+offset.x,z+offset.y)-anchor).dot(normal)) > EPS: return false
	return true
