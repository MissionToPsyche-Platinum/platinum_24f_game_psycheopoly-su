extends Node2D
class_name MainBoard

signal board_ready
signal branch_choice_requested(root_index: int, main_next_index: int, branch_next_index: int)
signal branch_path_chosen(next_index: int)
signal branch_prompt_opened(root_index: int)
signal branch_prompt_closed(chose_branch: bool, next_index: int)

@export var cell_size: Vector2i = Vector2i(64, 64)
@export var tile_count: int = 120
@export var tile_spacing_x: int = 24

@export var min_special_spacing: int = 2
@export var chance_tile_target: int=22
@export var red_tile_target: int = 12
@export var shop_tile_target: int = 6
@export var event_tile_target: int = 10
@export var treasure_tile_target: int = 8
@export var min_shop_spacing: int = 12
@export var min_shop_distance_from_start: int = 15

@export var branches_enabled: bool = true
@export var branch_count: int = 3
@export var min_branch_start_distance: int = 25
@export var branch_tile_count: int = 20
@export var min_spaces_between_branches: int = 20
@export_enum("Above", "Below", "Alternate", "Random") var branch_side: String = "Alternate"
@export var branch_gap_y: int = 140
@export var branch_choice_scene: PackedScene = preload("res://Scenes/UI/ConfirmSwitch.tscn")

@onready var overlay_root: Control = get_node_or_null("Overlay/OverlayRoot") as Control
@onready var game_root: Control = $GameOverlay/GameRoot

var rng := RandomNumberGenerator.new()

var tile_positions: Array[Vector2] = []
var red_tile_indices: Array[int] = []
var shop_tile_indices: Array[int] = []
var event_tile_indices: Array[int] = []
var treasure_tile_indices: Array[int] = []
var chance_tile_indices: Array[int]=[]

var start_tile_index: int = 0

var branches: Array[Dictionary] = []
var branch_roots: Array[int] = []
var branch_rejoins: Array[int] = []
var all_branch_indices: Array[int] = []
var branch_index_to_root: Dictionary = {}

var selected_branch_next_index: int = -1
var selected_branch_root_index: int = -1
var _branch_prompt: Control = null
var _branch_choice_active: bool = false
var _active_prompt_root_index: int = -1

func _ready() -> void:
	rng.randomize()
	_setup_board_delayed()

func _setup_board_delayed() -> void:
	await get_tree().process_frame
	initialize_board()
	queue_redraw()
	board_ready.emit()

func initialize_board() -> void:
	tile_positions.clear()
	red_tile_indices.clear()
	shop_tile_indices.clear()
	event_tile_indices.clear()
	treasure_tile_indices.clear()
	branches.clear()
	branch_roots.clear()
	branch_rejoins.clear()
	all_branch_indices.clear()
	branch_index_to_root.clear()
	selected_branch_next_index = -1
	selected_branch_root_index = -1
	_active_prompt_root_index = -1
	_generate_positions()
	_generate_special_tiles()

func _generate_positions() -> void:
	_generate_main_path_positions()
	if branches_enabled:
		_generate_branch_positions()

func _generate_main_path_positions() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var y: float = floor(viewport_size.y * 0.5) - cell_size.y / 2.0
	var current_x: float = 40.0
	var step_x: float = float(cell_size.x + tile_spacing_x)
	for i in range(tile_count):
		tile_positions.append(Vector2(current_x, y))
		current_x += step_x

func _generate_branch_positions() -> void:
	var usable_branch_length: int = max(branch_tile_count, 20)
	var earliest_root: int = clamp(min_branch_start_distance, 1, max(1, tile_count - 2))
	var latest_root: int = tile_count - usable_branch_length - 2
	if latest_root < earliest_root:
		push_warning("Board is too short for a 20-tile branch. Increase tile_count or lower branch_tile_count.")
		return

	var desired_count: int = max(branch_count, 1)
	var step_x: float = float(cell_size.x + tile_spacing_x)
	var next_min_root: int = earliest_root

	for branch_number in range(desired_count):
		if next_min_root > latest_root:
			break

		var remaining_branches: int = desired_count - branch_number - 1
		var max_root_for_spacing: int = latest_root - remaining_branches * (usable_branch_length + min_spaces_between_branches + 1)
		if max_root_for_spacing < next_min_root:
			max_root_for_spacing = latest_root

		var root_index: int = rng.randi_range(next_min_root, max_root_for_spacing)
		var rejoin_index: int = root_index + usable_branch_length + 1
		if rejoin_index >= tile_count:
			break

		var side_multiplier: int = _get_branch_side_multiplier(branch_number)
		var branch_tiles: Array[int] = []
		var root_pos: Vector2 = tile_positions[root_index]

		for b in range(usable_branch_length):
			var new_index: int = tile_positions.size()
			branch_tiles.append(new_index)
			all_branch_indices.append(new_index)
			branch_index_to_root[new_index] = root_index
			var pos := Vector2(root_pos.x + step_x * float(b + 1), root_pos.y + float(branch_gap_y) * float(side_multiplier))
			tile_positions.append(pos)

		branches.append({
			"root": root_index,
			"rejoin": rejoin_index,
			"tiles": branch_tiles,
			"side": side_multiplier
		})
		branch_roots.append(root_index)
		branch_rejoins.append(rejoin_index)

		next_min_root = rejoin_index + min_spaces_between_branches

