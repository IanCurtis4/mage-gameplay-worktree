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
