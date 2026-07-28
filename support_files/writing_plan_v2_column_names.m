function names = writing_plan_v2_column_names()
%WRITING_PLAN_V2_COLUMN_NAMES Canonical columns for unified writing plans.

names = {'schema_version', 'operation', 'group_id', 'segment_index', ...
    'laser_state', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'speed_mm_s', 'power', 'dwell_s', 'pause_s', 'source_recipe'};
end
