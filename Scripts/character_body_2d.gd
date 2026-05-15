extends CharacterBody2D
class_name Player

const MAX_BOARD_ITERATIONS: int = 1

@export var Board: MainBoard
@export var cell_size: Vector2i

@onready var turn_label: Label = get_parent().get_node("HUD/HUDBase/MarginContainer/HBoxContainer/HBoxContainer/turn counter")
@onready var inventory_overlay: InventoryOverlay = Board.get_node("Overlay/OverlayRoot/Inventory")
@onready var camera_node: Camera2D = $Camera2D

@export var shop_scene: PackedScene = preload("res://Scenes/UI/shopscreen.tscn")
@export var offer_scene: PackedScene = preload("res://Scenes/UI/ConfirmSwitch.tscn")
@export var asteroid: PackedScene = preload("res://Scenes/Minigames/AsteroidTargeting/AsteroidTargeting1.tscn")
@export var alien: PackedScene = preload("res://Scenes/Minigames/alien_communication/alien_communication.tscn")
@export var reward_screen: PackedScene = preload("res://Scenes/reward_screen.tscn")
@export var tutorial_scene: PackedScene = preload("res://Scenes/tutorial.tscn")
@export var possible_part_items: Array[ItemData] = []
const ITEM_DATABASE_PATH: String = "res://ItemDatabase_updated.json"
var initialized: bool = false
var rng := RandomNumberGenerator.new()
var spaces_moved_total: int = 0
var can_roll: bool = true
var roll: int = 0
var busy: bool = false
var current_tile_index: int = 0
var turn: int = 0
var minigames: Array[PackedScene] = []
var ending_triggered: bool = false
var active_offer: Control = null
var shop_database: ItemDatabase
func _ready() -> void:
	if Board == null:
		push_error("Player Board reference is missing.")
		return
	if offer_scene == null:
		offer_scene = preload("res://Scenes/UI/ConfirmSwitch.tscn")
	cell_size = Board.cell_size
	minigames.clear()

	rng.randomize()
	_configure_minigames()

	if Board.has_method("get_total_drawn_tile_count"):
		if Board.get_total_drawn_tile_count() == 0:
			await Board.board_ready
	elif Board.get_tile_count() == 0:
		await Board.board_ready

	await get_tree().process_frame

	current_tile_index = 0
	spaces_moved_total = 0
	global_position = Board.get_start_center()

	if camera_node:
		camera_node.enabled = true
		camera_node.position = Vector2.ZERO

	initialized = true
	_update_turn_label()

