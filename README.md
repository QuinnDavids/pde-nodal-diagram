# PDE Modeler Nodal Diagram

**See a MATLAB PDE Modeler solution as a labelled grid of nodal values, at exactly the nodal points of your hand (finite-difference / control-volume) calculation.**

Author: Ugonna David Ugochukwu-Okeogu

## The problem it solves

In heat-transfer courses you solve conduction problems by hand on a regular grid of nodes, and the results come out as a table of nodal temperatures. When you solve the same problem in MATLAB's **PDE Modeler** (`pdeModeler`, formerly `pdetool`), the answer comes back on an irregular triangular mesh chosen by the software. Its nodes are not your nodes, so there is no direct way to read off "the temperature at node (2, 3)" and compare it with your own result.

This tool closes that gap. After you solve in PDE Modeler, it:

- reads the solution at **the regular grid of points you choose**;
- draws a **node diagram**: the outline of your domain, a marker at each nodal point and its value printed beside it;
- prints the same values as a **table** in the Command Window, ready to compare with a hand calculation or paste into a report.

It works for any 2-D geometry (rectangles, L-shapes, plates with holes, multi-region domains). Points that fall outside the meshed domain, such as inside a notch or a hole, are clearly marked and are not given a value.

## Quick start

1. **Solve your model in PDE Modeler** as usual. New to PDE Modeler? See the [PDE Modeler guide](docs/PDE_MODELER_GUIDE.md), which maps every hand-method step to the matching PDE Modeler setting.
2. In the PDE Modeler window:
   - **Mesh → Export Mesh…** → click **OK**. This puts `p`, `e` and `t` in the MATLAB workspace.
   - **Solve → Export Solution…** → click **OK**. This puts `u` in the workspace.
   - Keep the default names `p`, `e`, `t` and `u`.
3. Open **`call_nodal_diagram.m`** and set your nodal grid in the `YOUR INPUTS` block:
   ```matlab
   xg = 0:0.015:0.06;     % x-coordinates of the nodal points
   yg = 0:0.015:0.09;     % y-coordinates of the nodal points
   ```
4. **Run `call_nodal_diagram`.** Keep both `.m` files in the same folder, or on the MATLAB path.

## Choosing `xg` and `yg`

`xg` and `yg` are written as `start : spacing : end`, in **the same units you drew the geometry in**. Every combination of one `xg` value and one `yg` value is one nodal point.

| Your hand calculation | What to enter |
|---|---|
| Plate 0.06 m wide, 0.09 m tall, node spacing Δx = Δy = 0.015 m | `xg = 0:0.015:0.06;` (5 columns) and `yg = 0:0.015:0.09;` (7 rows) → 35 nodal points |
| Plate 60 mm × 90 mm drawn in **millimetres**, 15 mm spacing | `xg = 0:15:60;` and `yg = 0:15:90;` |
| Different spacing in x and y | e.g. `xg = 0:0.02:0.10;` and `yg = 0:0.01:0.05;` |
| Geometry that does not start at the origin | start from the geometry's real corner, e.g. `xg = -0.03:0.015:0.03;` |

Each list needs at least two values, in increasing order.

**If the diagram looks wrong**, check the two lines printed first in the Command Window:

```
x range: 0.0000 to 0.0600
y range: 0.0000 to 0.0900
```

These give the extent of your mesh. Your `xg` and `yg` should run across these ranges. A common cause is a geometry drawn in millimetres with a grid entered in metres, or the other way round.

## Reading the output

**The diagram**

| You see | Meaning |
|---|---|
| Grey outline | The real boundary of the meshed domain (not a bounding box) |
| Filled marker with a number | Nodal point inside the domain, and its value (2 decimal places) |
| Hollow grey marker, no number | Nodal point outside the domain (e.g. in a notch or hole) |

The axes are labelled in metres. If you drew the geometry in other units, read the axes in those units.

