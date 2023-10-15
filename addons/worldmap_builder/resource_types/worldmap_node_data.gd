@tool
class_name WorldmapNodeData
extends Resource

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
## Node tags. Used by developer.
@export var tags : Array[StringName]
## Node's extra data. Used by developer.
@export var data : Array[Resource]


func _to_string() -> String:
  return "[Node: %s (%s)]" % [name, id]
