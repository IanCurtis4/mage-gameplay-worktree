class_name MobLootTable
extends Resource
## Explicit rates only. Empty means no configured production loot.
@export var profiles: Dictionary = {}

@export var strict_quality_pools: bool = false
@export var recipe_revision_id: StringName = &"catalog_v1"
@export var power_ruleset_id: StringName = &"legacy_unscaled"
# Explicit species without a card. Never substitute another species' recipe.
@export var cardless_base_ids: Array[StringName] = []
