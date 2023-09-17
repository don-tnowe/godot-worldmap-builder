@tool
class_name WorldmapPath
extends Node2D

enum PathMode {
	LINE = 0,
	RADIUS,
	BEZIER,
}

## Emitted when a node on this path receives input.
signal node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData)

@export_group("Points")
@export var start := Vector2(INF, INF):
	set(v):
		start = v
		queue_redraw()
@export var end := Vector2(INF, INF):
	set(v):
		end = v
		queue_redraw()
@export var handle_1 := Vector2(INF, INF):
	set(v):
		handle_1 = v
		queue_redraw()
@export var handle_2 := Vector2(0, 0):
	set(v):
		handle_2 = v
		queue_redraw()

@export_group("Path")
@export var mode : PathMode:
	set(v):
		mode = v
		queue_redraw()
@export var bidirectional := false:
	set(v):
		bidirectional = v
		queue_redraw()
@export var end_with_empty := false:
	set(v):
		end_with_empty = v
		queue_redraw()
@export var end_connections : Array[WorldmapPath]:
	set(v):
		end_connections = v
		queue_redraw()

var skill_datas : Array[WorldmapNodeData]
var skill_uid : Array[int]

var _node_controls : Array[Control] = []
var _arc_changing := false


func _enter_tree():
	if end.x == INF:
		end = start + Vector2(64.0, 0.0)
		handle_1 = start + Vector2(0.0, 0.0)
		handle_2 = end + Vector2(0.0, 0.0)

	if position != Vector2.ZERO:
		start += position
		end += position
		handle_1 += position
		if mode != PathMode.BEZIER: handle_2 += position
		position = Vector2.ZERO


func _draw():
	var last_pos := Vector2.ZERO
	var count_nodes := skill_datas.size()
	var count_points := count_nodes + (1 if end_with_empty else 0)
	var angle_diff := (start - handle_1).angle_to(end - handle_1)
	var is_editor := Engine.is_editor_hint()
	for x in _node_controls:
		x.hide()

	for i in count_nodes + 1:
		var cur_pos := last_pos
		match mode:
			PathMode.LINE:
				cur_pos = lerp(start, end, float(i) / count_points)

			PathMode.RADIUS:
				cur_pos = (start - handle_1).rotated(angle_diff * i / count_points) + handle_1

			PathMode.BEZIER:
				cur_pos = start.bezier_interpolate(handle_1, handle_2, end, float(i) / count_points)

		last_pos = cur_pos
		if i == 0 || skill_datas[i - 1] == null:
			continue

		var tex := skill_datas[i - 1].texture
		var tex_size := tex.get_size()
		var node := _node_controls[i - 1]
		node.position = cur_pos - tex_size * 0.5
		node.size = tex_size
		node.show()
		draw_texture(tex, cur_pos - tex_size * 0.5)


func _set(property : StringName, value) -> bool:
	if property == "skill_count":
		skill_datas.resize(value)
		skill_uid.resize(value)
		notify_property_list_changed()
		queue_redraw()
		while _node_controls.size() < value:
			var new_control := Control.new()
			new_control.gui_input.connect(_on_node_gui_input.bind(_node_controls.size()))
			add_child(new_control)
			_node_controls.append(new_control)

		while _node_controls.size() > value:
			_node_controls.pop_back().queue_free()

		return true

	if property == "skill_set_all":
		skill_datas.fill(value)
		queue_redraw()
		return true

	if property.begins_with("skill_"):
		var name_split := property.trim_prefix("skill_").split("/")
		var index := name_split[0].to_int()
		match name_split[1]:
			"data": skill_datas[index] = value
			"index": skill_uid[index] = value

		queue_redraw()
		return true

	return false


func _get(property : StringName):
	if property == "skill_count":
		return skill_datas.size()

	if property == "skill_set_all":
		return null

	if property.begins_with("skill_"):
		var name_split := property.trim_prefix("skill_").split("/")
		var index := name_split[0].to_int()
		match name_split[1]:
			"data": return skill_datas[index]
			"index": return skill_uid[index]

	return null


func _property_can_revert(property : StringName):
	match property:
		&"start":
			return end != start
		&"end":
			return end != start
		&"handle_1":
			return handle_1 != start
		&"handle_2":
			return handle_2 != end


func _property_get_revert(property : StringName):
	match property:
		&"start":
			return end
		&"end":
			return start
		&"handle_1":
			return start
		&"handle_2":
			return end


func _get_property_list() -> Array:
	var result := []
	result.append({
		&"name": "skill_count",
		&"type": TYPE_INT,
		&"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ARRAY,
		&"hint": PROPERTY_HINT_NONE,
		&"hint_string": "",
		&"class_name": "Skills,skill_",
	})
	for i in skill_datas.size():
		result.append({
			&"name": "skill_%d/data" % i,
			&"type": TYPE_OBJECT,
			&"hint": PROPERTY_HINT_RESOURCE_TYPE,
			&"hint_string": "WorldmapNodeData",
		})
		result.append({
			&"name": "skill_%d/uid" % i,
			&"type": TYPE_INT,
		})
	
	result.append({
		&"name": "skill_set_all",
		&"type": TYPE_OBJECT,
		&"hint": PROPERTY_HINT_RESOURCE_TYPE,
		&"hint_string": "WorldmapNodeData",
		&"usage": PROPERTY_USAGE_EDITOR,
	})
	return result


func _on_node_gui_input(event : InputEvent, index : int):
	if skill_datas[index] == null:
		return

	node_gui_input.emit(event, skill_uid[index], skill_datas[index])
