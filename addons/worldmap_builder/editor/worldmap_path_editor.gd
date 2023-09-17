extends RefCounted

const WorldmapEditorContextMenuClass := preload("res://addons/worldmap_builder/editor/worldmap_path_context_menu.gd")

var plugin : EditorPlugin

var draw_line_color := Color.WHITE
var draw_line_size := 2.0
var draw_marker : Texture2D
var snap_angle := 5.0

var edited_object : Object:
	set(v):
		edited_object = v
		plugin.update_overlays()

var dragging := -1
var context_menu : Popup


func _init(plugin : EditorPlugin):
	var ctrl := plugin.get_editor_interface().get_base_control()
	draw_marker = ctrl.get_theme_icon(&"EditorPathSharpHandle", &"EditorIcons")
	self.plugin = plugin


func _handles(object : Object):
	return object is WorldmapPath


func _forward_canvas_draw_over_viewport(overlay : Control):
	if edited_object == null: return
	var markers := _get_marker_positions()
	if edited_object is WorldmapPath:
		match edited_object.mode:
			0:
				overlay.draw_line(markers[0], markers[1], draw_line_color, draw_line_size)
			1:
				overlay.draw_line(markers[0], markers[2], draw_line_color, draw_line_size)
				overlay.draw_line(markers[1], markers[2], draw_line_color, draw_line_size)
			2:
				overlay.draw_line(markers[0], markers[2], draw_line_color, draw_line_size)
				overlay.draw_line(markers[1], markers[3], draw_line_color, draw_line_size)

	for x in markers:
		overlay.draw_texture(draw_marker, x - draw_marker.get_size() * 0.5)


func _forward_canvas_gui_input(event : InputEvent) -> bool:
	plugin.update_overlays()
	if edited_object == null: return false

	var marker_radius_squared := draw_marker.get_size().x * 0.5
	marker_radius_squared *= marker_radius_squared

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var was_dragging := dragging
			dragging = -1
			if event.pressed:
				var markers := _get_marker_positions()
				for i in markers.size():
					if event.position.distance_squared_to(markers[i]) < marker_radius_squared:
						dragging = i
						return true

			elif was_dragging != -1:
				plugin.get_undo_redo().create_action("Finish Moving Handle")
				plugin.get_undo_redo().add_undo_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().add_do_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().commit_action(true)

			return false

		if event.button_index == MOUSE_BUTTON_RIGHT && dragging == -1:
			if event.pressed:
				var markers := _get_marker_positions()
				for i in markers.size():
					if event.position.distance_squared_to(markers[i]) < marker_radius_squared:
						var menu_pos : Vector2 = event.global_position + plugin.get_editor_interface().get_base_control().get_screen_position()
						context_menu = WorldmapEditorContextMenuClass.open_context_menu_for_marker(edited_object, menu_pos, i, plugin)
						return true

			return false

	if event is InputEventMouseMotion:
		return _handle_drag(event)

	return false


func _handle_drag(event : InputEvent) -> bool:
	var vp_xform := _get_viewport_xform()
	var undoredo := plugin.get_undo_redo()
	var property := &""
	match dragging:
		-1: return false
		0: property = &"start"
		1: property = &"end"
		2: property = &"handle_1"
		3: property = &"handle_2"

	var old_value := edited_object.get(property)
	var target_value : Vector2 = vp_xform.affine_inverse() * event.position
	if !event.ctrl_pressed:
		var snap_targets : Array = edited_object.get_parent().get_children()
		var snap_distance_squared := draw_marker.get_size().x * 0.5
		snap_distance_squared *= snap_distance_squared
		target_value = _get_snap(snap_targets, target_value, snap_distance_squared)

	undoredo.create_action("Move Handle", UndoRedo.MERGE_ENDS)
	undoredo.add_undo_property(edited_object, property, old_value)
	undoredo.add_do_property(edited_object, property, target_value)
	undoredo.commit_action(true)

	return true


func _get_snap(snap_targets : Array, pos : Vector2, snap_distance_squared : float) -> Vector2:
	for x in snap_targets:
		if x is WorldmapPath:
			if x == edited_object:
				var pos_new := _arc_snap_end(pos, snap_distance_squared)
				if pos_new != pos:
					return pos_new

				continue

			if x.start.distance_squared_to(pos) < snap_distance_squared:
				return x.start

			if x.end.distance_squared_to(pos) < snap_distance_squared:
				return x.end

		elif x is Node2D:
			if x.position.distance_squared_to(pos) < snap_distance_squared:
				return x.position

	return pos


func _arc_snap_end(pos : Vector2, snap_distance_squared : float) -> Vector2:
	var start_point := Vector2()
	var end_point := Vector2()
	var center_point : Vector2 = edited_object.handle_1
	if edited_object.mode != WorldmapPath.PathMode.BEZIER:
		if dragging == 0:
			start_point = edited_object.end
			end_point = edited_object.start

		elif dragging == 1:
			start_point = edited_object.start
			end_point = edited_object.end

		else:
			return pos

	else:
		if dragging == 2:
			center_point = edited_object.start
			start_point = Vector2((edited_object.handle_1 - edited_object.start).length(), 0) + edited_object.start
			end_point = edited_object.handle_1

		elif dragging == 3:
			center_point = edited_object.end
			start_point = Vector2((edited_object.handle_2 - edited_object.end).length(), 0) + edited_object.end
			end_point = edited_object.handle_2

		else:
			return pos

	if edited_object.mode == WorldmapPath.PathMode.LINE:
		center_point = start_point
		start_point = Vector2((end_point - start_point).length(), 0) + start_point

	var target_value_snapped : Vector2 = (start_point - center_point)
	var arc_angle : float = (start_point - center_point).angle_to(end_point - center_point)
	var arc_angle_snapped : float = snappedf(arc_angle, deg_to_rad(snap_angle))
	if is_equal_approx(arc_angle_snapped, PI):
		# TODO: make this 180-degree snap actually consistent (if mouse on one side, then arc goes there instead of jittering)
		var rotated90 := (end_point - center_point)
		rotated90 = Vector2(rotated90.y, -rotated90.x).normalized()
		var dot := rotated90.dot((pos - center_point).normalized())
		if dot < 0.0:
			arc_angle_snapped -= 0.001

		else:
			arc_angle_snapped += 0.001

	target_value_snapped = center_point + target_value_snapped.rotated(arc_angle_snapped)
	if pos.distance_squared_to(target_value_snapped) < snap_distance_squared:
		return target_value_snapped

	return pos


func _get_viewport_xform() -> Transform2D:
	var xform : Transform2D = edited_object.get_viewport().global_canvas_transform
	return xform.translated(edited_object.position * xform.get_scale())


func _get_marker_positions() -> Array[Vector2]:
	var result : Array[Vector2] = []
	var xform : Transform2D = _get_viewport_xform()
	if edited_object is WorldmapPath:
		result.append(xform * edited_object.start)
		result.append(xform * edited_object.end)
		if edited_object.mode == WorldmapPath.PathMode.ARC:
			result.append(xform * edited_object.handle_1)

		if edited_object.mode == WorldmapPath.PathMode.BEZIER:
			result.append(xform * edited_object.handle_1)
			result.append(xform * edited_object.handle_2)

	return result
