extends RefCounted

const WorldmapEditorContextMenuClass := preload("res://addons/worldmap_builder/editor/worldmap_path_context_menu.gd")

var plugin : EditorPlugin

var draw_connection_end_color := Color.GOLD
var draw_line_color := Color.WHITE
var draw_line_size := 2.0
var draw_marker : Texture2D
var draw_marker_add : Texture2D
var snap_angle := 5.0

var edited_object : Object:
	set(v):
		edited_object = v
		plugin.update_overlays()

var last_dragging := -1
var dragging := -1
var context_menu : Popup


func _init(plugin : EditorPlugin):
	var ctrl := plugin.get_editor_interface().get_base_control()
	draw_marker = ctrl.get_theme_icon(&"EditorPathSharpHandle", &"EditorIcons")
	draw_marker_add = ctrl.get_theme_icon(&"EditorHandleAdd", &"EditorIcons")
	self.plugin = plugin


func _handles(object : Object):
	return object is WorldmapPath || object is WorldmapGraph


func _forward_canvas_draw_over_viewport(overlay : Control):
	if edited_object == null: return
	var vp_xform := _get_viewport_xform()
	var markers := _get_marker_positions()
	if markers.size() <= last_dragging:
		last_dragging = markers.size() - 1

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

	if edited_object is WorldmapGraph:
		var pos_arr : Array = edited_object.node_positions
		var selected_node_pos := markers[last_dragging]
		var add_node_distance : float = edited_object.connection_min_length
		if add_node_distance <= 0.0:
			add_node_distance = 32.0

		var selected_node_radius := vp_xform.get_scale().x * add_node_distance
		overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 0.05, PI * 0.45, 8, draw_line_color, draw_line_size)
		overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 0.55, PI * 0.95, 8, draw_line_color, draw_line_size)
		overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 1.05, PI * 1.45, 8, draw_line_color, draw_line_size)
		overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 1.55, PI * 1.95, 8, draw_line_color, draw_line_size)

		for i in edited_object.connection_nodes.size():
			var connection : Vector2i = edited_object.connection_nodes[i]
			var connection_start : Vector2 = pos_arr[connection.x]
			var connection_vec : Vector2 = pos_arr[connection.y] - connection_start
			var connection_weights : Vector2 = edited_object.connection_weights[i]
			var poly_pt_offset := Vector2(-connection_vec.y, connection_vec.x).normalized() * draw_line_size * 0.5

			var c1 := Color(draw_line_color, connection_weights.x / maxf(connection_weights.x, connection_weights.y))
			var c2 := Color(draw_line_color, connection_weights.y / maxf(connection_weights.x, connection_weights.y))

			overlay.draw_polygon([
				vp_xform * (connection_start) + poly_pt_offset * maxf(connection_weights.x, 1.0),
				vp_xform * (connection_start) - poly_pt_offset * maxf(connection_weights.x, 1.0),
				vp_xform * (connection_start + connection_vec) - poly_pt_offset * maxf(connection_weights.y, 1.0),
				vp_xform * (connection_start + connection_vec) + poly_pt_offset * maxf(connection_weights.y, 1.0),
			], [
				c1, c1, c2, c2,
			])

		var add_icon_size := draw_marker_add.get_size()
		var mouse_pos := overlay.get_local_mouse_position()
		if _is_within_ring(mouse_pos, selected_node_pos, selected_node_radius, add_icon_size.x):
			var snapped_angle := snappedf((mouse_pos - selected_node_pos).angle(), deg_to_rad(snap_angle))
			var snapped_offset := Vector2(selected_node_radius * cos(snapped_angle), selected_node_radius * sin(snapped_angle))
			overlay.draw_texture(draw_marker_add, selected_node_pos + snapped_offset - add_icon_size * 0.5)

		var font := overlay.get_theme_font("Font", "EditorFonts")
		var fontsize := overlay.get_theme_font_size("Font", "EditorFonts")
		var node_index_string := str(last_dragging)
		var index_label_size := font.get_string_size(node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize)
		var index_label_offset := Vector2(-index_label_size.x * 0.5, -index_label_size.y - 0.5 * draw_marker.get_size().y)
		overlay.draw_string_outline(font, selected_node_pos + index_label_offset, node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize, 4, Color.BLACK)
		overlay.draw_string(font, selected_node_pos + index_label_offset, node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize)

	var marker_size := draw_marker.get_size()
	for i in markers.size():
		overlay.draw_texture(draw_marker, markers[i] - marker_size * 0.5)

	if edited_object is WorldmapGraph:
		for x in edited_object.end_connection_nodes:
			overlay.draw_texture(draw_marker, vp_xform * edited_object.node_positions[x] - marker_size * 0.5, draw_connection_end_color)


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
				if _handle_non_marker_click(event):
					return true

				var markers := _get_marker_positions()
				for i in markers.size():
					if event.position.distance_squared_to(markers[i]) < marker_radius_squared:
						dragging = i
						last_dragging = i
						return true

			elif was_dragging != -1:
				plugin.get_undo_redo().create_action("Finish Moving Handle")
				plugin.get_undo_redo().add_undo_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().add_do_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().commit_action(true)

			return false

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var markers := _get_marker_positions()
				for i in markers.size():
					if event.position.distance_squared_to(markers[i]) < marker_radius_squared:
						var menu_pos : Vector2 = event.global_position + plugin.get_editor_interface().get_base_control().get_screen_position()
						context_menu = WorldmapEditorContextMenuClass.open_context_menu_for_marker(edited_object, menu_pos, i, plugin)
						last_dragging = i
						return true

			return false

	if event is InputEventMouseMotion:
		return _handle_drag(event)

	return false


