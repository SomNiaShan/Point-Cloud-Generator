clear all

% 设置参数
grid_size_x = 4;
grid_size_y = 4;
grid_size_z = 149*2;

pitch_x = 20;  % 间距（单位：像素 = 1μm）
pitch_y = 20;
pitch_z = 5;

% 初始化一个100x100x100的零体积（单位：μm）
canvas = zeros(grid_size_x*pitch_x, grid_size_y*pitch_y, grid_size_z*pitch_z);  % (y, x, z)

origin_x = 0;
origin_y = 0;
origin_z = 0;

% 设置点为1
for i = 1:grid_size_x
    for j = 1:grid_size_y
        for k = 1:grid_size_z
            x = origin_x + i * pitch_x;
            y = origin_y + j * pitch_y;
            z = origin_z + k * pitch_z;
                canvas(x, y, z) = 1;  % 注意：行y，列x，第3维z
                j
        end
    end
end

% 提取所有值为1的点坐标
[x_coords, y_coords, z_coords] = ind2sub(size(canvas), find(canvas == 1));

% 转换为 mm
x_coords_mm = (x_coords - pitch_x) / 1000;
y_coords_mm = (y_coords - pitch_y) / 1000;
z_coords_mm = (z_coords - pitch_z) / 1000;
power_z=15-(z_coords_mm)*15.9091;%初始为15%，每浅10um减少0.5%；

%% 保存为四个文件
prefix = [num2str(grid_size_x),'x',num2str(grid_size_y),'x',num2str(grid_size_z),'x_',num2str(pitch_x),'um','y_',num2str(pitch_y),'um','z_',num2str(pitch_z),'um'];

writematrix(x_coords_mm, ['X_', prefix, '.txt']);
writematrix(y_coords_mm, ['Y_', prefix, '.txt']);
writematrix(z_coords_mm, ['Z_', prefix, '.txt']);
writematrix(power_z, ['P_', prefix, '.txt']);

%% 可视化三维点阵
%
figure(1)
plot3(x_coords_mm, y_coords_mm, z_coords_mm, '.')
xlabel('X (mm)')
ylabel('Y (mm)')
zlabel('Z (mm)')
title('3D 激光直写点阵')
axis equal
grid on
%}