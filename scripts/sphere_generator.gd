extends Node3D

## Generates points on a sphere using the Fibonacci spiral algorithm
## and visualizes them with connecting lines to nearest neighbors.

const NeighborFinder = preload("res://scripts/neighbor_finder.gd")
const DebugClickHandler = preload("res://scripts/debug_click_handler.gd")

@export var point_count: int = 1000
@export var color_count: int = 1
@export var debug_mode: bool = true
@export var terrain_mode: bool = false  # Use earth-like terrain coloring
@export var sphere_radius: float = 5.0
@export var point_size: float = 0.025
@export var triangle_fill_ratio: float = 0.333  # How far toward opposite vertex (1/3)
@export var line_color: Color = Color(0.4, 0.7, 1.0, 0.8)
@export var triangle_color: Color = Color(0.3, 0.5, 0.8, 0.7)
@export var pentagonal_color: Color = Color(1.0, 0.4, 0.2)  # Orange for pentagonal points
@export var hexagonal_color: Color = Color(0.2, 0.8, 0.4)   # Green for hexagonal points

# Terrain colors
const TERRAIN_WATER := Color(0.2, 0.4, 0.8)     # Deep blue
const TERRAIN_DESERT := Color(0.9, 0.8, 0.5)   # Sandy yellow
const TERRAIN_WOODS := Color(0.2, 0.6, 0.3)    # Forest green
const TERRAIN_MOUNTAINS := Color(0.6, 0.6, 0.65) # Gray rock

# Terrain generation
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
@export var terrain_seed: int = 12345
@export var water_level: float = 0.4  # Fraction of surface that is water
@export var water_spread_chance: float = 0.3  # Chance for land near water to become water
@export var water_spread_distance: float = 0.5  # Max distance for water spreading

var points: PackedVector3Array = PackedVector3Array()
var point_meshes: Array[MeshInstance3D] = []
var neighbor_finder: NeighborFinder
var line_mesh_instance: MeshInstance3D
var debug_handler: Node3D
var triangle_mesh_instance: MeshInstance3D
var generated_areas: Array[Area3D] = []

# Full color palette (will use first color_count colors)
var full_palette: Array[Color] = [
	Color(0.9, 0.3, 0.3),  # Red
	Color(0.3, 0.9, 0.3),  # Green
	Color(0.3, 0.3, 0.9),  # Blue
	Color(0.9, 0.9, 0.3),  # Yellow
	Color(0.9, 0.3, 0.9),  # Magenta
	Color(0.3, 0.9, 0.9),  # Cyan
	Color(0.9, 0.6, 0.3),  # Orange
	Color(0.6, 0.3, 0.9),  # Purple
	Color(0.5, 0.9, 0.5),  # Light Green
	Color(0.9, 0.5, 0.5),  # Light Red
	Color(0.5, 0.5, 0.9),  # Light Blue
	Color(0.9, 0.7, 0.5),  # Peach
	Color(0.7, 0.5, 0.9),  # Lavender
	Color(0.5, 0.9, 0.9),  # Light Cyan
	Color(0.9, 0.9, 0.5),  # Light Yellow
	Color(0.8, 0.4, 0.6),  # Pink
]

func _ready() -> void:
	if debug_mode:
		_setup_debug_handler()

	regenerate()

func regenerate() -> void:
	"""Clear and regenerate the entire sphere visualization."""
	_clear_generated()

	if terrain_mode:
		_init_terrain_noise()

	generate_fibonacci_points()
	find_neighbors()
	visualize_points()
	draw_edges()
	draw_edge_triangles()

	if terrain_mode:
		print("Generated %d points on sphere with terrain coloring" % points.size())
	else:
		print("Generated %d points on sphere with %d colors" % [points.size(), color_count])

func _clear_generated() -> void:
	"""Remove all generated visual elements."""
	# Clear point meshes
	for mesh in point_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	point_meshes.clear()

	# Clear line mesh
	if line_mesh_instance and is_instance_valid(line_mesh_instance):
		line_mesh_instance.queue_free()
		line_mesh_instance = null

	# Clear triangle mesh
	if triangle_mesh_instance and is_instance_valid(triangle_mesh_instance):
		triangle_mesh_instance.queue_free()
		triangle_mesh_instance = null

	# Clear collision areas
	for area in generated_areas:
		if is_instance_valid(area):
			area.queue_free()
	generated_areas.clear()

	points.clear()

func set_point_count(count: int) -> void:
	"""Set the number of points and regenerate."""
	point_count = count
	regenerate()

func set_color_count(count: int) -> void:
	"""Set the number of colors and regenerate."""
	color_count = clampi(count, 1, full_palette.size())
	regenerate()

