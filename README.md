# MATLAB Coordinate Generator

Standalone MATLAB repository for coordinate-generator tools used by the laser writing workflow.

## Included tools

- `point_cloud_generator_app.m`: launches the point-cloud app UI
- `hexagon_matrix_coordinate_generator_app.m`: launches the hexagon point-cloud app UI
- `depth_and_power_coordinate_generator.m`: launches the depth/power generator script
- `frame_coordinate_generator.m`: launches the frame generator script
- `hexagon_matrix_coordinate_generator.m`: launches the hexagon matrix generator script
- `square_matrix_coordinate_generator.m`: launches the square matrix generator script

Core implementations live in the `Coordinate generator/` folder.

## Quick start

1. Open this repository folder in MATLAB.
2. Make sure the Current Folder is the repository root.
3. Run one of the launcher files from the root folder.

## Notes

- Generated `.txt` and `.csv` outputs are ignored by git.
- The repository is separated from the main laser-writing app so it can be shared independently.
