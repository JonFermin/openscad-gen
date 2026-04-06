---
name: export-model
description: Export generated 3D models (.stl, .step, .py) to STL, OBJ, glTF, or GLB via the Blender pipeline
user_invocable: true
---

# export-model: Model Export Pipeline

Export a model from `./output/` to a mesh format suitable for game engines, 3D printing, or other tools.

Accepts `.stl`, `.step`, or `.py` (build123d) input files.

---

## Usage

```
/export-model <name> [options]
```

Where `<name>` matches a file in `./output/` (e.g. `bracket` for `output/bracket.stl` or `output/bracket.py`).

---

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `-f`, `--format` | Output format: `stl`, `obj`, `glb`, `gltf` | `glb` |
| `-d`, `--decimate` | Decimate ratio 0.0–1.0 (1.0 = no reduction) | `1.0` |
| `-u`, `--uv` | Generate UV maps in Blender | off |
| `-b`, `--blender` | Force Blender cleanup (auto for glb/gltf) | auto |
| `--no-blender` | Skip Blender even for glb/gltf | off |

---

## Workflow

### Step 1: Identify the model

Look in `./output/` for files matching the user's request. Priority order: `.stl` > `.step` > `.py`.
If ambiguous, list available files and ask the user to pick.

### Step 2: Confirm export settings

If the user didn't specify format or options, ask briefly:
- **Format** — "What format? GLB (Godot/game engines), STL (3D printing), OBJ, or glTF?"
- **Mesh reduction** — Only ask if the model is likely high-poly: "Want to decimate the mesh? (e.g. 0.5 = half the polygons)"

Default to GLB if the user just says "export it."

### Step 3: Run the pipeline

Execute the export script:

```bash
./pipeline/scad-to-godot.sh output/<name>.<ext> -f <format> [options]
```

The script handles input type detection automatically:
- **`.stl`** — Used directly as mesh input
- **`.step`** — Converted to STL via Python (build123d/OCP)
- **`.py`** — Executed to generate STL, then processed

### Prerequisites

The pipeline requires:
- **Blender 3.x+** CLI — for mesh cleanup, decimation, UV generation, and glTF/GLB/OBJ export
- **Python with build123d** — only if exporting from `.py` or `.step` files

If Blender is missing, tell the user what to install and provide the download link.

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

The export pipeline (`pipeline/scad-to-godot.sh`) runs up to two stages:

1. **Input → STL** — If input is `.py`, runs the script to generate STL. If `.step`, converts via Python. If `.stl`, uses directly.
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
# Basic GLB export for Godot (from STL)
./pipeline/scad-to-godot.sh output/bracket.stl

# Run build123d script and export to GLB
./pipeline/scad-to-godot.sh output/bracket.py -f glb

# glTF with decimation and UVs
./pipeline/scad-to-godot.sh output/bracket.stl -f gltf -d 0.5 -u

# STL for 3D printing (no Blender needed)
./pipeline/scad-to-godot.sh output/bracket.stl -f stl
```
