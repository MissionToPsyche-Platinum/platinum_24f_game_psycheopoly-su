extends Control

signal closed

const SLOT_BUTTON_SCENE: PackedScene = preload("res://Scenes/UI/SlotBtn.tscn")
const SHOP_SLOT_COUNT: int = 10

static var _db_cache: ItemDatabase = null

var shop_inventory: InventoryModel = null
var shop_database: ItemDatabase = null

@export var slot_size: Vector2 = Vector2(85, 110)
@export var columns: int = 5

@onready var close_btn: BaseButton = $Control/Panel/Root/MarginContainer/NavBar/Close
@onready var buy_btn: BaseButton = $Control/Panel/Root/MarginContainer/MainShopCont/ShopBtns/BuyBtn
@onready var sell_btn: BaseButton = $Control/Panel/Root/MarginContainer/MainShopCont/ShopBtns/SellBtn
@onready var hire_btn: BaseButton = $Control/Panel/Root/MarginContainer/MainShopCont/ShopBtns/HireBtn

@onready var shop_grid: GridContainer = $Control/Panel/Root/MarginContainer/MainShopCont/Control/ScrollContainer/ShopGrid
@onready var item_name_label: Label = $Control/Panel/Root/MarginContainer/MainShopCont/ShopInfo/HBoxContainer/VBoxContainer/ItemLabel
@onready var item_desc_label: RichTextLabel = $Control/Panel/Root/MarginContainer/MainShopCont/ShopInfo/HBoxContainer/VBoxContainer/ItemDesc
@onready var item_price_label: Label = $Control/Panel/Root/MarginContainer/MainShopCont/ShopInfo/HBoxContainer/ItemPrice
@onready var buy_total_label: Label = $Control/Panel/Root/MarginContainer/MainShopCont/purchasePrice

var player_inventory: InventoryModel = null
var inventory_overlay: InventoryOverlay = null

var selected_index: int = -1
var selected_shop_index: int = -1

var selected_item: ItemData = null
var selected_part_instance: PartInstance = null

func _ready() -> void:
	randomize()

	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)
	if buy_btn != null:
		buy_btn.pressed.connect(_on_buy_pressed)
	if sell_btn != null:
		sell_btn.pressed.connect(_on_sell_pressed)
	if hire_btn != null:
		hire_btn.pressed.connect(_on_hire_pressed)

	if buy_total_label != null:
		buy_total_label.text = "Total Cost: $0"
	if item_price_label != null:
		item_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_price_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		item_price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		item_price_label.custom_minimum_size = Vector2(260, 180)

	if item_name_label != null:
		item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		item_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if item_desc_label != null:
		item_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clear_selection_display()
	_create_shop_inventory()
	_create_database()
	_fill_random_stock()

	_rebuild_shop_grid()

func setup_shop(player_inv: InventoryModel, inv_overlay: InventoryOverlay) -> void:
	player_inventory = player_inv
	inventory_overlay = inv_overlay

func _create_shop_inventory() -> void:
	shop_inventory = InventoryModel.new()
	shop_inventory.clear()

func _create_database() -> void:
	if _db_cache == null:
		_db_cache = ItemDatabase.new()
		_db_cache.load_items("")
	shop_database = _db_cache

func _fill_random_stock() -> void:
	if shop_inventory == null or shop_database == null:
		return

	shop_inventory.clear()

	var valid_parts: Array[ItemData] = []

	for item_data in shop_database.get_all_items():
		if item_data == null:
			continue

		if item_data.category == ItemData.InventoryCategory.PART:
			valid_parts.append(item_data)

	valid_parts.shuffle()

	var count: int = min(SHOP_SLOT_COUNT, valid_parts.size())

	for i in range(count):
		var item_data: ItemData = valid_parts[i]
		if item_data == null:
			continue

		var part_instance: PartInstance = RewardGen.make_random_part(item_data)

		shop_inventory.set_slot(i, {
			"item": part_instance,
			"item_data": item_data
		})

func _rebuild_shop_grid() -> void:
	if shop_grid == null:
		push_error("Shop: ShopGrid not found")
		return
	if SLOT_BUTTON_SCENE == null:
		push_error("Shop: SLOT_BUTTON_SCENE is null")
		return
	if shop_inventory == null:
		push_error("Shop: shop_inventory is null")
		return

	for c in shop_grid.get_children():
		c.queue_free()

	shop_grid.columns = columns

	for i in range(SHOP_SLOT_COUNT):
		var slot: SlotButton = SLOT_BUTTON_SCENE.instantiate() as SlotButton
		if slot == null:
			push_error("Shop: failed to instance SlotBtn")
			return

		slot.index = i
		slot.inventory_model = shop_inventory
		slot.custom_minimum_size = slot_size
		slot.interaction_mode = SlotButton.InteractionMode.SELECT
		slot.show_mouse_tooltip = false
		slot.is_selected = (i == selected_shop_index)

		if not slot.slot_selected.is_connected(_on_shop_slot_selected):
			slot.slot_selected.connect(_on_shop_slot_selected)
		if not slot.hovered_slot.is_connected(_on_shop_slot_hovered):
			slot.hovered_slot.connect(_on_shop_slot_hovered)
		if not slot.unhovered_slot.is_connected(_on_shop_slot_unhovered):
			slot.unhovered_slot.connect(_on_shop_slot_unhovered)

		shop_grid.add_child(slot)
		slot.refresh()

