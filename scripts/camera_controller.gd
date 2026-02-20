extends Camera3D

## Orbital camera controller for inspecting the sphere

@export var orbit_distance: float = 15.0
@export var rotation_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var min_distance: float = 5.0
@export var max_distance: float = 50.0
@export var light_energy: float = 1.2

var orbit_angles: Vector2 = Vector2(0, 0.6)  # x = horizontal, y = vertical (start looking at top where avatar spawns)
var is_dragging: bool = false
var camera_light: DirectionalLight3D

func _ready() -> void:
	_setup_camera_light()
	update_camera_position()

func _setup_camera_light() -> void:
	"""Create a directional light attached to the camera."""
	camera_light = DirectionalLight3D.new()
	camera_light.light_energy = light_energy
	camera_light.shadow_enabled = false
	add_child(camera_light)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = max(min_distance, orbit_distance - zoom_speed)
			update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = min(max_distance, orbit_distance + zoom_speed)
			update_camera_position()

	elif event is InputEventMouseMotion and is_dragging:
		orbit_angles.x -= event.relative.x * rotation_speed
		orbit_angles.y -= event.relative.y * rotation_speed
		orbit_angles.y = clamp(orbit_angles.y, -PI / 2 + 0.1, PI / 2 - 0.1)
		update_camera_position()

func update_camera_position() -> void:
	var x := orbit_distance * cos(orbit_angles.y) * sin(orbit_angles.x)
	var y := orbit_distance * sin(orbit_angles.y)
	var z := orbit_distance * cos(orbit_angles.y) * cos(orbit_angles.x)

	position = Vector3(x, y, z)
	look_at(Vector3.ZERO, Vector3.UP)
