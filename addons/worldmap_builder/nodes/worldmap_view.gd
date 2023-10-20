@tool
class_name WorldmapView
extends Control

class ConnectionPoint extends RefCounted:
	var position := Vector2.ZERO
	var id := 0
	var items : Array[WorldmapViewItem] = []:
		set(v): return
	var item_paths : Array[NodePath] = []:
		set(v): return
	var indices : Array[int] = []:
		set(v): return
	var filled_node_item := -1:
		set(v):
			if filled_node_item != -1:
				return

			filled_node_item = v


	func add(item : WorldmapViewItem, path : NodePath, node_index : int):
		items.append(item)
		item_paths.append(path)
		indices.append(node_index)
		if item.get_node_data(node_index) != null:
			filled_node_item = items.size() - 1


	func _to_string():
		return "[%s : id %s, map items: %s]" % [position, id, range(items.size()).map(func(i): return "%s::%s" % [items[i].name, indices[i]])]

## Emitted when a node on this map receives input.
signal node_gui_input(event : InputEvent, path : NodePath, node_in_path : int, resource : WorldmapNodeData)
## Emitted when a node on this map gets the mouse over it.
signal node_mouse_entered(path : NodePath, node_in_path : int, resource : WorldmapNodeData)
## Emitted when a node on this map no longer has the mouse over.
signal node_mouse_exited(path : NodePath, node_in_path : int, resource : WorldmapNodeData)

## Nodes are only able to be activated if this cost exceeds or equals the node's [member WorldmapNodeData.cost]. [br]
## Update it to your amount of unlock currency, such as skill points.
@export var max_unlock_cost := 1:
	set(v):
		max_unlock_cost = v
		_update_activatable()

@export_group("Configuration")
## On start, this [WorldmapViewItem] will be active.
@export var initial_item : WorldmapViewItem
## On start, this node of [member initial_item] will be active. [br]
## [b]Note:[/b] [WorldmapPath] starts with 1.
@export var initial_node := 1
## On start, [member initial_node] of [member initial_item] will receive this value.
@export var initial_node_value := 1

## When hovering over a node, highlight closest path to reach it.
# @export var highlight_closest_path := true
## When hovering over a node, highlight nodes with the same [WorldmapNodeData] object.
# @export var highlight_similar := true

## If [code]true[/code], auto-updates the minimum size to enclose all nodes. Disable to make it custom. [br]
## [b]Note:[/b] if disabled, may sometimes not display all child nodes.
@export var auto_minsize := true:
	set(v):
		auto_minsize = v
		queue_redraw()

## Toggle to update and show the map in the editor.
@export var editor_preview := false:
	set(v):
		editor_preview = v
		queue_redraw()

@export_group("Styles")
## Style for nodes that are active.
@export var style_active : WorldmapStyle
## Style for nodes that are connected to an active node, and can be activated.
@export var style_can_activate : WorldmapStyle
## Style for nodes that are inactive.
@export var style_inactive : WorldmapStyle
## Style for nodes that are highlighted by text search, closest-path, or similarity search.
# @export var style_search : WorldmapStyle

## Set this to highlight nodes that match the query. Searches the name and description, translated.
var search_query := ""

var _connections_all := []
var _connections_by_items := {}
var _connections_by_item_pairs := {}
var _worldmap_state := {}
var _worldmap_can_activate := {}

var _updating_activatable := false


func _init():
	child_entered_tree.connect(_on_child_entered_tree)


func _ready():
	editor_preview = false
	if !is_instance_valid(initial_item):
		initial_item = get_child(0)

	reset()


