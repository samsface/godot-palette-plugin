tool
extends TextureButton
class_name PaletteButton

signal double_clicked

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.doubleclick:
		emit_signal("double_clicked")
