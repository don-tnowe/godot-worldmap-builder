@tool
extends EditorPlugin

const scripts_dir := "res://addons/worldmap_builder/"

var editor_views := [
	load(scripts_dir + "editor/worldmap_path_editor.gd").new(self),
]

var added_scripts := [
	[
		"WorldmapView",
		preload(scripts_dir + "nodes/worldmap_view.gd"),
		# icons_dir + "worldmap_view.png",
		"Line2D",
	],
	[
		"WorldmapPath",
		preload(scripts_dir + "nodes/worldmap_path.gd"),
		# icons_dir + "worldmap_path.png",
		"Path2D",
	],
	[
		"WorldmapGraph",
		preload(scripts_dir + "nodes/worldmap_graph.gd"),
		# icons_dir + "worldmap_graph.png",
		"MeshInstance2D",
	],
	[
		"WorldmapSkillData",
		preload(scripts_dir + "resource_types/worldmap_node_data.gd"),
		# icons_dir + "worldmap_node_data.png",
		"Object",
	],
]


func _handles(object : Object):
	return editor_views.any(func(x): return x._handles(object))


func _edit(object : Object):
	for x in editor_views:
		if x == null:
			x.edited_object = null
			continue

		if x._handles(object):
			x.edited_object = object
			break


func _forward_canvas_draw_over_viewport(overlay : Control):
	for x in editor_views:
		x._forward_canvas_draw_over_viewport(overlay)


func _forward_canvas_gui_input(event : InputEvent):
	for x in editor_views:
		if x._forward_canvas_gui_input(event):
			return true

	return false


func _enter_tree():
	for x in added_scripts:
		var x_icon = x[2]
		if x_icon == null:
			x_icon = x[1].get_instance_base_type()

		if x_icon is StringName || x_icon is String:
			x_icon = get_editor_interface().get_base_control().get_theme_icon(x_icon, "EditorIcons")

		add_custom_type(x[0], x[1].get_instance_base_type(), x[1], x_icon)


func _exit_tree():
	for x in added_scripts:
		remove_custom_type(x[0])
