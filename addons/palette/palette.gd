tool
extends Node2D
class_name Palette

signal paint_scene

export(Vector2)            var canvas_size     := Vector2(256, 256)
export(bool)               var disabled_       := false
export(bool)               var brush_snap_     := true
export(int, 1, 64)         var brush_size_     := 16
export(bool)               var brush_overlap_  := false
export(Array, PackedScene) var colors_         := []
export(int)                var tile_map_erase_ := -1
export(int, 1, 64)         var icon_size       := 64

var canvas_           := self
var left_mouse_down_  := false
var right_mouse_down_ := false
var color_            : PackedScene     = null
var paint_tile_id_    : int             = -1
var paint_tile_map_   : TileMap         = null
var undo_                               = null
var editor_interface_ : EditorInterface = null

var last_global_mouse_position_ := Vector2()

func zombie_(node : Object) -> void:
	node.set_process(false)
	
	if node.is_class("AudioStreamPlayer2D"):
		node.queue_free()
	if node.is_class("Area2D"):
		node.monitoring = false
	if node.is_class("CollisionShape2D"):
		node.disabled = true

	for child in node.get_children():
		zombie_(child)

func find_exisitng_tile_map() -> TileMap:
	for child in canvas_.get_children():
		if child.is_class("TileMap"):
			return child
	return null

func break_up_tile_map(color, tile_map : TileMap, grid : GridContainer) -> void:
	if find_exisitng_tile_map():
		tile_map = find_exisitng_tile_map()

	for tile_id in tile_map.tile_set.get_tiles_ids():
		var button : PaletteButton = load("res://addons/palette/palette_button.tscn").instance()
		button.rect_size         = Vector2(icon_size, icon_size)
		button.rect_min_size     = Vector2(icon_size, icon_size)
		grid.add_child(button)
		
		var icon := tile_map.duplicate()
		icon.clear()
		icon.set_cellv(Vector2(0, 0), tile_id)
		button.add_child(icon)
		icon.position = Vector2(1, 1)
		
		icon.scale = Vector2(icon_size / 16, icon_size / 16)

		button.connect("pressed", self, "_on_paint_tile_selected", [tile_map, tile_id])
		button.connect("double_clicked", self, "_on_color_double_clicked", [color])
			
func attach(grid : GridContainer) -> void:
	for color in colors_:
		var icon : Node2D = color.instance()

		if icon.is_class("TileMap"):
			break_up_tile_map(color, icon, grid)
			continue
			
		var button : PaletteButton = load("res://addons/palette/palette_button.tscn").instance()
		button.rect_size         = Vector2(icon_size, icon_size) + Vector2(2, 2)
		button.rect_min_size     = Vector2(icon_size, icon_size) + Vector2(2, 2)
		grid.add_child(button)

		icon.scale = Vector2(icon_size / 16, icon_size / 16)
		button.add_child(icon)
		icon.position = (Vector2(icon_size, icon_size) / 2) + Vector2(1, 1)
		button.connect("pressed", self, "_on_color_selected", [color])
		button.connect("double_clicked", self, "_on_color_double_clicked", [color])
		
	if not Engine.is_editor_hint():
		for child in grid.get_children():
			zombie_(child)

func _forward_canvas_gui_input(event : InputEvent) -> bool:
	draw_preview(get_global_mouse_position())

	if event is InputEventMouseButton and event.button_index == 1:
		left_mouse_down_ = event.pressed

	if event is InputEventMouseButton and event.button_index == 2:
		right_mouse_down_ = event.pressed
	
	if event is InputEventMouse:
		last_global_mouse_position_ = get_global_mouse_position()
		update()

	if left_mouse_down_:
		if event.control:
			_on_middle_click(get_global_mouse_position())
		else:
			_on_click(get_global_mouse_position())
		return true
	
	if right_mouse_down_:
		_on_right_click(get_global_mouse_position())
		return true

	return false

