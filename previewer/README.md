# cadsmith Previewer

Interactive Three.js 3D previewer for cadsmith scene manifests.

## Setup

```bash
cd previewer
npm install
npm run dev
```

Opens at http://localhost:3000

## Loading a manifest

Three ways to load:

1. **File picker** — Click the file input in the toolbar
2. **Drag & drop** — Drop a `_manifest.json` file onto the viewport
3. **URL param** — `http://localhost:3000?manifest=../output/my_part_manifest.json`

## Controls

- **Drag** — Rotate camera
- **Shift+Drag** — Pan
- **Scroll** — Zoom
- **Touch** — Single finger rotate, pinch to zoom

## Manifest format

```json
{
  "name": "My Part",
  "units": "mm",
  "parts": [
    {
      "id": "base",
      "label": "Base Plate",
      "type": "box",
      "params": { "width": 50, "height": 5, "depth": 30 },
      "position": [0, 2.5, 0],
      "rotation": [0, 0, 0],
      "color": "#4488cc",
      "opacity": 1.0
    }
  ],
  "camera": {
    "distance": 120,
    "angle": [30, 45]
  }
}
```

### Geometry types

| type | params |
|------|--------|
| `box` | `width`, `height`, `depth` |
| `sphere` | `radius`, `segments` (optional) |
| `cylinder` | `radiusTop`, `radiusBottom`, `height`, `segments` (optional) |
| `extrude` | `shape` (array of [x,y] points), `height` |
| `lathe` | `points` (array of [x,y] profile points), `segments` |

### Difference operations

Parts with `"operation": "difference"` render as transparent red wireframes to indicate subtracted volumes:

```json
{
  "id": "hole",
  "label": "Mounting Hole",
  "type": "cylinder",
  "params": { "radiusTop": 2, "radiusBottom": 2, "height": 7 },
  "position": [10, 2.5, 0],
  "color": "#ff4444",
  "opacity": 0.3,
  "wireframe": true,
  "operation": "difference"
}
```

### Coordinate system

The previewer uses Three.js Y-up coordinates. When cadsmith generates manifests from build123d (Z-up), it swaps Y/Z automatically.
