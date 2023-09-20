@tool
class_name WorldmapView
extends Control

class ConnectionPoint extends RefCounted:
  var position := Vector2.ZERO
  var id := 0
  var items : Array[WorldmapViewItem] = []:
    set(v): return
  var indices : Array[int] = []:
    set(v): return


  func add(item : WorldmapViewItem, node_index : int):
    items.append(item)
    indices.append(node_index)


  func _to_string():
    return "[%s : id %s, map items: %s]" % [position, id, items.map(func(x): return "%s::%s" % [x.get_index(), x.name])]


## Emitted when a node on this map receives input.
signal node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData)

## When hovering over a node, highlight closest path to reach it.
@export var enable_closest_path := true
## When hovering over a node, highlight nodes with the same [WorldmapNodeData] object.
@export var enable_similar := true

## Set this to highlight nodes that match the query. Searches the name and description, translated.
var search_query := ""

var _connections_by_item_pairs : Dictionary


func _ready():
  child_entered_tree.connect(_on_child_entered_tree)
  recalculate_map()


## Looks through all child [WorldmapViewItem]s and builds a graph. Overlapping connectable points on different items are considered connected.[br]
## [b]Warning: [/b] this is called on ready, and must be called again when the map changes.
func recalculate_map():
  var connections : Array[ConnectionPoint] = []
  var connections_at_positions := {}
  var connections_by_item_pairs := {}
  var default_array : Array[ConnectionPoint] = []
  for x in get_children():
    var connectable_positions : Array[Vector2] = x.get_end_connection_positions()
    var connectable_indices : Array[int] = x.get_end_connection_indices()
    for i in connectable_positions.size():
      var point := connections_at_positions.get(connectable_positions[i], null)
      if point == null:
        point = ConnectionPoint.new()
        point.position = connectable_positions[i]
        point.id = connections.size()
        connections.append(point)
        connections_at_positions[connectable_positions[i]] = point

      point.add(x, connectable_indices[i])
      for connection_i in point.items.size():
        var connection_pair := Vector2i(point.items[connection_i].get_index(), x.get_index())
        var connection_pair_points : Array[ConnectionPoint] = connections_by_item_pairs.get(connection_pair, default_array.duplicate())
        if connection_pair_points.size() == 0:
          # Add the array as a list of connection points for the pair. Both directions ((x, y) and (y, x))
          connections_by_item_pairs[connection_pair] = connection_pair_points
          connections_by_item_pairs[Vector2i(connection_pair.y, connection_pair.x)] = connection_pair_points

        connection_pair_points.append(point)

  _connections_by_item_pairs = connections_by_item_pairs

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


func _on_child_entered_tree(child : Node):
  if child is WorldmapPath:
    child.node_gui_input.connect(_on_node_gui_input)


func _on_node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData):
  node_gui_input.emit(event, uid, resource)