func _draw():
	var children := get_children()
	if children.size() == 0:
		return

	if auto_minsize:
		var full_map_rect := get_node_minimum_rect()

		custom_minimum_size = full_map_rect.size + full_map_rect.position * 2

	if Engine.is_editor_hint() && !editor_preview: return
	if _worldmap_can_activate.size() == 0: return

	var node_positions : Array[Array] = []
	var node_datas : Array[Array] = []
	var node_styles : Array[Array] = []
	node_positions.resize(children.size())
	node_datas.resize(children.size())
	node_styles.resize(children.size())
	for i in children.size():
		var x := children[i]
		var cur_positions : Array[Vector2] = []
		var cur_datas : Array[WorldmapNodeData] = []
		var cur_styles : Array[WorldmapStyle] = []
		node_positions[i] = cur_positions
		node_datas[i] = cur_datas
		node_styles[i] = cur_styles
		if !x is WorldmapViewItem:
			continue

		var x_node_count : int = x.get_node_count()
		var x_path := get_path_to(x)
		var cur_item_states : Array = _worldmap_state[x_path]
		var cur_item_activatable : Array = _worldmap_can_activate[x_path]
		cur_positions.resize(x_node_count)
		cur_datas.resize(x_node_count)
		cur_styles.resize(x_node_count)
		for j in x_node_count:
			cur_positions[j] = x.get_node_position(j)
			cur_datas[j] = x.get_node_data(j)

			if cur_item_activatable[j]:
				cur_styles[j] = style_can_activate

			elif cur_item_states[j] != 0:
				cur_styles[j] = style_active

			else:
				cur_styles[j] = style_inactive

		for y in x.get_connections():
			cur_styles[y.x].draw_connection(self, cur_styles[y.y], cur_positions[y.x], cur_positions[y.y])

	for i in node_positions.size():
		if node_positions[i].size() == 0:
			continue

		var cur_positions : Array[Vector2] = node_positions[i]
		var cur_datas : Array[WorldmapNodeData] = node_datas[i]
		var cur_styles : Array[WorldmapStyle] = node_styles[i]
		for j in cur_positions.size():
			cur_styles[j].draw_node(self, cur_datas[j], cur_positions[j])

## Returns the rect that encloses all nodes on this worldmap graph, taking into account their texture size.
func get_node_minimum_rect() -> Rect2:
	var full_map_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
	var first_found := false
	for x in get_children():
		if !x is WorldmapViewItem:
			continue

		if !first_found:
			full_map_rect.position = get_child(0).get_node_position(0)
			first_found = true

		for j in x.get_node_count():
			var node_pos : Vector2 = x.get_node_position(j)
			var node_data : WorldmapNodeData = x.get_node_data(j)
			if node_data == null || node_data.texture == null:
				continue

			var node_tex_half_size := node_data.texture.get_size() * 0.5
			full_map_rect = full_map_rect.expand(node_pos - node_tex_half_size)
			full_map_rect = full_map_rect.expand(node_pos + node_tex_half_size)

	return full_map_rect

## Resets all unlocks, leaving just the starting node.
func reset():
	var initial_array := []
	initial_array.resize(initial_item.get_node_count())
	initial_array.fill(0)
	initial_array[initial_node] = initial_node_value
	recalculate_map()
	load_state({get_path_to(initial_item) : initial_array})

## Looks through all child [WorldmapViewItem]s and builds a graph. Overlapping connectable points on different items are considered connected.[br]
## [b]Warning: [/b] this is called on ready, and must be called again when the map changes.
func recalculate_map():
	var connections_at_positions := {}
	var connections_by_item_pairs := _connections_by_item_pairs
	var default_array : Array[ConnectionPoint] = []
	connections_by_item_pairs.clear()
	_connections_by_items.clear()
	_connections_all.clear()
	for x in get_children():
		if !x is WorldmapViewItem:
			continue

		var connectable_positions : Array[Vector2] = x.get_end_connection_positions()
		var connectable_indices : Array[int] = x.get_end_connection_indices()
		var connecting_to_points : Array[ConnectionPoint] = []
		var path_to_x := get_path_to(x)
		_connections_by_items[path_to_x] = connecting_to_points
		connecting_to_points.resize(connectable_positions.size())
		for i in connectable_positions.size():
			var point := connections_at_positions.get(connectable_positions[i], null)
			if point == null:
				point = ConnectionPoint.new()
				point.position = connectable_positions[i]
				point.id = _connections_all.size()
				_connections_all.append(point)
				connections_at_positions[connectable_positions[i]] = point

			point.add(x, path_to_x, connectable_indices[i])
			connecting_to_points[i] = point
			for connection_i in point.items.size():
				var connection_pair := Vector2i(point.items[connection_i].get_index(), x.get_index())
				var connection_pair_points : Array[ConnectionPoint] = connections_by_item_pairs.get(connection_pair, default_array.duplicate())
				if connection_pair_points.size() == 0:
					# Add the array as a list of connection points for the pair. Both directions ((x, y) and (y, x))
					connections_by_item_pairs[connection_pair] = connection_pair_points
					connections_by_item_pairs[Vector2i(connection_pair.y, connection_pair.x)] = connection_pair_points

				connection_pair_points.append(point)

	_update_activatable()

