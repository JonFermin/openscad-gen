#!/usr/bin/env bash
# scad-to-godot.sh — Export 3D models for game engines / 3D printing
#
# Usage:
#   ./pipeline/scad-to-godot.sh <input> [options]
#
# Accepts .stl, .step, or .py (build123d) input files.
#
# Options:
#   -o, --output-dir DIR     Output directory (default: ./output)
#   -f, --format FORMAT      Export format: stl, obj, glb, gltf (default: glb)
#   -b, --blender            Run Blender cleanup (auto-enabled for glb/gltf)
#   -d, --decimate RATIO     Blender decimate ratio 0.0-1.0 (default: 1.0 = no reduction)
#   -u, --uv                 Generate UV maps in Blender
#   --no-blender             Skip Blender even for glb/gltf (just convert)
#   -h, --help               Show this help
#
# Prerequisites:
#   - Blender 3.x+ (blender CLI) — needed for glb/gltf output or mesh cleanup
#   - Python with build123d — only if passing a .py file
#
# Examples:
#   ./pipeline/scad-to-godot.sh output/my_model.stl
#   ./pipeline/scad-to-godot.sh output/my_model.stl -f gltf -d 0.5 -u
#   ./pipeline/scad-to-godot.sh output/my_model.py -f glb

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults
OUTPUT_DIR="$PROJECT_DIR/output"
FORMAT="glb"
USE_BLENDER=""
DECIMATE_RATIO="1.0"
GENERATE_UV="false"
NO_BLENDER=""
INPUT_FILE=""

usage() {
    sed -n '3,20p' "$0" | sed 's/^# \?//'
    exit 0
}

log() { echo "[export] $*"; }
err() { echo "[export] ERROR: $*" >&2; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -f|--format)     FORMAT="$2"; shift 2 ;;
        -b|--blender)    USE_BLENDER="true"; shift ;;
        -d|--decimate)   DECIMATE_RATIO="$2"; USE_BLENDER="true"; shift 2 ;;
        -u|--uv)         GENERATE_UV="true"; USE_BLENDER="true"; shift ;;
        --no-blender)    NO_BLENDER="true"; shift ;;
        -h|--help)       usage ;;
        -*)              err "Unknown option: $1" ;;
        *)               INPUT_FILE="$1"; shift ;;
    esac
done

[[ -z "$INPUT_FILE" ]] && err "No input file specified. Run with --help for usage."
[[ ! -f "$INPUT_FILE" ]] && err "File not found: $INPUT_FILE"

INPUT_EXT="${INPUT_FILE##*.}"
BASENAME="$(basename "$INPUT_FILE" ".$INPUT_EXT")"
mkdir -p "$OUTPUT_DIR"

# Determine if Blender is needed
NEEDS_BLENDER="false"
if [[ "$FORMAT" == "glb" || "$FORMAT" == "gltf" ]]; then
    NEEDS_BLENDER="true"
fi
if [[ "$USE_BLENDER" == "true" ]]; then
    NEEDS_BLENDER="true"
fi
if [[ "$NO_BLENDER" == "true" ]]; then
    NEEDS_BLENDER="false"
fi

if [[ "$NEEDS_BLENDER" == "true" ]]; then
    command -v blender >/dev/null 2>&1 || err "Blender not found. Install: https://www.blender.org/download/ (needed for $FORMAT export / mesh cleanup)"
fi

# Step 1: Get an STL to work with
STL_FILE="$OUTPUT_DIR/${BASENAME}.stl"

case "$INPUT_EXT" in
    stl)
        log "Input is STL — using directly"
        STL_FILE="$INPUT_FILE"
        ;;
    step|stp)
        log "Input is STEP — converting to STL via Blender"
        command -v blender >/dev/null 2>&1 || err "Blender not found (needed for STEP import)"
        # Blender can import STEP natively and export STL
        blender --background --python-expr "
import bpy, sys
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()
bpy.ops.import_scene.x3d(filepath='') if False else None
bpy.ops.wm.stl_import(filepath='$INPUT_FILE') if hasattr(bpy.ops.wm, 'stl_import') else None
# For STEP, use the CAD importer add-on or FreeCAD
" 2>/dev/null || true
        # Fallback: use python with build123d to convert
        python -c "
