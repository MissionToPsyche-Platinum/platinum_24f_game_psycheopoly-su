extends Button

@export var target_scene: PackedScene
@export var target_scene_path: String
@export var reset_game_on_press: bool = false

var click_sound_player: AudioStreamPlayer

func _ready() -> void:
	if (target_scene == null) and (target_scene_path == "" or target_scene_path == null):
		push_error("It looks like the button titled {name} wasn't given a target scene to switch too.select the node in the editor and provide one.".format({"name":self.name}))

	if (target_scene != null) and (target_scene_path != "" or target_scene_path != null):
		push_warning("Both a target (packed) scene and a target scene path (string) were specified. Only one option will be used.\n\tNode: %s" % [self.name])

	self.pressed.connect(_on_press)
	
	# Initialize the click player if it has not been initialized already by a previous button.
	if click_sound_player == null:
		click_sound_player = AudioStreamPlayer.new()
		click_sound_player.stream = load("res://Sources/Sounds/Click.wav")
		add_child(click_sound_player)
		
	
		
func _on_press():
	if reset_game_on_press:
		var reset_owner := owner
		if reset_owner != null and reset_owner.has_method("reset_for_new_game"):
			reset_owner.reset_for_new_game()
		else:
			push_warning("Button '%s' was asked to reset the game, but its owner has no reset_for_new_game method." % self.name)

	_play_click_sound()
	
	await get_tree().create_timer(click_sound_player.stream.get_length()).timeout
	
	_switch_scenes()
	
func _switch_scenes():
	
	if (target_scene != null):
		Navigator.go_to_packed_scene(target_scene)
	
	elif (target_scene_path != null):
		Navigator.go_to_scene_by_path(target_scene_path)

func _play_click_sound():
	
	if click_sound_player.playing:
		click_sound_player.stop()
	
	if GlobalSettings.click_sound_enabled:
		click_sound_player.play()
