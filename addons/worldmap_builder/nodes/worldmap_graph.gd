@tool
class_name WorldmapGraph
extends WorldmapViewItem

enum ConnectionMode {
	BIDIRECTIONAL, ## Bidirectional connection. All [member connection_weights] are [code](1, 1)[/code].
	UNIDIRECTIONAL, ## Can only move from point X to Y. All [member connection_weights] are [code](1, 0)[/code].
	CUSTOM, ## All [member connection_weights] can be changed. X and Y determine the cost of moving FROM the corresponding node. will be multiplied by the nodes' [member WorldmapNodeData.unlock_cost].
}

## Emitted when a node on this path receives input.
signal node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData)

@export_group("Path")
@export var connection_mode : ConnectionMode:
	set(v):
		connection_mode = v
		match v:
			ConnectionMode.BIDIRECTIONAL:
				for i in connection_weights.size():
					connection_weights[i] = Vector2(1, 1)

			ConnectionMode.UNIDIRECTIONAL:
				for i in connection_weights.size():
					connection_weights[i] = Vector2(1, 0)

		notify_property_list_changed()
@export var connection_min_length := 0.0
## Nodes on this graph that can connect with overlapping [WorldmapViewItem]s, and act as snapping targets.
@export var end_connection_nodes : Array[int]:
	set(v):
		end_connection_nodes = v
		queue_redraw()
## [WorldmapViewItem]s this node is connected with.
@export var end_connections_with : Array[WorldmapViewItem]:
	set(v):
		end_connections_with = v
		queue_redraw()

var node_datas : Array[WorldmapNodeData]
var node_positions : Array[Vector2]

var connection_nodes : Array[Vector2i]
var connection_weights : Array[Vector2]

var _node_controls : Array[Control] = []
var _arc_changing := false

## Adds a node at [code]pos[/code] and connects it to [code]parent_node[/code]. [br]
## [member node_datas] is copied from the parent.
func add_node(pos : Vector2, parent_node : int):
	node_datas.append(node_datas[parent_node])
	node_positions.append(pos)
	connection_nodes.append(Vector2i(parent_node, node_datas.size() - 1))
	connection_weights.append(Vector2.ONE)
	connection_mode = connection_mode  # Trigger setter to apply mode
	_add_new_node_control()
	queue_redraw()

## Removes a node, along with all of its connections.[br]
func remove_node(index : int):
	node_datas.remove_at(index)
	node_positions.remove_at(index)
	end_connections_with.erase(index)
	set(&"node_count", node_datas.size())

	var i := 0
	while i < connection_nodes.size():
		if connection_nodes[i].x == index || connection_nodes[i].y == index:
			connection_nodes.remove_at(i)
			connection_weights.remove_at(i)

		if connection_nodes[i].x > index:
			connection_nodes[i].x -= 1

		if connection_nodes[i].y > index:
			connection_nodes[i].y -= 1

		i += 1

	set(&"connection_count", connection_nodes.size())
	queue_redraw()


func get_end_connections():
	return end_connections_with


func get_end_connection_positions():
	var result : Array[Vector2] = []
	result.resize(end_connection_nodes.size())
	for i in result.size():
		result[i] = node_positions[end_connection_nodes[i]]

	return 


func _enter_tree():
	if position != Vector2.ZERO:
		for i in node_positions.size():
			node_positions[i] += position

		position = Vector2.ZERO


func _draw():
	var is_editor := Engine.is_editor_hint()
	for x in _node_controls:
		x.hide()

	for i in node_datas.size():
		if node_datas[i] == null:
			continue

		var tex := node_datas[i].texture
		var tex_size := tex.get_size()
		var node := _node_controls[i]
		node.position = node_positions[i] - tex_size * 0.5
		node.size = tex_size
		node.show()
		draw_texture(tex, node_positions[i] - tex_size * 0.5)


func _add_new_node_control():
	var new_control := Control.new()
	new_control.gui_input.connect(_on_node_gui_input.bind(_node_controls.size()))
	add_child(new_control)
	_node_controls.append(new_control)


func _set(property : StringName, value) -> bool:
	if property.begins_with("node_"):
		if property == "node_count":
			node_datas.resize(value)
			node_positions.resize(value)
			notify_property_list_changed()
			queue_redraw()
			while _node_controls.size() < value:
				_add_new_node_control()

			while _node_controls.size() > value:
				_node_controls.pop_back().queue_free()

			return true

		if property == "node_set_all":
			node_datas.fill(value)
			queue_redraw()
			return true

		var name_split := property.trim_prefix("node_").split("/")
		if name_split.size() != 2:
			return false

		var index := name_split[0].to_int()
		match name_split[1]:
			"data": node_datas[index] = value
			"position": node_positions[index] = value

		queue_redraw()
		return true

	if property.begins_with("connection_"):
		if property == "connection_count":
			connection_nodes.resize(value)
			connection_weights.resize(value)
			connection_mode = connection_mode  # Triggers setter: updates weights to (1, 1) or (1, 0)
			notify_property_list_changed()
			queue_redraw()
			return true

		var name_split := property.trim_prefix("connection_").split("/")
		if name_split.size() != 2:
			return false

		var index := name_split[0].to_int()
		match name_split[1]:
			"nodes":
				value = value.clamp(Vector2i.ZERO, Vector2i.ONE * (node_datas.size() - 1))
				connection_nodes[index] = value
			"weights": connection_weights[index] = value

		queue_redraw()
		return true

	return false


func _get(property : StringName):
	if property.begins_with("node_"):
		if property == "node_count":
			return node_datas.size()

		var name_split := property.trim_prefix("node_").split("/")
		if name_split.size() != 2:
			return null

		var index := name_split[0].to_int()
		match name_split[1]:
			"data": return node_datas[index]
			"position": return node_positions[index]

	if property.begins_with("connection_"):
		if property == "connection_count":
			return connection_nodes.size()

		var name_split := property.trim_prefix("connection_").split("/")
		if name_split.size() != 2:
			return null

		var index := name_split[0].to_int()
		match name_split[1]:
			"nodes": return connection_nodes[index]
			"weights": return connection_weights[index]

	return null


func _get_property_list() -> Array:
	var result := []

	# --- NODE ARRAY

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
			&"name": "node_%d/position" % i,
			&"type": TYPE_VECTOR2,
		})
	
	# ---

	result.append({
		&"name": "node_set_all",
		&"type": TYPE_OBJECT,
		&"hint": PROPERTY_HINT_RESOURCE_TYPE,
		&"hint_string": "WorldmapNodeData",
		&"usage": PROPERTY_USAGE_EDITOR,
	})

	# --- CONNECTION ARRAY

	result.append({
		&"name": "connection_count",
		&"type": TYPE_INT,
		&"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ARRAY,
		&"hint": PROPERTY_HINT_NONE,
		&"hint_string": "",
		&"class_name": "Path Connections,connection_",
	})
	var show_weights := connection_mode == ConnectionMode.CUSTOM
	for i in connection_nodes.size():
		result.append({
			&"name": "connection_%d/nodes" % i,
			&"type": TYPE_VECTOR2I,
		})
		if show_weights:
			result.append({
				&"name": "connection_%d/weights" % i,
				&"type": TYPE_VECTOR2,
			})
	
	return result


func _on_node_gui_input(event : InputEvent, index : int):
	if node_datas[index] == null:
		return

	node_gui_input.emit(event, index, node_datas[index])
