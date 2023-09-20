class_name WorldmapViewItem
extends Node2D


func get_end_connection_indices() -> Array[int]:
	assert(false, "Method WorldmapViewItem::get_end_connection_indices() not implemented!")
	return []


func get_end_connection_positions() -> Array[Vector2]:
	assert(false, "Method WorldmapViewItem::get_end_connection_positions() not implemented!")
	return []


func get_node_count() -> int:
	assert(false, "Method WorldmapViewItem::get_node_count() not implemented!")
	return 0


func get_node_position(index : int) -> Vector2:
	assert(false, "Method WorldmapViewItem::get_node_position() not implemented!")
	return Vector2.ZERO


func get_connections() -> Array[Vector2i]:
	assert(false, "Method WorldmapViewItem::get_connections() not implemented!")
	return []


func get_connection_cost(index1 : int, index2 : int) -> float:
	assert(false, "Method WorldmapViewItem::get_connection_cost() not implemented!")
	return INF


func get_node_neighbors(index : int) -> Array[int]:
	assert(false, "Method WorldmapViewItem::get_node_neighbors() not implemented!")
	return []


func get_node_data(index : int) -> WorldmapNodeData:
	assert(false, "Method WorldmapViewItem::get_node_data() not implemented!")
	return null
