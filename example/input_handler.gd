extends Node

@export var starting_skillpoints := 12
@export var skilltree : WorldmapView
@export var tooltip_root : CanvasItem
@export var tooltip_title : Label
@export var tooltip_desc : Label


func _ready():
	skilltree.max_unlock_cost = starting_skillpoints
	tooltip_root.hide()


func _on_map_node_gui_input(event : InputEvent, path : NodePath, node_in_path : int, resource : WorldmapNodeData):
	if event is InputEventMouseMotion:
		tooltip_root.global_position = event.global_position

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			if skilltree.can_activate(path, node_in_path):
				tooltip_root.hide()
				skilltree.max_unlock_cost -= skilltree.set_node_state(path, node_in_path, 1)


func _on_map_node_mouse_entered(_path : NodePath, _node_in_path : int, resource : WorldmapNodeData):
	tooltip_root.show()
	tooltip_title.text = resource.name
	tooltip_desc.text = resource.desc
	tooltip_root.size = Vector2.ZERO


func _on_map_node_mouse_exited(_path : NodePath, _node_in_path : int, _resource : WorldmapNodeData):
	tooltip_root.hide()
