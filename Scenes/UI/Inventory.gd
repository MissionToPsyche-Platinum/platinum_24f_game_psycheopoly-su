extends Control
class_name InventoryOverlay
const SLOT_BUTTON_SCENE_PATH := "res://Scenes/UI/SlotBtn.tscn"
var slot_button_scene: PackedScene = null
@export var rows: int = 3
@export var slot_size: Vector2 = Vector2(85, 110)

@onready var close_btn := $Screen/MarginContainer/VBoxContainer/TopBar/HBoxContainer/Closebtn as BaseButton
#@onready var grid := $Screen/InvPanel/CenterContainer/MarginContainer/GridContainer as GridContainer
@onready var money_label: Label = %MoneyLabel
@onready var progress: ProgressBar = %progress
@onready var bg: ColorRect = $ColorRect
@onready var sell_total_label: Label = $Screen/MarginContainer/VBoxContainer/BottomBar/HBoxContainer/Total
@onready var sell_confirm_btn: BaseButton = $Screen/MarginContainer/VBoxContainer/BottomBar/HBoxContainer/ConfirmSell
@onready var sell_cancel_btn: BaseButton = $Screen/MarginContainer/VBoxContainer/BottomBar/HBoxContainer/CancelSell
@onready var items_btn: BaseButton = $Screen/MarginContainer/VBoxContainer/TopBar/HBoxContainer/ItemBtn
@onready var parts_btn: BaseButton = $Screen/MarginContainer/VBoxContainer/TopBar/HBoxContainer/PartBtn
@onready var members_btn: BaseButton = $Screen/MarginContainer/VBoxContainer/TopBar/HBoxContainer/MemberBtn
@onready var category_label: Label = $Screen/MarginContainer/VBoxContainer/TopBar/CenterContainer/VBoxContainer/HBoxContainer/Category
@onready var subfilter: OptionButton = $Screen/MarginContainer/VBoxContainer/TopBar/CenterContainer/VBoxContainer/HBoxContainer/OptionButton
@onready var scroll_container: ScrollContainer = $Screen/MarginContainer/VBoxContainer/CenterContainer/ScrollContainer
@onready var grid: GridContainer = $Screen/MarginContainer/VBoxContainer/CenterContainer/ScrollContainer/GridContainer
@onready var panel_mover: Control = $Screen

var panel_final_position: Vector2 = Vector2.ZERO
var panel_start_position: Vector2 = Vector2.ZERO
var is_opening_or_closing: bool = false
var inventory_ready_for_animation: bool = false
var current_category: int = ItemData.InventoryCategory.ITEM
enum InventoryMode {
	NORMAL,
	SELL
}
var selected_index: int = -1
var current_mode: InventoryMode = InventoryMode.NORMAL
var marked_for_sale: Dictionary = {} # { index: true }
var sell_target_shop = null
var sold_popup: AcceptDialog = null
var hover_tooltip: Panel = null
var hover_name_label: Label = null
var hover_desc_label: Label = null
var hovered_item: ItemData = null
var current_subfilter: String = "All"
var inventory_model: InventoryModel = null
var columns: int = 1

func _ready() -> void:

	visible = false	
	slot_button_scene = load(SLOT_BUTTON_SCENE_PATH) as PackedScene
	print("grid node",grid)
	hide()
	if items_btn != null:
		items_btn.pressed.connect(_on_items_pressed)

	if parts_btn != null:
		parts_btn.pressed.connect(_on_parts_pressed)

	if members_btn != null:
		members_btn.pressed.connect(_on_members_pressed)
	if money_label == null:
		push_error("InventoryOverlay: MoneyLabel path is wrong or node is missing.")
		return
	if subfilter != null:
		if not subfilter.item_selected.is_connected(_on_subfilter_select):
			subfilter.item_selected.connect(_on_subfilter_select)
	if grid == null:
		push_error("InventoryOverlay: GridContainer path is wrong or node is missing.")
		return

	_create_sold_popup()
	_create_hover_tooltip()

	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)

	if sell_total_label != null:
		#sell_total_label.text = "Total Profit: $0"
		sell_total_label.hide()

	if sell_confirm_btn != null:
		#sell_confirm_btn.text = "Sell"
		sell_confirm_btn.disabled = true
		sell_confirm_btn.hide()
		sell_confirm_btn.pressed.connect(_on_sell_confirm_pressed)

	if sell_cancel_btn != null:
		#sell_cancel_btn.text = "Cancel"
		sell_cancel_btn.hide()
		sell_cancel_btn.pressed.connect(_on_sell_cancel_pressed)

	_update_money(MoneySave.money)
	MoneySave.money_changed.connect(_update_money)
	_update_category_label()
	_populate_subfilter()
	await get_tree().process_frame
	await get_tree().process_frame

	panel_final_position = Vector2.ZERO

	var panel_height: float = get_viewport_rect().size.y
	panel_start_position = Vector2(0.0, -panel_height - 40.0)

	panel_mover.position = panel_start_position
	if bg != null:
		bg.modulate.a = 0.0
	visible = false
	inventory_ready_for_animation = true
