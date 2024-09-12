class_name WorldmapViewItem
extends Node2D

## Emitted when a node on this view item receives input.
signal node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData)
## Emitted when a node on this view item has the mouse over.
signal node_mouse_entered(uid : int, resource : WorldmapNodeData)
## Emitted when a node on this view item no longer has the mouse over.
signal node_mouse_exited(uid : int, resource : WorldmapNodeData)

## Abstract method. Must return a list of nodes that can overlap other items' nodes to be connected.
func get_end_connection_indices() -> Array[int]:
	assert(false, "Method WorldmapViewItem::get_end_connection_indices() not implemented!")
	return []

## Abstract method. Must return positions of nodes that can overlap other items' nodes to be connected.
func get_end_connection_positions() -> Array[Vector2]:
	assert(false, "Method WorldmapViewItem::get_end_connection_positions() not implemented!")
	return []

## Abstract method. Must return how many total nodes there are on this item.
func get_node_count() -> int:
	assert(false, "Method WorldmapViewItem::get_node_count() not implemented!")
	return 0

## Abstract method. Must return the specified node's position.
func get_node_position(index : int) -> Vector2:
	assert(false, "Method WorldmapViewItem::get_node_position() not implemented!")
	return Vector2.ZERO

## Abstract method. Must return the list of connectable node pairs: [code]x[/code] for first node's index, [code]y[/code] for second. [br]
## [b]Note:[/b] in bidirectional connections, only one direction is required to be in the list.
func get_connections() -> Array[Vector2i]:
	assert(false, "Method WorldmapViewItem::get_connections() not implemented!")
	return []

## Abstract method. Must return the cost of going from [code]index1[/code] to [code]index2[/code]. [br]
## Impossible connections should return [code]INF[/code], others return the second node's data's [WorldmapNodeData.cost].
func get_connection_cost(index1 : int, index2 : int) -> float:
	assert(false, "Method WorldmapViewItem::get_connection_cost() not implemented!")
	return INF

## Abstract method. Must return indices of all nodes that a connection exists to from the specified node. [br]
func get_node_neighbors(index : int) -> Array[int]:
	assert(false, "Method WorldmapViewItem::get_node_neighbors() not implemented!")
	return []

## Abstract method. Must return the [WorldmapNodeData] object inside the specified node.
func get_node_data(index : int) -> WorldmapNodeData:
	assert(false, "Method WorldmapViewItem::get_node_data() not implemented!")
	return null

## Abstract method. Must offset all nodes by a vector.
func offset_all_nodes(offset : Vector2):
	offset_all_nodes_xform(Transform2D(Vector2(1, 0), Vector2(0, 1), offset))

## Abstract method. Must offset all nodes by a Transform2D.
func offset_all_nodes_xform(offset : Transform2D):
	assert(false, "Method WorldmapViewItem::offset_all_nodes_xform() not implemented!")

## Must return the [Rect2] that encloses all worldmap nodes on this node, relative to this node's origin position.
func get_clickable_rect() -> Rect2:
	var result := Rect2(get_node_position(0), Vector2.ZERO)
	for i in get_node_count():
		if get_node_data(i) == null || get_node_data(i).texture == null:
			continue

		var tex_half_size := get_node_data(i).texture.get_size() * 0.5
		result = result.expand(get_node_position(i) + tex_half_size)
		result = result.expand(get_node_position(i) - tex_half_size)

	return result


func _set_grid_snap(v : int):
	if !is_inside_tree(): return
	get_parent().node_grid_snap = maxf(v, 0)


func _on_node_gui_input(event : InputEvent, index : int):
	var data_under := get_node_data(index)
	if data_under == null:
		return

	node_gui_input.emit(event, index, data_under)


func _on_node_mouse_entered(index : int):
	var data_under := get_node_data(index)
	if data_under == null:
		return

	node_mouse_entered.emit(index, data_under)


func _on_node_mouse_exited(index : int):
	var data_under := get_node_data(index)
	if data_under == null:
		return

	node_mouse_exited.emit(index, data_under)