from build123d import *
import cadquery as cq
result = cq.importers.importStep('$INPUT_FILE')
cq.exporters.export(result, '$STL_FILE')
print('[export] STEP → STL conversion complete')
" 2>/dev/null || python -c "
from OCP.STEPControl import STEPControl_Reader
from OCP.StlAPI import StlAPI_Writer
from OCP.BRepMesh import BRepMesh_IncrementalMesh
reader = STEPControl_Reader()
reader.ReadFile('$INPUT_FILE')
reader.TransferRoots()
shape = reader.OneShape()
mesh = BRepMesh_IncrementalMesh(shape, 0.1)
mesh.Perform()
writer = StlAPI_Writer()
writer.Write(shape, '$STL_FILE')
print('[export] STEP → STL conversion complete')
"
        [[ ! -f "$STL_FILE" ]] && err "STEP → STL conversion failed"
        ;;
    py)
        log "Input is Python (build123d) — running to generate STL"
        python "$INPUT_FILE"
        # The script should output STL to ./output/
        [[ ! -f "$STL_FILE" ]] && err "Python script did not produce expected STL: $STL_FILE"
        log "  STL generated: $STL_FILE"
        ;;
    *)
        err "Unsupported input format: .$INPUT_EXT (expected .stl, .step, or .py)"
        ;;
esac

STL_SIZE=$(stat -c%s "$STL_FILE" 2>/dev/null || stat -f%z "$STL_FILE" 2>/dev/null)
log "STL ready: ${BASENAME}.stl ($(numfmt --to=iec "$STL_SIZE" 2>/dev/null || echo "${STL_SIZE} bytes"))"

# If only STL requested, we're done
if [[ "$FORMAT" == "stl" && "$NEEDS_BLENDER" == "false" ]]; then
    log "Done! STL ready at: $STL_FILE"
    exit 0
fi

# If OBJ requested without Blender, need Blender anyway for conversion
if [[ "$FORMAT" == "obj" && "$NEEDS_BLENDER" == "false" ]]; then
    NEEDS_BLENDER="true"
    command -v blender >/dev/null 2>&1 || err "Blender not found (needed for OBJ conversion)"
fi

# Step 2: Blender processing
if [[ "$NEEDS_BLENDER" == "true" ]]; then
    log "Step 2: Blender mesh processing"
    log "  Decimate ratio: $DECIMATE_RATIO"
    log "  Generate UVs: $GENERATE_UV"
    log "  Output format: $FORMAT"

    BLENDER_OUTPUT="$OUTPUT_DIR/${BASENAME}.${FORMAT}"

    blender --background --python "$SCRIPT_DIR/blender_process.py" -- \
        --input "$STL_FILE" \
        --output "$BLENDER_OUTPUT" \
        --format "$FORMAT" \
        --decimate "$DECIMATE_RATIO" \
        --uv "$GENERATE_UV"

    [[ ! -f "$BLENDER_OUTPUT" ]] && err "Blender export failed — no output produced"

    OUT_SIZE=$(stat -c%s "$BLENDER_OUTPUT" 2>/dev/null || stat -f%z "$BLENDER_OUTPUT" 2>/dev/null)
    log "  Exported: ${BASENAME}.${FORMAT} ($(numfmt --to=iec "$OUT_SIZE" 2>/dev/null || echo "${OUT_SIZE} bytes"))"
fi

# Summary
log ""
log "=== Pipeline Complete ==="
log "  Source:  $INPUT_FILE"
log "  STL:     $STL_FILE"
if [[ "$NEEDS_BLENDER" == "true" ]]; then
    log "  Output:  $OUTPUT_DIR/${BASENAME}.${FORMAT}"
fi
log ""
log "=== Import Instructions ==="
case "$FORMAT" in
    glb|gltf)
        log "  1. Copy ${BASENAME}.${FORMAT} into your Godot project's res:// folder"
        log "  2. Godot auto-imports glTF — the model appears in the FileSystem dock"
        log "  3. Drag it into your scene, or instance it via code:"
        log "     var scene = load(\"res://${BASENAME}.${FORMAT}\")"
        log "     var instance = scene.instantiate()"
        log "     add_child(instance)"
        ;;
    stl)
        log "  1. Open in slicer (PrusaSlicer, Cura, etc.) for 3D printing"
        log "  2. Or copy into Godot project — re-run with -f glb for native support"
        ;;
    obj)
        log "  1. Copy ${BASENAME}.obj into your Godot project's res:// folder"
        log "  2. Godot auto-imports OBJ as a mesh resource"
        log "  3. Create a MeshInstance3D node and assign the mesh"
        ;;
esac