func toggle_inventory() -> void:
	if is_opening_or_closing:
		return

	if visible:
		await close_inventory()
	else:
		await open_inventory()
func open_inventory() -> void:
	if is_opening_or_closing:
		return

	is_opening_or_closing = true
	visible = true

	panel_mover.position = panel_start_position

	if bg != null:
		bg.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)

	if bg != null:
		tween.tween_property(bg, "modulate:a", 1.0, 0.2)

	tween.tween_property(panel_mover, "position", panel_final_position, 0.28) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

	await tween.finished
	is_opening_or_closing = false
func close_inventory() -> void:
	if is_opening_or_closing:
		return

	is_opening_or_closing = true

	var tween := create_tween()
	tween.set_parallel(true)

	if bg != null:
		tween.tween_property(bg, "modulate:a", 0.0, 0.18)

	tween.tween_property(panel_mover, "position", panel_start_position, 0.22) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)

	await tween.finished

	hide()
	is_opening_or_closing = false
func _slot_matches_current_filter(slot_data: Variant) -> bool:
	if current_subfilter == "All":
		return true

	if slot_data == null:
		return false

	var item = slot_data.get("item", null)
	if item == null:
		return false

	var category := _get_item_category(item)
	if category != current_category:
		return false

	match current_category:
		ItemData.InventoryCategory.ITEM:
			return _get_item_subfilter(item) == _subfilter_string_to_item_enum(current_subfilter)

		ItemData.InventoryCategory.PART:
			return _get_part_subfilter(item) == _subfilter_string_to_part_enum(current_subfilter)

		ItemData.InventoryCategory.MEMBER:
			return _get_member_subfilter(item) == _subfilter_string_to_member_enum(current_subfilter)

	return true
func _subfilter_string_to_part_enum(name: String) -> int:
	match name:
		"Engine": return ItemData.PartSubfilter.ENGINE
		"Engine Housing": return ItemData.PartSubfilter.ENGINE_HOUSING
		"Wing": return ItemData.PartSubfilter.WING
		"Fuel Tank": return ItemData.PartSubfilter.FUEL_TANK
		"Nose Cone": return ItemData.PartSubfilter.NOSE_CONE
		"Body Panels": return ItemData.PartSubfilter.BODY_PANELS
		"Electrical Components": return ItemData.PartSubfilter.ELECTRICAL_COMPONENTS
	return ItemData.PartSubfilter.NONE


func _subfilter_string_to_item_enum(name: String) -> int:
	match name:
		"Iron": return ItemData.ItemSubfilter.IRON
		"Copper": return ItemData.ItemSubfilter.COPPER
		"Carbon Fiber": return ItemData.ItemSubfilter.CARBON_FIBER
		"Steel": return ItemData.ItemSubfilter.STEEL
		"Silicone": return ItemData.ItemSubfilter.SILICONE
		"Water": return ItemData.ItemSubfilter.WATER
	return ItemData.ItemSubfilter.NONE


func _subfilter_string_to_member_enum(name: String) -> int:
	match name:
		"Economy": return ItemData.MemberSubfilter.ECONOMY
		"Buff": return ItemData.MemberSubfilter.BUFF
		"Support": return ItemData.MemberSubfilter.SUPPORT
		"Luck": return ItemData.MemberSubfilter.LUCK
	return ItemData.MemberSubfilter.NONE
