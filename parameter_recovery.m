%% parameter_recovery.m
% 本脚本实现参数恢复分析。
% 1. 为 nSubjects 个模拟受试者生成真实模型参数，并用这些参数模拟数据。
% 2. 利用 fmincon + negLL 对每个受试者数据进行参数拟合，恢复参数。
% 3. 绘制真参数与恢复参数的散点图，并标注相关系数。

clear; clc; close all;

%% 模拟设置
nSubjects = 200;      % 模拟受试者数量
nTrials   = 100;     % 每个受试者的回合数
rng(123);            % 固定随机数种子（便于结果重现）

% 预分配变量（每个受试者 7 个参数：alpha_good, alpha_bad, beta, gamma, lambda, eta, S）
trueParams = zeros(nSubjects, 7);
recoveredParams = zeros(nSubjects, 7);
fvals = zeros(nSubjects,1);



%% 拟合设置
% 初始猜测及参数上下界（与真实参数范围相仿）
param0 =  [0.5, 0.5, 5.0, 0.5, 1.5, 0.5, 0,2]; 
lb = [0, 0, 0, 0, 0, 0, -5 1];
ub = [1, 1, 10, 1, 3, 1, 5 3];

% fmincon 优化选项（Display 关闭以加快运行速度）
options = optimoptions('fmincon','Display','off','Algorithm','interior-point');
%%
% 参数生成区间（可根据实际情况调整）：
%   学习率 alpha_good, alpha_bad ~ Uniform(0.1,0.9)
%   beta ~ Uniform(0.5,5)
%   gamma ~ Uniform(0.5,1.5)
%   lambda ~ Uniform(0.5,2.5)
%   eta ~ Uniform(0, 1)
%   S ~ Uniform(-2,2)
rangep=-0.1;
for s = 1:nSubjects
    trueParams(s,1) = 0.1 + (ub(1)-lb(1)+rangep)*rand;           % alpha_good
    trueParams(s,2) = 0.1 + (ub(2)-lb(2)+rangep)*rand;            % alpha_bad
    trueParams(s,3) = 1 + (ub(3)-lb(3)+rangep)*rand;                % beta
    trueParams(s,4) = 0.1 + (ub(4)-lb(4)+rangep)*rand;              % gamma
    trueParams(s,5) = 0.3 + (ub(5)-lb(5)+rangep)*rand;              % lambda
    trueParams(s,6) = 0.1 + (ub(6)-lb(6)+rangep)*rand;                    % eta
    trueParams(s,7) = -4 + (ub(7)-lb(7)+rangep)*rand;              % S
end
%% 循环模拟每个受试者并进行模型拟合
for s = 1:nSubjects
    % 利用真参数生成模拟受试者数据
%     subjData = simulate_subject(trueParams(s,:), s, nTrials);
% 随机partner序列
partner_seq = cell(1, nTrials);
for t = 1:nTrials
    if rand < 0.5
        partner_seq{t} = 'good';
    else
        partner_seq{t} = 'bad';
    end
end
    subjData = simulate_subject_dynamic_tier(trueParams(s,:), nTrials, partner_seq, s);
    % 使用 fmincon 拟合参数，目标函数为 negLL（需保证 negLL.m 在路径下）
    [est_params, fval] = fmincon(@(params) negLL(params, subjData), param0, [], [], [], [], lb, ub, [], options);
    
    recoveredParams(s,:) = est_params(1:7);  % 只使用前 7 个参数
    fvals(s) = fval;
    fprintf('受试者 %d, 真参数 = %s, 恢复参数 = %s\n', s, mat2str(trueParams(s,:),3), mat2str(recoveredParams(s,:),3));
end

%% 绘制参数恢复结果
 paramNames = {'\alpha_{good}', '\alpha_{bad}', '\beta', '\gamma', '\lambda', '\eta', '\S'};
% figure;
for p = 1:6
    subplot(2,3,p);
    scatter(trueParams(:,p), recoveredParams(:,p), 50, 'filled'); hold on;
    % 计算相关系数并显示
    r_val = corr(trueParams(:,p), recoveredParams(:,p));
    x_text = minVal + 0.05*(maxVal-minVal);
    y_text = minVal + 0.9*(maxVal-minVal);
%     text(x_text, y_text, sprintf('r=%.2f', r_val), 'FontSize',14, 'Color', 'b');
    rcover(p)=r_val;
    % 绘制对角线
    minVal = min(trueParams(:,p));
    maxVal = max(trueParams(:,p));
    plot([minVal, maxVal], [minVal, maxVal], 'r--', 'LineWidth',1.5);
    xlabel('Real parameter', 'FontSize',12, 'Color', 'k');
    ylabel('Recover parameter', 'FontSize',12, 'Color', 'k');
    title([paramNames{p},' (r = ',num2str(round(r_val,2)),')'], 'FontSize',12, 'Color', 'k');
    grid on;

end
rcover
% subplot(2,4,8); axis off; % 最后一个子图空置
% sgtitle('Parameter recovery results');
% 定义各参数的容忍度，若|恢复值-真实值| <= tol，则视为恢复成功
tol = abs(lb-ub)*0.1 

nBins = 10;  % 将真实参数值分成10个区间
binCenters = cell(1,7);
recoveryProb = cell(1,7);

for p = 1:7
    true_vals = trueParams(:,p);
    % 利用线性均分确定区间边界
    binEdges = linspace(min(true_vals), max(true_vals), nBins+1);
    % 计算每个区间的中心值
    binCenters{p} = (binEdges(1:end-1) + binEdges(2:end)) / 2;
    recoveryProb{p} = zeros(1, nBins);
    
    for b = 1:nBins
        % 找出真实参数值落在当前区间的被试
        idx = true_vals >= binEdges(b) & true_vals < binEdges(b+1);
        if sum(idx) > 0
            nInBin = sum(idx);
            % 计算该区间内恢复成功的被试数目
            success = sum( abs(recoveredParams(idx, p) - true_vals(idx)) <= tol(p) );
            recoveryProb{p}(b) = success / nInBin;
        else
            recoveryProb{p}(b) = NaN; % 如果当前区间没有被试，则标记为 NaN
        end
    end
end

%% 4. 绘制各参数恢复概率的折线图
paramNames = {'\alpha_{good}', '\alpha_{bad}', 'beta', 'gamma', '\lambda', '\eta', 'S'};

figure;
for p = 1:7
    subplot(2,4,p);
    plot(binCenters{p}, recoveryProb{p}, '-o', 'LineWidth', 2, 'MarkerSize', 6);
    xlabel(['True ' paramNames{p}]);
    ylabel('Recovery Probability');
    title(paramNames{p});
    ylim([0,1]);
    grid on;
end
subplot(2,4,8); axis off;
sgtitle('Recovery Probability vs True Parameter Value');