## If [code]point1[/code] can be connected to [code]point2[/code], returns [code]true[/code]. [br]
## See also: [method get_connection_cost].
func can_connect(point1 : int, item1 : NodePath, point2 : int, item2 : NodePath = item1) -> bool:
	return get_connection_cost(point1, item1, point2, item2)

## If [code]point1[/code] can be connected to [code]point2[/code], returns its cost, otherwise [code]INF[/code]. [br]
## If [code]item2[/code] not specified, check points on the same item. [br]
## [b]Note: [/b]if a map-item's movement is uni-directional and (p1 -> p2) would return a valid cost, (p2 -> p1) would not.
func get_connection_cost(point1 : int, item1 : NodePath, point2 : int, item2 : NodePath = item1) -> float:
	var item1_node := get_node_or_null(item1)
	var item2_node := get_node_or_null(item2)
	if item1_node == null || item2_node == null:
		return INF

	if item1_node == item2_node:
		return item1_node.get_connection_cost(point1, point2)

	# If not on same item, they're connected as long as they overlap.
	var item_pair := Vector2i(item1_node.get_index(), item2_node.get_index())
	if !_connections_by_item_pairs.has(item_pair):
		return INF

	if item1_node.get_node_position(point1) != item2_node.get_node_position(point2):
		return INF

	# If it's a connection between subgraphs, it's free - the nodes are at the same position.
	return 0.0

## Set a node's state, activating or deactivating it. if [code]state[/code] is non-zero, it will show as active and highlight inactive neighbors. [br]
## Numbers other than 0 or 1 can be stored for extra information, such as level. [br]
## Return the "cost to change node's state by this much", which you can then subtract from [max_unlock_cost] to update available nodes. [br]
## The calculation for the return is: [code](<provided state> - <node's previous state>) * <node data's cost>[/code].
func set_node_state(item : NodePath, node : int, state : int) -> int:
	var state_arr : Array = _worldmap_state.get(item, [])
	if state_arr.size() <= node:
		return 0

	var old_state : int = state_arr[node]
	state_arr[node] = state
	_update_activatable()
	var node_data := get_node_data(item, node)
	return (state - old_state) * (0.0 if node_data == null else node_data.cost)

## Get a node's state.
func get_node_state(item : NodePath, node : int) -> int:
	var state_arr : Array = _worldmap_state.get(item, [])
	if state_arr.size() <= node:
		return 0

	return state_arr[node]

## Get a node's [WorldmapNodeData] resource.
func get_node_data(item : NodePath, node : int) -> WorldmapNodeData:
	return get_node(item).get_node_data(node)

## Returns [code]true[/code] if requirements for activating a node were met.
func can_activate(item : NodePath, node : int) -> bool:
	return _worldmap_can_activate[item][node]

## For each [WorldmapNodeData] in the graph, returns its [method get_node_state]. Duplicate resources will have their numbers summed up.
func get_all_nodes() -> Dictionary:
	var result := {}
	var state_keys := _worldmap_state.keys()
	var state_values := _worldmap_state.values()
	for i in state_keys.size():
		var cur_view_item : NodePath = state_keys[i]
		var cur_view_values : Array = state_values[i]
		for j in cur_view_values.size():
			var cur_data := get_node_data(cur_view_item, j)
			result[cur_data] = result.get(cur_data, 0) + cur_view_values[j]

	result.erase(null)  # From connector nodes
	return result

## Returns the state of the entire map, to be loaded with [method load_state]. [br]
func get_state() -> Dictionary:
	return _worldmap_state.duplicate(true)

## Load the state of the entire map, in a format saved with [method get_state]. [br]
## The supplied dictionary must contain Strings or NodePaths as keys, and int Arrays as values corresponding to levels of the activated.
func load_state(state : Dictionary):
	# --- TODO ---
	_worldmap_state.clear()
	var children := get_children()
	for x in children:
		if !x is WorldmapViewItem:
			continue

		var cur_path := get_path_to(x)
		var cur_array := []
		var loading_from_array : Array = state.get(cur_path, [])
		_worldmap_state[cur_path] = cur_array
		cur_array.resize(x.get_node_count())
		cur_array.fill(0)
		if loading_from_array.size() == 0:
			continue

		for i in mini(cur_array.size(), loading_from_array.size()):
			cur_array[i] = loading_from_array[i]

	_update_activatable()


