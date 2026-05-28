extends Node

signal quest_completed(quest_index: int)

var _quests: Array[Quest] = [null, null, null]
var _used_types: Array[Quest.Type] = []
var _used_targets: Array[String] = []

func _get_live_inventory() -> InventoryModel:
	return get_node("/root/MainBoard/CharacterBody2D/InventoryModel")

func set_inventory(inv: InventoryModel) -> void:
	pass

func generate_quest(quest_number: int) -> void:
	assert(quest_number >= 1 and quest_number <= 3, "Quest number must be 1, 2, or 3")
	var available_types: Array[Quest.Type] = []
	for t in Quest.Type.values():
		if not _used_types.has(t):
			available_types.append(t)
	if available_types.is_empty():
		available_types = Quest.Type.values()
	var chosen_type: Quest.Type = available_types[randi() % available_types.size()]
	_used_types.append(chosen_type)
	var q := Quest.create(chosen_type, _used_targets)
	for target in q.get_used_target().split("|"):
		if target != "":
			_used_targets.append(target)
	_quests[quest_number - 1] = q
	print("Quest %d generated: %s" % [quest_number, q.print_quests()])

func get_quest(quest_number: int) -> Quest:
	assert(quest_number >= 1 and quest_number <= 3, "Quest number must be 1, 2, or 3")
	return _quests[quest_number - 1]

func check_all() -> void:
	var inv := _get_live_inventory()
	if inv == null:
		return
	for i in range(3):
		var q := _quests[i]
		if q == null or q.is_complete:
			continue
		if q.check_completion(inv):
			q.is_complete = true
			quest_completed.emit(i + 1)

func is_quest_1_complete() -> bool: return _quests[0] != null and _quests[0].check_completion(_get_live_inventory())
func is_quest_2_complete() -> bool: return _quests[1] != null and _quests[1].check_completion(_get_live_inventory())
func is_quest_3_complete() -> bool: return _quests[2] != null and _quests[2].check_completion(_get_live_inventory())
