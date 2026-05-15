extends Control
@onready var fade_rect: ColorRect =$FadeLayer/FadeRect

var click_player: AudioStreamPlayer
var target_scene: PackedScene
#signal request_transition
@export var play_target_scene: PackedScene
func _ready():
	# Create the audio player
	click_player = AudioStreamPlayer.new()
	add_child(click_player)

	# Load the click sound file
	click_player.stream = load("res://Sources/Sounds/click.wav")

	fade_rect.color.a=1.0
	var tween := create_tween()
	tween.tween_property(fade_rect,"color:a",0.0,0.4)

	# Link to external Psyche Resources
	%PsycheMissionLink.pressed.connect(_on_external_link_pressed)


	
func _on_external_link_pressed():
	click_player.play()
	await get_tree().create_timer(click_player.stream.get_length()).timeout
	OS.shell_open("https://psyche.ssl.berkeley.edu/mission/faq/")
	
# Handle General Button Transitions to New Scenes
func _transition_to_scene(load_scene: PackedScene) ->void:
	var tween := create_tween()
	tween.tween_property(fade_rect,"color:a",1.0,0.4)
	await tween.finished
	get_tree().change_scene_to_packed(load_scene)
	
func _click_then_transition(load_scene: PackedScene):
	if click_player and click_player.stream:
		click_player.play()
		await get_tree().create_timer(click_player.stream.get_length()).timeout
	await _transition_to_scene(load_scene)

func _on_request_transition(load_scene: PackedScene) -> void:
	await _click_then_transition(load_scene)

func reset_for_new_game() -> void:
	if has_node("/root/Navigator"):
		var current_scene := get_tree().current_scene
		for scene_node in Navigator.scenes_in_memory.values():
			if is_instance_valid(scene_node) and scene_node != current_scene:
				scene_node.queue_free()
		Navigator.scenes_in_memory.clear()
		Navigator.previous_scene_stack.clear()

	if has_node("/root/playerPos"):
		playerPos.savedPosition = Vector2.ZERO
		playerPos.savedTurn = 0

	if has_node("/root/CurGameState"):
		CurGameState.total_difficulty_reduction = 0
		CurGameState.total_time_bonus = 0
		CurGameState.cbroot_stat = 0.0

		if CurGameState.inventory != null:
			CurGameState.inventory.clear()

	if has_node("/root/MoneySave"):
		MoneySave.money = 100

	if has_node("/root/Settings"):
		Settings.play_tutorial = true

	if has_node("/root/GlobalSettings"):
		GlobalSettings.number_of_players = 0
		GlobalSettings.next_player_id = 0
		GlobalSettings.players.clear()
		GlobalSettings.active_players.clear()
		GlobalSettings.used_buttons.clear()

func _reset_main_board_memory_for_new_game() -> void:
	reset_for_new_game()


func _on_confirm_pressed() -> void:
	if play_target_scene == null:
		push_error("MainMenu: play_target_scene not set")
		return

	reset_for_new_game()
	await _click_then_transition(play_target_scene)
