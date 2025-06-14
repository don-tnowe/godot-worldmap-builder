@tool
class_name WorldmapNodeData
extends Resource

## A resource type for storing read-only data that a worldmap node represents.
##
## Multiple worldmap nodes may use the same data resource, but state, such as unlock state or amount of points allocated, is stored inside the [WorldmapView]. Developers should usually add their own game-specific features and data here, such as effect per level, generated descriptions and variable cost.

## A node with no texture or description. Unlike assigning [code]null[/code], will still show the empty frame from a [WorldmapStyle].
static var EMPTY := WorldmapNodeData.new()

## Node ID. Used by developer.
@export var id := &""
## Node texture.
@export var texture : Texture2D
## Node color. Used by developer.
@export var color := Color.WHITE
## Node name.
@export var name := ""
## Node description.
@export_multiline var desc := ""

## Node size tier. Used by developer, intended for skills or stages of varying importance.
@export var size_tier := 0
## The cost of moving onto this node, if possible. Used for pathfinding.
@export var cost := 1
## Other nodes that connect to this node must have at least this much state to make this node available. Anything less than 1 makes it always available.
@export var dependency_min_state := 1
## Node tags. Used by developer.
@export var tags : Array[StringName]
## Node's extra data. Used by developer.
@export var data : Array[Resource]


func _to_string() -> String:
  return "[Node: %s (%s)]" % [name, id]
