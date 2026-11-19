extends Node2D
## E10a T16 (A15) — the drawing of the Exorcista: a child node of the enemy the passive acted on.
## `exposed`: a gold aro on the ground and a seal of light over the head, for as long as the
## enemy keeps the Exposto source of this Sacerdote (it fades out in the last 0.5 s).
## `stripped`: a short burst when the light removed a shield or a buff. Presentation only: it
## reads the enemy, never writes it, joins no group and frees itself when its source is gone
## (the source expired, the enemy died or left, another owner replaced it). The kit never keeps
## a reference to it. No class_name (E10a T1 note about 4.7.2).

const IVORY := Color(1.0, 0.97, 0.86)
const GOLD := Color(1.0, 0.84, 0.38)
const SKY := Color(0.62, 0.84, 1.0)
const KIND_EXPOSED := &"exposed"
const KIND_STRIPPED := &"stripped"
const BURST_SECONDS := 0.6
const NODE_PREFIX := "PriestExorcist_"

var kind: StringName = KIND_EXPOSED
## Source id of the Exposto (the kit's EXPOSED_SOURCE) and the owner it must keep.
var source_id: StringName = &""
var owner_id := 0
## Number of times _draw drew something (tests and captures).
var draw_count := 0
var _age := 0.0
var _remaining := 0.0
var _body := 18.0

## Creates or replaces the mark on `victim`; returns the node (null when the victim cannot host it).
static func attach(victim: Node2D, mark_kind: StringName, source: StringName, owner: int) -> Node2D:
	if victim == null or not is_instance_valid(victim) or victim.is_queued_for_deletion(): return null
	var node_name := NODE_PREFIX + String(mark_kind)
	var previous := victim.get_node_or_null(NodePath(node_name))
	if previous != null:
		previous.call(&"release")
	var mark: Node2D = (load("res://scripts/classes/priest/priest_exorcist_mark.gd") as Script).new()
	mark.name = node_name
	mark.kind = mark_kind
	mark.source_id = source
	mark.owner_id = owner
	mark.call(&"_refresh", victim)
	victim.add_child(mark)
	return mark

## Detaches and frees the node now (idempotent).
func release() -> void:
	if get_parent() != null: get_parent().remove_child(self)
	if not is_queued_for_deletion(): queue_free()

func _process(delta: float) -> void:
	var victim := get_parent() as CombatActor
	if victim == null or not victim.is_alive():
		release()
		return
	_age += delta
	if kind == KIND_STRIPPED:
		_remaining = maxf(0.0, BURST_SECONDS - _age)
		if _remaining <= 0.0:
			release()
			return
	elif not _refresh(victim):
		release()
		return
	queue_redraw()

## Reads the enemy: false when the Exposto of this owner is gone.
func _refresh(victim: Node2D) -> bool:
	_body = maxf(10.0, float(victim.get(&"collision_radius")) if victim.get(&"collision_radius") != null else 18.0)
	if kind == KIND_STRIPPED:
		_remaining = BURST_SECONDS
		return true
	var sources: Variant = victim.get(&"received_damage_sources")
	if not sources is Dictionary or not (sources as Dictionary).has(source_id): return false
	var entry: Variant = (sources as Dictionary)[source_id]
	if not entry is Dictionary or int((entry as Dictionary).get("owner_id", 0)) != owner_id: return false
	_remaining = float((entry as Dictionary).get("remaining", 0.0))
	return _remaining > 0.0

func _draw() -> void:
	draw_count += 1
	if kind == KIND_STRIPPED: _draw_burst()
	else: _draw_exposed()

func _draw_exposed() -> void:
	var fade := clampf(_remaining / 0.5, 0.0, 1.0) * clampf(_age / 0.2, 0.0, 1.0)
	var spin := _age * 1.4
	# Ground aro, squashed like the rest of the ground art, broken in three places.
	var radius := _body * 1.7 + 4.0 * sin(_age * 3.0)
	for k: int in 3:
		var from := spin + TAU * k / 3.0
		var arc := PackedVector2Array()
		for i: int in 13: arc.append(Vector2(cos(from + 1.5 * i / 12.0), sin(from + 1.5 * i / 12.0) * 0.5) * radius)
		draw_polyline(arc, Color(GOLD, 0.85 * fade), 2.5)
	# Seal over the head: a sun-cross (the light of the Sacerdote lands harder here).
	var head := Vector2(0.0, -(_body * 2.0 + 20.0 + 3.0 * sin(_age * 4.0)))
	draw_arc(head, 9.0, 0.0, TAU, 20, Color(GOLD, fade), 2.0)
	for k: int in 4:
		var dir := Vector2.from_angle(PI * 0.25 + PI * 0.5 * k)
		draw_line(head + dir * 11.0, head + dir * 17.0, Color(IVORY, fade), 2.0)
	draw_line(head + Vector2(-5.0, 0.0), head + Vector2(5.0, 0.0), Color(IVORY, 0.9 * fade), 2.0)
	draw_line(head + Vector2(0.0, -5.0), head + Vector2(0.0, 5.0), Color(IVORY, 0.9 * fade), 2.0)

func _draw_burst() -> void:
	var t := clampf(_age / BURST_SECONDS, 0.0, 1.0)
	var fade := 1.0 - t
	var center := Vector2(0.0, -_body - 6.0)
	for k: int in 8:
		var dir := Vector2.from_angle(TAU * k / 8.0 + 0.3)
		draw_line(center + dir * (8.0 + 10.0 * t), center + dir * (16.0 + 30.0 * t), Color(GOLD if k % 2 == 0 else SKY, fade), 2.5)
	draw_arc(center, 10.0 + 26.0 * t, 0.0, TAU, 24, Color(IVORY, 0.9 * fade), 2.0)
