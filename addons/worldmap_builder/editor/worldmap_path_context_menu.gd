extends RefCounted


static func open_context_menu_for_marker(obj : Object, screen_position : Vector2, marker_index : int, plugin : EditorPlugin) -> Popup:
	if obj is WorldmapGraph:
		var menu_box := [null]  # Keep it under reference so callbacks can be told to reference it before it's created
		menu_box[0] = open_context_menu(screen_position,
			["Is End Connection", "Node Data", "Delete"],
			[
				obj.end_connection_nodes.find(marker_index) != -1,
				{&"data": obj.node_datas[marker_index], &"type": "resource", &"class_name": "WorldmapNodeData"},
			],
			[
				(func(x):
					obj.end_connection_nodes.erase(marker_index)
					if x:
						obj.end_connection_nodes.append(marker_index)
					),
				(func(node_data):
					obj.change_node(marker_index, node_data)
					plugin.get_editor_interface().edit_resource(node_data)
					),
				(func():
					obj.remove_node(marker_index)
					menu_box[0].hide()
					),
			],
			plugin,
		)
		return menu_box[0]

	if obj is WorldmapPath:
		var context_props : Array[StringName] = []
		var context_values : Array = []
		var context_callbacks : Array[Callable] = []
		if obj.mode != WorldmapPath.PathMode.ARC:
			var diff_vec := Vector2()
			var invert := 1 - marker_index * 2
			if marker_index == 2:
				diff_vec = obj.handle_1 - obj.start

			elif marker_index == 3:
				diff_vec = obj.handle_2 - obj.end

			else:
				diff_vec = invert * (obj.start - obj.end)

			context_callbacks = _get_path_context_menu_callbacks(marker_index, obj)
			context_props = ["Angle", "Length"]
			context_values = [
				rad_to_deg(diff_vec.angle()),
				diff_vec.length(),
			]

		else:
			match marker_index:
				2:
					context_props = ["Angle", "Radius", "Distance"]
					context_values = [
						rad_to_deg((obj.start - obj.handle_1).angle_to(obj.end - obj.handle_1)),
						(obj.start - obj.handle_1).length(),
						obj.get_distance_between_points(),
					]
					context_callbacks = [
						(func(x):
							x = arc_safe_180(x, (obj.start - obj.handle_1).angle_to(obj.end - obj.handle_1))
							obj.end = obj.handle_1 + (obj.start - obj.handle_1).rotated(deg_to_rad(x))
							),
						(func(x):
							var old_start : Vector2 = obj.start
							obj.start = obj.handle_1 + (obj.start - obj.handle_1).normalized() * x
							obj.end = obj.handle_1 + (obj.end - obj.handle_1).normalized() * x
							var start_diff : Vector2 = obj.start - old_start
							obj.start -= start_diff
							obj.end -= start_diff
							obj.handle_1 -= start_diff
							),
						(func(x):
							obj.set_distance_between_points(x)
							),
						]
				0, 1:
					context_props = ["Angle (absolute)", "Angle (arc)", "Radius"]
					context_values = [
						0.0,
						rad_to_deg((obj.end - obj.handle_1).angle_to(obj.start - obj.handle_1)),
						0.0,
					]
					if marker_index == 0:
						context_values[0] = rad_to_deg((obj.start - obj.handle_1).angle())
						context_values[2] = (obj.start - obj.handle_1).length()
						context_callbacks = [
							(func(x):
								# TODO: Safe arc for absolute arc setter
								obj.start = obj.handle_1 + Vector2((obj.handle_1 - obj.start).length(), 0.0).rotated(deg_to_rad(x))
								),
							(func(x):
								x = arc_safe_180(x, (obj.end - obj.handle_1).angle_to(obj.start - obj.handle_1))
								obj.start = obj.handle_1 + (obj.end - obj.handle_1).rotated(deg_to_rad(x))
								),
							(func(x):
								obj.end = obj.handle_1 + (obj.end - obj.handle_1).normalized() * x
								obj.start = obj.handle_1 + (obj.start - obj.handle_1).normalized() * x
								),
							]

					else:
						context_values[1] = -context_values[1]
						context_values[0] = rad_to_deg((obj.end - obj.handle_1).angle())
						context_values[2] = (obj.end - obj.handle_1).length()
						context_callbacks = [
							(func(x):
								# TODO: Safe arc for absolute arc setter
								obj.end = obj.handle_1 + Vector2((obj.handle_1 - obj.end).length(), 0.0).rotated(deg_to_rad(x))
								),
							(func(x):
								x = arc_safe_180(x, (obj.start - obj.handle_1).angle_to(obj.end - obj.handle_1))
								obj.end = obj.handle_1 + (obj.start - obj.handle_1).rotated(deg_to_rad(x))
								),
							(func(x):
								obj.end = obj.handle_1 + (obj.end - obj.handle_1).normalized() * x
								obj.start = obj.handle_1 + (obj.start - obj.handle_1).normalized() * x
								),
							]

		return open_context_menu(screen_position,
			context_props + ["Reverse"],
			context_values + [],
			context_callbacks + [
				(func():
					var start = obj.start
					obj.start = obj.end
					obj.end = start
					),
			],
			plugin,
		)

	return null


