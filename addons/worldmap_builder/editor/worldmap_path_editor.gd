extends RefCounted

const WorldmapEditorContextMenuClass := preload("res://addons/worldmap_builder/editor/worldmap_path_context_menu.gd")

var plugin : EditorPlugin

var draw_connection_end_color := Color.GOLD
var draw_line_color := Color.WHITE
var draw_line_size := 2.0
var draw_marker : Texture2D
var draw_marker_add : Texture2D
var draw_marker_checkbox_checked : Texture2D
var draw_marker_checkbox_unchecked : Texture2D
var snap_angle := 15.0
var button_margin := 4.0

var edited_object : Object:
	set(v):
		edited_object = v
		if v is WorldmapViewItem:
			var siblings : Array = v.get_parent().get_children()
			edited_sibling_rects.resize(siblings.size())
			for i in siblings.size():
				edited_sibling_rects[i] = Rect2()
				if siblings[i] is WorldmapViewItem:
					edited_sibling_rects[i] = siblings[i].get_clickable_rect()
					edited_sibling_rects[i].position += siblings[i].position

		plugin.update_overlays()

var edited_sibling_rects : Array[Rect2] = []
var last_dragging := -1
var dragging := -1
var context_menu : Popup


func _init(plugin : EditorPlugin):
	var ctrl := plugin.get_editor_interface().get_base_control()
	draw_marker = ctrl.get_theme_icon(&"EditorPathSharpHandle", &"EditorIcons")
	draw_marker_add = ctrl.get_theme_icon(&"EditorHandleAdd", &"EditorIcons")
	draw_marker_checkbox_checked = ctrl.get_theme_icon(&"checked", &"CheckBox")
	draw_marker_checkbox_unchecked = ctrl.get_theme_icon(&"unchecked", &"CheckBox")
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
		_draw_graph(overlay, vp_xform, markers)

	var marker_size := draw_marker.get_size()

	if edited_object is WorldmapGraph:
		for i in markers.size():
			overlay.draw_texture(draw_marker, markers[i] - marker_size * 0.5)

		for x in edited_object.end_connection_nodes:
			overlay.draw_texture(draw_marker, vp_xform * (edited_object.node_positions[x] + edited_object.global_position) - marker_size * 0.5, draw_connection_end_color)

	if edited_object is WorldmapPath:
		overlay.draw_texture(draw_marker, markers[0] - marker_size * 0.5, draw_connection_end_color)
		overlay.draw_texture(draw_marker, markers[1] - marker_size * 0.5, draw_connection_end_color)
		match edited_object.mode:
			1:
				overlay.draw_texture(draw_marker, markers[2] - marker_size * 0.5)
			2:
				overlay.draw_texture(draw_marker, markers[2] - marker_size * 0.5)
				overlay.draw_texture(draw_marker, markers[3] - marker_size * 0.5)