func set_terrain_mode(enabled: bool) -> void:
	"""Enable or disable terrain coloring mode."""
	terrain_mode = enabled
	regenerate()

func _init_terrain_noise() -> void:
	"""Initialize noise generators for terrain generation."""
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = terrain_seed
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.5
	elevation_noise.fractal_octaves = 4
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.5

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = terrain_seed + 1000  # Different seed for variety
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.8
	moisture_noise.fractal_octaves = 3

func get_terrain_color(position: Vector3) -> Color:
	"""Determine terrain color based on position using noise."""
	# Normalize position for noise sampling
	var normalized := position.normalized()

	# Get elevation (0 to 1)
	var elevation_raw := elevation_noise.get_noise_3d(
		normalized.x * 10.0,
		normalized.y * 10.0,
		normalized.z * 10.0
	)
	var elevation := (elevation_raw + 1.0) / 2.0  # Convert from [-1,1] to [0,1]

	# Get moisture (0 to 1)
	var moisture_raw := moisture_noise.get_noise_3d(
		normalized.x * 10.0,
		normalized.y * 10.0,
		normalized.z * 10.0
	)
	var moisture := (moisture_raw + 1.0) / 2.0

	# Latitude factor (affects temperature - poles are colder)
	var latitude := absf(normalized.y)  # 0 at equator, 1 at poles

	# Determine terrain type
	if elevation < water_level:
		return TERRAIN_WATER
	elif elevation > 0.75:
		return TERRAIN_MOUNTAINS
	elif moisture < 0.4 and latitude < 0.6:
		# Low moisture + not too close to poles = desert
		return TERRAIN_DESERT
	else:
		return TERRAIN_WOODS

func _calculate_terrain_colors_with_spread(vertices: PackedVector3Array) -> PackedColorArray:
	"""Calculate terrain colors with water spreading to nearby triangles."""
	var colors := PackedColorArray()
	var tri_count := vertices.size() / 3

	# First pass: calculate initial terrain and collect centroids
	var centroids: Array[Vector3] = []
	var initial_colors: Array[Color] = []

	for i in range(tri_count):
		var v0 := vertices[i * 3]
		var v1 := vertices[i * 3 + 1]
		var v2 := vertices[i * 3 + 2]
		var centroid := (v0 + v1 + v2) / 3.0
		centroids.append(centroid)
		initial_colors.append(get_terrain_color(centroid))

	# Collect water triangle indices
	var water_indices: Array[int] = []
	for i in range(tri_count):
		if initial_colors[i] == TERRAIN_WATER:
			water_indices.append(i)

	# Second pass: spread water to nearby non-water triangles
	var final_colors: Array[Color] = initial_colors.duplicate()

	for i in range(tri_count):
		if final_colors[i] == TERRAIN_WATER:
			continue  # Already water

		# Check distance to nearby water triangles
		var near_water := false
		for water_idx in water_indices:
			var dist := centroids[i].distance_to(centroids[water_idx])
			if dist < water_spread_distance:
				near_water = true
				break

		# Apply spread chance if near water
		if near_water and randf() < water_spread_chance:
			final_colors[i] = TERRAIN_WATER

	# Build color array (3 vertices per triangle, same color)
	for i in range(tri_count):
		colors.append(final_colors[i])
		colors.append(final_colors[i])
		colors.append(final_colors[i])

	return colors

func _setup_debug_handler() -> void:
	"""Set up the debug click handler."""
	debug_handler = DebugClickHandler.new()
	add_child(debug_handler)
	debug_handler.node_clicked.connect(_on_node_clicked)
	debug_handler.edge_clicked.connect(_on_edge_clicked)

func _on_node_clicked(node_id: String, pos: Vector3) -> void:
	print("Node clicked: %s at %s" % [node_id, pos])

func _on_edge_clicked(edge_id: String, pos: Vector3) -> void:
	print("Edge clicked: %s at %s" % [edge_id, pos])

func generate_fibonacci_points() -> void:
	"""Generate points on sphere using Fibonacci spiral distribution."""
	points.clear()

	var golden_ratio: float = (1.0 + sqrt(5.0)) / 2.0
	var golden_angle: float = 2.0 * PI / (golden_ratio * golden_ratio)

	for i in range(point_count):
		# Calculate polar angle (phi) - latitude from pole
		var phi: float = acos(1.0 - 2.0 * (float(i) + 0.5) / float(point_count))

		# Calculate azimuthal angle (theta) - longitude
		var theta: float = golden_angle * float(i)

		# Convert spherical to Cartesian coordinates
		var x: float = sin(phi) * cos(theta) * sphere_radius
		var y: float = cos(phi) * sphere_radius  # Y is up in Godot
		var z: float = sin(phi) * sin(theta) * sphere_radius

		points.append(Vector3(x, y, z))

