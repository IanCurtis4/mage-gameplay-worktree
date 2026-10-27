@tool
extends RefCounted
## Shared presentation projection. No actor, camera state, or gameplay authority.
const AXIS := Vector2(0.85,0.425)
static func project(point: Vector3) -> Vector2:
	return Vector2((point.x-point.z)*AXIS.x,(point.x+point.z)*AXIS.y-point.y)
static func ray(canvas_point: Vector2) -> Dictionary:
	var x := (canvas_point.x/AXIS.x+canvas_point.y/AXIS.y)*0.5
	var z := (canvas_point.y/AXIS.y-canvas_point.x/AXIS.x)*0.5
	var height := 10000.0
	return {"origin":Vector3(x+height/(2*AXIS.y),height,z+height/(2*AXIS.y)),"direction":Vector3(-1/(2*AXIS.y),-1,-1/(2*AXIS.y))}