func _draw_graph(overlay : Control, vp_xform : Transform2D, markers : Array[Vector2]):
	var pos_arr : Array = edited_object.node_positions.duplicate()
	for i in pos_arr.size():
		pos_arr[i] += edited_object.global_position

	var selected_node_pos := markers[last_dragging]
	var add_node_distance : float = edited_object.connection_min_length
	if add_node_distance <= 0.0:
		add_node_distance = 32.0

	# --- Add Node ring

	var selected_node_radius := vp_xform.get_scale().x * add_node_distance
	overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 0.05, PI * 0.45, 8, draw_line_color, draw_line_size)
	overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 0.55, PI * 0.95, 8, draw_line_color, draw_line_size)
	overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 1.05, PI * 1.45, 8, draw_line_color, draw_line_size)
	overlay.draw_arc(selected_node_pos, selected_node_radius, PI * 1.55, PI * 1.95, 8, draw_line_color, draw_line_size)

	# --- Connection lines

	var connections_with_selected : Array[bool] = []
	connections_with_selected.resize(markers.size())
	connections_with_selected.fill(false)
	for i in edited_object.connection_nodes.size():
		var connection : Vector2i = edited_object.connection_nodes[i]

		if connection.x == last_dragging:
			connections_with_selected[connection.y] = true

		if connection.y == last_dragging:
			connections_with_selected[connection.x] = true

		var connection_start : Vector2 = pos_arr[connection.x]
		var connection_vec : Vector2 = pos_arr[connection.y] - connection_start
		var connection_costs : Vector2 = edited_object.connection_costs[i]
		var poly_pt_offset := Vector2(-connection_vec.y, connection_vec.x).normalized() * draw_line_size * 0.5

		var c1 := draw_line_color
		var c2 := draw_line_color

		if connection_costs.x == INF:
			c1.a = 0.0
			connection_costs.x = connection_costs.y

		if connection_costs.y == INF:
			c2.a = 0.0
			connection_costs.y = connection_costs.x

		overlay.draw_polygon([
			vp_xform * (connection_start) + poly_pt_offset * maxf(connection_costs.x, 1.0),
			vp_xform * (connection_start) - poly_pt_offset * maxf(connection_costs.x, 1.0),
			vp_xform * (connection_start + connection_vec) - poly_pt_offset * maxf(connection_costs.y, 1.0),
			vp_xform * (connection_start + connection_vec) + poly_pt_offset * maxf(connection_costs.y, 1.0),
		], [
			c1, c1, c2, c2,
		])

	# --- Checkboxes for connections

	var checkbox_size := draw_marker_checkbox_checked.get_size()
	for i in markers.size():
		if i == last_dragging:
			continue

		var tex := draw_marker_checkbox_checked if connections_with_selected[i] else draw_marker_checkbox_unchecked
		overlay.draw_texture(tex, markers[i].move_toward(markers[last_dragging], checkbox_size.x + checkbox_size.y) - checkbox_size * 0.5)

	# --- Add Node ring: add position marker

	var add_icon_size := draw_marker_add.get_size()
	var mouse_pos := overlay.get_local_mouse_position()
	if _is_within_ring(mouse_pos, selected_node_pos, selected_node_radius, add_icon_size.x):
		var snapped_angle := snappedf((mouse_pos - selected_node_pos).angle(), deg_to_rad(snap_angle))
		var snapped_offset := Vector2(selected_node_radius * cos(snapped_angle), selected_node_radius * sin(snapped_angle))
		overlay.draw_texture(draw_marker_add, selected_node_pos + snapped_offset - add_icon_size * 0.5)

	# --- Node index label

	var font := overlay.get_theme_font("Font", "EditorFonts")
	var fontsize := overlay.get_theme_font_size("Font", "EditorFonts")
	var node_index_string := str(last_dragging)
	var index_label_size := font.get_string_size(node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize)
	var index_label_offset := Vector2(-index_label_size.x * 0.5, -index_label_size.y - 0.5 * draw_marker.get_size().y)
	overlay.draw_string_outline(font, selected_node_pos + index_label_offset, node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize, 4, Color.BLACK)
	overlay.draw_string(font, selected_node_pos + index_label_offset, node_index_string, HORIZONTAL_ALIGNMENT_CENTER, -1, fontsize)


func _forward_canvas_gui_input(event : InputEvent) -> bool:
	if edited_object == null: return false

	var marker_radius_squared := draw_marker.get_size().x * 0.5
	marker_radius_squared *= marker_radius_squared

	if event is InputEventMouseButton:
		plugin.update_overlays.call_deferred()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var was_dragging := dragging
			dragging = -1
			if event.pressed:
				var markers := _get_marker_positions()
				for i in markers.size():
					if event.position.distance_squared_to(markers[i]) < marker_radius_squared:
						dragging = i
						last_dragging = i
						plugin.get_editor_interface().edit_node(null)
						plugin.get_editor_interface().edit_node(edited_object)
						return true

				if _handle_non_marker_click(event):
					return true

			elif was_dragging != -1:
				plugin.get_undo_redo().create_action("Finish Moving Handle")
				plugin.get_undo_redo().add_undo_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().add_do_property(edited_object, &"position", edited_object.position)
				plugin.get_undo_redo().commit_action(true)
				edited_object.get_parent().queue_redraw()

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
		if dragging != -1:
			return _handle_drag(event)

		# TODO: only update if view actually changes
		plugin.update_overlays()
		return false

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
	var target_value : Vector2 = vp_xform.affine_inverse() * event.position - edited_object.global_position
	if !event.ctrl_pressed:
		var snap_targets : Array = edited_object.get_parent().get_children()
		var snap_distance_squared := draw_marker.get_size().x * 0.5
		snap_distance_squared *= snap_distance_squared
		var target_value_snapped := _get_snap(snap_targets, target_value, snap_distance_squared)
		if target_value_snapped == target_value:
			target_value_snapped = target_value.snappedf(edited_object.get_parent().node_grid_snap)

		target_value = target_value_snapped

	undoredo.create_action("Move Handle", UndoRedo.MERGE_ENDS)
	undoredo.add_undo_property(edited_object, property, old_value)
	undoredo.add_do_property(edited_object, property, target_value)
	undoredo.commit_action(true)

	plugin.update_overlays()
	return true