func find_neighbors() -> void:
	"""Find neighbors for all points using NeighborFinder."""
	neighbor_finder = NeighborFinder.new(points)
	neighbor_finder.find_all_neighbors()

func visualize_points() -> void:
	"""Create visual representations of each point, color-coded by type."""
	var hex_mesh := SphereMesh.new()
	hex_mesh.radius = point_size
	hex_mesh.height = point_size * 2.0
	hex_mesh.radial_segments = 8
	hex_mesh.rings = 4

	var hex_material := StandardMaterial3D.new()
	hex_material.albedo_color = hexagonal_color
	hex_material.emission_enabled = true
	hex_material.emission = hexagonal_color * 0.5
	hex_mesh.material = hex_material

	var pent_mesh := SphereMesh.new()
	pent_mesh.radius = point_size * 1.5  # Slightly larger for visibility
	pent_mesh.height = point_size * 3.0
	pent_mesh.radial_segments = 8
	pent_mesh.rings = 4

	var pent_material := StandardMaterial3D.new()
	pent_material.albedo_color = pentagonal_color
	pent_material.emission_enabled = true
	pent_material.emission = pentagonal_color * 0.5
	pent_mesh.material = pent_material

	# Collision shape for click detection
	var collision_shape := SphereShape3D.new()
	collision_shape.radius = point_size * 3.0  # Larger for easier clicking

	for i in range(points.size()):
		var mesh_instance := MeshInstance3D.new()
		if neighbor_finder.is_point_pentagonal(i):
			mesh_instance.mesh = pent_mesh
		else:
			mesh_instance.mesh = hex_mesh
		mesh_instance.position = points[i]
		add_child(mesh_instance)
		point_meshes.append(mesh_instance)

		# Add clickable area for debug mode
		if debug_mode:
			var area := Area3D.new()
			area.position = points[i]

			var col_shape := CollisionShape3D.new()
			col_shape.shape = collision_shape
			area.add_child(col_shape)

			var node_id: String = debug_handler.generate_node_id(i, points[i])
			area.set_meta("debug_id", node_id)
			area.set_meta("debug_type", "node")
			area.set_meta("node_index", i)

			add_child(area)
			generated_areas.append(area)

func draw_edges() -> void:
	"""Draw lines between connected points using ImmediateMesh."""
	var edges := neighbor_finder.get_edges()

	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = line_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	for i in range(edges.size()):
		var edge := edges[i]
		var p1 := points[edge.x]
		var p2 := points[edge.y]
		immediate_mesh.surface_add_vertex(p1)
		immediate_mesh.surface_add_vertex(p2)

		# Add clickable area for debug mode
		if debug_mode:
			_create_edge_collision(i, edge, p1, p2)

	immediate_mesh.surface_end()

	line_mesh_instance = MeshInstance3D.new()
	line_mesh_instance.mesh = immediate_mesh
	add_child(line_mesh_instance)

func _create_edge_collision(edge_index: int, edge: Vector2i, p1: Vector3, p2: Vector3) -> void:
	"""Create a clickable collision area for an edge."""
	var midpoint := (p1 + p2) / 2.0
	var direction := p2 - p1
	var length := direction.length()

	var area := Area3D.new()
	area.position = midpoint

	# Create capsule aligned with edge
	var capsule := CapsuleShape3D.new()
	capsule.radius = point_size * 2.0
	capsule.height = length

	var col_shape := CollisionShape3D.new()
	col_shape.shape = capsule

	# Rotate capsule to align with edge direction
	var up := Vector3.UP
	var edge_dir := direction.normalized()
	if abs(edge_dir.dot(up)) > 0.99:
		up = Vector3.RIGHT
	col_shape.look_at_from_position(Vector3.ZERO, edge_dir, up)
	col_shape.rotate_object_local(Vector3.RIGHT, PI / 2.0)  # Capsule is Y-aligned by default

	area.add_child(col_shape)

	var edge_id: String = debug_handler.generate_edge_id(edge_index, edge.x, edge.y)
	area.set_meta("debug_id", edge_id)
	area.set_meta("debug_type", "edge")
	area.set_meta("edge_index", edge_index)

	add_child(area)
	generated_areas.append(area)

func get_points() -> PackedVector3Array:
	"""Return the generated points array."""
	return points

func get_neighbor_finder() -> NeighborFinder:
	"""Return the neighbor finder for external access."""
	return neighbor_finder

