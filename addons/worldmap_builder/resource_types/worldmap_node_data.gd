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
## Node unlock cost. Used as pathfinding cost.
@export var unlock_cost := 1
## Node tags. Used by developer.
@export var tags : Array[StringName]
