class_name ClassKit
extends RefCounted
## E09 C1 — class kit seam. API: docs/epics/e09/t1_kit_seam_api.md.
##
## One script per kit (`scripts/classes/<id>/<id>_kit.gd`) plays two roles:
## - catalog module: the registry keeps one instance and only calls the pure data
##   methods below (skills, learning, effects, recipes, texts, effect drawers);
## - per-character kit object: PlayerActor creates its own instance with
##   `create_runtime()` and calls the hooks. Its script variables are run state,
##   persisted through the folder's `snapshot_manifest.json`.
## Data methods must not read or write instance state. Hooks receive the player and
## never cache it (no Node references in kit fields; entity IDs use the
## SnapshotIdentityRoles names, such as `victim_id` or `owner_id`).

## Evolution this kit object belongs to. Set by PlayerActor.attach_kit().
var evolution_id: StringName = &""

# --- Catalog data (pure; overridden by each module) -------------------------------

## Evolution ID served by the module. Must equal its key in ClassKitRegistry.
func kit_id() -> StringName:
	return &""

## False keeps the evolution out of ProfileCatalog (C1.3). Fixtures may force it.
func ready_for_play() -> bool:
	return false

## Visible pt-BR identity name.
func display_name() -> String:
	return ""

## Immutable SkillDefinitions with ranks; handler_id must be SkillDefinition.Handler.KIT.
func skill_definitions() -> Array[SkillDefinition]:
	return []

## Learning rows. Each: {"skill_id", "category" (ProfileCatalog.ACTIVE/PASSIVE),
## "free_rank" (1 only for the job-20 entry), "max_purchased_rank", "job_level",
## "prerequisites" ({skill_id: rank}, optional)}.
func learning_entries() -> Array[Dictionary]:
	return []

## Stat modifier source of a learned passive, same shape as ClassCatalog.passive_modifier_source.
func passive_modifier_source(_skill_id: StringName, _rank: int) -> Dictionary:
	return {}

## Causal families the kit claims through EffectProcLedger. They join every root
## plan of the player and count as intrinsic for BuildEffectCatalog (items cannot
## reuse them as PROC families). Must start with the kit skill prefix.
func causal_families() -> Array[StringName]:
	return []

## FeedbackRecipeCatalog rows: skill_id -> [family, element, signature, flags].
func feedback_recipes() -> Dictionary:
	return {}

## Basic-attack feedback row for this evolution; empty keeps the origin row.
func basic_attack_recipe() -> Array:
	return []

## SkillCopy/SkillPresentation texts: skill_id -> {"flavor", "effect", "combo", "mechanics"}.
func skill_texts() -> Dictionary:
	return {}

## Code-drawn effects: effect_id -> {"skill_id", "kinds" (bridge kinds), "size" (px)}.
## effect_id is `<prefix><effect>`; a flipbook with the same ID replaces the drawing.
func vfx_effects() -> Dictionary:
	return {}

## Draws one frame of a code effect on the feedback canvas. Presentation only.
func draw_vfx(_effect_id: StringName, _canvas: CanvasItem, _pulse: Dictionary, _position: Vector2, _t: float) -> bool:
	return false

## Element of a cast; default is SkillDefinition.element (ClassKitRegistry.KIT_ELEMENTS).
func skill_element(skill_id: StringName) -> StringName:
	var definition := ClassKitRegistry.skill_definition(skill_id)
	return definition.element if definition != null else &""

## New per-character kit object. Modules with extra state override nothing: the
## same script is instantiated, so its variables are the run state.
func create_runtime() -> ClassKit:
	var runtime: ClassKit = (get_script() as Script).new()
	runtime.evolution_id = kit_id()
	return runtime

# --- Per-character hooks (called by PlayerActor/RunController) ---------------------

## Once, when the kit object is attached during PlayerActor.configure(). Not on restore.
func on_attach(_player: PlayerActor) -> void:
	pass

## Gameplay tick. Never called while the tree is paused or the player is dead.
func on_tick(_player: PlayerActor, _delta: float) -> void:
	pass

## Pure check repeated at preview, request, every preparation frame and commit.
## Return {"ok": false, "error_code": &"..."} to refuse; must not change state.
func can_cast(_player: PlayerActor, _cast: Dictionary) -> Dictionary:
	return {"ok": true, "error_code": &""}

## Once per accepted request (before any preparation time). May record intent.
func on_cast_requested(_player: PlayerActor, _cast: Dictionary) -> void:
	pass

## After the canonical payment (SP and cooldown committed), before resolution.
func on_cast_confirmed(_player: PlayerActor, _cast: Dictionary) -> void:
	pass