static func _get_path_context_menu_callbacks(marker_index : int, obj : WorldmapPath) -> Array[Callable]:
	match marker_index:
		0:
			return [
				(func(x):
					obj.start = obj.end + Vector2((obj.start - obj.end).length(), 0.0).rotated(deg_to_rad(x))
					),
				(func(x):
					obj.start = obj.end + (obj.start - obj.end).normalized() * max(x, 0.001)
					),
				]
		1:
			return [
				(func(x):
					obj.end = obj.start + Vector2((obj.end - obj.start).length(), 0.0).rotated(deg_to_rad(x))
					),
				(func(x):
					obj.end = obj.start + (obj.end - obj.start).normalized() * max(x, 0.001)
					),
				]
		2:
			return [
				(func(x):
					obj.handle_1 = obj.start + Vector2((obj.handle_1 - obj.start).length(), 0.0).rotated(deg_to_rad(x))
					),
				(func(x):
					obj.handle_1 = obj.start + (obj.handle_1 - obj.start).normalized() * max(x, 0.001)
					),
				]
		3:
			return [
				(func(x):
					obj.handle_2 = obj.end + Vector2((obj.handle_2 - obj.end).length(), 0.0).rotated(deg_to_rad(x))
					),
				(func(x):
					obj.handle_2 = obj.end + (obj.handle_2 - obj.end).normalized() * max(x, 0.001)
					),
				]

	return []