func _get_branch_side_multiplier(branch_number: int) -> int:
	match branch_side:
		"Above":
			return -1
		"Below":
			return 1
		"Random":
			return -1 if rng.randi_range(0, 1) == 0 else 1
		_:
			return -1 if branch_number % 2 == 0 else 1

func _generate_special_tiles() -> void:
	var usable_indices: Array[int] = []
	for i in range(1, tile_positions.size()):
		usable_indices.append(i)
	usable_indices.shuffle()
	_place_special_tiles(usable_indices, "red", red_tile_target)
	usable_indices.shuffle()
	_place_special_tiles(usable_indices, "event", event_tile_target)
	usable_indices.shuffle()
	_place_special_tiles(usable_indices, "treasure", treasure_tile_target)
	usable_indices.shuffle()
	_place_special_tiles(usable_indices, "shop", shop_tile_target)
	usable_indices.shuffle()
	_place_special_tiles(usable_indices,"chance",chance_tile_target)
	
	red_tile_indices.sort()
	shop_tile_indices.sort()
	event_tile_indices.sort()
	treasure_tile_indices.sort()
	chance_tile_indices.sort()

func _place_special_tiles(usable_indices: Array[int], tile_type: String, target_count: int) -> void:
	var placed_count: int = 0
	for idx in usable_indices:
		if placed_count >= target_count:
			break
		if _can_place_special(idx, tile_type):
			match tile_type:
				"red": red_tile_indices.append(idx)
				"shop": shop_tile_indices.append(idx)
				"event": event_tile_indices.append(idx)
				"treasure": treasure_tile_indices.append(idx)
				"chance":chance_tile_indices.append(idx)
			placed_count += 1

func _can_place_special(index: int, tile_type: String) -> bool:
	if index == start_tile_index:
		return false
	if branch_roots.has(index) or branch_rejoins.has(index):
		return false
	if tile_type == "shop" and path_distance_from_start(index) < min_shop_distance_from_start:
		return false
	if red_tile_indices.has(index) or shop_tile_indices.has(index) or event_tile_indices.has(index) or treasure_tile_indices.has(index):
		return false
	for red_idx in red_tile_indices:
		if abs(path_distance_from_start(index) - path_distance_from_start(red_idx)) < min_special_spacing:
			return false
	for event_idx in event_tile_indices:
		if abs(path_distance_from_start(index) - path_distance_from_start(event_idx)) < min_special_spacing:
			return false
	for treasure_idx in treasure_tile_indices:
		if abs(path_distance_from_start(index) - path_distance_from_start(treasure_idx)) < min_special_spacing:
			return false
	for shop_idx in shop_tile_indices:
		if tile_type == "shop":
			if abs(path_distance_from_start(index) - path_distance_from_start(shop_idx)) < min_shop_spacing:
				return false
		else:
			if abs(path_distance_from_start(index) - path_distance_from_start(shop_idx)) < min_special_spacing:
				return false
	return true

func get_tile_center(index: int) -> Vector2:
	if index < 0 or index >= tile_positions.size():
		return Vector2.ZERO
	return tile_positions[index] + Vector2(cell_size.x / 2.0, cell_size.y / 2.0)

func get_tile_center_global(index: int) -> Vector2:
	return to_global(get_tile_center(index))

func get_start_center() -> Vector2:
	if tile_positions.is_empty():
		return global_position
	return get_tile_center_global(start_tile_index)

func is_shop_tile(index: int) -> bool:
	return shop_tile_indices.has(index)
func is_chance_tile(tile_index: int) -> bool:
	return chance_tile_indices.has(tile_index)
func is_red_tile(index: int) -> bool:
	return red_tile_indices.has(index)

func is_event_tile(index: int) -> bool:
	return event_tile_indices.has(index)

func is_treasure_tile(index: int) -> bool:
	return treasure_tile_indices.has(index)

func is_branch_tile(index: int) -> bool:
	return all_branch_indices.has(index)

