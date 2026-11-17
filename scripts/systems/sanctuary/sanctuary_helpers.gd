class_name SanctuaryHelpers
extends RefCounted
## E09 T5 (C2) — stateless helpers: Juízo (vertical light column), light damage (A2),
## event descriptors for SanctuaryGrace.gain and the enemy list of the owner.
## No damage formula here: amounts come from the owner's stat_breakdown and the
## defenses are applied by CombatMath.resolve inside HealthState.

## A2: light damage is magic damage of a skill whose SkillDefinition.element is light.
## There is no resistance axis; no enemy resists or is weak to light.
static func is_light_skill(skill_id: StringName) -> bool:
	var definition := ClassKitRegistry.skill_definition(skill_id)
	if definition == null: definition = ClassCatalog.skill_definition(skill_id)
	return definition != null and definition.element == SanctuaryRules.LIGHT_ELEMENT

## A confirmed damage result counts as light damage.
static func is_light_result(result: Dictionary) -> bool:
	return float(result.get("actual_damage", 0.0)) + float(result.get("absorbed_damage", 0.0)) > 0.0 and is_light_skill(StringName(result.get("skill_id", &"")))

## Grace event of a damage or hit result: the ledger identity of that application.
static func result_event(result: Dictionary) -> Dictionary:
	return {"context": result.get("context"), "target_id": int(result.get("target_id", 0)), "key": "result:%d:%d:%d" % [int(result.get("source_id", 0)), int(result.get("target_id", 0)), int(result.get("application_sequence", 0))]}

## Grace event of a cast (no causal context): one per skill and commit instant.
static func cast_event(cast: Dictionary, kit_time: float) -> Dictionary:
	return {"key": "cast:%s@%.5f" % [String(cast.get("skill_id", &"")), kit_time]}

## Juízo amount before defenses: base * (1 + per_charge * charges).
static func judgment_amount(base_amount: float, charges: int, per_charge: float = SanctuaryRules.JUDGMENT_PER_CHARGE) -> float:
	if not is_finite(base_amount) or base_amount <= 0.0 or charges < 0 or not is_finite(per_charge) or per_charge < 0.0: return 0.0
	return base_amount * (1.0 + per_charge * float(charges))

## Juízo request (magic, light skill) for one victim, through the shared factory.
static func judgment_request(owner: PlayerActor, victim: CombatActor, skill_id: StringName, base_amount: float, charges: int, per_charge: float = SanctuaryRules.JUDGMENT_PER_CHARGE, can_crit: bool = true) -> DamageRequest:
	var amount := judgment_amount(base_amount, charges, per_charge)
	if amount <= 0.0 or not is_instance_valid(owner) or not is_instance_valid(victim): return null
	return owner.kit_make_request(victim, skill_id, 0.0, amount, DamageRequest.AccuracyMode.GEOMETRY, can_crit)

## Enemies hit by a vertical column at `point` (world: x/z distance and height band;
## flat arena: distance). A zone, when given, replaces the column: every enemy inside.
static func judgment_targets(owner: PlayerActor, actors: Array, point: Variant, column_radius: float = SanctuaryRules.JUDGMENT_COLUMN_RADIUS, zone: SanctuaryZone = null) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	if not is_instance_valid(owner): return result
	var radius := clampf(column_radius, SanctuaryRules.JUDGMENT_COLUMN_RADIUS_RANGE.x, SanctuaryRules.JUDGMENT_COLUMN_RADIUS_RANGE.y)
	for candidate: Variant in actors:
		var actor := candidate as CombatActor
		if not is_instance_valid(actor) or not actor.is_alive() or actor == owner: continue
		if zone != null:
			if zone.contains(owner, actor): result.append(actor)
			continue
		if point is ExpeditionWorldPoint:
			var anchor: ExpeditionWorldPoint = point
			var at := actor.world_point()
			if at == null or at.stage_id != anchor.stage_id: continue
			var offset := at.position - anchor.position
			var reach := radius + (float(actor.world_motion.profile()["radius"]) if actor.world_motion != null else actor.collision_radius)
			if Vector2(offset.x, offset.z).length() <= reach and absf(offset.y) <= SanctuaryRules.JUDGMENT_COLUMN_HALF_HEIGHT: result.append(actor)
		elif point is Vector2:
			if actor.global_position.distance_to(point) <= radius + actor.collision_radius: result.append(actor)
	return result

## Living enemies of the owner's run (RunController.enemies), or `fallback`.
static func enemies_of(owner: PlayerActor, fallback: Array = []) -> Array:
	if not fallback.is_empty() or not is_instance_valid(owner): return fallback
	var parent := owner.get_parent()
	if parent == null: return []
	var listed: Variant = parent.get(&"enemies")
	return listed if listed is Array else []
