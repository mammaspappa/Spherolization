extends Control

## UI Controller with sliders for adjusting sphere parameters

signal color_count_changed(count: int)
signal node_count_changed(count: int)
signal terrain_mode_changed(enabled: bool)
signal draw_triangles_changed(enabled: bool)

@export var min_colors: int = 1
@export var max_colors: int = 16
@export var default_colors: int = 4

@export var min_nodes: int = 100
@export var max_nodes: int = 2000
@export var default_nodes: int = 1000

var color_slider: HSlider
var color_label: Label
var node_slider: HSlider
var node_label: Label
var terrain_checkbox: CheckBox
var triangles_checkbox: CheckBox

func _ready() -> void:
	_create_ui()

func _create_ui() -> void:
	# Main container
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Sphere Controls"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Color count slider
	var color_hbox := HBoxContainer.new()
	vbox.add_child(color_hbox)

	var color_text := Label.new()
	color_text.text = "Colors: "
	color_text.custom_minimum_size.x = 60
	color_hbox.add_child(color_text)

	color_slider = HSlider.new()
	color_slider.min_value = min_colors
	color_slider.max_value = max_colors
	color_slider.value = default_colors
	color_slider.step = 1
	color_slider.custom_minimum_size.x = 150
	color_slider.value_changed.connect(_on_color_slider_changed)
	color_hbox.add_child(color_slider)

	color_label = Label.new()
	color_label.text = str(default_colors)
	color_label.custom_minimum_size.x = 40
	color_hbox.add_child(color_label)

	# Node count slider
	var node_hbox := HBoxContainer.new()
	vbox.add_child(node_hbox)

	var node_text := Label.new()
	node_text.text = "Nodes: "
	node_text.custom_minimum_size.x = 60
	node_hbox.add_child(node_text)

	node_slider = HSlider.new()
	node_slider.min_value = min_nodes
	node_slider.max_value = max_nodes
	node_slider.value = default_nodes
	node_slider.step = 50
	node_slider.custom_minimum_size.x = 150
	node_slider.value_changed.connect(_on_node_slider_changed)
	node_hbox.add_child(node_slider)

	node_label = Label.new()
	node_label.text = str(default_nodes)
	node_label.custom_minimum_size.x = 50
	node_hbox.add_child(node_label)

	# Terrain mode checkbox
	terrain_checkbox = CheckBox.new()
	terrain_checkbox.text = "Terrain Mode (Earth-like)"
	terrain_checkbox.toggled.connect(_on_terrain_checkbox_toggled)
	vbox.add_child(terrain_checkbox)

	# Draw triangles checkbox (off by default)
	triangles_checkbox = CheckBox.new()
	triangles_checkbox.text = "Draw Triangles"
	triangles_checkbox.button_pressed = false
	triangles_checkbox.toggled.connect(_on_triangles_checkbox_toggled)
	vbox.add_child(triangles_checkbox)

	# Instructions
	var instructions := Label.new()
	instructions.text = "Drag sliders to adjust\nLeft-click + drag: rotate\nScroll: zoom"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(instructions)

func _on_color_slider_changed(value: float) -> void:
	var count := int(value)
	color_label.text = str(count)
	color_count_changed.emit(count)

func _on_node_slider_changed(value: float) -> void:
	var count := int(value)
	node_label.text = str(count)
	node_count_changed.emit(count)

func _on_terrain_checkbox_toggled(enabled: bool) -> void:
	terrain_mode_changed.emit(enabled)

func _on_triangles_checkbox_toggled(enabled: bool) -> void:
	draw_triangles_changed.emit(enabled)

func get_color_count() -> int:
	return int(color_slider.value)

func get_node_count() -> int:
	return int(node_slider.value)
