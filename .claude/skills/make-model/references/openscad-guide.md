# OpenSCAD Quick Reference

Read this before generating any .scad file. This covers the patterns that produce clean,
parametric, print-ready OpenSCAD code.

## Table of Contents
1. Primitives
2. Transforms
3. Boolean / CSG Operations
4. Modules and Parameters
5. Loops and Conditionals
6. Common Patterns
7. Gotchas

---

## 1. Primitives

```scad
cube([x, y, z]);                    // box, corner at origin
cube([x, y, z], center=true);       // box, centered at origin
sphere(r=10);                        // sphere
sphere(d=20);                        // sphere by diameter
cylinder(h=10, r=5);                 // cylinder
cylinder(h=10, r1=5, r2=3);         // cone/frustum
cylinder(h=10, d=10);               // cylinder by diameter
```

All curved primitives accept `$fn` (facet count), `$fa` (min angle), `$fs` (min size).
Use `$fn` for predictable results:
- Preview: `$fn=64`
- Final render: `$fn=128` or higher
- Threads/fine detail: `$fn=256`

## 2. Transforms

```scad
translate([x, y, z]) child();
rotate([x_deg, y_deg, z_deg]) child();
scale([sx, sy, sz]) child();
mirror([1, 0, 0]) child();          // mirror across YZ plane
resize([x, y, z]) child();          // resize to exact dimensions
```

**Rotation order matters.** OpenSCAD applies rotations as Z, then Y, then X.
When in doubt, nest single-axis rotations:
```scad
rotate([0, 0, 45])
  rotate([0, 30, 0])
    rotate([15, 0, 0])
      child();
```

## 3. Boolean / CSG Operations

```scad
union() {        // combine shapes (additive)
  cube([10,10,10]);
  translate([5,0,0]) sphere(r=8);
}

difference() {   // subtract children from first child
  cube([20,20,10]);           // this is the base
  translate([10,10,-1])       // everything after is subtracted
    cylinder(h=12, r=4);     // -1/+1 to avoid z-fighting
}

intersection() { // keep only overlapping volume
  cube([10,10,10]);
  sphere(r=8);
}
```

**Critical: difference() z-fighting.** When cutting holes, extend the cutting shape 1mm
beyond the surface in both directions. Otherwise OpenSCAD leaves a paper-thin face:
```scad
// BAD - leaves artifacts
difference() {
  cube([20, 20, 10]);
  translate([10, 10, 0]) cylinder(h=10, r=3);
}

// GOOD - clean cut
difference() {
  cube([20, 20, 10]);
  translate([10, 10, -0.5]) cylinder(h=11, r=3);
}
```

## 4. Modules and Parameters

```scad
// Define a reusable part
module rounded_box(size, radius) {
  minkowski() {
    cube([size.x - 2*radius, size.y - 2*radius, size.z/2]);
    cylinder(r=radius, h=size.z/2);
  }
}

// Use it
rounded_box(size=[30, 20, 10], radius=2);
```

**Default parameters:**
```scad
module screw_hole(diameter=3, depth=10, clearance=0.2) {
  cylinder(h=depth, d=diameter + clearance, $fn=32);
}
```

## 5. Loops and Conditionals

```scad
// Linear pattern
for (i = [0 : 4]) {
  translate([i * 15, 0, 0]) cube([10, 10, 10]);
}

// Grid pattern
for (x = [0 : 3], y = [0 : 2]) {
  translate([x * 20, y * 20, 0]) cylinder(h=5, r=3);
}

// Circular pattern
for (i = [0 : 5]) {
  rotate([0, 0, i * 60])
    translate([20, 0, 0])
      cylinder(h=10, r=3);
}

// Conditional geometry
module bracket(with_holes=true) {
  difference() {
    cube([40, 20, 5]);
    if (with_holes) {
      for (x = [10, 30]) {
        translate([x, 10, -0.5])
          cylinder(h=6, d=4, $fn=32);
      }
    }
  }
}
```

## 6. Common Patterns

### Rounded rectangle (2D for extrusion)
```scad
module rounded_rect(size, r) {
  offset(r=r) offset(r=-r)
    square([size.x, size.y], center=true);
}
linear_extrude(height=5)
  rounded_rect([30, 20], 3);
```

### Shell / hollow box
```scad
module shell(outer, wall) {
  difference() {
    cube(outer, center=true);
    cube([outer.x - 2*wall, outer.y - 2*wall, outer.z - wall], center=true);
  }
}
```

### Fillet (edge rounding via minkowski)
```scad
module filleted_cube(size, fillet) {
  minkowski() {
    cube([size.x - 2*fillet, size.y - 2*fillet, size.z - fillet]);
    sphere(r=fillet, $fn=32);
  }
}
```

### Counterbore screw hole
```scad
module counterbore(shaft_d, head_d, shaft_depth, head_depth, clearance=0.2) {
  // Shaft
  cylinder(h=shaft_depth + 1, d=shaft_d + clearance, $fn=32);
  // Head recess
  translate([0, 0, shaft_depth - head_depth])
    cylinder(h=head_depth + 1, d=head_d + clearance, $fn=32);
}
```

### Snap-fit clip
```scad
module snap_clip(width, height, hook_depth, wall) {
  // Flexible arm
  cube([wall, width, height]);
  // Hook
  translate([0, 0, height - hook_depth])
    cube([wall + hook_depth, width, hook_depth]);
}
```

## 7. Gotchas

1. **No variables are truly variable.** OpenSCAD is functional — variables are assigned once.
   You can't do `x = x + 1`. Use recursion or `let()` for computed values.

2. **2D vs 3D context.** `circle()` and `square()` are 2D. They must be extruded
   (`linear_extrude` or `rotate_extrude`) to become 3D.

3. **Centering.** `cube()` defaults to corner-at-origin. `sphere()` and `cylinder()` are
   centered on XY but sit on Z=0. Use `center=true` when it simplifies transforms.

4. **render() for complex CSG.** If preview (F5) looks wrong with many booleans, wrap in
   `render()` to force full CGAL computation. Slow but accurate.

5. **minkowski() is expensive.** Great for fillets but very slow on complex shapes.
   Use sparingly and consider lowering `$fn` on the rounding primitive.

6. **Coordinate system.** OpenSCAD uses right-hand: X=right, Y=back, Z=up.
   Three.js uses: X=right, Y=up, Z=forward. When translating to Three.js,
   swap Y and Z and negate the new Z if needed.

7. **Units.** OpenSCAD is unitless — by convention, 1 unit = 1mm. If the user wants inches,
   either note "1 unit = 1 inch" in the header or multiply all dimensions by 25.4.

8. **Manifold geometry for printing.** Shapes must be watertight:
   - No coincident faces (offset by 0.01mm)
   - No zero-thickness walls
   - No self-intersecting geometry
   - Use `render()` + STL export to validate
