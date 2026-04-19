# MATLAB Coordinate Generator

Standalone MATLAB repository for coordinate-generator tools used by the laser writing workflow.

## Included tools

- `point_cloud_generator_app.m`: launches the point-cloud app UI, including Staircase lattice mode
- `hexagon_matrix_coordinate_generator_app.m`: launches the hexagon point-cloud app UI
- `depth_and_power_coordinate_generator.m`: launches the depth/power generator script
- `frame_coordinate_generator.m`: launches the frame generator script
- `hexagon_matrix_coordinate_generator.m`: launches the hexagon matrix generator script
- `square_matrix_coordinate_generator.m`: launches the square matrix generator script
- `generate_point_cloud.m`: core point-cloud generation logic for Cartesian, Hex, HCP, and Staircase lattices
- `generate_hexagon_point_cloud.m`: core hexagon point-cloud generation logic
- `depth2powerMgF2.m`: helper for the MgF2 depth-to-power model
- `*_app_impl.m`: app implementation files used by the UI launchers

## Quick start

1. Open this repository folder in MATLAB.
2. Make sure the Current Folder is the repository root.
3. Run one of the launcher files from the root folder.

## Notes

- Generated `.txt` and `.csv` outputs are ignored by git.
- All MATLAB source files now live directly in the repository root.
- The repository is separated from the main laser-writing app so it can be shared independently.