func _handle_non_marker_click(event : InputEventMouseButton) -> bool:
	var vp_xform := _get_viewport_xform()
	var handle_input_anyway := false

	if edited_object is WorldmapGraph:
		var selected_node_pos : Vector2 = edited_object.node_positions[last_dragging]
		var selected_node_pos_onscreen : Vector2 = vp_xform * (selected_node_pos + edited_object.global_position)
		var mouse_pos := event.position

		# --- Add Connection checkboxes

		var checkbox_size := draw_marker_checkbox_checked.get_size() + Vector2.ONE * (button_margin + button_margin)
		var checkbox_offset := checkbox_size.x + checkbox_size.y - button_margin * 4.0
		for i in edited_object.node_positions.size():
			if i == last_dragging:
				continue

			var checkbox_origin : Vector2 = (vp_xform * (edited_object.node_positions[i] + edited_object.global_position)).move_toward(selected_node_pos_onscreen, checkbox_offset)
			if Rect2(checkbox_origin - checkbox_size * 0.5, checkbox_size).has_point(mouse_pos):
				edited_object.set_connected(last_dragging, i, !edited_object.connection_exists(last_dragging, i))
				plugin.update_overlays()
				return true

		# --- Add Node ring

		var add_node_distance : float = edited_object.connection_min_length
		if add_node_distance <= 0.0:
			add_node_distance = 32.0

		var selected_node_radius := vp_xform.get_scale().x * add_node_distance
		if _is_within_ring(mouse_pos, selected_node_pos_onscreen, selected_node_radius, draw_marker_add.get_width()):
			var snapped_angle := snappedf((mouse_pos - selected_node_pos_onscreen).angle(), deg_to_rad(snap_angle))
			var snapped_offset := Vector2(add_node_distance * cos(snapped_angle), add_node_distance * sin(snapped_angle))
			edited_object.add_node(selected_node_pos + snapped_offset, last_dragging)
			last_dragging = edited_object.node_datas.size() - 1
			plugin.update_overlays()
			return true

	# --- Clicking on other graph items

	if edited_object is WorldmapViewItem:
		var click_pos : Vector2 = vp_xform.affine_inverse() * event.position - edited_object.global_position
		for i in edited_sibling_rects.size():
			if edited_sibling_rects[i].has_point(click_pos):
				var clicked_node : Node = edited_object.get_parent().get_child(i)
				if clicked_node == edited_object:
					handle_input_anyway = true
					continue

				plugin.get_editor_interface().edit_node(null)
				plugin.get_editor_interface().edit_node(clicked_node)
				return true

	return handle_input_anyway


func _get_snap(snap_targets : Array, pos : Vector2, snap_distance_squared : float) -> Vector2:
	for x in snap_targets:
		if x is WorldmapPath:
			if x == edited_object:
				var pos_new := _arc_snap_end(pos, snap_distance_squared)
				if pos_new != pos:
					return pos_new

				continue

			if x.snap_to_all:
				for i in x.get_node_count():
					if x.get_node_position(i).distance_squared_to(pos) < snap_distance_squared:
						return x.get_node_position(i)

			else:
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
		result.append(xform * (edited_object.start + edited_object.global_position))
		result.append(xform * (edited_object.end + edited_object.global_position))
		if edited_object.mode == WorldmapPath.PathMode.ARC:
			result.append(xform * (edited_object.handle_1 + edited_object.global_position))

		if edited_object.mode == WorldmapPath.PathMode.BEZIER:
			result.append(xform * (edited_object.handle_1 + edited_object.global_position))
			result.append(xform * (edited_object.handle_2 + edited_object.global_position))

	if edited_object is WorldmapGraph:
		for x in edited_object.node_positions:
			result.append(xform * (x + edited_object.global_position))

	return result
