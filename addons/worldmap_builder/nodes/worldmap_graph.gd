@tool
class_name WorldmapGraph
extends WorldmapViewItem

enum ConnectionMode {
	BIDIRECTIONAL, ## Bidirectional connection. All [member connection_costs] are [code](1, 1)[/code].
	UNIDIRECTIONAL, ## Can only move from point X to Y. All [member connection_costs] are [code](1, INF)[/code].
	CUSTOM, ## All [member connection_costs] can be changed. X and Y determine the cost of moving FROM the corresponding node. will be multiplied by the nodes' [member WorldmapNodeData.cost].
}

@export_group("Path")
@export var connection_mode : ConnectionMode:
	set(v):
		connection_mode = v
		match v:
			ConnectionMode.BIDIRECTIONAL:
				for i in connection_costs.size():
					connection_costs[i] = Vector2(1, 1)

			ConnectionMode.UNIDIRECTIONAL:
				for i in connection_costs.size():
					connection_costs[i] = Vector2(1, INF)

		notify_property_list_changed()
## Length of new connections, if a node is added by clicking on the white ring around the selected node.
@export var connection_min_length := 0.0
## When moving graph nodes, snap the position to a grid with this size. If 0, disable snapping. [br]
## This value is shared between all sibling [WorldmapViewItem]s.
@export var node_grid_snap : int:
	set(v):
		_set_grid_snap(v)
	get:
		return get_parent().node_grid_snap

## Nodes on this graph that can connect with overlapping [WorldmapViewItem]s, and act as snapping targets. [br]
## If the plugin is enabled, you can right-click a node to change this. Such nodes are shown as yellow.
@export var end_connection_nodes : Array[int]:
	set(v):
		end_connection_nodes = v
		queue_redraw()

var node_datas : Array[WorldmapNodeData]
var node_positions : Array[Vector2]

var connection_nodes : Array[Vector2i]
var connection_costs : Array[Vector2]

var _node_controls : Array[Control] = []
var _node_neighbors := []
var _costs_dict := {}
var _arc_changing := false


func _ready():
	_connections_changed()

## Adds a node at [code]pos[/code] and connects it to [code]parent_node[/code]. [br]
## [member node_datas] is copied from the parent.
func add_node(pos : Vector2, parent_node : int, node_data : WorldmapNodeData = null) -> int:
	if node_data == null:
		node_data = node_datas[parent_node]

	node_datas.append(node_data)
	node_positions.append(pos)
	set_connected(parent_node, node_datas.size() - 1, true)
	_add_new_node_control()
	queue_redraw()
	get_parent().view_item_node_added(self, node_datas.size() - 1)
	return node_datas.size() - 1

## Replaces the data of node [code]index[/code] with a given [code]node_data[/code].
func change_node(index: int, node_data: WorldmapNodeData = null) -> int:
	node_datas[index] = node_data
	queue_redraw()
	get_parent().queue_redraw()
	return index

## Removes a node, along with all of its connections.[br]
func remove_node(index : int):
	node_datas.remove_at(index)
	node_positions.remove_at(index)
	end_connection_nodes.erase(index)
	set(&"node_count", node_datas.size())

	var i := 0
	while i < connection_nodes.size():
		if connection_nodes[i].x == index || connection_nodes[i].y == index:
			connection_nodes.remove_at(i)
			connection_costs.remove_at(i)

		if connection_nodes[i].x > index:
			connection_nodes[i].x -= 1

		if connection_nodes[i].y > index:
			connection_nodes[i].y -= 1

		i += 1

	set(&"connection_count", connection_nodes.size())
	get_parent().view_item_node_removed(self, index)
	queue_redraw()

## Makes nodes with the specified indices connected or disconnected. Will remove both directions.
func set_connected(index1 : int, index2 : int, connected : bool):
	var i := 0
	while i < connection_nodes.size():
		var connection := connection_nodes[i]
		if connection.x == index1 && connection.y == index2:
			connection_nodes.remove_at(i)
			connection_costs.remove_at(i)
			continue

		if connection.y == index1 && connection.x == index2:
			connection_nodes.remove_at(i)
			connection_costs.remove_at(i)
			continue

		i += 1

	if connected:
		connection_nodes.append(Vector2i(index1, index2))
		connection_costs.append(Vector2.ONE)

	_connections_changed()

