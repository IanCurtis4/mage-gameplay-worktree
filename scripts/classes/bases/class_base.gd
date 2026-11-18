class_name ClassBase
extends ClassKit
## E10a C1 — base (origin) module seam. API: docs/epics/e10a/t1_base_seam_api.md.
##
## A registered base is a module in `scripts/classes/bases/<id>/<id>_base.gd` that
## extends this class. Like a kit it plays two roles: a catalog module (pure data
## methods, aggregated by IdentityIds, ClassCatalog, ProfileCatalog, BuildEffectCatalog,
## FeedbackRecipeCatalog and SkillCopy) and a per-character origin object that
## PlayerActor attaches next to the evolution kit (C1.4). Every ClassKit hook applies;
## `kit_id()` returns the base ID and `evolution_id` holds it as well.
## The three E00 bases are not registered and never use this seam.

## Basic-attack types of basic_attack() and the PlayerActor delivery they select. Kept here
## (ClassBaseRegistry mirrors it) so this script never names the registry that caches its
## instances: that script cycle is not released at exit by Godot 4.7.2.
const DELIVERIES := {&"magic": &"mage", &"precision": &"precision", &"direct": &"direct"}

## Module ID. Must equal its key in ClassBaseRegistry.
func base_id() -> StringName:
	return &""

func kit_id() -> StringName:
	return base_id()

## Initial attributes (the six IDs of IdentityIds.attribute_ids(), summing 30). Empty
## keeps the base out of creation even when it declares ready_for_play.
func initial_attributes() -> Dictionary[StringName, int]:
	return {}

## Basic attack data: {"delivery": &"magic"|&"precision"|&"direct", "range": float
## (reach beyond bodies), "power": float (multiplier of the attack stat)}. Empty keeps
## the class defaults (direct, 50, 1.0).
func basic_attack() -> Dictionary:
	return {}

## Library skills taught at creation (ClassDefinition.skill_ids of the flat arena).
func starting_skill_ids() -> Array[StringName]:
	return []

## Starting passive (ClassDefinition.passive_id), or empty.
func starting_passive_id() -> StringName:
	return &""

## Learning rows of the base library (base wallet). Each:
## {"skill_id", "category" (ProfileCatalog.ACTIVE/PASSIVE), "max_purchased_rank"
## (5 actives, 3 passives), "job_level" (1..19, optional, default 1),
## "prerequisites" ({skill_id: rank} of this base, optional)}. free_rank is always 0.
func learning_entries() -> Array[Dictionary]:
	return []

## Basic attack profile hook: the base data, so preview and execution read one place.
## An evolution kit that declares its own profile replaces it (C1.4).
func basic_attack_profile(_player: PlayerActor) -> Dictionary:
	var data := basic_attack()
	if data.is_empty(): return {}
	return {"range": float(data.get("range", 0.0)), "delivery": StringName(DELIVERIES.get(StringName(data.get("delivery", &"")), &""))}
