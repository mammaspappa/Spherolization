extends Node3D

## Main scene controller - connects UI to sphere generator

@onready var sphere_generator: Node3D = $SphereGenerator
@onready var ui_controller: Control = $UILayer/UIController

func _ready() -> void:
	# Connect UI signals to sphere generator
	ui_controller.color_count_changed.connect(_on_color_count_changed)
	ui_controller.node_count_changed.connect(_on_node_count_changed)
	ui_controller.terrain_mode_changed.connect(_on_terrain_mode_changed)

func _on_color_count_changed(count: int) -> void:
	sphere_generator.set_color_count(count)

func _on_node_count_changed(count: int) -> void:
	sphere_generator.set_point_count(count)

func _on_terrain_mode_changed(enabled: bool) -> void:
	sphere_generator.set_terrain_mode(enabled)
