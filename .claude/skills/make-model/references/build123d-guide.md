# build123d / CadQuery Quick Reference

Read this before generating any CAD Python script. This covers the patterns that produce clean,
parametric, print-ready models using the OpenCascade BREP kernel.

## Table of Contents
1. build123d Basics
2. Sketching (2D)
3. 3D Operations
4. Selectors and Fillets
5. Assemblies
6. CadQuery Equivalent Patterns
7. Export
8. Gotchas

---

## 1. build123d Basics

build123d uses nested context managers to scope geometry operations:

```python
from build123d import *

# Three builder levels:
with BuildPart() as part:          # 3D solid context
    with BuildSketch() as sketch:  # 2D sketch context
        with BuildLine() as line:  # 1D wire context
            ...
```

### Importing

```python
from build123d import *  # Imports all builders, operations, and shapes
```

### Parameters at the top

```python
# --- Parameters ---
width = 50
depth = 30
height = 10
wall_thickness = 2
hole_diameter = 5
fillet_radius = 2
```

---

## 2. Sketching (2D)

Sketches define 2D profiles for extrusion, revolution, etc.

```python
with BuildSketch() as sk:
    Rectangle(width, depth)                          # Centered rectangle
    Circle(radius=10)                                # Centered circle
    with Locations((15, 0), (-15, 0)):               # Multiple positions
        Circle(radius=hole_diameter / 2, mode=Mode.SUBTRACT)

# Rounded rectangle
with BuildSketch() as sk:
    RectangleRounded(width, depth, radius=fillet_radius)

# Arbitrary polygon
with BuildSketch() as sk:
    with BuildLine() as ln:
        Polyline([(0, 0), (30, 0), (30, 20), (15, 25), (0, 20)], close=True)
    make_face()

# Slot shape
with BuildSketch() as sk:
    SlotOverall(width=40, height=10)

# Regular polygon
with BuildSketch() as sk:
    RegularPolygon(radius=15, side_count=6)  # Hexagon
```

### Sketch operations

```python
with BuildSketch() as sk:
    Rectangle(50, 30)
    fillet(sk.vertices(), radius=3)      # Round all corners of 2D sketch
    offset(amount=-wall_thickness)       # Shell operation in 2D
```

---

## 3. 3D Operations

### Extrude

```python
with BuildPart() as part:
    with BuildSketch():
        Rectangle(50, 30)
    extrude(amount=height)                           # Straight extrude
    extrude(amount=height, taper=10)                 # Tapered extrude (draft angle)
    extrude(amount=-5, mode=Mode.SUBTRACT)           # Cut downward
```

### Revolve

```python
with BuildPart() as part:
    with BuildSketch(Plane.XZ):        # Sketch on XZ plane
        with BuildLine():
            Polyline([(0, 0), (10, 0), (10, 20), (5, 25), (0, 25)], close=True)
        make_face()
    revolve(axis=Axis.Z, revolution_arc=360)
```

### Sweep and Loft

```python
# Sweep a profile along a path
with BuildPart() as part:
    with BuildLine() as path:
        Spline((0, 0, 0), (50, 0, 20), (100, 0, 0))
    with BuildSketch(Plane(origin=path @ 0, z_dir=path % 0)):
        Circle(5)
    sweep()

# Loft between sketches
with BuildPart() as part:
    with BuildSketch(Plane.XY):
        Rectangle(40, 40)
    with BuildSketch(Plane.XY.offset(30)):
        Circle(15)
    loft()
```

### Primitives (direct 3D)

```python
with BuildPart() as part:
    Box(width, depth, height)                        # Centered box
    Cylinder(radius=10, height=20)                   # Centered cylinder
    Sphere(radius=15)                                # Centered sphere
    Cone(bottom_radius=15, top_radius=5, height=20)  # Cone/frustum
```

### Boolean operations

```python
with BuildPart() as part:
    Box(50, 30, 10)                                  # Base (additive by default)
    with Locations((10, 0)):
        Cylinder(radius=5, height=12, mode=Mode.SUBTRACT)   # Cut hole
    with Locations((-10, 0)):
        Cylinder(radius=3, height=12, mode=Mode.ADD)         # Add boss

# Operator syntax (outside builders)
result = box_part + cylinder_part    # Fuse
result = box_part - cylinder_part    # Cut
result = box_part & cylinder_part    # Intersect
```

---

## 4. Selectors and Fillets

build123d's selector API targets edges/faces by geometry:

```python
with BuildPart() as part:
    Box(50, 30, 10)

    # Fillet all edges
    fillet(part.edges(), radius=2)

    # Fillet only top edges
    fillet(part.edges().filter_by(Axis.Z).sort_by(Axis.Z)[-4:], radius=2)

    # Fillet vertical edges
    fillet(part.edges().filter_by(Axis.Z), radius=3)

    # Chamfer bottom edges
    chamfer(part.edges().sort_by(Axis.Z)[:4], length=1)
```

### Common selectors

