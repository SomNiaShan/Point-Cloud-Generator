                                                  clear; clc; close all;

%% ===== 参数设置（按需修改） =====
grid_size_x = 20;        % 列数（X方向）
grid_size_y = 11;        % 行数（Y方向）

pitch_x = 10;             % 相邻列 X 间距 (um)
pitch_y = 10;             % 相邻行 Y 间距 (um)

origin_x = 0;            % X 原点 (um)
origin_y = 0;            % Y 原点 (um)
origin_z = 0;            % Z 原点 (um)

z_start   = 0;           % 第1列深度 (um)
z_interval = 50;         % 每列的深度步进 (um)，可正可负

P_start    = 0;          % 第1行功率 (%)
P_interval = 10;         % 每行功率步进 (%)

%% ===== 生成列优先的(i,j)索引（i列，j行） =====
i_idx = kron((1:grid_size_x)', ones(grid_size_y,1));   % 形如: 1,1,...,1, 2,2,...,2, ...
j_idx = repmat((1:grid_size_y)', grid_size_x, 1);      % 形如: 1,2,...,grid_size_y, 1,2,...

%% ===== 功率序列（仅随 j 变化）并做上限检查 =====
P = P_start + (j_idx - 1) * P_interval;   % 百分数（0~100）
Pmax = max(P);
if Pmax > 100
    error('功率上限超出: 最大值=%.3g%% > 100%%。请调整 P_start/P_interval/grid_size_y。', Pmax);
end
% 如需禁止负功率，可打开下面一行改为报错或警告：
% if any(P < 0), warning('存在负功率值，最小=%.3g%%。', min(P)); end

%% ===== 坐标（X/Y 随索引与pitch均匀变化；Z 仅随列i变化） =====
x_um = origin_x + (i_idx - 1) * pitch_x;
y_um = origin_y + (j_idx - 1) * pitch_y;
z_um = origin_z + (z_start + (i_idx - 1) * z_interval);

% 转换为 mm
x_mm = x_um / 1000;
y_mm = y_um / 1000;
z_mm = z_um / 1000;

%% ===== 保存四个文件 =====
prefix = sprintf('%dx%d_P=%g_%+g_Z=%g_%+gum_pitch=%g,%gum', ...
    grid_size_x, grid_size_y, P_start, P_interval, z_start, z_interval, pitch_x, pitch_y);

writematrix(x_mm, ['X_', prefix, '.txt']);
writematrix(y_mm, ['Y_', prefix, '.txt']);
writematrix(z_mm, ['Z_', prefix, '.txt']);
writematrix(P,    ['P_', prefix, '.txt']);

fprintf('总点数: %d (=%d x %d)\n', numel(x_mm), grid_size_x, grid_size_y);
fprintf('功率范围: [%.3g, %.3g] %%\n', min(P), max(P));
fprintf('深度范围: [%.3g, %.3g] um\n', min(z_um), max(z_um));

%% ===== 可视化（颜色映射为功率） =====
figure; 
scatter3(x_mm, y_mm, z_mm, 18, P, 'filled'); 
colorbar; c = colorbar; c.Label.String = 'Power (%)';
axis equal; grid on;
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('Depth (by column) & Power (by row) grid');