static func open_context_menu(screen_position : Vector2, names : Array, values : Array, callbacks : Array, plugin : EditorPlugin) -> Popup:
	var count := mini(names.size(), callbacks.size())
	if values.size() < count:
		values = values.duplicate()
		values.resize(count)  # And fill with <null>s

	var root_box := VBoxContainer.new()
	var cur_grid : GridContainer
	for i in count:
		if values[i] == null:
			if cur_grid != null:
				root_box.add_child(cur_grid)
				cur_grid = null

			if names[i] == "":
				root_box.add_child(HSeparator.new())

			else:
				var new_button := Button.new()
				root_box.add_child(new_button)
				new_button.text = names[i]
				new_button.pressed.connect(callbacks[i])
				new_button.pressed.connect(plugin.update_overlays)

			continue

		if cur_grid == null:
			cur_grid = GridContainer.new()
			cur_grid.columns = 2

		var prop_label := Label.new()
		var prop_type := typeof(values[i])
		var prop_editor : Control
		match prop_type:
			TYPE_INT, TYPE_FLOAT:
				prop_editor = EditorSpinSlider.new()
				prop_editor.allow_greater = true
				prop_editor.allow_lesser = true
				prop_editor.hide_slider = true
				if prop_type != TYPE_INT:
					prop_editor.step = 0.001

				prop_editor.value = values[i]
				prop_editor.value_changed.connect(callbacks[i])
				prop_editor.value_changed.connect(plugin.update_overlays.unbind(1))
				prop_editor.custom_minimum_size = Vector2(64.0, 0.0)

			TYPE_STRING, TYPE_STRING_NAME:
				prop_editor = LineEdit.new()
				prop_editor.value = values[i]
				prop_editor.text_changed.connect(callbacks[i])
				prop_editor.text_changed.connect(plugin.update_overlays.unbind(1))
				prop_editor.custom_minimum_size = Vector2(64.0, 0.0)

			TYPE_BOOL:
				prop_editor = CheckBox.new()
				prop_editor.button_pressed = values[i]
				prop_editor.toggled.connect(callbacks[i])
				prop_editor.toggled.connect(plugin.update_overlays.unbind(1))
				
			TYPE_DICTIONARY:
				match values[i][&"type"]:
					"resource":
						prop_editor = EditorResourcePicker.new()
						prop_editor.base_type = values[i][&"class_name"]
						prop_editor.edited_resource = values[i][&"data"]
						prop_editor.resource_changed.connect(callbacks[i])
						prop_editor.resource_changed.connect(plugin.update_overlays.unbind(1))
						prop_editor.custom_minimum_size = Vector2(192.0, 0.0)
						prop_editor.get_child(0).pressed.connect(func():
							prop_editor.get_child(1).pressed.emit()

							# Emit the signal as if "Quick Load" was pressed.
							# This does not work in practice (tested on 4.3 stable): the opened window immediately closes.

							# prop_editor.get_child(2).id_pressed.emit.call_deferred(1)
						)

					"resource_array":
						prop_editor = ScrollContainer.new()
						prop_editor.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
						prop_editor.custom_minimum_size = Vector2(192.0, 64.0)

						var picker_box := GridContainer.new()
						picker_box.columns = 2
						picker_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						prop_editor.add_child(picker_box)

						var picker_class_name : String = values[i][&"class_name"]
						var picker_data : Array = values[i][&"data"]
						for resource_i in values[i][&"data"].size():
							var picker := EditorResourcePicker.new()
							picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
							picker.base_type = picker_class_name
							picker.edited_resource = picker_data[resource_i]
							picker.resource_changed.connect(callbacks[i].bind(resource_i))
							picker.resource_changed.connect(plugin.update_overlays.unbind(1))
							picker.get_child(0).pressed.connect(func():
								picker.get_child(1).pressed.emit()
							)

							var picker_label := Label.new()
							picker_label.text = str(resource_i)
							picker_box.add_child(picker_label)
							picker_box.add_child(picker)

		prop_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prop_label.text = names[i]
		cur_grid.add_child(prop_label)
		cur_grid.add_child(prop_editor)

	if cur_grid != null:
		root_box.add_child(cur_grid)

	var context_menu := PopupPanel.new()
	context_menu.add_child(root_box)
	plugin.get_editor_interface().get_base_control().add_child(context_menu)

	context_menu.popup_centered()
	context_menu.size = root_box.get_minimum_size()
	context_menu.position = screen_position
	context_menu.visibility_changed.connect(func(): context_menu.queue_free())
	return context_menu


static func arc_equalize_length(point1 : Vector2, point2 : Vector2, center : Vector2):
	return center + (point2 - center).normalized() * (point1 - center).length()


static func arc_safe_180(angle_degrees : float, old_angle_degrees : float) -> float:
	if is_equal_approx(angle_degrees, 180.0):
		if wrapf(old_angle_degrees, 0.0, 360.0) > 180.0:
			return angle_degrees + 0.01

		else:
			return angle_degrees - 0.01

	return angle_degrees