```python
part.edges()                              # All edges
part.edges().filter_by(Axis.Z)           # Edges parallel to Z
part.edges().sort_by(Axis.Z)[-1]         # Topmost edge
part.faces().sort_by(Axis.Z)[-1]         # Top face
part.faces().filter_by(Plane.XY)         # Faces parallel to XY
part.vertices().sort_by(Axis.Z)[0]       # Lowest vertex
```

### Holes

```python
with BuildPart() as part:
    Box(50, 30, 10)
    # Simple through-hole from top face
    with Locations((0, 0)):
        Hole(radius=3)
    # Counterbore hole
    with Locations((15, 0)):
        CounterBoreHole(radius=2, counter_bore_radius=4, counter_bore_depth=3)
    # Countersink hole
    with Locations((-15, 0)):
        CounterSinkHole(radius=2, counter_sink_radius=4)
```

---

## 5. Assemblies

For multi-part models:

```python
from build123d import *

def make_bracket(width, height, thickness):
    with BuildPart() as bracket:
        with BuildSketch():
            Rectangle(width, thickness)
        extrude(amount=height)
    return bracket.part

def make_pin(radius, length):
    with BuildPart() as pin:
        Cylinder(radius=radius, height=length)
    return pin.part

# Combine
bracket = make_bracket(40, 20, 5)
pin = make_pin(2.5, 25)
pin_placed = pin.moved(Location((10, 0, 10)))
assembly = bracket + pin_placed
```

---

## 6. CadQuery Equivalent Patterns

If the user requests CadQuery or the model fits its chaining style better:

```python
import cadquery as cq

# Basic box with fillets and holes
result = (
    cq.Workplane("XY")
    .box(50, 30, 10)
    .edges("|Z")
    .fillet(2)
    .faces(">Z")
    .workplane()
    .pushPoints([(10, 0), (-10, 0)])
    .hole(5)
)

# Shell (hollow out)
result = (
    cq.Workplane("XY")
    .box(50, 30, 20)
    .faces(">Z")
    .shell(-wall_thickness)
)

# Revolve
result = (
    cq.Workplane("XZ")
    .polyline([(0, 0), (10, 0), (10, 20), (5, 25), (0, 25)])
    .close()
    .revolve(360, (0, 0, 0), (0, 1, 0))
)

# Export
cq.exporters.export(result, "./output/name.step")
cq.exporters.export(result, "./output/name.stl")
```

### CadQuery selectors

```
">Z"   — highest Z face         "<Z"   — lowest Z face
"|Z"   — edges parallel to Z    "#Z"   — edges perpendicular to Z
">X"   — rightmost X face       "<X"   — leftmost X face
```

---

## 7. Export

### build123d

```python
from build123d import *

# After building:
export_step(part.part, "./output/name.step")
export_stl(part.part, "./output/name.stl")

# With tolerance control for STL
export_stl(part.part, "./output/name.stl",
           angular_tolerance=0.1, linear_tolerance=0.01)
```

### CadQuery

```python
import cadquery as cq

cq.exporters.export(result, "./output/name.step")
cq.exporters.export(result, "./output/name.stl")
```

### Format notes
- **STEP** — Lossless BREP, best for manufacturing and further CAD work
- **STL** — Tessellated mesh, for 3D printing and game engine import

---

## 8. Gotchas

1. **Context manager scoping.** Geometry created inside `with BuildPart()` is automatically
   added. Outside the context, you must use operators (`+`, `-`) to combine.

2. **Mode matters.** Default mode is `Mode.ADD`. Use `Mode.SUBTRACT` for cuts,
   `Mode.INTERSECT` for intersections. Forgetting this is the #1 bug.

3. **Plane orientation.** `BuildSketch()` defaults to XY plane. For vertical sketches,
   pass `Plane.XZ` or `Plane.YZ`. For offset planes: `Plane.XY.offset(height)`.

4. **Fillet/chamfer order.** Always fillet/chamfer after all boolean operations on the
   affected edges. Doing it before a cut can fail or produce unexpected results.

5. **Fillet radius limits.** Radius cannot exceed the shortest adjacent edge. If a fillet
   fails, reduce the radius or check adjacent geometry.

6. **Coordinate system.** build123d and CadQuery both use Z-up, same as OpenSCAD.
   X=right, Y=back, Z=up. Units are mm by convention.

7. **Locations for patterns.** Use `with Locations(...)` for placing features:
   ```python
   with Locations((0, 0), (20, 0), (20, 20), (0, 20)):
       Hole(radius=2.5)
   ```

8. **Manifold geometry.** BREP kernel produces watertight solids by default — no need
   for the z-fighting workarounds that OpenSCAD requires. Cuts automatically extend
   through surfaces cleanly.

9. **Performance.** build123d handles complex fillets and booleans much faster than
   OpenSCAD's CGAL/minkowski. Don't hesitate to use fillets liberally.

10. **Installation.** build123d requires the OCP (OpenCascade) kernel:
    ```bash
    pip install build123d
    ```
    CadQuery has its own installer:
    ```bash
    pip install cadquery
    ```
    Both work on Windows, macOS, and Linux.
