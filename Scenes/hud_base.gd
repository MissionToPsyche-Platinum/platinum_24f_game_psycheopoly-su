extends Control

@onready var inv_btn: BaseButton = %InvBtn

@onready var inventory_overlay: InventoryOverlay = get_node("../../Overlay/OverlayRoot/Inventory")
@onready var player_inventory: InventoryModel = get_node("../../CharacterBody2D/InventoryModel")


func _on_inv_btn_pressed() -> void:
	if inventory_overlay == null:
		push_error("InventoryOverlay not found")
		return

	if player_inventory == null:
		push_error("InventoryModel not found")
		return

	inventory_overlay.set_inventory(player_inventory)

	if inventory_overlay.visible:
		await inventory_overlay.close_inventory()
	else:
		await inventory_overlay.open_inventory()
