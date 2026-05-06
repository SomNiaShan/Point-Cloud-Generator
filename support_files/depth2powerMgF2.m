function P = depth2powerMgF2(depth_um)
%DEPTH2POWER 根据激光加工深度返回对应功率（百分比）
%   输入: depth_um (单位: µm，可为标量或向量)
%   输出: P (单位: %)

    % 实测数据
    D = [70 170 270 370 470 570 670 770 870 970];
    power = [15 35 35 30 12 10 12 28 28 33];

    % 归一化为百分比（相对最大功率）

    % 线性插值（外推）
    P = interp1(D, power, depth_um, 'linear', 'extrap');
end