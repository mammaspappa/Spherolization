# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spherolization is a Godot 4.6 project that generates a spherical gameworld using Fibonacci spiral point distribution. It creates ~1000 points on a sphere surface, connects them with edges to form a hexagonal/pentagonal mesh (like a soccer ball topology), and renders small triangles along each edge.

## Running the Project

Open the project in Godot 4.6 and press F5 to run `main.tscn`.

## Architecture

### Core Scripts

**sphere_generator.gd** - Main orchestrator that:
- Generates Fibonacci spiral points on a sphere
- Coordinates neighbor finding and visualization
- Renders edge triangles using ArrayMesh with vertex colors
- Handles terrain mode (earth-like coloring with FastNoiseLite)
- Exposes `set_point_count()`, `set_color_count()`, `set_terrain_mode()` for UI control

**neighbor_finder.gd** - Graph topology manager:
- Finds k-nearest neighbors using distance sorting
- Builds edges using union approach (A→B OR B→A creates edge)
- Iteratively trims excess edges to maintain MAX_NEIGHBORS (7) per point
- Identifies pentagonal points (5 neighbors) vs hexagonal (6 neighbors)
- Provides `get_all_edge_triangles()` for face geometry

**main.gd** - Connects UI signals to sphere_generator methods

**ui_controller.gd** - Programmatically creates sliders for colors/nodes and terrain checkbox

**camera_controller.gd** - Orbital camera with attached DirectionalLight3D

**debug_click_handler.gd** - Raycasts to detect clicks on nodes/edges, shows Label3D with IDs

### Data Flow

1. `sphere_generator.regenerate()` clears existing geometry
2. Fibonacci algorithm generates `points: PackedVector3Array`
3. `NeighborFinder` computes `edges: Array[Vector2i]` via k-nearest union + trimming
4. Point meshes and edge lines are created as children of SphereGenerator
5. `draw_edge_triangles()` creates ArrayMesh with triangles, colors assigned per-edge

### Key Algorithms

**Fibonacci Spiral**: Uses golden angle (`2π / φ²`) for uniform point distribution. Each point placed at `(phi, theta)` where phi varies linearly from pole to pole.

**Edge Trimming**: After k-nearest union creates edges, iteratively removes longest edge from any point with >7 neighbors until all points have ≤7 neighbors.

**Winding Order**: Small triangles check face normal vs centroid direction to ensure consistent CCW winding for correct shading.

## GDScript Patterns Used

- `class_name` for importable classes (`NeighborFinder`)
- `@export` for inspector-editable properties
- Signals for decoupled communication (`color_count_changed`, `node_clicked`)
- `PackedVector3Array`, `PackedInt32Array`, `PackedColorArray` for performance
- `ArrayMesh` with `ARRAY_VERTEX`, `ARRAY_NORMAL`, `ARRAY_COLOR` for triangle rendering
- `ImmediateMesh` for line rendering