## Effective SP cost of any skill of the player, kit or origin (T1.2). Receives the
## base cost (rank and item modifiers applied); the player floors the answer at 0 and
## ignores non-finite values. Pure read of kit state: it runs at preview, request,
## payment check, debit and in the UI.
func skill_cost(_player: PlayerActor, _skill_id: StringName, base_cost: float) -> float:
	return base_cost

## Once per paid commit of a skill the kit does not own (T1.2), flat or world, with
## slash, dash and teleport included; same instant as on_cast_confirmed (after the
## payment, before the resolution). Never for refused casts, reservations or retries;
## the basic attack is excluded. context: "target" (CombatActor or null), "point"
## (Vector2), "world" (bool), "rank" (int), "element" (StringName, empty if none).
## Must not cast or spend.
func on_base_skill_committed(_player: PlayerActor, _skill_id: StringName, _context: Dictionary) -> void:
	pass

## Executes the skill. Return false only if nothing happened (payment stays spent).
func resolve_cast(_player: PlayerActor, _cast: Dictionary) -> bool:
	return false

## Basic-attack replacement (E00 explicit intrinsic). {} keeps the origin attack.
## Keys: "range" (float, reach beyond bodies), "delivery" (&"direct", &"mage" or &"precision").
func basic_attack_profile(_player: PlayerActor) -> Dictionary:
	return {}

## Composes the basic-attack request. Receive the origin request; return it,
## a modified copy, or a new request made with PlayerActor.kit_make_request().
func compose_basic_attack(_player: PlayerActor, _target: CombatActor, request: DamageRequest) -> DamageRequest:
	return request

## Incoming-hit step 1, before mitigation. Return {"cancel": true, "reason": &"..."}
## to cancel the whole hit (no damage, no mitigation, no later steps). Optional
## "damage_multiplier" (float >= 0, finite; T1.1) scales damage_dealt_multiplier on a
## copy of the request before mitigation; cancel wins over it, and invalid values are ignored.
func before_hit_mitigation(_player: PlayerActor, _hit: Dictionary) -> Dictionary:
	return {}

## Incoming-hit step 2, after mitigation. hit["frontal"] tells whether the source
## was in front of the player's gameplay facing.
func after_hit_mitigation(_player: PlayerActor, _hit: Dictionary, _result: Dictionary) -> void:
	pass

## Incoming-hit step 3: this hit took the last point of the player's shield.
func on_shield_broken(_player: PlayerActor, _hit: Dictionary, _result: Dictionary) -> void:
	pass

## E10a T15 (A15.3): barrier received. Every barrier the player gains through
## CombatActor.grant_barrier (Escudo Votivo, Égide and any later producer) calls this hook
## before HealthState.grant_shield, chained origin then evolution: each module receives the
## capacity so far and returns the new one. A non-finite or negative answer keeps the previous
## value; 0 refuses the grant. context: "source" (StringName, the skill or system that grants;
## empty if unknown), "raw_capacity" (float, before any module). Pure: must not grant barriers,
## heal, cast or spend (no re-entry guard, like skill_cost).
func barrier_received(_player: PlayerActor, capacity: float, _context: Dictionary) -> float:
	return capacity

## Heal through PlayerActor.heal_player() or a base heal: requested vs applied.
func on_heal(_player: PlayerActor, _requested: float, _applied: float, _source: StringName) -> void:
	pass

## Player damage confirmed on an enemy, after the claim of the result.
func on_damage_dealt(_player: PlayerActor, _result: Dictionary) -> void:
	pass

## Confirmed kill credited once per victim, after the claim.
func on_kill_confirmed(_player: PlayerActor, _result: Dictionary) -> void:
	pass

## Player death (before the death recovery of an expedition).
func on_death(_player: PlayerActor) -> void:
	pass

## Player alive again after a death (portal return or revive).
func on_return(_player: PlayerActor) -> void:
	pass

## Build or learning changed in the run. No implicit heal, recharge or reset.
func on_build_changed(_player: PlayerActor) -> void:
	pass

## Temporary stat sources of the kit (T1.1), same shape as the Defender's
## "defender_anchor" source: {"source_id", "label", "increased"/...}. Read every time the
## player rebuilds its breakdown; call PlayerActor.refresh_kit_stats() when the answer
## changes (zone presence, for example). Pure read of kit state.
func temporary_stat_sources(_player: PlayerActor) -> Array[Dictionary]:
	return []

