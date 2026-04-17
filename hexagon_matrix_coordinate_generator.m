clearvars; clc;

%% ========== 参数 ==========
% 计数（每行点数、行数、层数）
grid_size_x = 66;   % 每行的点数（列数）
grid_size_y = round(66*1.155);   % 行数
grid_size_z = 1;     % 层数

% 节距（像素=μm）
pitch_xy = 3;        % 六方格最近邻节距 a（沿 x 方向）
pitch_z  = 75;       % 层间距（像素=μm）

% 原点（像素=μm）
origin_x = 0;
origin_y = 0;
origin_z = 0;

% 六方格几何量
row_spacing = sqrt(3)/2 * pitch_xy;   % 相邻行的 y 间距 Δy

% 是否启用 HCP（AB 堆垛）层间平移：偶数层相对奇数层平移 (a/2, √3 a/6)
use_hcp_AB_shift = false;
AB_dx = pitch_xy/2;
AB_dy = (sqrt(3)/6) * pitch_xy;       % = row_spacing / 3

%% ========== 生成六方格点坐标 ==========
X = [];
Y = [];
Z = [];

for k = 1:grid_size_z
    % 当前层 z（像素=μm），使得第一层 z=0
    z_pix = origin_z + (k-1)*pitch_z;

    % 层间平移（HCP）
    if use_hcp_AB_shift && mod(k,2)==0
        layer_shift_x = AB_dx;
        layer_shift_y = AB_dy;
    else
        layer_shift_x = 0;
        layer_shift_y = 0;
    end

    for j = 1:grid_size_y
        % 行基准 y（像素）
        y_pix = origin_y + (j-1)*row_spacing + layer_shift_y;

        % 奇偶行的半个 pitch 错位
        row_offset = mod(j-1, 2) * (pitch_xy/2);

        % 该行所有 x（像素）
        x_row = origin_x + (0:grid_size_x-1)*pitch_xy + row_offset + layer_shift_x;

        % 追加到全局坐标
        X = [X; x_row(:)];
        Y = [Y; repmat(y_pix, numel(x_row), 1)];
        Z = [Z; repmat(z_pix, numel(x_row), 1)];
    end
end

%% ========== 单位转换到 mm ==========
x_coords_mm = X / 1000;   % 像素=μm -> mm
y_coords_mm = Y / 1000;
z_coords_mm = Z / 1000;

% 功率随深度（示例：沿用你原来的线性关系）
power_z = depth2powerMgF2(1070-(z_coords_mm+0.1)*1000);

%% ========== 保存 ==========
prefix = [num2str(grid_size_x),'x',num2str(grid_size_y),'x',num2str(grid_size_z), ...
          '_hex_xy_', num2str(pitch_xy), 'um_z_', num2str(pitch_z), 'um'];

writematrix(x_coords_mm, ['X_', prefix, '.txt']);
writematrix(y_coords_mm, ['Y_', prefix, '.txt']);
writematrix(z_coords_mm, ['Z_', prefix, '.txt']);
writematrix(power_z,   ['P_', prefix, '.txt']);

%% ========== 可视化 ==========
figure(1); clf;
plot3(x_coords_mm, y_coords_mm, z_coords_mm, '.');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
title('3D 六方格点阵（可选 HCP AB 堆垛）');
axis equal; grid on;
view(30, 25);
