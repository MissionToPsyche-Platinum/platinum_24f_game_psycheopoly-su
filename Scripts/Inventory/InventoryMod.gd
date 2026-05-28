extends Node
class_name InventoryModel

signal changed

const SLOTS_PER_CATEGORY: int = 72
const CATEGORY_COUNT: int = 3

const REQUIRED_SHIP_PART_TYPES: Array[int] = [
	ItemData.PartSubfilter.ENGINE,
	ItemData.PartSubfilter.WING,
	ItemData.PartSubfilter.FUEL_TANK,
	ItemData.PartSubfilter.NOSE_CONE,
	ItemData.PartSubfilter.BODY_PANELS,
	ItemData.PartSubfilter.ELECTRICAL_COMPONENTS,
	ItemData.PartSubfilter.ENGINE_HOUSING
]

@export var slot_count: int = SLOTS_PER_CATEGORY * CATEGORY_COUNT

var slots: Array = []
var ending_triggered: bool = false

func _init() -> void:
	initialize()

func initialize() -> void:
	slots.clear()
	slots.resize(slot_count)

	for i in range(slot_count):
		slots[i] = null

	ending_triggered = false

func ensure_initialized() -> void:
	if slots.size() != slot_count:
		initialize()

func clear() -> void:
	initialize()
	changed.emit()

func add_part_instance(part_instance: PartInstance) -> bool:
	if part_instance == null:
		return false

	var slot_index: int = get_first_empty_slot_in_category(ItemData.InventoryCategory.PART)
	if slot_index == -1:
		return false

	slots[slot_index] = {
		"item": part_instance,
		"item_data": part_instance.item_data
	}

	changed.emit()
	_check_for_ship_completion()
	return true

func get_category_slot_range(category: int) -> Dictionary:
	match category:
		ItemData.InventoryCategory.ITEM:
			return {"start": 0, "count": SLOTS_PER_CATEGORY}
		ItemData.InventoryCategory.PART:
			return {"start": SLOTS_PER_CATEGORY, "count": SLOTS_PER_CATEGORY}
		ItemData.InventoryCategory.MEMBER:
			return {"start": SLOTS_PER_CATEGORY * 2, "count": SLOTS_PER_CATEGORY}
		_:
			return {"start": 0, "count": 0}

func get_slot(index: int) -> Variant:
	ensure_initialized()

	if index < 0 or index >= slot_count:
		return null

	return slots[index]

func set_slot(index: int, value: Variant) -> void:
	ensure_initialized()

	if index < 0 or index >= slot_count:
		return

	slots[index] = value
	changed.emit()
	_check_for_ship_completion()

func get_slot_indexes_for_category(category: int) -> Array[int]:
	ensure_initialized()

	var result: Array[int] = []
	var range_info: Dictionary = get_category_slot_range(category)
	var start_index: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	for i in range(start_index, start_index + count):
		result.append(i)

	return result

func get_occupied_slot_indexes_for_category(category: int) -> Array[int]:
	ensure_initialized()

	var result: Array[int] = []
	var range_info: Dictionary = get_category_slot_range(category)
	var start_index: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	for i in range(start_index, start_index + count):
		if slots[i] != null:
			result.append(i)

	return result

func get_first_empty_slot_in_category(category: int) -> int:
	ensure_initialized()

	var range_info: Dictionary = get_category_slot_range(category)
	var start_index: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	for i in range(start_index, start_index + count):
		if slots[i] == null:
			return i

	return -1

func add_item(item: ItemData, quantity: int = 1) -> bool:
	ensure_initialized()

	if item == null:
		return false

	var range_info: Dictionary = get_category_slot_range(item.category)
	var start_index: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	for i in range(start_index, start_index + count):
		var slot_data: Variant = slots[i]
		if slot_data == null:
			continue

		var slot_item: ItemData = slot_data.get("item", null)
		if slot_item == null:
			continue

		if slot_item == item and int(slot_data.get("qty", 0)) < item.max_stack:
			var current_qty: int = int(slot_data.get("qty", 0))
			var space_left: int = item.max_stack - current_qty
			var amount_to_add: int = min(space_left, quantity)

			slot_data["qty"] = current_qty + amount_to_add
			quantity -= amount_to_add

			if quantity <= 0:
				changed.emit()
				_check_for_ship_completion()
				return true

	while quantity > 0:
		var empty_index: int = get_first_empty_slot_in_category(item.category)
		if empty_index == -1:
			changed.emit()
			_check_for_ship_completion()
			return false

		var amount_for_slot: int = min(quantity, item.max_stack)
		slots[empty_index] = {
			"item": item,
			"qty": amount_for_slot
		}
		quantity -= amount_for_slot

	changed.emit()
	_check_for_ship_completion()
	return true