func _get_item_category(item) -> int:
	if item is PartInstance:
		return item.category
	if item is ItemData:
		return item.category
	return ItemData.InventoryCategory.ITEM


func _get_item_subfilter(item) -> int:
	if item is PartInstance:
		return item.item_subfilter
	if item is ItemData:
		return item.item_subfilter
	return ItemData.ItemSubfilter.NONE


func _get_part_subfilter(item) -> int:
	if item is PartInstance:
		return item.part_subfilter
	if item is ItemData:
		return item.part_subfilter
	return ItemData.PartSubfilter.NONE


func _get_member_subfilter(item) -> int:
	if item is PartInstance:
		return item.member_subfilter
	if item is ItemData:
		return item.member_subfilter
	return ItemData.MemberSubfilter.NONE


func _matches_item_subfilter(item) -> bool:
	match current_subfilter:
		"All":
			return true
		"Iron":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.IRON
		"Copper":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.COPPER
		"Carbon Fiber":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.CARBON_FIBER
		"Steel":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.STEEL
		"Silicone":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.SILICONE
		"Water":
			return _get_item_subfilter(item) == ItemData.ItemSubfilter.WATER
		_:
			return true


func _matches_part_subfilter(item) -> bool:
	match current_subfilter:
		"All":
			return true
		"Engine":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.ENGINE
		"Engine Housing":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.ENGINE_HOUSING
		"Wing":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.WING
		"Fuel Tank":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.FUEL_TANK
		"Nose Cone":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.NOSE_CONE
		"Body Panels":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.BODY_PANELS
		"Electrical Components":
			return _get_part_subfilter(item) == ItemData.PartSubfilter.ELECTRICAL_COMPONENTS
		_:
			return true


func _matches_member_subfilter(item) -> bool:
	match current_subfilter:
		"All":
			return true
		"Economy":
			return _get_member_subfilter(item) == ItemData.MemberSubfilter.ECONOMY
		"Buff":
			return _get_member_subfilter(item) == ItemData.MemberSubfilter.BUFF
		"Support":
			return _get_member_subfilter(item) == ItemData.MemberSubfilter.SUPPORT
		"Luck":
			return _get_member_subfilter(item) == ItemData.MemberSubfilter.LUCK
		_:
			return true

func _on_subfilter_select(index: int) -> void:
	current_subfilter = subfilter.get_item_text(index)
	_rebuild_grid()
func _populate_subfilter() -> void:
	if subfilter == null:
		return

	subfilter.clear()

	match current_category:
		ItemData.InventoryCategory.ITEM:
			subfilter.add_item("All")
			subfilter.add_item("Iron")
			subfilter.add_item("Steel")
			subfilter.add_item("Carbon Fiber")
			subfilter.add_item("Copper")
			subfilter.add_item("Silicone")
			subfilter.add_item("Water")

		ItemData.InventoryCategory.PART:
			subfilter.add_item("All")
			subfilter.add_item("Engine")
			subfilter.add_item("Engine Housing")
			subfilter.add_item("Wing")
			subfilter.add_item("Fuel Tank")
			subfilter.add_item("Nose Cone")
			subfilter.add_item("Body Panels")
			subfilter.add_item("Electrical Components")
		ItemData.InventoryCategory.MEMBER:
			subfilter.add_item("All")
			subfilter.add_item("Support")
			subfilter.add_item("Economy")
			subfilter.add_item("Buff")
			subfilter.add_item("Luck")

	subfilter.select(0)
	current_subfilter = "All"
func _update_category_label() -> void:
	match current_category:
		ItemData.InventoryCategory.ITEM:
			category_label.text = "Items"

		ItemData.InventoryCategory.PART:
			category_label.text = "Parts"

		ItemData.InventoryCategory.MEMBER:
			category_label.text = "Members"
func _on_items_pressed() -> void:
	current_category = ItemData.InventoryCategory.ITEM
	_update_category_label()
	_populate_subfilter()
	_rebuild_grid()

func _on_parts_pressed() -> void:
	current_category = ItemData.InventoryCategory.PART
	_update_category_label()
	_populate_subfilter()
	_rebuild_grid()

