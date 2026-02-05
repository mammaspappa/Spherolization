class_name NeighborFinder
extends RefCounted

## Finds nearest neighbors for points on a sphere using k-nearest with edge trimming.
## Uses union of neighbor relationships, then trims excess edges by length.

const MAX_NEIGHBORS: int = 7  # Maximum neighbors per point before trimming
const SEARCH_NEIGHBORS: int = 8  # Search radius for potential neighbors (wider than target)
const TARGET_NEIGHBORS: int = 6  # Target neighbor count for hexagonal points

var points: PackedVector3Array
var neighbors: Array[PackedInt32Array] = []  # For each point, indices of neighbors
var is_pentagonal: PackedByteArray = PackedByteArray()  # 1 if pentagonal, 0 if hexagonal
var edges: Array[Vector2i] = []  # Unique edges as pairs of point indices

func _init(point_array: PackedVector3Array) -> void:
	points = point_array

func find_all_neighbors() -> void:
	"""Find neighbors for all points using k-nearest with union and trimming."""
	neighbors.clear()
	neighbors.resize(points.size())
	is_pentagonal.resize(points.size())

	# Step 1: Find 6-nearest neighbors for each point
	var k_nearest: Array[PackedInt32Array] = []
	k_nearest.resize(points.size())

	for i in range(points.size()):
		k_nearest[i] = _find_nearest_neighbors(i, SEARCH_NEIGHBORS)

	# Step 2: Build edges using union (A->B OR B->A)
	_build_edge_list_union(k_nearest)

	# Step 3: Build initial neighbor lists from edges
	_build_neighbor_lists_from_edges()

	# Step 4: Trim excess neighbors (keep shortest edges)
	_trim_excess_neighbors()

	# Step 5: Rebuild edge list from trimmed neighbors
	_rebuild_edges_from_neighbors()

	# Step 6: Identify pentagonal points
	_identify_pentagonal_points()

	var pent_count := is_pentagonal.count(1)
	print("Found %d pentagonal points and %d hexagonal points" % [pent_count, points.size() - pent_count])

func _find_nearest_neighbors(point_index: int, count: int) -> PackedInt32Array:
	"""Find the nearest 'count' neighbors for a given point."""
	var distances: Array[Dictionary] = []
	var point := points[point_index]

	for i in range(points.size()):
		if i == point_index:
			continue
		distances.append({
			"index": i,
			"distance": point.distance_squared_to(points[i])
		})

	distances.sort_custom(func(a, b): return a["distance"] < b["distance"])

	var result := PackedInt32Array()
	for i in range(count):
		result.append(distances[i]["index"])

	return result

func _build_edge_list_union(k_nearest: Array[PackedInt32Array]) -> void:
	"""Build edge list using union of k-nearest relationships."""
	edges.clear()
	var edge_set := {}

	for i in range(points.size()):
		for neighbor_idx in k_nearest[i]:
			var edge := Vector2i(mini(i, neighbor_idx), maxi(i, neighbor_idx))
			if not edge_set.has(edge):
				edge_set[edge] = true
				edges.append(edge)

	print("Initial edges (union): %d" % edges.size())

func _build_neighbor_lists_from_edges() -> void:
	"""Build neighbor lists from edge list."""
	for i in range(points.size()):
		neighbors[i] = PackedInt32Array()

	for edge in edges:
		var a := edge.x
		var b := edge.y

		var neighbors_a := neighbors[a]
		neighbors_a.append(b)
		neighbors[a] = neighbors_a

		var neighbors_b := neighbors[b]
		neighbors_b.append(a)
		neighbors[b] = neighbors_b

func _trim_excess_neighbors() -> void:
	"""Iteratively remove longest edges until all points have <= MAX_NEIGHBORS."""
	var max_iterations := 100
	var iteration := 0

	while iteration < max_iterations:
		iteration += 1
		var trimmed_any := false

		for i in range(points.size()):
			var point_neighbors := neighbors[i]
			if point_neighbors.size() <= MAX_NEIGHBORS:
				continue

			trimmed_any = true

			# Sort neighbors by distance
			var neighbor_distances: Array[Dictionary] = []
			for n in point_neighbors:
				neighbor_distances.append({
					"index": n,
					"distance": points[i].distance_squared_to(points[n])
				})
			neighbor_distances.sort_custom(func(a, b): return a["distance"] < b["distance"])

			# Find the farthest neighbor to remove
			var to_remove: int = neighbor_distances[neighbor_distances.size() - 1]["index"]

			# Remove from both sides
			var new_neighbors_i := PackedInt32Array()
			for n in neighbors[i]:
				if n != to_remove:
					new_neighbors_i.append(n)
			neighbors[i] = new_neighbors_i

			var new_neighbors_r := PackedInt32Array()
			for n in neighbors[to_remove]:
				if n != i:
					new_neighbors_r.append(n)
			neighbors[to_remove] = new_neighbors_r

		if not trimmed_any:
			break

	print("Trimming completed after %d iterations" % iteration)

func _rebuild_edges_from_neighbors() -> void:
	"""Rebuild edge list from neighbor lists (all edges, not just mutual)."""
	edges.clear()
	var edge_set := {}

	for i in range(points.size()):
		for neighbor_idx in neighbors[i]:
			var edge := Vector2i(mini(i, neighbor_idx), maxi(i, neighbor_idx))
			if not edge_set.has(edge):
				edge_set[edge] = true
				edges.append(edge)

	print("Final edges (after trimming): %d" % edges.size())

	# Update neighbor lists to be symmetric (if A->B exists, ensure B->A exists)
	for i in range(points.size()):
		neighbors[i] = PackedInt32Array()

	for edge in edges:
		var a := edge.x
		var b := edge.y

		var neighbors_a := neighbors[a]
		if not neighbors_a.has(b):
			neighbors_a.append(b)
		neighbors[a] = neighbors_a

		var neighbors_b := neighbors[b]
		if not neighbors_b.has(a):
			neighbors_b.append(a)
		neighbors[b] = neighbors_b

func _identify_pentagonal_points() -> void:
	"""Identify pentagonal (5 neighbors) vs hexagonal (6+ neighbors) points."""
	for i in range(points.size()):
		var neighbor_count := neighbors[i].size()
		if neighbor_count <= 5:
			is_pentagonal[i] = 1
		else:
			is_pentagonal[i] = 0

		if neighbor_count < 5 or neighbor_count > 7:
			print("Warning: Point %d has %d neighbors" % [i, neighbor_count])

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
	var a := edge.x
	var b := edge.y
	var neighbors_a := neighbors[a]
	var neighbors_b := neighbors[b]

	var result := PackedInt32Array()
	for n in neighbors_a:
		if neighbors_b.has(n):
			result.append(n)
	return result

func get_all_edge_triangles() -> Array[Dictionary]:
	"""Get triangle data for each edge: {edge: Vector2i, adjacent: PackedInt32Array}."""
	var result: Array[Dictionary] = []
	for edge in edges:
		var adjacent := get_edge_adjacent_vertices(edge)
		result.append({
			"edge": edge,
			"adjacent": adjacent
		})
	return result