func _on_shop_slot_selected(index: int, source_inventory: InventoryModel) -> void:
	if source_inventory == null:
		return

	var slot: Variant = source_inventory.get_slot(index)
	if slot == null:
		return

	if selected_shop_index == index:
		_clear_selection_display()
		_update_sell_button_state()
		_rebuild_shop_grid()
		return
	selected_shop_index = index
	selected_index = index

	var slot_item = slot.get("item", null)

	if slot_item is PartInstance:
		selected_part_instance = slot_item
		selected_item = selected_part_instance.item_data
	elif slot_item is ItemData:
		selected_item = slot_item
		selected_part_instance = null
	else:
		selected_item = null
		selected_part_instance = null

	_update_selection_display()
	_update_buy_total()
	_update_sell_button_state()
	_rebuild_shop_grid()

func _on_shop_slot_hovered(index: int, source_inventory: InventoryModel) -> void:
	if source_inventory == null:
		return

	var slot: Variant = source_inventory.get_slot(index)
	if slot == null:
		return

	var slot_item = slot.get("item", null)
	var hovered_item: ItemData = null
	var hovered_instance: PartInstance = null

	if slot_item is PartInstance:
		hovered_instance = slot_item
		hovered_item = hovered_instance.item_data
	elif slot_item is ItemData:
		hovered_item = slot_item

	if hovered_item == null:
		return

	_show_item_details(hovered_item, hovered_instance)

func _on_shop_slot_unhovered() -> void:
	if selected_item != null:
		_show_item_details(selected_item, selected_part_instance)
	else:
		_clear_selection_display()
func _show_item_details(item: ItemData, instance: PartInstance) -> void:
	if item == null:
		return

	if instance != null:
		item_price_label.text = "Aerodynamics: %.1f\nWeight: %.1f\nCost: %.1f\nRepairability: %.1f\nAcceleration: %.1f\nTotal: %.1f" % [
			instance.aerodynamics,
			instance.weight,
			instance.cost,
			instance.repairability,
			instance.acceleration,
			instance.get_total_stats()
		]

		item_name_label.text = "%s [%s][%s]" % [
			item.display_name,
			instance.get_rarity_name(),
			instance.get_display_name()
		]

		item_desc_label.text = "%s\n\nBuy: %d coins" % [
			item.description,
			instance.shop_price
		]
	else:
		item_price_label.text = ""
		item_name_label.text = item.display_name
		item_desc_label.text = "%s\n\nBuy: %d coins" % [
			item.description,
			int(item.buy_price)
		]
func _update_selection_display() -> void:
	if selected_item == null:
		_clear_selection_display()
		return

	_show_item_details(selected_item, selected_part_instance)
func _clear_selection_display() -> void:
	selected_shop_index = -1
	selected_index = -1
	selected_item = null
	selected_part_instance = null

	if item_name_label != null:
		item_name_label.text = ""
	if item_desc_label != null:
		item_desc_label.text = ""
	if item_price_label != null:
		item_price_label.text = ""
	if buy_total_label != null:
		buy_total_label.text = "Total Cost: $0 "
	_update_sell_button_state()
func _update_buy_total() -> void:
	if buy_total_label == null:
		return

	if selected_part_instance != null:
		buy_total_label.text = "Buy: %d coins" % selected_part_instance.shop_price
	elif selected_item != null:
		buy_total_label.text = "Buy: %d coins" % selected_item.buy_price
	else:
		buy_total_label.text = "Buy: 0 coins"
func _update_sell_button_state() -> void:
	var has_shop_item_selected := selected_shop_index >= 0

	if buy_btn != null:
		buy_btn.disabled = not has_shop_item_selected


	if sell_btn != null:
		sell_btn.disabled = has_shop_item_selected
func _on_buy_pressed() -> void:
	if selected_shop_index < 0:
		return

	if shop_inventory == null or player_inventory== null:
		return

	var slot: Variant = shop_inventory.get_slot(selected_shop_index)
	if slot == null:
		return

	var slot_item = slot.get("item", null)
	if slot_item == null:
		return

	var part_instance: PartInstance = null
	var item_data: ItemData = null
	var price: int = 0

	if slot_item is PartInstance:
		part_instance = slot_item
		item_data = part_instance.item_data
		price = part_instance.shop_price
	elif slot_item is ItemData:
		item_data = slot_item
		price = item_data.buy_price
	else:
		return

	if item_data == null:
		return

	if MoneySave.money < price:
		print("Not enough money.")
		return

	var added: bool = false

	if part_instance != null:
		added = player_inventory.add_part_instance(part_instance)
	else:
		added = player_inventory.add_item(item_data, 1)

	if not added:
		print("Inventory full.")
		return

	MoneySave.add_money(-price)

	shop_inventory.set_slot(selected_shop_index, null)

	_clear_selection_display()
	_rebuild_shop_grid()
	_update_buy_total()
func _on_sell_pressed() -> void:
	if selected_shop_index >= 0:
		return

	if inventory_overlay == null or player_inventory == null:
		push_error("Shop: inventory overlay or player inventory missing")
		return

	_clear_selection_display()

	hide()

	inventory_overlay.set_inventory(player_inventory)
	inventory_overlay.enter_sell_mode(self)

	
	await inventory_overlay.open_inventory()
func _on_hire_pressed() -> void:
	print("Hire pressed")

func receive_sold_item(item: ItemData, qty: int) -> void:
	if shop_inventory == null or item == null or qty <= 0:
		return

	shop_inventory.add_item(item, qty)
	_rebuild_shop_grid()

func _on_close_pressed() -> void:
	leave_shop()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu == null:
		return
	
	leave_shop()

func leave_shop() -> void:
	closed.emit()
	queue_free()
