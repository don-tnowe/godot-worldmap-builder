extends Node

@export var starting_skillpoints := 12
@export var skilltree : WorldmapView

@export_group("Bottom Bar")
@export var skillpoint_label : Label
@export var skillpoint_label_format := "{0} Points Left"
@export var skill_reset : BaseButton
@export var stat_list : Label

@export_group("Tooltip")
@export var tooltip_root : CanvasItem
@export var tooltip_title : Label
@export var tooltip_desc : Label

@export_group("Adding Nodes")
@export var add_target : WorldmapGraph
@export var add_node_index := 3


func _ready():
	skilltree.max_unlock_cost = starting_skillpoints
	_skillpoints_changed()
	tooltip_root.hide()


func _skillpoints_changed():
	skillpoint_label.text = skillpoint_label_format.format([skilltree.max_unlock_cost])
	skill_reset.disabled = skilltree.max_unlock_cost >= starting_skillpoints
	var stat_list_text : Array[String] = []
	var stats_raw := skilltree.get_all_nodes()
	var stats := {}
	for k in stats_raw:
		var v : int = stats_raw[k]
		if v == 0: continue
		for node_data_item in k.data:
			# [SkillStats] is a resource specific to this example.
			# You can search for your own resource types,
			# or if you're using Wyvernshield, you can store stats in [StatModification]s.
			if node_data_item is SkillStats:
				stats[node_data_item.name] = stats.get(node_data_item.name, 0) + v * node_data_item.amount

	for k in stats:
		stat_list_text.append("%s: %s" % [k, stats[k]])

	stat_list.text = "\n".join(stat_list_text)


func _on_map_node_gui_input(event : InputEvent, path : NodePath, node_in_path : int, resource : WorldmapNodeData):
	if event is InputEventMouseMotion:
		tooltip_root.global_position = event.global_position

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			if skilltree.can_activate(path, node_in_path):
				tooltip_root.hide()
				skilltree.max_unlock_cost -= skilltree.set_node_state(path, node_in_path, 1)
				_skillpoints_changed()

		if event.button_index == MOUSE_BUTTON_MIDDLE && event.pressed:
			skilltree.get_node(path).remove_node(node_in_path)


func _unhandled_input(event : InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE && event.pressed:
			add_node_index = add_target.add_node(event.position * skilltree.get_global_transform(), add_node_index)


func _on_map_node_mouse_entered(_path : NodePath, _node_in_path : int, resource : WorldmapNodeData):
	tooltip_root.show()
	tooltip_title.text = resource.name
	tooltip_desc.text = resource.desc
	tooltip_root.size = Vector2.ZERO


func _on_map_node_mouse_exited(_path : NodePath, _node_in_path : int, _resource : WorldmapNodeData):
	tooltip_root.hide()


func _on_reset_skills_pressed():
	skilltree.max_unlock_cost = starting_skillpoints
	skilltree.reset()
	_skillpoints_changed()


func _on_save_pressed():
	$"Anchors/BottomLeftBox/Box/Box2/SaveData".text = var_to_str([
		skilltree.max_unlock_cost,
		skilltree.get_state(),
	])


func _on_load_pressed():
	var varr = str_to_var($"Anchors/BottomLeftBox/Box/Box2/SaveData".text)
	if !varr is Array || varr.size() < 2: return
	if !varr[0] is int: return
	if !varr[1] is Dictionary: return

	skilltree.max_unlock_cost = varr[0]
	skilltree.load_state(varr[1])

	_skillpoints_changed()