## Returns [code]true[/code] if the connection exists in either direction, [b]regardless if it's traversible[/b]. [br]
## For checking traversibility, use [method get_connection_cost].
func connection_exists(index1 : int, index2 : int) -> bool:
	for i in connection_nodes.size():
		var connection := connection_nodes[i]
		if connection.x == index1 && connection.y == index2:
			return true

		if connection.y == index1 && connection.x == index2:
			return true

	return false


func get_end_connection_positions() -> Array[Vector2]:
	var result : Array[Vector2] = []
	result.resize(end_connection_nodes.size())
	for i in result.size():
		result[i] = node_positions[end_connection_nodes[i]]

	return result


func get_end_connection_indices() -> Array[int]:
	return end_connection_nodes.duplicate()


func get_node_count() -> int:
	return node_datas.size()


func get_node_position(index : int) -> Vector2:
	return node_positions[index]


func get_connection_cost(index1 : int, index2 : int) -> float:
	var cost : Vector2 = _costs_dict.get(Vector2i(index1, index2), Vector2(-INF, -INF))
	if cost == Vector2(-INF, -INF):
		cost = _costs_dict.get(Vector2i(index2, index1), Vector2(INF, INF))
		cost = Vector2(cost.y, cost.x)

	if cost.x != INF && node_datas[index2] == null:
		cost.x *= get_parent().get_node_data_non_null(NodePath(name), index2).cost

	return cost.x


func get_connections() -> Array[Vector2i]:
	return connection_nodes.duplicate()


func get_node_neighbors(index : int) -> Array[int]:
	return _node_neighbors[index]


func get_node_data(index : int) -> WorldmapNodeData:
	return node_datas[index]


func offset_all_nodes_xform(offset : Transform2D):
	for i in node_positions.size():
		node_positions[i] = offset * node_positions[i]

	queue_redraw()


func _enter_tree():
	if transform != Transform2D.IDENTITY:
		offset_all_nodes_xform(transform)
		transform = Transform2D.IDENTITY


func _draw():
	var is_editor := Engine.is_editor_hint()
	for x in _node_controls:
		x.hide()

	if is_editor:
		for x in connection_nodes:
			draw_line(node_positions[x.x], node_positions[x.y], Color.ORANGE_RED, 4.0)

	for i in node_datas.size():
		if node_datas[i] == null:
			continue

		var tex := node_datas[i].texture
		if tex == null:
			continue

		var tex_size := tex.get_size()
		var node := _node_controls[i]
		node.position = node_positions[i] - tex_size * 0.5
		node.size = tex_size
		node.show()
		if is_editor:
			draw_texture(tex, node_positions[i] - tex_size * 0.5)


func _add_new_node_control():
	var new_control := Control.new()
	new_control.gui_input.connect(_on_node_gui_input.bind(_node_controls.size()))
	new_control.mouse_exited.connect(_on_node_mouse_exited.bind(_node_controls.size()))
	new_control.mouse_entered.connect(_on_node_mouse_entered.bind(_node_controls.size()))
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
			connection_costs.resize(value)
			_connections_changed()
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
			"costs":
				connection_costs[index] = value
				_connections_changed()

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
			"costs": return connection_costs[index]

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
	var show_costs := connection_mode == ConnectionMode.CUSTOM
	for i in connection_nodes.size():
		result.append({
			&"name": "connection_%d/nodes" % i,
			&"type": TYPE_VECTOR2I,
		})
		if show_costs:
			result.append({
				&"name": "connection_%d/costs" % i,
				&"type": TYPE_VECTOR2,
			})
	
	return result


func _connections_changed():
	connection_mode = connection_mode  # Triggers setter: updates costs to (1, 1) or (1, 0)
	_node_neighbors.resize(node_datas.size())
	_costs_dict.clear()
	for i in node_datas.size():
		var new_arr : Array[int] = []
		_node_neighbors[i] = new_arr

	for i in connection_nodes.size():
		var costs_pair := connection_costs[i]
		var nodes_pair := connection_nodes[i]
		costs_pair.x *= node_datas[nodes_pair.y].cost if node_datas[nodes_pair.y] != null else 1.0
		costs_pair.y *= node_datas[nodes_pair.x].cost if node_datas[nodes_pair.x] != null else 1.0
		_costs_dict[nodes_pair] = costs_pair
		_costs_dict[Vector2(nodes_pair.y, nodes_pair.x)] = Vector2(costs_pair.x, costs_pair.y)

		if costs_pair.x != INF:
			_node_neighbors[nodes_pair.x].append(nodes_pair.y)

		if costs_pair.y != INF:
			_node_neighbors[nodes_pair.y].append(nodes_pair.x)
