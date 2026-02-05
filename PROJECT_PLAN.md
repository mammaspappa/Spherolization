# Spherolization Project Plan

A Godot 4.6 project to create a spherical gameworld using Fibonacci spiral point distribution.

## Overview

This pilot project constructs a sphere mesh by:
1. Generating ~1000 points on a sphere using the Fibonacci spiral algorithm
2. Connecting each point to its nearest neighbors (6 for most, 5 for exactly 12 special points)
3. Rendering the resulting mesh structure

## Technical Background

### Fibonacci Spiral Distribution

The Fibonacci spiral (also known as the golden spiral or Fibonacci lattice) provides near-uniform point distribution on a sphere. For `n` points, each point `i` is placed at:

```
phi = arccos(1 - 2*(i + 0.5)/n)  # polar angle from pole
theta = pi * (1 + sqrt(5)) * i    # azimuthal angle (golden angle)
```

Converting to Cartesian coordinates:
```
x = sin(phi) * cos(theta)
y = sin(phi) * sin(theta)
z = cos(phi)
```

### Neighbor Topology

Due to Euler's formula for convex polyhedra (V - E + F = 2), when tessellating a sphere with mostly hexagonal faces:
- **988 points** will have exactly **6 neighbors** (hexagonal regions)
- **12 points** will have exactly **5 neighbors** (pentagonal regions)

This is mathematically unavoidable and creates the characteristic soccer ball-like topology.

## Implementation Phases

### Phase 1: Point Generation
- [x] Create a new Godot 4.6 project
- [x] Implement Fibonacci spiral algorithm in GDScript
- [x] Generate 1000 points on unit sphere
- [x] Visualize points as debug spheres/dots

### Phase 2: Neighbor Detection
- [x] For each point, calculate distances to all other points
- [x] Determine the 6 closest neighbors per point
- [x] Identify the 12 pentagonal points (those whose 6th neighbor is significantly farther than 5th)
- [x] Store neighbor relationships in data structure

### Phase 3: Line Rendering
- [x] Draw lines between each point and its neighbors
- [x] Use ImmediateMesh or Line3D for visualization
- [x] Ensure no duplicate lines (A→B and B→A)

### Phase 4: Refinement
- [x] Add camera controls for inspection
- [x] Color-code pentagonal vs hexagonal points
- [ ] Optimize neighbor search if needed (spatial hashing)

### Phase 5: Edge Triangle Geometry
Add triangular face geometry along each edge to begin forming solid faces.

**Concept:**
- Each edge (A-B) is shared by exactly 2 triangular faces on the sphere
- For each edge, find the two opposite vertices (C1 and C2) that complete the triangles
- Draw 2 small triangles per edge, one toward each opposite vertex
- Each small triangle fills approximately 1/3 of its parent triangle

**Geometry:**
```
        C                    C
       /|\                  /|\
      / | \                / | \
     /  |  \              /  *  \      <- apex at 1/3 height
    /   |   \            / /   \ \
   /    |    \          / /     \ \
  A-----+-----B        A---------B     <- base = edge

  Parent triangle      Edge triangle (1/3 fill)
```

**Implementation:**
- [x] Find all triangular faces from edge/neighbor data
- [x] For each edge, identify the two adjacent face vertices
- [x] Calculate triangle apex at 1/3 distance from edge midpoint toward opposite vertex
- [x] Render triangles using ArrayMesh with PRIMITIVE_TRIANGLES
- [x] Ensure triangles lie in the plane of their parent triangle

## Project Structure

```
Spherolizaton/
├── project.godot
├── main.tscn              # Main scene
├── scripts/
│   ├── sphere_generator.gd    # Fibonacci point generation
│   ├── neighbor_finder.gd     # Neighbor detection logic
│   └── mesh_renderer.gd       # Line/mesh rendering
└── PROJECT_PLAN.md
```

## Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Point count | 1000 | Adjustable |
| Sphere radius | 1.0 | Unit sphere |
| Hexagonal neighbors | 6 | Standard |
| Pentagonal neighbors | 5 | For 12 special points |

## Algorithm Details

### Identifying Pentagonal Points

Method: After finding the 6 nearest neighbors for each point, compare the distance ratio between the 5th and 6th nearest neighbor. Points where this ratio exceeds a threshold (e.g., 1.3x) are pentagonal.

Alternative: Use Delaunay triangulation on sphere (more complex but mathematically precise).

## Success Criteria

- [ ] 1000 points visible on sphere surface
- [ ] Lines drawn forming hexagonal/pentagonal grid pattern
- [ ] Exactly 12 points with 5 neighbors identified
- [ ] No visual gaps or overlapping lines
- [ ] Smooth camera navigation around sphere

## Future Extensions (Out of Scope)

- Face/polygon generation from edges
- Terrain height mapping
- Game entity placement on vertices
- LOD (Level of Detail) system
