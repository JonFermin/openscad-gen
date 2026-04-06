---
name: export-model
description: Export generated .scad models to STL, OBJ, glTF, or GLB via the OpenSCAD + Blender pipeline
user_invocable: true
---

# export-model: Model Export Pipeline

Export a `.scad` file from `./output/` to a mesh format suitable for game engines, 3D printing, or other tools.

---

## Usage

```
/export-model <name> [options]
```

Where `<name>` is the stem of a `.scad` file in `./output/` (e.g. `bracket` for `output/bracket.scad`).

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-f`, `--format` | Output format: `stl`, `obj`, `glb`, `gltf` | `glb` |
| `-d`, `--decimate` | Decimate ratio 0.0–1.0 (1.0 = no reduction) | `1.0` |
| `-u`, `--uv` | Generate UV maps in Blender | off |
| `-b`, `--blender` | Force Blender cleanup (auto for glb/gltf) | auto |
| `--no-blender` | Skip Blender even for glb/gltf | off |
| `-p`, `--params` | OpenSCAD parameter overrides `"KEY=VAL"` (repeatable) | — |

---

## Workflow

### Step 1: Identify the model

Look in `./output/` for the `.scad` file matching the user's request. If ambiguous, list available `.scad` files and ask the user to pick.

### Step 2: Confirm export settings

If the user didn't specify format or options, ask briefly:
- **Format** — "What format? GLB (Godot/game engines), STL (3D printing), OBJ, or glTF?"
- **Mesh reduction** — Only ask if the model is likely high-poly: "Want to decimate the mesh? (e.g. 0.5 = half the polygons)"

Default to GLB if the user just says "export it."

### Step 3: Run the pipeline

Execute the export script:

```bash
./pipeline/scad-to-godot.sh output/<name>.scad -f <format> [options]
```

### Prerequisites

The pipeline requires:
- **OpenSCAD** CLI — for `.scad` → STL conversion
- **Blender 3.x+** CLI — for mesh cleanup, decimation, UV generation, and glTF/GLB export

If either tool is missing, tell the user what to install and provide the download link.

### Step 4: Verify output

Check that the output file was created in `./output/`:
- `<name>.stl` — always produced as intermediate
- `<name>.<format>` — final output

Report the file size and path.

### Step 5: Import instructions

Based on the format, provide concise import guidance:

**GLB/glTF (Godot):**
- Copy into `res://` folder
- Godot auto-imports glTF
- Instance via: `var scene = load("res://<name>.glb"); add_child(scene.instantiate())`

**STL (3D printing):**
- Open in slicer (PrusaSlicer, Cura, etc.)
- Check orientation and add supports if needed

**OBJ:**
- Copy into `res://` folder or import into modeling tool
- Godot auto-imports OBJ as mesh resource

---

## Pipeline Details

The export pipeline (`pipeline/scad-to-godot.sh`) runs two stages:

1. **OpenSCAD → STL** — Renders the parametric `.scad` to a triangle mesh
2. **Blender processing** (optional/auto for glb/gltf) — Cleans mesh, decimates, generates UVs, applies default material, centers origin, exports to target format

The Blender script (`pipeline/blender_process.py`) handles:
- Merge duplicate vertices (threshold 0.0001)
- Recalculate normals outward
- Remove loose vertices/edges
- Apply decimate modifier if ratio < 1.0
- Smart UV project if requested
- Neutral gray material for glTF
- Center at origin

---

## Examples

```bash
# Basic GLB export for Godot
./pipeline/scad-to-godot.sh output/bracket.scad

# STL for 3D printing
./pipeline/scad-to-godot.sh output/bracket.scad -f stl

# glTF with decimation and UVs
./pipeline/scad-to-godot.sh output/bracket.scad -f gltf -d 0.5 -u

# Override OpenSCAD parameters at export time
./pipeline/scad-to-godot.sh output/bracket.scad -p 'wall_thickness=3' -p 'height=50'
```
