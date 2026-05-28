extends Node
class_name GameState

@onready var inventory: InventoryModel = InventoryModel.new()

var total_difficulty_reduction: int = 0
var total_time_bonus: int = 0
var cbroot_stat: float = 0.0

func _ready() -> void:
	add_child(inventory)
	MoneySave.add_money(100)
	QuestManager.set_inventory(inventory)
	print("[GameState] inventory instance_id: ", inventory.get_instance_id())
	QuestManager.generate_quest(1)
	QuestManager.generate_quest(2)
	QuestManager.generate_quest(3)
	inventory.changed.connect(QuestManager.check_all)
	QuestManager.quest_completed.connect(_on_quest_completed)

func _update_stats():
	if inventory == null:
		return
		
	total_difficulty_reduction = 0
	total_time_bonus = 0
	cbroot_stat = 0.0

	for slot in inventory.slots:
		if slot == null:
			continue
		var item = slot["item"]
		var qty = int(slot["qty"])
		if item == null:
			continue

		total_difficulty_reduction += item.difficulty_reduction * qty
		
		total_time_bonus += item.time_bonus * qty

		cbroot_stat += pow(item.speed, 3) + pow(item.durability, 3) + pow(item.efficiency, 3)

	cbroot_stat = pow(cbroot_stat, 1/3)

func _on_quest_completed(quest_number: int) -> void:
	var q := QuestManager.get_quest(quest_number)
	print("Quest %d complete: %s" % [quest_number, q.title])
