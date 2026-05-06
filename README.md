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
