extends Control

var overlay : RefCounted
var dragging_resource : Resource
var dropping_onto_node_index := -1
var dropping_onto_node_position := Vector2()
var dropping_onto_node_global_radius := 0.0


func _init(with_overlay : RefCounted) -> void:
    overlay = with_overlay
    hide()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if dragging_resource == null:
        if data.get(&"type", &"") == &"files":
            dragging_resource = load(data[&"files"][0])

        elif data.get(&"type", &"") == &"resource":
            dragging_resource = data[&"resource"]

        if dragging_resource == null || !(dragging_resource is WorldmapNodeData):
            dragging_resource = null
            hide()

    return true


func set_enabled(state : bool):
    set_process_input(state)
    if !state:
        hide()


func _draw() -> void:
    if dropping_onto_node_index == -1:
        return

    var nearest_marker_index := 0
    var nearest_marker_distance := INF
    var markers : Array[Vector2] = _get_marker_positions()
    for i in markers.size():
        if dropping_onto_node_index == i:
            draw_circle(markers[i], 48.0, Color(1.0, 1.0, 0.25, 0.25))

        else:
            draw_circle(markers[i], 32.0, Color(1.0, 1.0, 1.0, 0.25))


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
        if event.is_pressed():
            if !get_rect().has_point(event.global_position):
                show()

        else:
            if dragging_resource != null && dropping_onto_node_index != -1:
                if !(overlay.edited_object is WorldmapViewItem):
                    return

                overlay.edited_object.set_node_data(dropping_onto_node_index, dragging_resource)
                overlay.edited_object.queue_redraw()

            dragging_resource = null
            dropping_onto_node_index = -1
            hide()

    if event is InputEventMouseMotion && dragging_resource != null:
        if get_rect().has_point(event.global_position):
            var nearest_marker_index := 0
            var nearest_marker_distance := INF
            var markers : Array[Vector2] = _get_marker_positions()
            for i in markers.size():
                var dist : float = (event.global_position - position).distance_squared_to(markers[i])
                if dist < nearest_marker_distance:
                    nearest_marker_distance = dist
                    nearest_marker_index = i

            dropping_onto_node_index = nearest_marker_index

        else:
            dropping_onto_node_index = -1

        queue_redraw()


func _get_marker_positions() -> Array[Vector2]:
    if !(overlay.edited_object is WorldmapViewItem):
        return []

    var result : Array[Vector2] = []
    result.resize(overlay.edited_object.get_node_count())
    for i in result.size():
        result[i] = overlay._get_viewport_xform() * overlay.edited_object.get_global_transform() * overlay.edited_object.get_node_position(i)

    return result