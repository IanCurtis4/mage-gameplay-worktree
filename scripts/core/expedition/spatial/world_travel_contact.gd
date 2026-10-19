class_name WorldTravelContact
extends RefCounted
## Queries actual supported motion segments; never a chord between projected endpoints.
static func first(world: WorldGeometry, segments: Array, body: Dictionary, actors: Array[CombatActor], preserve_actor_order: bool = false) -> Dictionary:
	var chosen: Dictionary = {}
	var nearest := INF
	for actor: CombatActor in actors:
		if not is_instance_valid(actor) or not actor.is_alive() or actor.is_queued_for_deletion() or actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != world: continue
		var travelled := 0.0
		for segment: Dictionary in segments:
			var from: Vector3 = segment["from"]["position"]
			var to: Vector3 = segment["to"]["position"]
			var length := from.distance_to(to)
			var fraction := WorldProjectileMotion.cylinder_fraction(from,to,actor.world_point().position,float(body["radius"])+float(actor.world_motion.profile()["radius"]),float(actor.world_motion.profile()["height"]),float(body["height"]))
			if fraction >= 0.0:
				var source := ExpeditionWorldPoint.create(segment["from"]["stage_id"],segment["from"]["surface_id"],from.lerp(to,fraction))
				var sight := world.query_attack({"geometry_rule_id":&"direct_volume","range":1.0e20,"source_offset":Vector3.UP*float(body["height"])*0.5,"target_offset":Vector3.UP*float(actor.world_motion.profile()["height"])*0.5},source,actor.world_point(),world.geometry_revision)
				var distance := travelled+length*fraction
				if sight["ok"] and sight["data"]["hit"] and (distance < nearest or (is_equal_approx(distance,nearest) and (chosen.is_empty() or actor.get_instance_id() < (chosen["actor"] as CombatActor).get_instance_id()))):
					chosen = {"actor":actor,"point":source,"distance":distance}
					nearest = distance
					if preserve_actor_order: return chosen
			travelled += length
	return chosen
