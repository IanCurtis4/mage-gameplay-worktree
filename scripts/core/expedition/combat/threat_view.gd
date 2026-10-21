class_name ThreatView
extends RefCounted
## Detached projection. No gameplay mutation or estimated values in consumers.
var enemy_id := ""
var current_id := ""
var forced_id := ""
var forced_remaining := 0.0
var engaged := false
var revision := 0
var switch_threshold := 0.0
var entries: Array[Dictionary] = []