func _update_activatable():
	if _updating_activatable: return
	_updating_activatable = true
	await get_tree().process_frame

	_worldmap_can_activate.clear()
	for k in _worldmap_state:
		_update_activatable_local(k)

	for x in _connections_all:
		_update_activatable_interitem(x)

	_updating_activatable = false
	queue_redraw()
	return


func _update_activatable_local(item_path : NodePath):
	var item : WorldmapViewItem = get_node(item_path)
	var nodes_state : Array = _worldmap_state[item_path]
	var nodes_activatable : Array[bool] = []
	nodes_activatable.resize(item.get_node_count())
	nodes_activatable.fill(false)
	_worldmap_can_activate[item_path] = nodes_activatable
	for x in item.get_connections():
		if nodes_activatable[x.x]:
			# We already know it can be activated, but if it can't,
			# it can if AT LEAST one connection activates it.
			continue

		if nodes_state[x.y] > 0 && nodes_state[x.x] <= 0:
			var cost : float = item.get_connection_cost(x.y, x.x)
			if max_unlock_cost >= cost:
				nodes_activatable[x.x] = true

		if nodes_state[x.x] > 0 && nodes_state[x.y] <= 0:
			var cost : float = item.get_connection_cost(x.x, x.y)
			if max_unlock_cost >= cost:
				nodes_activatable[x.y] = true


func _update_activatable_interitem(connection : ConnectionPoint):
	var filled_node_index : int = connection.indices[connection.filled_node_item]
	var filled_node_path : NodePath = connection.item_paths[connection.filled_node_item]

	var filled_node : WorldmapViewItem = get_node(filled_node_path)
	var nodes_state : Array = _worldmap_state[filled_node_path]
	var nodes_activatable : Array[bool] = _worldmap_can_activate[filled_node_path]

	if nodes_state[filled_node_index] > 0:
		# if filled item is active:
		# - make empty items below as-if active, update neighbors
		for i in connection.items.size():
			var cur_empty_item := connection.items[i]
			_worldmap_state[connection.item_paths[i]][connection.indices[i]] = nodes_state[filled_node_index]
			for x in cur_empty_item.get_node_neighbors(connection.indices[i]):
				if _worldmap_state[connection.item_paths[i]][x] > 0:
					continue

				var cost : float = cur_empty_item.get_connection_cost(connection.indices[i], x)
				if max_unlock_cost >= cost:
					_worldmap_can_activate[connection.item_paths[i]][x] = true

	elif !nodes_activatable[filled_node_index]:
		# if filled item is inactive, but not activatable:
		# - if any item below activatable, make filled item activatable
		for i in connection.items.size():
			var cur_empty_item := connection.items[i]
			if _worldmap_can_activate[connection.item_paths[i]][connection.indices[i]]:
				nodes_activatable[filled_node_index] = true
				break

	else:
		# if filled item is activatable, not active:
		# - nothing happens.
		pass


func _on_child_entered_tree(child : Node):
	if !child is WorldmapViewItem:
		return

	var node_path := get_path_to(child)
	child.node_gui_input.connect(_on_node_gui_input.bind(node_path))
	child.node_mouse_entered.connect(_on_node_mouse_entered.bind(node_path))
	child.node_mouse_exited.connect(_on_node_mouse_exited.bind(node_path))
	if !_connections_by_item_pairs.has(node_path):
		_connections_by_item_pairs[node_path] = []


func _on_node_gui_input(event : InputEvent, node_id : int, resource : WorldmapNodeData, path : NodePath):
	node_gui_input.emit(event, path, node_id, resource)


func _on_node_mouse_entered(node_id : int, resource : WorldmapNodeData, path : NodePath):
	node_mouse_entered.emit(path, node_id, resource)


func _on_node_mouse_exited(node_id : int, resource : WorldmapNodeData, path : NodePath):
	node_mouse_exited.emit(path, node_id, resource)