func is_branch_root(index: int) -> bool:
	return branch_roots.has(index)

func is_branch_rejoin(index: int) -> bool:
	return branch_rejoins.has(index)

func is_valid_tile(index: int) -> bool:
	return index >= 0 and index < tile_positions.size()

func get_tile_count() -> int:
	return tile_count

func get_total_drawn_tile_count() -> int:
	return tile_positions.size()

func should_show_path_choice(index: int) -> bool:
	return branch_roots.has(index) and _get_branch_for_root(index).size() > 0

func _get_branch_for_root(root_index: int) -> Dictionary:
	for branch in branches:
		if int(branch.get("root", -1)) == root_index:
			return branch
	return {}

func _get_branch_for_tile(tile_index: int) -> Dictionary:
	if not branch_index_to_root.has(tile_index):
		return {}
	return _get_branch_for_root(int(branch_index_to_root[tile_index]))

func get_next_tile_options(index: int) -> Array[int]:
	var options: Array[int] = []
	if should_show_path_choice(index):
		var branch := _get_branch_for_root(index)
		var tiles: Array = branch.get("tiles", [])
		if index + 1 < tile_count:
			options.append(index + 1)
		if not tiles.is_empty():
			options.append(int(tiles[0]))
		return options

	if is_branch_tile(index):
		var branch := _get_branch_for_tile(index)
		var tiles: Array = branch.get("tiles", [])
		var branch_pos: int = tiles.find(index)
		if branch_pos >= 0 and branch_pos + 1 < tiles.size():
			options.append(int(tiles[branch_pos + 1]))
		else:
			var rejoin_index: int = int(branch.get("rejoin", -1))
			if rejoin_index >= 0 and rejoin_index < tile_count:
				options.append(rejoin_index)
			else:
				options.append(start_tile_index)
		return options

	if index + 1 < tile_count:
		options.append(index + 1)
	else:
		options.append(start_tile_index)
	return options

func get_next_tile_index(index: int) -> int:
	# Use this instead of current_tile + 1 or modulo movement.
	# When the player is on a fork, do not move until that fork gets a choice.
	if should_show_path_choice(index):
		if selected_branch_root_index == index and selected_branch_next_index != -1:
			var chosen_next: int = selected_branch_next_index
			selected_branch_next_index = -1
			selected_branch_root_index = -1
			return chosen_next
		return index

	var options := get_next_tile_options(index)
	if options.is_empty():
		return start_tile_index
	return options[0]

func reset_branch_choice() -> void:
	selected_branch_next_index = -1
	selected_branch_root_index = -1

func path_distance_from_start(index: int) -> int:
	if is_branch_tile(index):
		var branch := _get_branch_for_tile(index)
		var tiles: Array = branch.get("tiles", [])
		return int(branch.get("root", 0)) + 1 + tiles.find(index)
	return index

func request_branch_choice(root_index: int = -1) -> int:

	if root_index < 0:
		root_index = _active_prompt_root_index
	if not should_show_path_choice(root_index):
		return root_index + 1
	if _branch_choice_active:
		await branch_path_chosen
		return selected_branch_next_index

	var branch := _get_branch_for_root(root_index)
	var tiles: Array = branch.get("tiles", [])
	if tiles.is_empty():
		return root_index + 1

	_branch_choice_active = true
	_active_prompt_root_index = root_index
	var main_next: int = root_index + 1
	var branch_next: int = int(tiles[0])
	branch_choice_requested.emit(root_index, main_next, branch_next)
	branch_prompt_opened.emit(root_index)

	if _branch_prompt != null:
		_branch_prompt.queue_free()
		_branch_prompt = null

	var parent_node: Node = overlay_root if overlay_root != null else self
	if overlay_root != null:
		overlay_root.visible = true
	var prompt: Control = null
	if branch_choice_scene != null:
		prompt = branch_choice_scene.instantiate() as Control
	else:
		prompt = _create_fallback_branch_prompt(root_index)

	parent_node.add_child(prompt)
	_branch_prompt = prompt
	_configure_branch_prompt(prompt)

	var chose_branch: bool = false
	if prompt.has_signal("choice"):
		chose_branch = await prompt.choice
	else:
		await branch_path_chosen
		_branch_choice_active = false
		return selected_branch_next_index

	var next_index: int = branch_next if chose_branch else main_next
	_select_branch_path(root_index, next_index, chose_branch)
	return next_index