func _handle_drag(event : InputEventMouseMotion) -> bool:
	var vp_xform := _get_viewport_xform()
	var undoredo := plugin.get_undo_redo()
	var property := &""
	if edited_object is WorldmapPath:
		match dragging:
			-1: return false
			0: property = &"start"
			1: property = &"end"
			2: property = &"handle_1"
			3: property = &"handle_2"

	if edited_object is WorldmapGraph:
		if dragging == -1: return false
		property = "node_%d/position" % dragging

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


func _handle_non_marker_click(event : InputEventMouseButton) -> bool:
	if edited_object is WorldmapGraph:
		var vp_xform := _get_viewport_xform()
		var add_node_distance : float = edited_object.connection_min_length
		if add_node_distance <= 0.0:
			add_node_distance = 32.0

		var selected_node_radius := vp_xform.get_scale().x * add_node_distance
		var selected_node_pos : Vector2 = edited_object.node_positions[last_dragging]
		if _is_within_ring(event.position, vp_xform * selected_node_pos, selected_node_radius, draw_marker_add.get_width()):
			var snapped_angle := snappedf((event.position - vp_xform * selected_node_pos).angle(), deg_to_rad(snap_angle))
			var snapped_offset := Vector2(add_node_distance * cos(snapped_angle), add_node_distance * sin(snapped_angle))
			edited_object.add_node(selected_node_pos + snapped_offset, last_dragging)
			last_dragging = edited_object.node_datas.size() - 1
			plugin.update_overlays()
			return true

		return false

	return false


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

		elif x is WorldmapGraph:
			if x == edited_object:
				continue

			for pt_index in x.end_connection_nodes:
				if x.node_positions[pt_index].distance_squared_to(pos) < snap_distance_squared:
					return x.node_positions[pt_index]

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


func _is_within_ring(pos : Vector2, ring_pos : Vector2, ring_radius : float, ring_thickness : float) -> bool:
	var l2 := (pos - ring_pos).length_squared()
	ring_thickness *= 0.5
	return l2 <= (ring_radius + ring_thickness) * (ring_radius + ring_thickness) && l2 >= (ring_radius - ring_thickness) * (ring_radius - ring_thickness)


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

	if edited_object is WorldmapGraph:
		for x in edited_object.node_positions:
			result.append(xform * x)

	return result