func draw_edge_triangles() -> void:
	"""Draw small triangles along each edge, filling ~1/3 of each adjacent face."""
	var edge_data := neighbor_finder.get_all_edge_triangles()

	# Use configurable number of colors from the full palette
	var palette: Array[Color] = []
	for i in range(color_count):
		palette.append(full_palette[i % full_palette.size()])

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var edge_colors: Array[Color] = []  # Track color per edge for non-terrain mode

	for data in edge_data:
		var edge: Vector2i = data["edge"]
		var adjacent: PackedInt32Array = data["adjacent"]

		var p_a := points[edge.x]
		var p_b := points[edge.y]
		var edge_midpoint := (p_a + p_b) / 2.0

		# Pick one color for this edge (both triangles will share it)
		var edge_color := palette[randi() % palette.size()]

		# Create a triangle toward each adjacent vertex
		for adj_idx in adjacent:
			var p_c := points[adj_idx]

			# Calculate apex: 1/3 of the way from edge midpoint toward opposite vertex
			var apex := edge_midpoint.lerp(p_c, triangle_fill_ratio)

			# Calculate face normal from current winding: (B-A) × (C-A)
			var ab := p_b - p_a
			var ac := p_c - p_a
			var face_normal := ab.cross(ac).normalized()

			# Check if winding is correct (normal should point outward from sphere)
			var centroid := (p_a + p_b + p_c) / 3.0
			var winding_correct := face_normal.dot(centroid) > 0

			# Add triangle vertices with consistent CCW winding (viewed from outside)
			if winding_correct:
				vertices.append(p_a)
				vertices.append(p_b)
				vertices.append(apex)
			else:
				# Swap p_a and p_b to reverse winding
				vertices.append(p_b)
				vertices.append(p_a)
				vertices.append(apex)
				face_normal = -face_normal  # Flip normal to match new winding

			normals.append(face_normal)
			normals.append(face_normal)
			normals.append(face_normal)

			# Store edge color for this triangle
			edge_colors.append(edge_color)

	# Determine colors for all triangles
	if terrain_mode:
		colors = _calculate_terrain_colors_with_spread(vertices)
	else:
		# Use pre-assigned edge colors (both triangles per edge share same color)
		for edge_color in edge_colors:
			colors.append(edge_color)
			colors.append(edge_color)
			colors.append(edge_color)

	# Create ArrayMesh
	var array_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors

	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Create material that uses vertex colors
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides

	array_mesh.surface_set_material(0, material)

	triangle_mesh_instance = MeshInstance3D.new()
	triangle_mesh_instance.mesh = array_mesh
	add_child(triangle_mesh_instance)

	print("Drew %d edge triangles" % (vertices.size() / 3))

	# Verify coplanarity
	if debug_mode:
		_verify_triangle_coplanarity()

func _verify_triangle_coplanarity() -> void:
	"""Verify that small triangles are coplanar with their parent triangles."""
	var edge_data: Array[Dictionary] = neighbor_finder.get_all_edge_triangles()
	var tolerance: float = 0.0001
	var errors: int = 0
	var checked: int = 0

	for data in edge_data:
		var edge: Vector2i = data["edge"]
		var adjacent: PackedInt32Array = data["adjacent"]

		var p_a: Vector3 = points[edge.x]
		var p_b: Vector3 = points[edge.y]
		var edge_midpoint: Vector3 = (p_a + p_b) / 2.0

		for adj_idx in adjacent:
			var p_c: Vector3 = points[adj_idx]
			checked += 1

			# Calculate apex of small triangle
			var apex: Vector3 = edge_midpoint.lerp(p_c, triangle_fill_ratio)

			# Calculate plane normal of parent triangle (A, B, C)
			var ab: Vector3 = p_b - p_a
			var ac: Vector3 = p_c - p_a
			var normal: Vector3 = ab.cross(ac)

			# Skip degenerate triangles
			if normal.length_squared() < 0.0001:
				continue

			normal = normal.normalized()

			# Check if apex is in the plane: (apex - A) · normal should be ~0
			var apex_offset: Vector3 = apex - p_a
			var distance_to_plane: float = absf(apex_offset.dot(normal))

			if distance_to_plane > tolerance:
				errors += 1
				if errors <= 5:  # Only print first 5 errors
					print("Coplanarity error: Edge %d-%d with vertex %d" % [edge.x, edge.y, adj_idx])
					print("  Distance from plane: %.6f" % distance_to_plane)

	if errors == 0:
		print("Coplanarity check PASSED: All %d small triangles are coplanar with parent triangles" % checked)
	else:
		print("Coplanarity check FAILED: %d of %d triangles have errors" % [errors, checked])
