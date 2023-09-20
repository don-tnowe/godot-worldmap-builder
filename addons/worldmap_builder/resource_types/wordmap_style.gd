@tool
class_name WorldmapStyle
extends Resource

## Tint icons by this color, white to draw unchanged.
@export var icon_modulate := Color.WHITE
## Tint icon borders by this color, white to draw unchanged.
@export var icon_border_modulate := Color.WHITE
## Tint connection lines by this color, white to draw unchanged.
@export var connection_modulate := Color.WHITE

## Texture drawn over every icon, for each [member WorldmapNodeData.size_tier].
@export var icon_borders : Array[Texture2D]
## Texture drawn over straight connections. If none, draws solid lines.
@export var straight_tex : Texture2D
## The UV region of [member straight_tex], in pixels.
@export var straight_tex_region := Rect2()
## Repeats the texture. Make sure it's configured to repeat.
@export var straight_tex_repeat := false

## If a line is drawn between nodes with different styles, the one with higher priority will be used._add_cell_to_selection
@export var priority := 0


func draw_node(canvas : CanvasItem, data : WorldmapNodeData, pos : Vector2):
	if data == null || data.texture == null:
		return

	var used_border := icon_borders[mini(data.size_tier, icon_borders.size() - 1)]
	canvas.draw_texture(data.texture, pos - data.texture.get_size() * 0.5)
	canvas.draw_texture(used_border, pos - used_border.get_size() * 0.5)


func draw_connection(canvas : CanvasItem, other : WorldmapStyle, pos1 : Vector2, pos2 : Vector2):
	if other.priority > priority:
		other.draw_connection(canvas, other, pos2, pos1)
		return

	if pos1.x > pos2.x:
		var pos_swap := pos1
		pos1 = pos2
		pos2 = pos_swap

	var line_perpendicular_offset := (pos2 - pos1)
	var tex_size := straight_tex.get_size()
	var line_uv_region := Rect2(straight_tex_region.position / tex_size, straight_tex_region.size / tex_size)
	var tex_uv_x_end := (pos1 - pos2).length() / tex_size.x if straight_tex_repeat else straight_tex_region.end.x
	line_perpendicular_offset = Vector2(line_perpendicular_offset.y, -line_perpendicular_offset.x).normalized() * tex_size.y * line_uv_region.size.y

	canvas.draw_colored_polygon(
		[
			pos1 - line_perpendicular_offset,
			pos1 + line_perpendicular_offset,
			pos2 + line_perpendicular_offset,
			pos2 - line_perpendicular_offset
		],
		connection_modulate,
		[
			Vector2(line_uv_region.position.x,line_uv_region.end.y),
			line_uv_region.position,
			Vector2(tex_uv_x_end, line_uv_region.position.y),
			Vector2(tex_uv_x_end, line_uv_region.end.y)],
		straight_tex
	)
