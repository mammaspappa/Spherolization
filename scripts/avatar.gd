class_name Avatar
extends Node3D

## Avatar that moves between nodes on the sphere mesh.

signal moved_to_node(node_index: int)

@export var avatar_color: Color = Color(1.0, 0.8, 0.2)  # Gold/yellow
@export var avatar_size: float = 0.2  # Larger than node markers
@export var move_speed: float = 5.0  # Units per second for smooth movement
@export var hover_height: float = 0.15  # Height above node surface

var current_node_index: int = 0
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var mesh_instance: MeshInstance3D

func _ready() -> void:
	_create_avatar_mesh()

func _create_avatar_mesh() -> void:
	"""Create the visual sphere for the avatar."""
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = avatar_size
	sphere_mesh.height = avatar_size * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8

	var material := StandardMaterial3D.new()
	material.albedo_color = avatar_color
	material.emission_enabled = true
	material.emission = avatar_color * 0.3
	material.metallic = 0.3
	material.roughness = 0.4
	sphere_mesh.material = material

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	add_child(mesh_instance)

func _process(delta: float) -> void:
	if is_moving:
		var distance := position.distance_to(target_position)
		if distance < 0.01:
			position = target_position
			is_moving = false
		else:
			position = position.move_toward(target_position, move_speed * delta)

func initialize(start_node_index: int, node_position: Vector3) -> void:
	"""Place avatar at initial node."""
	current_node_index = start_node_index
	var hover_pos := _get_hover_position(node_position)
	position = hover_pos
	target_position = hover_pos

func move_to_node(node_index: int, node_position: Vector3) -> void:
	"""Move avatar to a new node position."""
	current_node_index = node_index
	target_position = _get_hover_position(node_position)
	is_moving = true
	moved_to_node.emit(node_index)

func _get_hover_position(node_position: Vector3) -> Vector3:
	"""Calculate position hovering above the node (offset outward from sphere center)."""
	var direction := node_position.normalized()
	return node_position + direction * hover_height

func get_current_node() -> int:
	"""Return the current node index."""
	return current_node_index
