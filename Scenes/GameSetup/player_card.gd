extends VBoxContainer

#
# Code Handling Card Creation
#

@export var unconfigured_card_background:Texture2D
@export var configured_card_background:Texture2D

@onready var card_background = %CardBackground
@onready var card_foreground = %CardForeground

@onready var mission_icon_display = %MissionIcon

static var card_number:int = 0

const CARDS_TO_COLORS = {
	0: "res://Scenes/GameSetup/Images/BluePlayerSelect.svg",
	1: "res://Scenes/GameSetup/Images/RedPlayerSelect.svg",
	2: "res://Scenes/GameSetup/Images/GreenPlayerSelect.svg",
	3: "res://Scenes/GameSetup/Images/PurplePlayerSelect.svg"
}

func _set_texture_rect_texture_from_image_path(image_path: String, target_texture_rect: TextureRect) -> void:
	var target_texture := load(image_path) as Texture2D

	if target_texture == null:
		push_error("PlayerCard: failed to load texture at " + image_path)
		return

	target_texture_rect.texture = target_texture


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# Each instantiated card should have it's own color. If necessary, repeat colors.
	var target_image_path:String = CARDS_TO_COLORS[card_number % 4]
	_set_texture_rect_texture_from_image_path(target_image_path, card_background)
	card_number += 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
#	
# Code Handling Card Interactions
#

@onready var coin_slot = %CoinSlot
func _coin_inserted():
	pass
	

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is DiscoveryToken:
		data.rotate_to_click_position()
	return false
	
func handle_inserted_token(token:DiscoveryToken):
	pass

# Handle tokens dropped on the coin slot.
func _on_coin_slot_token_dropped(token: DiscoveryToken) -> void:
	card_foreground.texture = configured_card_background
	GlobalSettings.set_number_of_players(GlobalSettings.get_number_of_active_players() + 1)

	mission_icon_display.texture = load(token.image_texture)
