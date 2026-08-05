# MATLAB Coordinate Generator

Standalone MATLAB point-cloud generator used by the laser writing workflow.

## Layout

- `point_cloud_generator_app.m`: main app entry point
- `support_files/generate_point_cloud.m`: core point-cloud generation logic for Cartesian, Hex, HCP, and Staircase lattices
- `support_files/depth2powerMgF2.m`: MgF2 depth-to-power helper
- `support_files/build_standalone.m`: Windows standalone app and installer builder

## Quick Start

1. Open this repository folder in MATLAB.
2. Make sure the Current Folder is the repository root.
3. Run `point_cloud_generator_app`.

## Excel Recipe Patterns

Open the top-level `Excel Pattern` tab to convert an `.xlsx` worksheet into
point-dwell Writing Plan v2 rows. This workflow is independent of the
procedural shapes listed under `Generator Type`.

- The worksheet must contain one complete rectangular matrix of finite,
  nonnegative integer Recipe IDs without headers.
- Blank rows and columns around the matrix are ignored. Blank cells inside
  the matrix, text, negative IDs, and fractional IDs are rejected.
- Recipe ID `0` is always skipped. Every processed nonzero ID maps to its
  own Z shift, power, dwell time, exposure count, and pre-write pause.
- `Z Shift (mm)` is added to the pattern's base Origin Z for that Recipe.
  Positive values move toward +Z (up); negative values move toward -Z
  (down/deeper).
- Excel formatting and conditional colors are ignored. Preview colors are
  selected from a 10-color drop-down menu in the app and stored as `#RRGGBB`.
- The configured origin is the lower-left image corner by default. Writing
  starts with the bottom Excel image row and advances upward toward +Y, while
  Excel row 1 remains at the top so the image is not vertically flipped.
  Column and row directions can still be independently reversed, and writing
  order can be row-major, serpentine, or recipe-by-recipe. Recipe-by-recipe
  uses serpentine point order within each Recipe. Leave its `Recipe order`
  field blank to process IDs in ascending order, or enter every processed
  nonzero ID in a custom sequence such as `3, 2, 1`. Recipe 0 and Recipes
  configured to Skip are omitted from this field.
- The current import limit is 1,000,000 matrix cells, 256 distinct Recipe
  IDs, and 2,000,000 generated Writing Plan rows.

Pattern mode currently produces point-dwell operations only. Supporting
additional per-Recipe hardware settings such as pulse frequency or pulse
width requires a future Writing Plan schema and executor update.

## Packaging

To build a standalone Windows application:

```matlab
addpath('support_files')
build_standalone
```

By default, the script creates the executable under `deploy/PointCloudGenerator/build` and an installer under `deploy/PointCloudGenerator/package`.

MATLAB Compiler is required. End users do not need MATLAB, but they do need MATLAB Runtime.

## Notes

- Generated `.txt` and `.csv` outputs are ignored by git.
- `support_files/` contains helper code used by the app and packaging script.
- This repository is separated from the main laser-writing app so it can be shared independently.
- In Point dwell mode, `Exposures per point` writes each source point as consecutive plan rows so the laser-writing app performs separate move-settle-expose operations at that point. The default value is 1.

## Writing Plan v2

Newly saved plans use one explicit operation model:

- `operation=point` stores a dwell exposure at one XYZ position.
- `operation=path` stores an ordered motion segment from XYZ to XYZ2.
- `laser_state=on|off` states whether the laser is exposed during each path segment.
- `group_id` and `segment_index` define one continuous, recoverable path group.
- `source_recipe` records how the path was generated, such as
  `cartesian_axis_scan`, `hexagon_cut`, or `circle_release_cut`; it does not
  control execution.

An axis scan contains one laser-on segment in its own group. Optional
`Lead-in (mm)` and `Lead-out (mm)` settings add laser-off motion immediately
before and after that exposed segment without changing its anchor or exposed
length. All three segments use the selected scan speed. A cut uses the same
explicit laser-off/on segment model. This removes the old distinction between
`mode=scan` and `mode=cut` from newly saved files. Every current recipe builds
this v2 table directly; generation no longer creates an intermediate legacy
table.

The app continues to load legacy point/scan/cut writing plans and converts
them at the file-import boundary. Point and path operations cannot be mixed
in one v2 file because they use different execution and recovery contracts.