func _animate_to_tile(tile_index: int, duration: float = 0.2) -> void:
	var destination: Vector2 = Board.get_tile_center_global(tile_index) if Board.has_method("get_tile_center_global") else Board.get_tile_center(tile_index)

	var tween := create_tween()
	tween.tween_property(self, "global_position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
func _open_chance_card() -> void:
	busy = true
	can_roll = false

	var effects: Array[Dictionary] = [
		{
			"text": "You found a mysterious part!",
			"type": "gain_part"
		},
		{
			"text": "A part was stolen from you!",
			"type": "lose_part"
		},
		{
			"text": "You gained 10 coins!",
			"type": "money",
			"amount": 10
		},
		{
			"text": "You lost 5 coins!",
			"type": "money",
			"amount": -5
		}
	]

	var effect: Dictionary = effects[rng.randi_range(0, effects.size() - 1)]

	await _show_chance_prompt(str(effect["text"]))
	await _apply_chance_effect(effect)

	can_roll = true
	busy = false
func _show_chance_prompt(message: String) -> void:
	if offer_scene == null:
		push_error("offer_scene is missing.")
		return

	if Board.overlay_root != null:
		Board.overlay_root.visible = true

	var prompt := offer_scene.instantiate()
	Board.overlay_root.add_child(prompt)

	if prompt.has_method("setup_prompt"):
		prompt.setup_prompt(message, "OK", "Skip")
	elif prompt.has_method("setup"):
		prompt.setup("Chance Card")
	else:
		push_warning("Chance prompt scene does not have setup_prompt().")

	await prompt.choice
func _apply_chance_effect(effect: Dictionary) -> void:
	var effect_type: String = str(effect["type"])

	match effect_type:
		"money":
			var amount: int = int(effect["amount"])
			MoneySave.add_money(amount)

		"gain_part":
			_gain_random_part()

		"lose_part":
			_lose_random_part()
func _get_random_part_from_database() -> ItemData:
	if not FileAccess.file_exists(ITEM_DATABASE_PATH):
		push_warning("Item database not found: " + ITEM_DATABASE_PATH)
		return null

	var file := FileAccess.open(ITEM_DATABASE_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Item database JSON is not a Dictionary.")
		return null

	var items: Array = parsed.get("items", [])
	var valid_parts: Array[Dictionary] = []

	for item_data in items:
		if typeof(item_data) != TYPE_DICTIONARY:
			continue

		# Your JSON uses Category "1" for parts.
		if str(item_data.get("Category", "")) == "1":
			valid_parts.append(item_data)

	if valid_parts.is_empty():
		return null

	var chosen: Dictionary = valid_parts[rng.randi_range(0, valid_parts.size() - 1)]

	var item := ItemData.new()

	item.id = str(chosen.get("ID", ""))
	item.display_name = str(chosen.get("Name", "Unknown Part"))
	item.description = str(chosen.get("Description", ""))
	item.buy_price = int(chosen.get("Price", "0"))
	item.sell_price = int(chosen.get("Price", "0"))
	item.max_stack = int(chosen.get("MaxStack", "1"))
	item.category = ItemData.InventoryCategory.PART

	var icon_path: String = str(chosen.get("Icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path)

	item.part_subfilter = int(chosen.get("PartSubfilter", "0"))

	item.aerodynamics = float(chosen.get("Aerodynamics", "0"))
	item.weight = float(chosen.get("Weight", "0"))
	item.cost = float(chosen.get("Cost", "0"))
	item.repairability = float(chosen.get("Repairability", "0"))
	item.acceleration = float(chosen.get("Acceleration", "0"))

	return item			
func _gain_random_part() -> void:
	var player_inventory: InventoryModel = $InventoryModel

	if shop_database == null:
		shop_database = ItemDatabase.new()
		shop_database.load_items("")

	var valid_parts: Array[ItemData] = []

	for item_data in shop_database.get_all_items():
		if item_data == null:
			continue

		if item_data.category == ItemData.InventoryCategory.PART:
			valid_parts.append(item_data)

	if valid_parts.is_empty():
		push_warning("No valid part items found in ItemDatabase.")
		return

	var base_item: ItemData = valid_parts[rng.randi_range(0, valid_parts.size() - 1)]
	var part_instance: PartInstance = RewardGen.make_random_part(base_item)

	# 🔑 THIS is the important part
	var range_info: Dictionary = player_inventory.get_category_slot_range(ItemData.InventoryCategory.PART)
	var start: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	var empty_index: int = -1

	for i in range(start, start + count):
		if player_inventory.get_slot(i) == null:
			empty_index = i
			break

	if empty_index == -1:
		push_warning("No empty PART slots available.")
		return

	player_inventory.set_slot(empty_index, {
		"item": part_instance,
		"item_data": base_item
	})

	print("Gained part in PART slot: ", empty_index)
func _lose_random_part() -> void:
	var player_inventory: InventoryModel = $InventoryModel

	var range_info: Dictionary = player_inventory.get_category_slot_range(ItemData.InventoryCategory.PART)
	var start: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	var valid_slots: Array[int] = []

	for i in range(start, start + count):
		var slot = player_inventory.get_slot(i)

		if slot == null:
			continue

		if not slot.has("item"):
			continue

		var part_instance: PartInstance = slot["item"] as PartInstance

		if part_instance != null:
			valid_slots.append(i)

	if valid_slots.is_empty():
		print("No parts to remove.")
		return

	var chosen_index: int = valid_slots[rng.randi_range(0, valid_slots.size() - 1)]

	player_inventory.set_slot(chosen_index, null)

func roll_and_move(amount: int = 0) -> void:
	if not initialized:
		push_error("roll_and_move called too early")
		return

	if not can_roll or busy or ending_triggered:
		return

	can_roll = false
	busy = true

	roll = rng.randi_range(1, 6) if amount == 0 else amount

	var steps_remaining: int = roll

	while steps_remaining > 0:
		var next_tile_index: int = Board.get_next_tile_index(current_tile_index)

		if next_tile_index == current_tile_index:
			if Board.should_show_path_choice(current_tile_index):
				await Board.request_branch_choice(current_tile_index)
				next_tile_index = Board.get_next_tile_index(current_tile_index)
			else:
				break

		if next_tile_index == current_tile_index:
			break

		current_tile_index = next_tile_index
		spaces_moved_total += 1
		steps_remaining -= 1

		if Board.should_show_path_choice(current_tile_index):
			await Board.request_branch_choice(current_tile_index)

	await _animate_to_tile(current_tile_index, 0.2)

	_update_turn_label()

	if _has_reached_iteration_limit():
		_trigger_credits_end()
		return

	if Board.is_shop_tile(current_tile_index):
		await _open_shop()
	elif Board.is_red_tile(current_tile_index):
		await _offer_game()
	elif Board.is_chance_tile(current_tile_index):
		await _open_chance_card()
	else:
		MoneySave.add_money(3)

	can_roll = true
	busy = false

func _unhandled_input(event: InputEvent) -> void:
	if busy or ending_triggered:
		return

	if event.is_action_pressed("ui_accept"):
		roll_and_move()

func _open_shop() -> void:
	busy = true
	can_roll = false

	if shop_scene == null:
		shop_scene = load("res://Scenes/UI/shopscreen.tscn")

	if shop_scene == null:
		push_error("shop_scene is not assigned and could not be loaded.")
		busy = false
		can_roll = true
		return

	if Board.overlay_root != null:
		Board.overlay_root.visible = true

	var shop := shop_scene.instantiate()
	Board.overlay_root.add_child(shop)

	var player_inventory: InventoryModel = $InventoryModel
	var overlay: InventoryOverlay = Board.get_node("Overlay/OverlayRoot/Inventory")

	shop.setup_shop(player_inventory, overlay)

	await shop.closed

	if ending_triggered:
		return

	can_roll = true
	busy = false

func _update_turn_label() -> void:
	var board_iterations: int = _get_board_iterations_completed()
	turn_label.text = "Turn: %d | Roll: %d | Tile: %d | Laps: %d/%d" % [
		turn,
		roll,
		current_tile_index,
		board_iterations,
		MAX_BOARD_ITERATIONS
	]
	turn += 1

func _set_board_ui_visible(is_visible: bool) -> void:
	var hud := Board.get_node_or_null("HUD")
	if hud != null:
		hud.visible = is_visible

	if Board.overlay_root != null:
		Board.overlay_root.visible = is_visible

	if inventory_overlay != null and not is_visible:
		inventory_overlay.hide()

func _configure_minigames() -> void:
	minigames.clear()

	if asteroid == null:
		asteroid = load("res://Scenes/Minigames/AsteroidTargeting/AsteroidTargeting1.tscn")

	if alien == null:
		alien = load("res://Scenes/Minigames/alien_communication/alien_communication.tscn")

	if asteroid != null:
		minigames.append(asteroid)

	if alien != null:
		minigames.append(alien)

func _offer_game() -> void:
	busy = true
	can_roll = false

	if offer_scene == null:
		push_error("offer_scene is not assigned!")
		busy = false
		can_roll = true
		return

	_configure_minigames()

	if minigames.is_empty():
		push_error("No minigames configured.")
		busy = false
		can_roll = true
		return

	var chosen_game_scene: PackedScene = minigames[rng.randi_range(0, minigames.size() - 1)]

	if chosen_game_scene == null:
		push_error("Chosen minigame scene is null.")
		busy = false
		can_roll = true
		return

	var scene_key: String = chosen_game_scene.resource_path.get_file().get_basename()

	if Board.overlay_root != null:
		Board.overlay_root.visible = true

	var offer := offer_scene.instantiate()
	Board.overlay_root.add_child(offer)

	if offer.has_method("setup"):
		offer.setup(scene_key)
	elif offer.has_method("setup_prompt"):
		offer.setup_prompt("Do you want to play this minigame?", "Play", "Skip")
	else:
		offer.title_text = "Do you want to play this minigame?"
		offer.play_text = "Play"
		offer.skip_text = "Skip"

	var play: bool = await offer.choice

	if not play:
		busy = false
		can_roll = true
		return

	_set_board_ui_visible(false)

	if GlobalSettings.minigame_intros_enabled:
		var canvas := CanvasLayer.new()
		Board.add_child(canvas)

		var intro := tutorial_scene.instantiate()
		intro.tutorial_type = scene_key
		canvas.add_child(intro)

		await intro.intro_finished
		canvas.queue_free()

	var mg := chosen_game_scene.instantiate()
	Board.game_root.add_child(mg)

	var result: Dictionary = await mg.done
	await _result(result)
	await get_tree().process_frame

	for child in Board.game_root.get_children():
		child.queue_free()

	await get_tree().process_frame

	if not ending_triggered:
		_set_board_ui_visible(true)
		busy = false
		can_roll = true

func _result(result: Dictionary) -> void:
	if result.get("status") == "win":
		# await _show_reward_screen()

		# TEMPORARY: skip reward screen
		print("Reward screen disabled - returning to board")

func _show_reward_screen() -> void:
	var screen := reward_screen.instantiate()
	var player_inventory: InventoryModel = $InventoryModel
	screen.setup(player_inventory)
	Board.overlay_root.add_child(screen)
	Board.overlay_root.visible = true
	await screen.item_chosen

	if ending_triggered:
		return

	Board.overlay_root.visible = false

func _get_board_iterations_completed() -> int:
	var board_count: int = Board.get_tile_count()
	if board_count <= 0:
		return 0

	return int(spaces_moved_total / board_count)

func _has_reached_iteration_limit() -> bool:
	return _get_board_iterations_completed() >= MAX_BOARD_ITERATIONS

func _trigger_credits_end() -> void:
	if ending_triggered:
		return

	ending_triggered = true
	can_roll = false
	busy = true

	_set_board_ui_visible(false)

	for child in Board.game_root.get_children():
		child.queue_free()

	if has_node("/root/Navigator"):
		Navigator.call_deferred("go_to_scene_by_path", "res://Scenes/Credits/credits.tscn")