func remove_from_slot(index: int, amount: int = 1) -> bool:
	ensure_initialized()

	if index < 0 or index >= slot_count:
		return false

	var slot_data: Variant = slots[index]
	if slot_data == null:
		return false

	var current_qty: int = int(slot_data.get("qty", 0))
	if current_qty <= amount:
		slots[index] = null
	else:
		slot_data["qty"] = current_qty - amount

	changed.emit()
	return true

func transfer_or_swap(from_index: int, to_index: int) -> void:
	ensure_initialized()

	if from_index < 0 or from_index >= slot_count:
		return
	if to_index < 0 or to_index >= slot_count:
		return
	if from_index == to_index:
		return

	var from_slot: Variant = slots[from_index]
	var to_slot: Variant = slots[to_index]

	slots[to_index] = from_slot
	slots[from_index] = to_slot

	changed.emit()
	_check_for_ship_completion()

func get_collected_ship_part_types() -> Array[int]:
	ensure_initialized()

	var collected: Dictionary = {}
	var part_indexes: Array[int] = get_occupied_slot_indexes_for_category(ItemData.InventoryCategory.PART)

	for index in part_indexes:
		var slot_data: Variant = slots[index]
		if slot_data == null:
			continue

		var part_instance: PartInstance = slot_data.get("item", null)
		if part_instance == null:
			continue

		collected[part_instance.part_subfilter] = true

	var result: Array[int] = []
	for key in collected.keys():
		result.append(int(key))

	result.sort()
	return result

func has_all_required_ship_parts() -> bool:
	var collected: Array[int] = get_collected_ship_part_types()

	for required_type in REQUIRED_SHIP_PART_TYPES:
		if not collected.has(required_type):
			return false

	return true

func _check_for_ship_completion() -> void:
	if ending_triggered:
		return

	if not has_all_required_ship_parts():
		return

	ending_triggered = true

	if has_node("/root/Navigator"):
		Navigator.call_deferred("go_to_scene_by_path", "res://Scenes/credits.tscn")

func get_total_stat(stat_name: String) -> float:
	ensure_initialized()
	var stat_map: Dictionary = {
		"Aerodynamics": "aerodynamics",
		"Weight": "weight",
		"Cost": "cost",
		"Repairability": "repairability",
		"Acceleration": "acceleration",
	}
	var prop_name: String = stat_map.get(stat_name, "")
	if prop_name == "":
		return 0.0
	var total: float = 0.0
	for i in range(slots.size()):
		var slot_data: Variant = slots[i]
		if slot_data == null:
			continue
		var item = slot_data.get("item", null)
		if item == null:
			continue
		var data: ItemData = null
		if item is PartInstance:
			data = item.item_data
		elif item is ItemData:
			data = item
		if data == null:
			continue
		var raw = data.get(prop_name)
		var qty: int = int(slot_data.get("qty", 1))
		var stat_value: float = float(raw)
		total += stat_value * qty
	return total

func get_count_by_subfilter(subfilter_value: int) -> int:
	ensure_initialized()
	var total: int = 0
	for i in range(slots.size()):
		var slot_data: Variant = slots[i]
		if slot_data == null:
			continue
		var item = slot_data.get("item", null)
		if item == null:
			continue
		var data: ItemData = null
		if item is PartInstance:
			data = item.item_data
		elif item is ItemData:
			data = item
		if data == null:
			continue
		if data.part_subfilter == subfilter_value:
			var qty: int = int(slot_data.get("qty", 1))
			total += qty
	return total

func get_count_by_mission(mission_name: String) -> int:
	ensure_initialized()
	var total: int = 0
	var target: String = mission_name.to_lower().strip_edges()
	for i in range(slots.size()):
		var slot_data: Variant = slots[i]
		if slot_data == null:
			continue
		var item = slot_data.get("item", null)
		if item == null:
			continue
		var data: ItemData = null
		if item is PartInstance:
			data = item.item_data
		elif item is ItemData:
			data = item
		if data == null:
			continue
		var item_mission: String = data.mission.to_lower().strip_edges()
		if item_mission == target:
			var qty: int = int(slot_data.get("qty", 1))
			total += qty
	return total
