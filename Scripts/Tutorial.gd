extends Node2D

@onready var pause_menu: CanvasLayer = $CanvasLayer/PauseMenu
@onready var dialog_label: Label = $DialogLayer/DialogBox/DialogContainer/DialogText
@onready var bg_rect: TextureRect = $BackgroundLayer/Background
@onready var tutorialchar: TextureRect = $BackgroundLayer/Characters/Spaceman
@onready var contextimg: TextureRect = $ContextLayer/Context
@export var tutorial_type := "board"

signal intro_finished

var dialog_entries: Array = []
var current_index := 0

var board_dialog := [
	{
		"text": "Welcome to Psyche-Opoly. This game is inspired by NASA's Psyche mission, but it is not a literal simulation of the real mission. Press Space or left click to move through the tutorial.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Your goal is to complete quests as you travel between different NASA buildings. Each building represents a new stop where your crew can take on mission work.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "The game is not about finishing a set number of stages or collecting every item. Keep moving forward by finishing quests and visiting the NASA buildings on your route.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Press Space or click the Roll button on your turn to move. The spaces you land on can guide you toward quests, rewards, shops, or minigames.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Minigame tiles can launch a challenge. Winning minigames can help your crew earn rewards that make future quests easier.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Shops let you spend money on useful items and helpers. Pick what supports your current quests and helps your crew reach the next NASA building.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Some minigames allow multiple players, so choose the right player count before starting the board.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	},
	{
		"text": "Good luck. Complete quests, move through the NASA buildings, and keep your mission team advancing.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	}
]

var alien_dialog := [
	{
		"text": "Your crew has intercepted an alien signal. Type valid words using only the letters shown on the board before time runs out.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	}
]

var hanger_dialog := [
	{
		"text": "Your crew found a shipyard. Sort the ships correctly according to the rules to clear the challenge.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	}
]

var asteroid_dialog := [
	{
		"text": "Your crew has spotted the Psyche asteroid. Click the moving asteroid to keep advancing through the encounter.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	}
]

var genisis_dialog := [
	{
		"text": "Your crew has found the Genesis craft drifting through space. Collect different kinds of solar wind to help the mission.",
		"bg": "",
		"tutorialchar": "res://Sources/Images/SpacemanCharacter1.png",
		"context": ""
	}
]

func _ready() -> void:
	match tutorial_type:
		"board":
			dialog_entries = board_dialog
		"alien_communication":
			dialog_entries = alien_dialog
		"hanger":
			dialog_entries = hanger_dialog
		"AsteroidTargeting1":
			dialog_entries = asteroid_dialog
		"genesis":
			dialog_entries = genisis_dialog
		_:
			push_error("tutorial.gd: unrecognized tutorial_type '%s'" % tutorial_type)
			dialog_entries = []

	_show_dialog_entry(current_index)
	pause_menu.connect("main_menu_requested", Callable(self, "_on_pause_main_menu"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.toggle()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		advance_dialog()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance_dialog()

func _set_tex(rect: TextureRect, path: Variant, label_name: String) -> void:
	if rect == null:
		push_error("TextureRect is NULL for: " + label_name)
		return

	if path == null or String(path) == "":
		rect.texture = null
		rect.visible = false
		return

	var tex := load(String(path)) as Texture2D
	if tex == null:
		push_error("Failed to load texture for " + label_name + " at: " + String(path))
		rect.texture = null
		rect.visible = false
		return

	rect.texture = tex
	rect.visible = true

func _on_pause_main_menu() -> void:
	get_tree().paused = false
	Navigator.go_to_scene_by_path("res://Scenes/main_menu.tscn")

func _show_dialog_entry(index: int) -> void:
	if index < 0 or index >= dialog_entries.size():
		return

	var entry: Dictionary = dialog_entries[index]
	
	if dialog_label == null:
		push_error("dialog_label is null!")
	else:
		dialog_label.text = entry.get("text", "")
	
	_set_tex(bg_rect, entry.get("bg", ""), "BG")
	_set_tex(tutorialchar, entry.get("tutorialchar", ""), "Char")
	_set_tex(contextimg, entry.get("context", ""), "Context")

func _check_visibility_chain(node: Node) -> String:
	var result := ""
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			result = "%s(visible=%s) -> " % [current.name, (current as CanvasItem).visible] + result
		current = current.get_parent()
	return result

func advance_dialog() -> void:
	current_index += 1

	if current_index < dialog_entries.size():
		_show_dialog_entry(current_index)
	else:
		if get_parent() == get_tree().root:
			Navigator.go_to_scene_by_path("res://Scenes/main_board.tscn")
		else:
			intro_finished.emit()