func _on_members_pressed() -> void:
	current_category = ItemData.InventoryCategory.MEMBER
	_update_category_label()
	_populate_subfilter()
	_rebuild_grid()
func _create_sold_popup() -> void:
	sold_popup = AcceptDialog.new()
	sold_popup.title = "Sale Complete"
	sold_popup.dialog_text = "Successfully sold."
	sold_popup.visible = false
	add_child(sold_popup)
func _show_sold_popup(total: int) -> void:
	if sold_popup == null:
		return

	sold_popup.dialog_text = "Successfully sold items for $" + str(total) + "."
	sold_popup.popup_centered()
func _process(delta: float) -> void:
	if hover_tooltip != null and hover_tooltip.visible:
		_update_hover_tooltip_position()

func _create_hover_tooltip() -> void:
	hover_tooltip = Panel.new()
	hover_tooltip.name = "HoverTooltip"
	hover_tooltip.visible = false
	hover_tooltip.custom_minimum_size = Vector2(220, 100)
	hover_tooltip.z_index = 1000
	hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_tooltip)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	hover_tooltip.add_child(vbox)

	hover_name_label = Label.new()
	hover_name_label.text = ""
	hover_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hover_name_label)

	hover_desc_label = Label.new()
	hover_desc_label.text = ""
	hover_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hover_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hover_desc_label)

func show_hover_tooltip(item: ItemData) -> void:
	if item == null or hover_tooltip == null:
		hide_hover_tooltip()
		return

	hovered_item = item
	hover_name_label.text = item.display_name
	hover_desc_label.text = item.description
	hover_tooltip.show()
	_update_hover_tooltip_position()

func hide_hover_tooltip() -> void:
	hovered_item = null
	if hover_tooltip != null:
		hover_tooltip.hide()

func _update_hover_tooltip_position() -> void:
	if hover_tooltip == null:
		return

	var mouse_pos := get_global_mouse_position()
	var offset := Vector2(16, 16)
	var desired_pos := mouse_pos + offset

	var viewport_rect := get_viewport_rect()
	var tooltip_size := hover_tooltip.size

	if desired_pos.x + tooltip_size.x > viewport_rect.size.x:
		desired_pos.x = mouse_pos.x - tooltip_size.x - 16

	if desired_pos.y + tooltip_size.y > viewport_rect.size.y:
		desired_pos.y = mouse_pos.y - tooltip_size.y - 16

	hover_tooltip.global_position = desired_pos

func set_inventory(model: InventoryModel) -> void:
	if inventory_model != null and inventory_model.changed.is_connected(_rebuild_grid):
		inventory_model.changed.disconnect(_rebuild_grid)

	inventory_model = model

	if inventory_model != null:
		if not inventory_model.changed.is_connected(_rebuild_grid):
			inventory_model.changed.connect(_rebuild_grid)

	_rebuild_grid()

func enter_sell_mode(shop_ref = null) -> void:
	current_mode = InventoryMode.SELL
	sell_target_shop = shop_ref
	marked_for_sale.clear()

	if sell_total_label != null:
		sell_total_label.show()

	if sell_confirm_btn != null:
		sell_confirm_btn.show()
		sell_confirm_btn.disabled = false

	if sell_cancel_btn != null:
		sell_cancel_btn.show()
		sell_cancel_btn.disabled = false

	current_subfilter = "All"
	_populate_subfilter()
	_update_sell_total()
	_rebuild_grid()
func exit_sell_mode() -> void:
	current_mode = InventoryMode.NORMAL
	sell_target_shop = null
	marked_for_sale.clear()

	if sell_total_label != null:
		sell_total_label.hide()

	if sell_confirm_btn != null:
		sell_confirm_btn.hide()
		sell_confirm_btn.disabled = true

	if sell_cancel_btn != null:
		sell_cancel_btn.hide()
		sell_cancel_btn.disabled = true

	_rebuild_grid()

func _update_money(amount: int) -> void:
	if money_label != null:
		money_label.text = "Money: " + str(amount)

