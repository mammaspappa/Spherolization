class_name NeighborFinder
extends RefCounted

## Finds neighbors using stereographic projection + Godot's built-in 2D Delaunay.
## Algorithm ported from test/node_3d.gd.
##
## Points are in Godot's Y-up coordinate system.
## Stereographic projection from north pole (0,1,0):
##   unit-sphere point (px, py, pz)  →  2D (px/(1-py), pz/(1-py))
## This maps sphere → plane while preserving the Delaunay property,
## so the 2D Delaunay triangulation equals the spherical Delaunay triangulation.

var points: PackedVector3Array
var neighbors: Array[PackedInt32Array] = []  # For each point, indices of neighbors
var is_pentagonal: PackedByteArray = PackedByteArray()  # 1 if pentagonal, 0 if hexagonal
var edges: Array[Vector2i] = []  # Unique edges as pairs of point indices

func _init(point_array: PackedVector3Array) -> void:
	points = point_array

func find_all_neighbors() -> void:
	"""Find neighbors using stereographic projection + 2D Delaunay triangulation."""
	neighbors.clear()
	neighbors.resize(points.size())
	is_pentagonal.resize(points.size())

	# Step 1: Project sphere points to 2D via stereographic projection from north pole.
	var points_2d := PackedVector2Array()
	points_2d.resize(points.size())
	for i in range(points.size()):
		var p := points[i].normalized()
		var denom := 1.0 - p.y
		if denom < 1e-6:
			denom = 1e-6  # Guard against division by zero at the exact north pole
		points_2d[i] = Vector2(p.x / denom, p.z / denom)

	# Step 2: Delaunay triangulation of the projected 2D points.
	var triangles := Geometry2D.triangulate_delaunay(points_2d)
	print("Delaunay: %d triangles from %d points" % [triangles.size() / 3, points.size()])

	# Step 3: Extract unique edges from the triangle list.
	edges.clear()
	var edge_set := {}
	for i in range(0, triangles.size(), 3):
		var id_a := triangles[i]
		var id_b := triangles[i + 1]
		var id_c := triangles[i + 2]
		var e1 := Vector2i(mini(id_a, id_b), maxi(id_a, id_b))
		var e2 := Vector2i(mini(id_b, id_c), maxi(id_b, id_c))
		var e3 := Vector2i(mini(id_c, id_a), maxi(id_c, id_a))
		if not edge_set.has(e1):
			edge_set[e1] = true
			edges.append(e1)
		if not edge_set.has(e2):
			edge_set[e2] = true
			edges.append(e2)
		if not edge_set.has(e3):
			edge_set[e3] = true
			edges.append(e3)
	print("Edges from Delaunay: %d (planar limit: %d)" % [edges.size(), 3 * points.size() - 6])

	# Step 4: Build neighbor lists from edges.
	for i in range(points.size()):
		neighbors[i] = PackedInt32Array()
	for edge in edges:
		var a := edge.x
		var b := edge.y
		var na := neighbors[a]
		na.append(b)
		neighbors[a] = na
		var nb := neighbors[b]
		nb.append(a)
		neighbors[b] = nb

	# Step 5: Identify pentagonal points.
	_identify_pentagonal_points()

	var pent_count := is_pentagonal.count(1)
	print("Found %d pentagonal points and %d hexagonal points" % [pent_count, points.size() - pent_count])

func _identify_pentagonal_points() -> void:
	"""Identify pentagonal (5 neighbors) vs hexagonal (6+ neighbors) points."""
	for i in range(points.size()):
		var neighbor_count := neighbors[i].size()
		if neighbor_count <= 5:
			is_pentagonal[i] = 1
		else:
			is_pentagonal[i] = 0

		if neighbor_count < 3:
			print("Warning: Point %d has only %d neighbors" % [i, neighbor_count])

func get_neighbors(point_index: int) -> PackedInt32Array:
	"""Get neighbor indices for a specific point."""
	return neighbors[point_index]

func is_point_pentagonal(point_index: int) -> bool:
	"""Check if a point is pentagonal (5 neighbors) vs hexagonal (6 neighbors)."""
	return is_pentagonal[point_index] == 1

func get_edges() -> Array[Vector2i]:
	"""Get all unique edges as pairs of point indices."""
	return edges

func get_pentagonal_indices() -> PackedInt32Array:
	"""Get indices of all pentagonal points."""
	var result := PackedInt32Array()
	for i in range(is_pentagonal.size()):
		if is_pentagonal[i] == 1:
			result.append(i)
	return result

func get_edge_adjacent_vertices(edge: Vector2i) -> PackedInt32Array:
	"""Find vertices that form triangles with this edge (shared neighbors of both endpoints)."""
	var neighbors_a := neighbors[edge.x]
	var neighbors_b := neighbors[edge.y]

	var result := PackedInt32Array()
	for n in neighbors_a:
		if neighbors_b.has(n):
			result.append(n)
	return result

func find_crossing_edges() -> Array[Vector2i]:
	"""Detect pairs of edges whose geodesic arcs cross on the sphere surface.

	Two great-circle arcs (A,B) and (C,D) cross iff each pair of endpoints
	straddles the other arc's great-circle plane:
	  (n_cd · A)(n_cd · B) < 0  AND  (n_ab · C)(n_ab · D) < 0
	where n_ab = A × B, n_cd = C × D.
	"""
	var crossings: Array[Vector2i] = []
	var n := edges.size()

	for i in range(n):
		var e1 := edges[i]
		var a := points[e1.x]
		var b := points[e1.y]
		var n_ab := a.cross(b)

		for j in range(i + 1, n):
			var e2 := edges[j]

			# Skip edges sharing an endpoint
			if e2.x == e1.x or e2.x == e1.y or e2.y == e1.x or e2.y == e1.y:
				continue

			var c := points[e2.x]
			var d := points[e2.y]
			var n_cd := c.cross(d)

			if n_cd.dot(a) * n_cd.dot(b) >= 0.0:
				continue

			if n_ab.dot(c) * n_ab.dot(d) >= 0.0:
				continue

			crossings.append(Vector2i(i, j))

	return crossings
