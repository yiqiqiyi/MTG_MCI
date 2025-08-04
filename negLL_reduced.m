function nLL = negLL_reduced(params, subject, fixMask)
% negLL_reduced 计算简化模型（风险敏感性 lambda 固定为 0）的负对数似然，
% 同时允许通过 fixMask 固定任意参数为 0。
%
% 输入:
%   params  - 参数向量 [alpha, beta, gamma, eta, S]
%             其中：
%               alpha：学习率
%               beta：决策逆温参数（奖赏敏感性）
%               gamma：奖赏敏感性参数（对预期收益的非线性放大）
%               eta  ：干扰比例参数
%               S    ：策略变量（长期规划奖励）
%   subject - 结构体，包含字段 rounds，且每轮数据包含:
%               partner      - 'good' 或 'bad'
%               investment   - 投资额度
%               feedback     - 反馈金额（实际收到的金额）
%               tier         - 当前试次对应的档位（1~7）
%   fixMask - 可选参数，一个逻辑向量，与 params 尺寸相同，若 fixMask(i)==true，
%             则将 params(i) 固定为 0。若未提供，则默认不固定任何参数。
%
% 输出:
%   nLL - 负对数似然值

if nargin < 3
    fixMask = false(size(params));
end
% 将需要固定的参数值设为 0
params(fixMask) = 0;


% Unpack parameters
alpha_good = params(1);
alpha_bad  = params(2);
beta       = params(3);
gamma      = params(4);
lambda     = params(5);
eta        = params(6);
% S          = params(7);
 S          = 0;
n_exp      = 2;  % Exponent for risk amplification, e.g., 2
% Initialize beliefs for each partner type
Q_good = 0.5;  % Initial belief for "good" partner (100%)
Q_bad  = 0.5;  % Initial belief for "bad" partner (100%)

% Define available investment options (in points)
options_invest = [0, 2, 5, 8, 10];

nLL = 0;
nRounds = length(subject.rounds);

% Initialize arrays for debugging information
predErrors = zeros(nRounds, 1);
valueUpdates = zeros(nRounds, 1);

for t = 1:nRounds
    round_data = subject.rounds(t);
    partner = lower(round_data.partner);
    x = round_data.investment;
    feedback_amount = round_data.feedback;
    tier = round_data.tier;
    
    % Compute the feedback probability distribution based on partner type and tier
    if strcmp(partner, 'good')
        p200 = 0.3333 + (tier - 1) * 0.10;
        p200 = min(p200, 0.9333);
        remaining = 1 - p200;
        p150 = remaining / 2;
        p100 = remaining / 2;
        outcomes = [2, 1.5, 1];  % Corresponds to 200%, 150%, and 100%
        probs = [p200, p150, p100];
        Q_current = Q_good;
    elseif strcmp(partner, 'bad')
        p50 = 0.3333 + (tier - 1) * 0.10;
        p50 = min(p50, 0.9333);
        remaining = 1 - p50;
        p100 = remaining / 2;
        p75 = remaining / 2;
        outcomes = [1, 0.75, 0.5];  % Corresponds to 100%, 75%, and 50%
        probs = [p100, p75, p50];
        Q_current = Q_bad;
    else
        error('Unknown partner type: %s', partner);
    end
    
    % Calculate mean and variance (sigma^2) of the feedback distribution
    mu = sum(outcomes .* probs);
    sigma2 = sum(probs .* (outcomes - mu).^2);
    
    % Calculate expected utility for each investment option
    U = zeros(1, length(options_invest));
    for i = 1:length(options_invest)
        invest = options_invest(i);
        EU = (10 - invest) + 3 * invest * Q_current;
        % Risk penalty: scales non-linearly with investment using exponent n_exp
        riskPenalty = lambda * sigma2* (invest / 10)^n_exp;
        % Strategy bonus term adds long-term planning effect
%         strategyBonus = S * (invest / 10);
        strategyBonus = S ;
        U(i) = EU^gamma - riskPenalty + strategyBonus;
    end
    
    % Convert utilities to probabilities using softmax
    expU = exp(beta * U);
    prob_options = expU / sum(expU);
    
    % Identify the index of the chosen investment option
    idx = find(options_invest == x);
    if isempty(idx)
        error('Investment value %f is not among the predefined options', x);
    end
    nLL = nLL - log(prob_options(idx) + eps);
    
    % Convert feedback amount to feedback ratio (if investment > 0)
    if x > 0
        r_ratio = feedback_amount / (2 * x);
    else
         r_ratio = Q_current;
%         r_ratio = 0;
    end
    
    % Calculate predictive error and value update
predError = r_ratio - Q_current;
if strcmp(partner, 'good')
    valueUpdate = alpha_good * predError;
    interference = eta * (Q_bad - Q_good);
 
    Q_good = Q_good + valueUpdate + interference;

    % 约束 Q_good 保持在 [0,1] 内
     Q_good = min(max(Q_good, 0), 1);
else  % partner == 'bad'
    valueUpdate = alpha_bad * predError;
    interference = eta * (Q_good - Q_bad);
  
    Q_bad = Q_bad + valueUpdate + interference;

    % 约束 Q_bad 保持在 [0,1] 内
     Q_bad = min(max(Q_bad, 0), 1);
end
    % Save debugging information for the current trial
    predErrors(t) = predError;
    valueUpdates(t) = valueUpdate;
end

% Store debugging information
debugInfo.predErrors = predErrors;
debugInfo.valueUpdates = valueUpdates;
end

