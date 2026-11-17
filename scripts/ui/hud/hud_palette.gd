class_name HudPalette
extends RefCounted
## E12 H3: single presentation palette and shared cast-progress reading for the HUD
## components (CastBar, ActorCastBar, KitResourcePanel, KitWorldOverlay). Presentation
## only: colors and a defensive read of dictionaries; no rule, clock or save.
## Colors and sizes are playtest tuning (recorded in docs/epics/e12/h3_delivery.md).

## One color per element of ragrpg_kit_hud_v1 (KitHudState.ELEMENTS); empty maps to none.
const ELEMENT_COLORS := {
	&"none": Color("c9c3b4"),
	&"fire": Color("ff7a3d"),
	&"ice": Color("72c9ff"),
	&"lightning": Color("e9d76a"),
	&"tricolor": Color("e58cc8"),
	&"light": Color("f6e7a8"),
	&"arcane": Color("ba8de9"),
}
const NEUTRAL := Color("c9c3b4")

const PANEL_BACK := Color(0.08, 0.09, 0.12, 0.88)
const PIP_EMPTY := Color("3e3440")
const PIP_OUTLINE := Color("4b2434")
const TEXT := Color("f6dfc0")
const TEXT_DIM := Color("b8aa94")
const TEXT_OUTLINE := Color(0.05, 0.05, 0.08, 0.95)

## Cast bar colors, shared by CastBar and ActorCastBar.
const CAST_BACK := Color(0.08, 0.09, 0.12, 0.9)
const CAST_FILL := Color("f5cc77")
const CAST_CANCEL := Color("dc5757")
const CAST_RELEASE := Color("fff3c4")
const FLASH_SECONDS := 0.35

static func element_color(element: Variant) -> Color:
	if typeof(element) != TYPE_STRING_NAME and typeof(element) != TYPE_STRING:
		return NEUTRAL
	var key := StringName(element)
	if key == &"": key = &"none"
	return ELEMENT_COLORS.get(key, NEUTRAL)

static func is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT and is_finite(value)) or typeof(value) == TYPE_INT

## Empty or one of the palette elements, as a StringName.
static func is_known_element(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING_NAME: return false
	return value == &"" or ELEMENT_COLORS.has(value)

## Top level of a ragrpg_kit_hud_v1 dictionary: right schema and only the known keys.
static func is_clean_state(state: Dictionary) -> bool:
	if typeof(state.get("schema")) != TYPE_STRING or state["schema"] != KitHudState.SCHEMA: return false
	for key: Variant in state.keys():
		if typeof(key) != TYPE_STRING or not KitHudState.TOP_KEYS.has(key): return false
	return true

## Defensive read of a CombatActor.cast_progress() dictionary. Returns {} when there is
## no valid active cast; otherwise {"label", "remaining", "total", "ratio"} with
## ratio = 1 - remaining / total, the single fill ratio of every cast bar.
static func read_cast(progress: Variant) -> Dictionary:
	if typeof(progress) != TYPE_DICTIONARY: return {}
	var data: Dictionary = progress
	if typeof(data.get("active")) != TYPE_BOOL or not data["active"]: return {}
	if not is_number(data.get("total")) or not is_number(data.get("remaining")): return {}
	var total := float(data["total"])
	var remaining := float(data["remaining"])
	if total <= 0.0 or remaining < 0.0 or remaining > total: return {}
	var label := ""
	if data.has("label"):
		if typeof(data["label"]) != TYPE_STRING: return {}
		label = data["label"]
	return {"label": label, "remaining": remaining, "total": total, "ratio": clampf(1.0 - remaining / total, 0.0, 1.0)}

static func flash_color(kind: Variant) -> Color:
	if typeof(kind) == TYPE_STRING_NAME:
		if kind == &"cancel": return CAST_CANCEL
		if kind == &"release": return CAST_RELEASE
	return CAST_FILL

static func is_flash_kind(kind: Variant) -> bool:
	return typeof(kind) == TYPE_STRING_NAME and (kind == &"cancel" or kind == &"release")
