extends RefCounted
class_name Quest

enum Type { MISSION, SUBFILTER, STAT, COMBO_MISSION_SUBFILTER, COMBO_MISSION_STAT, COMBO_SUBFILTER_STAT }

const POSSIBLE_MISSIONS: Array[String] = [
	"NEAR Shoemaker",
	"Psyche",
	"Lucy",
	"InSight",
	"Mars Pathfinder",
	"Stardust",
	"Genisis",
	"MESSENGER",
	"Deep Impact",
	"Dawn",
	"Kepler Space Telescope",
	"GRAIL",
]

const POSSIBLE_SUBFILTERS: Array[String] = [
	"ENGINE",
	"WING",
	"FUEL_TANK",
	"NOSE_CONE",
	"BODY_PANELS",
	"ELECTRICAL_COMPONENTS",
	"ENGINE_HOUSING",
]

const POSSIBLE_STATS: Array[String] = [
	"Aerodynamics",
	"Weight",
	"Cost",
	"Repairability",
	"Acceleration",
]

var type: Type
var title: String = ""
var description: String = ""
var is_complete: bool = false

var target_mission: String = ""
var target_subfilter: String = ""
var target_stat: String = ""
var required_count: int = 1
var required_stat_value: float = 10.0
var sub_quest_a: Quest = null
var sub_quest_b: Quest = null

static func create(quest_type: Type, used_targets: Array[String]) -> Quest:
	var q := Quest.new()
	q.type = quest_type
	q._setup(used_targets)
	return q

func check_completion(inventory: InventoryModel) -> bool:
	if inventory == null:
		return false
	match type:
		Type.MISSION:
			return inventory.get_count_by_mission(target_mission) >= required_count
		Type.SUBFILTER:
			return inventory.get_count_by_subfilter(_subfilter_to_enum(target_subfilter)) >= required_count
		Type.STAT:
			return inventory.get_total_stat(target_stat) >= required_stat_value
		Type.COMBO_MISSION_SUBFILTER, Type.COMBO_MISSION_STAT, Type.COMBO_SUBFILTER_STAT:
			return sub_quest_a.check_completion(inventory) and sub_quest_b.check_completion(inventory)
	return false

func _setup(used_targets: Array[String]) -> void:
	match type:
		Type.MISSION:
			target_mission = _pick_unused(POSSIBLE_MISSIONS, used_targets)
			title = "Mission Collector"
			description = "Collect at least 1 item from: %s" % target_mission
		Type.SUBFILTER:
			target_subfilter = _pick_unused(POSSIBLE_SUBFILTERS, used_targets)
			required_count = 2
			title = "Part Collector"
			description = "Collect %d parts of type: %s" % [required_count, target_subfilter]
		Type.STAT:
			target_stat = _pick_unused(POSSIBLE_STATS, used_targets)
			required_stat_value = 50.0
			title = "Stat Threshold"
			description = "Reach %.0f total %s" % [required_stat_value, target_stat]
		Type.COMBO_MISSION_SUBFILTER:
			sub_quest_a = Quest.create(Type.MISSION, used_targets)
			used_targets.append(sub_quest_a.get_used_target())
			sub_quest_b = Quest.create(Type.SUBFILTER, used_targets)
			used_targets.append(sub_quest_b.get_used_target())
			title = "Mission & Parts"
			description = "%s\nAND: %s" % [sub_quest_a.description, sub_quest_b.description]
		Type.COMBO_MISSION_STAT:
			sub_quest_a = Quest.create(Type.MISSION, used_targets)
			used_targets.append(sub_quest_a.get_used_target())
			sub_quest_b = Quest.create(Type.STAT, used_targets)
			used_targets.append(sub_quest_b.get_used_target())
			title = "Mission & Stats"
			description = "%s\nAND: %s" % [sub_quest_a.description, sub_quest_b.description]
		Type.COMBO_SUBFILTER_STAT:
			sub_quest_a = Quest.create(Type.SUBFILTER, used_targets)
			used_targets.append(sub_quest_a.get_used_target())
			sub_quest_b = Quest.create(Type.STAT, used_targets)
			used_targets.append(sub_quest_b.get_used_target())
			title = "Parts & Stats"
			description = "%s\nAND: %s" % [sub_quest_a.description, sub_quest_b.description]

func get_used_target() -> String:
	match type:
		Type.MISSION:   return target_mission
		Type.SUBFILTER: return target_subfilter
		Type.STAT:      return target_stat
		Type.COMBO_MISSION_SUBFILTER, Type.COMBO_MISSION_STAT, Type.COMBO_SUBFILTER_STAT:
			return "%s|%s" % [sub_quest_a.get_used_target(), sub_quest_b.get_used_target()]
	return ""

func _pick_unused(pool: Array[String], used: Array[String]) -> String:
	var available := pool.filter(func(s): return not used.has(s))
	if available.is_empty():
		available = pool.duplicate()
	return available[randi() % available.size()]

func _subfilter_to_enum(name: String) -> int:
	match name:
		"ENGINE":                return ItemData.PartSubfilter.ENGINE
		"WING":                  return ItemData.PartSubfilter.WING
		"FUEL_TANK":             return ItemData.PartSubfilter.FUEL_TANK
		"NOSE_CONE":             return ItemData.PartSubfilter.NOSE_CONE
		"BODY_PANELS":           return ItemData.PartSubfilter.BODY_PANELS
		"ELECTRICAL_COMPONENTS": return ItemData.PartSubfilter.ELECTRICAL_COMPONENTS
		"ENGINE_HOUSING":        return ItemData.PartSubfilter.ENGINE_HOUSING
	return -1

func print_quests() -> String:
	match type:
		Type.MISSION:
			return "[Quest] %s — collect %d item(s) from mission: %s" % [title, required_count, target_mission]
		Type.SUBFILTER:
			return "[Quest] %s — collect %d part(s) of type: %s" % [title, required_count, target_subfilter]
		Type.STAT:
			return "[Quest] %s — reach %.0f total %s" % [title, required_stat_value, target_stat]
		Type.COMBO_MISSION_SUBFILTER, Type.COMBO_MISSION_STAT, Type.COMBO_SUBFILTER_STAT:
			return "[Quest] %s — %s AND %s" % [title, sub_quest_a.print_quests(), sub_quest_b.print_quests()]
	return "[Quest] unknown"

func get_progress_text(inventory: InventoryModel) -> String:
	if inventory == null:
		return "No inventory"
	match type:
		Type.MISSION:
			var current: int = inventory.get_count_by_mission(target_mission)
			return "%d / %d items from %s" % [current, required_count, target_mission]
		Type.SUBFILTER:
			var current: int = inventory.get_count_by_subfilter(_subfilter_to_enum(target_subfilter))
			return "%d / %d %s parts" % [current, required_count, target_subfilter.replace("_", " ").capitalize()]
		Type.STAT:
			var current: float = inventory.get_total_stat(target_stat)
			return "%.1f / %.0f total %s" % [current, required_stat_value, target_stat]
		Type.COMBO_MISSION_SUBFILTER, Type.COMBO_MISSION_STAT, Type.COMBO_SUBFILTER_STAT:
			return "%s\n%s" % [sub_quest_a.get_progress_text(inventory), sub_quest_b.get_progress_text(inventory)]
	return ""