## An enemy committed an attack against the player (see EnemyAttackEvent keys in the API).
func on_enemy_attack(_player: PlayerActor, _event: Dictionary) -> void:
	pass

## Kit concealment source (not a place). Revealing rules follow the Hunter's.
func concealment_active(_player: PlayerActor) -> bool:
	return false

## The player revealed itself by an offensive action.
func on_reveal(_player: PlayerActor, _duration: float) -> void:
	pass

## Non-empty reason makes the compact cut ineligible (the save uses the exact format).
## Required while a zone or temporary entity is active without a contracted projection.
func snapshot_compact_blocker(_player: PlayerActor) -> String:
	return ""

## Pure read of the kit state for the HUD and the world overlay (E12 C1). Format
## `ragrpg_kit_hud_v1`, validated by KitHudState (docs/epics/e12/h1_hud_seam_api.md).
## Same purity rule as skill_cost and temporary_stat_sources: no state change, no node
## creation, no signal, no randomness; may run every HUD update and while the tree is
## paused. Values come from the authorities; no formula is recomputed for the HUD.
## {} means "no HUD state" (the default) and is always valid.
func hud_state(_player: PlayerActor) -> Dictionary:
	return {}

# --- World floor of a selection (E10a T15: A19, A20, A21) ------------------------------
# Static and pure. A world selection of the family (Juízo, Olhar, Sussurro, Geometria,
# Revelação, Ídolo, contagion) keeps its own planar or 3D test and also asks these helpers
# whether the target stands on the floor of the selection's anchor: the canonical ground
# selection of the E07 (WorldEffectArea, `ground_connected`), the same rule as the Santuário.
# Two floors stacked within the height band (the F1 bridge, 40 above) are never mixed.

## Ground area of `anchor` for the traversal of `actor` (the caster, the decoy or the centre
## enemy). Null on the flat map, with no anchor, or when the point cannot anchor a ground area
## for that traversal (on_anchor_floor then compares surfaces).
static func floor_area(actor: CombatActor, anchor: ExpeditionWorldPoint) -> WorldEffectArea:
	if anchor == null or not is_instance_valid(actor) or actor.world_motion == null or actor.world_motion.geometry == null: return null
	var world := actor.world_motion.geometry
	var area := WorldEffectArea.new()
	return area if area.configure(world, anchor, actor.world_motion.profile(), &"ground_connected", world.geometry_revision)["ok"] else null

## True when `target` stands on the floor of `anchor`, reachable over the ground within `reach`
## plus its own world radius. Always true on the flat map (`anchor` null); false for a target
## outside the anchor's world or stage. Without an area, the same surface decides.
static func on_anchor_floor(area: WorldEffectArea, anchor: ExpeditionWorldPoint, target: CombatActor, reach: float) -> bool:
	if anchor == null: return true
	if not is_instance_valid(target) or target.world_motion == null or target.world_point() == null: return false
	var at := target.world_point()
	if at.stage_id != anchor.stage_id: return false
	if area == null: return at.surface_id == anchor.surface_id
	var reached := area.query(target, maxf(0.0, reach) + float(target.world_motion.profile()["radius"]))
	return bool(reached.get("ok", false)) and bool(reached.get("data", {}).get("hit", false))

## World point of `actor`, or null on the flat map. The anchor of a selection centred on it.
static func world_anchor(actor: CombatActor) -> ExpeditionWorldPoint:
	return actor.world_point() if is_instance_valid(actor) and actor.world_motion != null and actor.world_motion.is_current_world() else null

## Anchor of a ground point kept only as a position (a figure's centre between pulses): the
## surface among `around` (actors of the same world) whose support at the point's x/z has the
## point's height. Null on the flat map or when no such surface is found.
static func anchor_on_floor(actor: CombatActor, position: Vector3, around: Array) -> ExpeditionWorldPoint:
	var own := world_anchor(actor)
	if own == null or not position.is_finite(): return null
	var world := actor.world_motion.geometry
	var surfaces: Array[String] = [own.surface_id]
	for candidate: Variant in around:
		var other := candidate as CombatActor
		var point := world_anchor(other)
		if point != null and point.stage_id == own.stage_id and point.surface_id not in surfaces: surfaces.append(point.surface_id)
	for surface: String in surfaces:
		var found := world.support_at(surface, Vector2(position.x, position.z), world.geometry_revision)
		if not found.get("ok", false): continue
		var data: Dictionary = found["data"]["point"]
		var at := ExpeditionWorldPoint.create(data["stage_id"], data["surface_id"], data["position"])
		if absf(at.position.y - position.y) <= 0.5: return at
	return null