**The table** (Command Window), listed top row first so it reads like the diagram (values below are illustrative):

```
       x        y            T   inside
  0.0000   0.0900       85.214      yes
  0.0150   0.0900       83.907      yes
  ...
```

The `T` column is whatever PDE Modeler solved for: temperature in a heat-conduction problem. Points outside the domain show `--` and `no`, and MATLAB also shows a warning giving how many points were skipped.

## Options

**Time-dependent problems (parabolic or hyperbolic mode).** The exported `u` then has one column per time in `tlist`. Pick one column before plotting. `call_nodal_diagram.m` has a ready line for the last time step:

```matlab
u = u(:, end);    % last time step; use u(:, k) for the k-th time in tlist
```

**Colour the nodes by type.** For example, you might show fixed-temperature, convective and interior nodes in different colours, as in a hand-method node diagram. Pass a matrix with one group number per nodal point, sized `numel(yg)`-by-`numel(xg)`, where row 1 is the bottom row (`yg(1)`):

```matlab
groupIdx = 3 * ones(numel(yg), numel(xg));   % 3 = interior
groupIdx([1 end], :) = 1;                    % bottom and top rows
groupIdx(:, [1 end]) = 2;                    % left and right columns
plot_nodal_diagram(p, t, u, xg, yg, 'ColorByGroup', groupIdx)
```

Five colours are defined (groups 1–5); higher group numbers reuse them.

## How it works

For each nodal point `(xg(i), yg(j))`:

1. **Find the mesh triangle that contains the point** (`pointLocation` on a `triangulation` built from `p` and `t`).
2. **Interpolate linearly** between that triangle's three corner values using barycentric weights (`cartesianToBarycentric`). This matches the linear triangular elements of the exported mesh, so the value is the finite-element solution itself at that point, not an approximation of it.
3. **Corner and edge rescue:** if no triangle is found but the point lies within `1e-6` (geometry units) of a mesh node, it takes that node's value. This catches corner and edge points that the triangle search misses because of floating-point round-off.
4. **Otherwise the point is outside the domain** and is shown without a value.

Earlier versions of the tool simply took the value of the nearest mesh node. On non-convex shapes that silently gave a number even for points outside the domain, such as the missing corner of an L-shape. Locating the containing triangle avoids that, and gives proper interpolated values instead of the value of a nearby node.

## Files

| File | What it is |
|---|---|
| `call_nodal_diagram.m` | **Start here.** Script: checks the exported variables, holds your grid inputs, calls the plotting function. |
| `plot_nodal_diagram.m` | The function that does the work: interpolation, diagram and table. Full help: `help plot_nodal_diagram`. |
| `docs/PDE_MODELER_GUIDE.md` | Handbook: translating hand-calculated heat-conduction problems into PDE Modeler (governing equation, the four PDE modes, boundary conditions, cheat sheet). |

## Requirements

- MATLAB with the **Partial Differential Equation Toolbox**, to build and solve the model in PDE Modeler.
- The nodal-diagram functions themselves use only core MATLAB (`triangulation`, `pointLocation`, `cartesianToBarycentric`, `freeBoundary`).

## Limitations

- **2-D only.** It works with the 2-D meshes PDE Modeler produces.
- **Linear triangles.** Interpolation uses the three corner nodes of each triangle (rows 1–3 of `t`), which is what PDE Modeler's Export Mesh provides.
- **Scalar problems.** One solution value per mesh node (such as temperature). For a system of equations, select the component you want before plotting.
- **Mesh and solution must match.** Export both after the final solve. If you refine the mesh after solving, export again, or the sizes will not match (the tool stops with a message explaining this).

## License

[PolyForm Noncommercial License 1.0.0](LICENSE). You are free to use, study, modify and share this tool for **non-commercial purposes**, including teaching, learning, personal study and research at educational and public institutions. **Commercial use is not permitted** without the author's permission.