func _configure_branch_prompt(prompt: Control) -> void:
	prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt.set_offsets_preset(Control.PRESET_FULL_RECT)
	prompt.position = Vector2.ZERO
	prompt.global_position = Vector2.ZERO
	prompt.size = get_viewport_rect().size
	prompt.visible = true

	if prompt.has_method("setup_prompt"):
		prompt.setup_prompt(
			"Choose a path\nTake the branch or stay on the main road?",
			"Take Branch",
			"Stay Main"
		)
	else:
		prompt.set("title_text", "Choose a path\nTake the branch or stay on the main road?")
		prompt.set("play_text", "Take Branch")
		prompt.set("skip_text", "Stay Main")

func _create_fallback_branch_prompt(root_index: int) -> Control:
	var panel := Panel.new()
	panel.name = "BranchChoicePrompt"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 150)
	panel.offset_left = -180
	panel.offset_top = -75
	panel.offset_right = 180
	panel.offset_bottom = 75
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	var label := Label.new()
	label.text = "Choose a path"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	var main_button := Button.new()
	main_button.text = "Stay Main"
	buttons.add_child(main_button)
	var branch_button := Button.new()
	branch_button.text = "Take Branch"
	buttons.add_child(branch_button)
	main_button.pressed.connect(func() -> void:
		_select_branch_path(root_index, root_index + 1, false)
	)
	branch_button.pressed.connect(func() -> void:
		var branch := _get_branch_for_root(root_index)
		var tiles: Array = branch.get("tiles", [])
		if not tiles.is_empty():
			_select_branch_path(root_index, int(tiles[0]), true)
	)
	return panel

func _select_branch_path(root_index: int, next_index: int, chose_branch: bool = false) -> void:
	selected_branch_root_index = root_index
	selected_branch_next_index = next_index
	if _branch_prompt != null and is_instance_valid(_branch_prompt):
		if not _branch_prompt.is_queued_for_deletion():
			_branch_prompt.queue_free()
	_branch_prompt = null
	_branch_choice_active = false
	_active_prompt_root_index = -1
	branch_prompt_closed.emit(chose_branch, next_index)
	branch_path_chosen.emit(next_index)

func move_index_by_steps(current_index: int, steps: int) -> int:
	var index := current_index
	var remaining := steps
	while remaining > 0:
		if should_show_path_choice(index):
			return index
		var next_index := get_next_tile_index(index)
		if next_index == index:
			return index
		index = next_index
		remaining -= 1
		if should_show_path_choice(index):
			return index
	return index

func _draw() -> void:
	if tile_positions.is_empty():
		return
	_draw_path_lines()
	_draw_tiles()

func _draw_path_lines() -> void:
	for i in range(tile_count - 1):
		draw_line(get_tile_center(i), get_tile_center(i + 1), Color(0.85, 0.85, 0.85), 6.0)
	for branch in branches:
		var root_index: int = int(branch.get("root", -1))
		var rejoin_index: int = int(branch.get("rejoin", -1))
		var tiles: Array = branch.get("tiles", [])
		if root_index < 0 or tiles.is_empty():
			continue
		draw_line(get_tile_center(root_index), get_tile_center(int(tiles[0])), Color(0.85, 0.85, 0.85), 6.0)
		for b in range(tiles.size() - 1):
			draw_line(get_tile_center(int(tiles[b])), get_tile_center(int(tiles[b + 1])), Color(0.85, 0.85, 0.85), 6.0)
		if rejoin_index >= 0:
			draw_line(get_tile_center(int(tiles[tiles.size() - 1])), get_tile_center(rejoin_index), Color(0.85, 0.85, 0.85), 6.0)

func _draw_tiles() -> void:
	for i in range(tile_positions.size()):
		var pos: Vector2 = tile_positions[i]
		var rect := Rect2(pos, Vector2(cell_size))
		var tile_color := Color(0.45, 0.45, 0.45)
		if i == start_tile_index:
			tile_color = Color(0.2, 0.85, 0.2)
		elif branch_roots.has(i):
			tile_color = Color(1.0, 0.75, 0.15)
		elif branch_rejoins.has(i):
			tile_color = Color(1.0, 0.75, 0.15)
		elif red_tile_indices.has(i):
			tile_color = Color(0.9, 0.2, 0.2)
		elif shop_tile_indices.has(i):
			tile_color = Color(0.2, 0.65, 1.0)
		elif event_tile_indices.has(i):
			tile_color = Color(0.65, 0.35, 1.0)
		elif treasure_tile_indices.has(i):
			tile_color = Color(1.0, 0.85, 0.2)
		elif chance_tile_indices.has(i):
			tile_color= Color(0.7,0.6,0.9)
		elif all_branch_indices.has(i):
			tile_color = Color(0.35, 0.55, 0.75)
		draw_rect(rect, tile_color, true)
		draw_rect(rect, Color.WHITE, false, 2.0)
