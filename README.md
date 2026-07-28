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