func detach(grid : GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()
	if cursor_:
		cursor_.queue_free()
		cursor_ = null

func _on_color_double_clicked(color : PackedScene) -> void:
	if editor_interface_:
		editor_interface_.open_scene_from_path(color.resource_path)

func _on_color_selected(color : PackedScene) -> void:
	color_          = color
	paint_tile_map_ = null
	paint_tile_id_  = -1

func _on_paint_tile_selected(tile_map : TileMap, tile_id : int) -> void:
	paint_tile_map_ = tile_map
	paint_tile_id_  = tile_id
	color_          = null

func _on_click(position : Vector2) -> void:
	if paint_tile_id_ != -1:
		paint_tile_(paint_tile_map_, paint_tile_id_, position)
	elif color_ != null:
		paint_scene_(position)
	
func _on_right_click(position : Vector2) -> void:
	if paint_tile_id_ != -1:
		erase_tile_(paint_tile_map_, paint_tile_id_, position)
	elif color_ != null:
		remove_(position)
	
func _on_middle_click(position : Vector2) -> void:
	rotate_(position)
	
func snap_(position : Vector2) -> Vector2:
	return (position - (Vector2(brush_size_, brush_size_) / 2)).snapped(Vector2(brush_size_, brush_size_))
	
func paint_scene_(position : Vector2) -> void:
	if brush_snap_:
		position = snap_(position) + (Vector2(brush_size_, brush_size_) / 2)

	if not color_:
		return

	for item in canvas_.get_children():
		if item.global_position.distance_to(position) < 8.0 and not brush_overlap_:
			return

	var ting = color_.instance()
	
	undo_.create_action("paint scene")
	undo_.add_undo_method(self, "undo_paint_scene_", ting)
	
	canvas_.add_child(ting)
	ting.global_position = position
	ting.set_owner(get_tree().get_edited_scene_root())
	
	undo_.commit_action()
	
	emit_signal("paint_scene", ting)

func undo_paint_scene_(scene_instance : Node2D) -> void:
	scene_instance.get_parent().remove_child(scene_instance)
	scene_instance.queue_free()
	
func paint_tile_(tile_map : TileMap, tile_id : int, position : Vector2) -> void:
	var tile_position   := tile_map.world_to_map(position)
	var current_tile_id := tile_map.get_cellv(tile_position)
	if current_tile_id == tile_id:
		return

	undo_.create_action("paint tile")
	undo_.add_undo_method(self, "undo_paint_tile_", tile_map, current_tile_id, position)
	tile_map.set_cellv(tile_position, tile_id)
	tile_map.update_bitmask_area(tile_position)
	undo_.commit_action()

func undo_paint_tile_(tile_map : TileMap, tile_id : int, position : Vector2) -> void:
	var tile_position := paint_tile_map_.world_to_map(position)
	tile_map.set_cellv(tile_position, tile_id)
	tile_map.update_bitmask_area(tile_position)

func erase_tile_(tile_map : TileMap, tile_id : int, position : Vector2) -> void:
	var tile_position   := paint_tile_map_.world_to_map(position)
	var current_tile_id := tile_map.get_cellv(tile_position)
	if current_tile_id == tile_map_erase_:
		remove_(position)
		return

	undo_.create_action("paint tile")
	undo_.add_undo_method(self, "undo_paint_tile_", tile_map, current_tile_id, position)
	tile_map.set_cellv(tile_position, tile_map_erase_)
	tile_map.update_bitmask_area(tile_position)
	undo_.commit_action()

func remove_(position : Vector2) -> void:
	if brush_snap_:
		position = snap_(position) + (Vector2(brush_size_, brush_size_) / 2)
		
	for item in canvas_.get_children():
		if item.global_position.distance_to(position) < 8.0:
			item.get_parent().remove_child(item)
			item.queue_free()
	
func rotate_(position : Vector2) -> void:
	for item in canvas_.get_children():
		if item.global_position.distance_to(position) < 8.0:
			item.global_rotation_degrees += 90
	
var cursor_ = null

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2(), canvas_size), Color.red, false, 1)

func draw_preview(position : Vector2) -> void:
	if brush_snap_:
		position = snap_(position) + (Vector2(brush_size_, brush_size_) / 2)

	if not color_:
		return

	if not cursor_ or cursor_.get_meta("resource_path") !=  color_.resource_path:
		if cursor_:
			cursor_.queue_free()
		cursor_ = color_.instance()
		cursor_.set_meta("resource_path", color_.resource_path)
		get_parent().add_child(cursor_)
		if not Engine.is_editor_hint():
			zombie_(cursor_)
		cursor_.modulate[3] = 0.5

	cursor_.global_position = position
