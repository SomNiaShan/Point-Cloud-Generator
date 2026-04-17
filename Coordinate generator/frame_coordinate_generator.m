clear; clc; close all;

%% ===== 参数设置 =====
grid_size_x = 10+2;   % X 方向点数（横向）
grid_size_y = 10+2;   % Y 方向点数（纵向）
pitch_x = 10;        % X 间距，单位: um
pitch_y = 10;        % Y 间距，单位: um

origin_x = 0;       % X 原点(um)
origin_y = 0;       % Y 原点(um)
origin_z = 0;       % Z 原点(um) —— 这里做2D框，放在同一Z平面
z_plane_um = origin_z;  % 固定的Z高度(um)

%% ===== 生成2D方框(仅边界)的格点索引（1-based，与原代码一致） =====
% 上边: y=1, x=1..grid_size_x
top_x = 1:grid_size_x;
top_y = ones(1, grid_size_x);

% 下边: y=grid_size_y, x=1..grid_size_x
bot_x = 1:grid_size_x;
bot_y = grid_size_y*ones(1, grid_size_x);

% 左边(去掉角): x=1, y=2..grid_size_y-1
if grid_size_y >= 3
    left_x = ones(1, grid_size_y-2);
    left_y = 2:(grid_size_y-1);
else
    left_x = [];
    left_y = [];
end

% 右边(去掉角): x=grid_size_x, y=2..grid_size_y-1
if grid_size_y >= 3
    right_x = grid_size_x*ones(1, grid_size_y-2);
    right_y = 2:(grid_size_y-1);
else
    right_x = [];
    right_y = [];
end

% 合并（注意：四个角不重复）
x_idx = [top_x, bot_x, left_x, right_x];
y_idx = [top_y, bot_y, left_y, right_y];

% 点数检查
n_pts = numel(x_idx);   % 应为 2*(grid_size_x + grid_size_y) - 4
fprintf('Frame points: %d\n', n_pts);

%% ===== 计算物理坐标（与原逻辑保持一致：i*pitch，然后减去一个pitch）=====
% 先得到以um为单位的坐标（起点为 pitch），再减去一个 pitch，使原点对齐到 0
x_um = origin_x + x_idx * pitch_x;
y_um = origin_y + y_idx * pitch_y;
z_um = z_plane_um * ones(size(x_um));  % 全部在同一Z平面

% 转换为 mm（保持你原先的 -pitch 再/1000 的做法）
x_mm = (x_um - pitch_x) / 1000;
y_mm = (y_um - pitch_y) / 1000;
z_mm = (z_um - 0) / 1000;  % 这里z_um本来就固定，直接/1000

% 功率随z的示例（保持你原公式；z为0时就是常数15）
power_z = 15 - (z_mm) * 15.9091;

%% ===== 保存为四个文件（沿用你的命名风格） =====
prefix = sprintf('%dx%d_frame_xy_%dum', grid_size_x, grid_size_y, pitch_x);
writematrix(x_mm, ['X_', prefix, '.txt']);
writematrix(y_mm, ['Y_', prefix, '.txt']);
writematrix(z_mm, ['Z_', prefix, '.txt']);
writematrix(power_z, ['P_', prefix, '.txt']);

%% ===== 可视化（2D & 3D） =====
figure(1); 
plot(x_mm, y_mm, '.-','MarkerSize',12);
axis equal; grid on;
xlabel('X (mm)'); ylabel('Y (mm)');
title(sprintf('2D Square Frame (%d x %d)', grid_size_x, grid_size_y));

% figure(2);
% plot3(x_mm, y_mm, z_mm, '.','MarkerSize',12);
% axis equal; grid on;
% xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
% title('3D View of 2D Frame (single Z plane)');
