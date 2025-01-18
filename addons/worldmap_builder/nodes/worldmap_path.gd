@tool
class_name WorldmapPath
extends WorldmapViewItem

enum PathMode {
	LINE = 0,
	ARC,
	BEZIER,
}

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
## If [code]true[/code], dragging points of other [WorldmapViewItem]s in the editor makes points snap to all of this item's nodes, not just to ends. [br]
## [b]Note:[/b] when using [method WorldmapView.can_connect] and similar methods, they will still not be considered connected.
@export var snap_to_all := false
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

## When moving graph nodes, snap the position to a grid with this size. If 0, disable snapping. [br]
## This value is shared between all sibling [WorldmapViewItem]s.
@export var node_grid_snap : int:
	set(v):
		_set_grid_snap(v)
	get:
		return get_parent().node_grid_snap

var node_datas : Array[WorldmapNodeData]

var _node_controls : Array[Control] = []
var _arc_changing := false

## Calculate distance between any 2 points, if using a mode that spaces them equally. [br]
## [b]Note:[/b] undefined behaviour for the [code]PathMode.BEZIER[/code] mode.
func get_distance_between_points() -> float:
	var segment_count := node_datas.size() + (1 if end_with_empty else 0)
	if mode == PathMode.ARC:
		var arc_angle := (start - handle_1).angle_to(end - handle_1)
		var chord_length := ((start - handle_1) - (start - handle_1).rotated(arc_angle / segment_count)).length()
		return chord_length

	else:
		return (start - end).length() / segment_count

## Align points so that distance between them equals the specified amount. [br]
## The [member start] point will always stay in place. [br]
## [b]Note:[/b] undefined behaviour for the [code]PathMode.BEZIER[/code] mode.
func set_distance_between_points(value : float):
	var segment_count := node_datas.size() + (1 if end_with_empty else 0)
	if mode == PathMode.ARC:
		var radius := (start - handle_1).length()
		var half_sine := value * 0.5 / radius
		var arc_angle := asin(half_sine) * 2.0 * segment_count
		end = handle_1 + (start - handle_1).rotated(arc_angle)

	elif mode == PathMode.LINE:
		end = start + (end - start).normalized() * value * segment_count


func get_end_connection_indices() -> Array[int]:
	return [0, get_node_count() - 1]


func get_end_connection_positions() -> Array[Vector2]:
	return [start, end]


func get_node_count() -> int:
	return node_datas.size() + (2 if end_with_empty else 1)


func get_node_position(index : int) -> Vector2:
	return _get_node_position_precalc(
		index,
		get_node_count() - 1,
		(start - handle_1).angle_to(end - handle_1) if mode == PathMode.ARC else 0.0
	)


func get_connection_cost(index1 : int, index2 : int) -> float:
	if !bidirectional && index1 > index2:
		return INF

	if absi(index1 - index2) != 1:
		return INF

	var data := get_node_data(index2)
	if data == null:
		return get_parent().get_node_data_non_null(NodePath(name), index2).cost

	return data.cost


func get_connections() -> Array[Vector2i]:
	var connection_list : Array[Vector2i] = []
	connection_list.resize(get_node_count() - 1)
	for i in connection_list.size():
		connection_list[i] = Vector2i(i, i + 1)

	return connection_list


func get_node_neighbors(index : int) -> Array[int]:
	var result : Array[int] = []
	if index < get_node_count() - 1:
		result.append(index + 1)

	if bidirectional && index > 0:
		result.append(index - 1)

	return result


func get_node_data(index : int) -> WorldmapNodeData:
	if index > node_datas.size() || index == 0:
		return null

	return node_datas[index - 1]


func offset_all_nodes_xform(offset : Transform2D):
	start = offset * start
	end = offset * end
	handle_1 = offset * handle_1
	handle_2 = offset * handle_2


func _enter_tree():
	if end.x == INF:
		end = start + Vector2(64.0, 0.0)
		handle_1 = start + Vector2(0.0, 0.0)
		handle_2 = end + Vector2(0.0, 0.0)

	if transform != Transform2D.IDENTITY:
		offset_all_nodes_xform(transform)
		transform = Transform2D.IDENTITY


func _draw():
	var count_points := get_node_count() - 1
	var angle_diff := (start - handle_1).angle_to(end - handle_1)
	var is_editor := Engine.is_editor_hint()
	for x in _node_controls:
		x.hide()

	var prev_pos := Vector2.ZERO
	for i in get_node_count():
		var cur_pos := _get_node_position_precalc(i, count_points, angle_diff)
		if is_editor && i != 0:
			draw_line(prev_pos, cur_pos, Color.ORANGE_RED, 4.0)

		prev_pos = cur_pos
		if i == 0 || node_datas.size() < i || node_datas[i - 1] == null:
			continue

		var tex := node_datas[i - 1].texture
		if tex == null:
			continue

		var tex_size := tex.get_size()
		var node := _node_controls[i - 1]
		node.position = cur_pos - tex_size * 0.5
		node.size = tex_size
		node.show()
		if is_editor:
			draw_texture(tex, cur_pos - tex_size * 0.5)


func _set(property : StringName, value) -> bool:
	if property == "node_count":
		node_datas.resize(value)
		notify_property_list_changed()
		queue_redraw()
		while _node_controls.size() < value:
			var new_control := Control.new()
			var control_index := _node_controls.size() + 1
			new_control.gui_input.connect(_on_node_gui_input.bind(control_index))
			new_control.mouse_entered.connect(_on_node_mouse_entered.bind(control_index))
			new_control.mouse_exited.connect(_on_node_mouse_exited.bind(control_index))
			add_child(new_control)
			_node_controls.append(new_control)

		while _node_controls.size() > value:
			_node_controls.pop_back().queue_free()

		return true

	if property == "node_set_all":
		node_datas.fill(value)
		queue_redraw()
		return true

	if property.begins_with("node_"):
		var name_split := property.trim_prefix("node_").split("/")
		var index := name_split[0].to_int()
		match name_split[1]:
			"data": node_datas[index] = value

		queue_redraw()
		return true

	return false


func _get(property : StringName):
	if property == "node_count":
		return node_datas.size()

	if property == "node_set_all":
		return null

	if property.begins_with("node_"):
		var name_split := property.trim_prefix("node_").split("/")
		if name_split.size() != 2:
			return null

		var index := name_split[0].to_int()
		match name_split[1]:
			"data": return node_datas[index]

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
		&"name": "node_count",
		&"type": TYPE_INT,
		&"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ARRAY,
		&"hint": PROPERTY_HINT_NONE,
		&"hint_string": "",
		&"class_name": "Path Nodes,node_",
	})
	for i in node_datas.size():
		result.append({
			&"name": "node_%d/data" % i,
			&"type": TYPE_OBJECT,
			&"hint": PROPERTY_HINT_RESOURCE_TYPE,
			&"hint_string": "WorldmapNodeData",
		})
	
	result.append({
		&"name": "node_set_all",
		&"type": TYPE_OBJECT,
		&"hint": PROPERTY_HINT_RESOURCE_TYPE,
		&"hint_string": "WorldmapNodeData",
		&"usage": PROPERTY_USAGE_EDITOR,
	})
	return result


func _get_node_position_precalc(index : int, count_points, angle_diff) -> Vector2:
	match mode:
		PathMode.LINE:
			return lerp(start, end, float(index) / count_points)

		PathMode.ARC:
			return (start - handle_1).rotated(angle_diff * index / count_points) + handle_1

		PathMode.BEZIER:
			return start.bezier_interpolate(handle_1, handle_2, end, float(index) / count_points)

		_:
			return Vector2()
