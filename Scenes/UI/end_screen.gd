extends Control
class_name EndScreen

@onready var title_label: Label = $CenterContainer/VBoxContainer/title_label
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/subtitle_label
@onready var quest_list: VBoxContainer = $CenterContainer/VBoxContainer/QuestList
@onready var credits_btn: Button = $CornerButtons/HBoxContainer/CreditsBtn
@onready var restart_btn: Button = $CornerButtons/HBoxContainer/RestartBtn
@onready var space: TextureRect = $Space

var is_win: bool = false
var color_overlay: ColorRect

const QUEST_DISPLAY_DURATION: float = 3.0
const FADE_DURATION: float = 1.0
const WIN_BG_COLOR := Color(0.05, 0.12, 0.7, 0.6)
const LOSE_BG_COLOR := Color(0.7, 0.04, 0.04, 0.6)

func _ready() -> void:
	color_overlay = ColorRect.new()
	color_overlay.color = Color(0, 0, 0, 0)
	color_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(color_overlay)
	move_child(color_overlay, get_node("CenterContainer").get_index())
	var vbox: VBoxContainer = $CenterContainer/VBoxContainer
	vbox.custom_minimum_size = Vector2(500, 0)
	for child in vbox.get_children():
		if child is Label:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func setup(won: bool) -> void:
	is_win = won
	if title_label != null:
		title_label.text = "MISSION COMPLETE" if won else "MISSION FAILED"
	if subtitle_label != null:
		subtitle_label.modulate.a = 0.0
		subtitle_label.text = (
			"You arrive at the NASA board meeting, papers in hand, and you present your new discovery mission. Everyone there is entranced by your mission and everyone signs on"
			if won else
			"You arrive at the NASA board meeting, you got so close to realizing your mission but you sadly failed. Better luck next time"
		)
	_populate_quest_status()
	_start_transition()

func _start_transition() -> void:
	await get_tree().create_timer(QUEST_DISPLAY_DURATION).timeout
	_do_transition()

func _do_transition() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(color_overlay, "color", WIN_BG_COLOR if is_win else LOSE_BG_COLOR, FADE_DURATION)
	tween.tween_property(quest_list, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_property(title_label, "modulate:a", 0.0, FADE_DURATION)
	if subtitle_label != null:
		tween.tween_property(subtitle_label, "modulate:a", 1.0, FADE_DURATION)

func _populate_quest_status() -> void:
	if quest_list == null:
		return
	for child in quest_list.get_children():
		child.queue_free()
	for i in range(1, 4):
		var q: Quest = QuestManager.get_quest(i)
		if q == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := Label.new()
		icon.text = "COMPLETE" if q.is_complete else "incomplete"
		icon.add_theme_font_size_override("font_size", 18)
		icon.add_theme_color_override(
			"font_color",
			Color(0.2, 0.9, 0.3) if q.is_complete else Color(0.9, 0.2, 0.2)
		)
		row.add_child(icon)
		quest_list.add_child(row)

func _on_credits_pressed() -> void:
	if has_node("/root/Navigator"):
		Navigator.call_deferred("go_to_scene_by_path", "res://Scenes/Credits/credits.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Credits/credits.tscn")
