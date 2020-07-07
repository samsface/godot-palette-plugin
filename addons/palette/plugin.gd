tool
extends EditorPlugin

var palette_ : Palette
var panel_   : PanelContainer
var grid_    : GridContainer

	#if panel_:
	#	remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU , panel_)
	#	panel_.queue_free()
	#	panel_ = null


		#panel_ = PanelContainer.new()
		#var b = Button.new()
		#panel_.add_child(b)
		#add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, panel_)

func show_dock_(show : bool) -> void:
	if not show:
		if palette_:
			if grid_:
				palette_.detach(grid_)
				remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, grid_)
				grid_.queue_free()
				grid_ = null

	if show:
		if grid_:
			show_dock_(false)

		grid_         = GridContainer.new()
		grid_.name    = "Palette"
		grid_.columns = 4
		palette_.attach(grid_)
		add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, grid_)

func edit(object : Object) -> void:
	palette_                   = object
	palette_.undo_             = get_undo_redo()
	palette_.editor_interface_ = get_editor_interface()
	show_dock_(true)

func handles(object : Object) -> bool:
	if object is Palette:
		return true
	else:
		show_dock_(false)
		return false

func make_visible(show : bool) -> void:
	show_dock_(show)

func forward_canvas_gui_input(event : InputEvent) -> bool:
	if not palette_ or not palette_.is_inside_tree():
		return false

	return palette_._forward_canvas_gui_input(event)