func _update_sell_total() -> void:
	var total := 0

	if inventory_model != null:
		for i in marked_for_sale.keys():
			var slot = inventory_model.get_slot(int(i))
			if slot == null:
				continue

			var slot_item = slot.get("item", null)
			if slot_item == null:
				continue

			if slot_item is PartInstance:
				total += slot_item.shop_price
			elif slot_item is ItemData:
				var qty: int = int(slot.get("qty", 1))
				total += slot_item.sell_price * qty

	if sell_total_label != null:
		sell_total_label.text = "Total Profit: $" + str(total)

	_update_sell_buttons()
func _update_sell_buttons() -> void:
	var has_selection := not marked_for_sale.is_empty()

	if sell_confirm_btn != null:
		sell_confirm_btn.disabled = not has_selection
func _on_slot_selected(index: int, source_inventory: InventoryModel) -> void:
	if source_inventory == null:
		return

	var slot_data: Variant = source_inventory.get_slot(index)
	if slot_data == null:
		return

	if selected_index == index:
		selected_index = -1
	else:
		selected_index = index

	_rebuild_grid()
func _rebuild_grid() -> void:
	for c in grid.get_children():
		c.queue_free()

	if inventory_model == null:
		return

	var range_info: Dictionary = inventory_model.get_category_slot_range(current_category)
	var start_index: int = int(range_info["start"])
	var count: int = int(range_info["count"])

	grid.columns = 6

	for i in range(start_index, start_index + count):
		var slot: SlotButton = slot_button_scene.instantiate() as SlotButton
		if slot == null:
			push_error("SlotBtn.tscn failed to instance.")
			return

		slot.index = i
		slot.inventory_model = inventory_model
		slot.custom_minimum_size = slot_size

		match current_mode:
			InventoryMode.SELL:
				slot.interaction_mode = SlotButton.InteractionMode.SELL
				slot.marked_for_sale = marked_for_sale.has(i)
				slot.is_selected = marked_for_sale.has(i)

				if not slot.sell_toggled.is_connected(_on_slot_sell_toggled):
					slot.sell_toggled.connect(_on_slot_sell_toggled)

			_:
				slot.interaction_mode = SlotButton.InteractionMode.SELECT
				slot.is_selected = (i == selected_index)
				slot.marked_for_sale = false

		if not slot.slot_selected.is_connected(_on_slot_selected):
			slot.slot_selected.connect(_on_slot_selected)

		grid.add_child(slot)

		var slot_data: Variant = inventory_model.get_slot(i)
		var is_match: bool = _slot_matches_current_filter(slot_data)
		slot.set_filter_enabled(is_match)

		slot.call_deferred("refresh")

	if current_mode == InventoryMode.SELL:
		_update_sell_total()
func _on_slot_sell_toggled(index: int) -> void:
	if inventory_model == null:
		return

	var slot = inventory_model.get_slot(index)
	if slot == null:
		return

	if marked_for_sale.has(index):
		marked_for_sale.erase(index)
	else:
		marked_for_sale[index] = true

	_update_sell_total()
	_rebuild_grid()
func _on_sell_confirm_pressed() -> void:
	if inventory_model == null:
		return

	var total_profit: int = 0
	var indices_to_clear: Array[int] = []

	for i in marked_for_sale.keys():
		var slot_index: int = int(i)
		var slot = inventory_model.get_slot(slot_index)
		if slot == null:
			continue

		var slot_item = slot.get("item", null)
		if slot_item == null:
			continue

		if slot_item is PartInstance:
			total_profit += slot_item.shop_price
		elif slot_item is ItemData:
			var qty: int = int(slot.get("qty", 1))
			total_profit += slot_item.sell_price * qty

		indices_to_clear.append(slot_index)

	if total_profit > 0:
		MoneySave.add_money(total_profit)

	for slot_index in indices_to_clear:
		inventory_model.set_slot(slot_index, null)

	marked_for_sale.clear()
	selected_index = -1

	_update_sell_total()
	_rebuild_grid()
func _on_sell_cancel_pressed() -> void:
	var shop_ref = sell_target_shop
	exit_sell_mode()

	await close_inventory()

	if shop_ref != null:
		shop_ref.show()
func _on_close_pressed() -> void:
	hide_hover_tooltip()

	if current_mode == InventoryMode.SELL:
		var shop_ref = sell_target_shop
		exit_sell_mode()
		await close_inventory()

		if shop_ref != null:
			shop_ref.show()
		return

	await close_inventory()
