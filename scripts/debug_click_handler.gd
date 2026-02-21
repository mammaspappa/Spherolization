extends Node3D

## Handles debug click detection for nodes and edges, displaying IDs on click.

signal node_clicked(node_id: String, position: Vector3)
signal edge_clicked(edge_id: String, position: Vector3)
signal node_right_clicked(node_index: int, position: Vector3)

var active_label: Label3D = null
var camera: Camera3D = null

func _ready() -> void:
	# Find camera in scene
	await get_tree().process_frame
	camera = get_viewport().get_camera_3d()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Don't interfere with camera dragging - only handle clicks (not drags)
			_handle_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click for avatar movement
			_handle_right_click(event.position)

func _handle_click(screen_pos: Vector2) -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)

	if result:
		var collider: Object = result["collider"]
		if collider and collider.has_meta("debug_id"):
			var debug_id: String = collider.get_meta("debug_id")
			var debug_type: String = collider.get_meta("debug_type")
			var click_pos: Vector3 = result["position"]

			_show_label(debug_id, debug_type, click_pos)

			if debug_type == "node":
				node_clicked.emit(debug_id, click_pos)
			elif debug_type == "edge":
				edge_clicked.emit(debug_id, click_pos)
	else:
		_hide_label()

func _handle_right_click(screen_pos: Vector2) -> void:
	"""Handle right-click for avatar movement."""
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)

	if result:
		var collider: Object = result["collider"]
		if collider and collider.has_meta("debug_type"):
			var debug_type: String = collider.get_meta("debug_type")
			if debug_type == "node" and collider.has_meta("node_index"):
				var node_index: int = collider.get_meta("node_index")
				var click_pos: Vector3 = result["position"]
				node_right_clicked.emit(node_index, click_pos)

func _show_label(id: String, type: String, pos: Vector3) -> void:
	if active_label:
		active_label.queue_free()

	active_label = Label3D.new()
	active_label.text = "%s\n[%s]" % [id, type]
	active_label.position = pos + pos.normalized() * 0.15  # Offset outward
	active_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	active_label.font_size = 48
	active_label.outline_size = 8
	active_label.modulate = Color.WHITE
	active_label.outline_modulate = Color.BLACK

	add_child(active_label)

	# Auto-hide after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(_hide_label)

func _hide_label() -> void:
	if active_label and is_instance_valid(active_label):
		active_label.queue_free()
		active_label = null

func generate_node_id(index: int, position: Vector3) -> String:
	"""Generate a unique ID for a node based on index and position."""
	var n := position.normalized()
	var lat := rad_to_deg(asin(n.y))
	var lon := rad_to_deg(atan2(n.z, n.x))
	return "N%d_%.0f,%.0f" % [index, lat, lon]

func generate_edge_id(index: int, node_a: int, node_b: int) -> String:
	"""Generate a unique ID for an edge based on endpoint indices."""
	return "E%d_%d-%d" % [index, node_a, node_b]
