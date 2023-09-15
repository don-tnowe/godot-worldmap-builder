@tool
class_name WorldmapView
extends Control

## Emitted when a node on this map receives input.
signal node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData)

## When hovering over a node, highlight closest path to reach it.
@export var enable_closest_path := true
## When hovering over a node, highlight nodes with the same [WorldmapNodeData] object.
@export var enable_similar := true

## Set this to highlight nodes that match the query. Searches the name and description, translated.
var search_query := ""

var _editor_interface : Object


func _init():
  child_entered_tree.connect(_on_child_entered_tree)


func _on_child_entered_tree(child : Node):
  if child is WorldmapPath:
    child.node_gui_input.connect(_on_node_gui_input)


func _on_node_gui_input(event : InputEvent, uid : int, resource : WorldmapNodeData):
  node_gui_input.emit(event, uid, resource)
