function subject = simulate_subject_dynamic_tier(params, nRounds, partner_seq, subjID)
% simulate_subject_dynamic_tier 生成模拟受试者行为数据（动态tier）
% 输入
%   params: [alpha_good, alpha_bad, beta, gamma, lambda, eta, S, n]
%   nRounds: 实验轮数
%   partner_seq: 1xnRounds cell数组，每轮的partner类型，'good'或'bad'（你可以随机生成）
%   subject_id, group: 标识信息
% 输出
%   subject: 可直接用于negLL的结构体

options_invest = [0, 2, 5, 8, 10];

alpha_good = params(1);
alpha_bad  = params(2);
beta       = params(3);
gamma      = params(4);
lambda     = params(5);
eta        = params(6);

% S          = params(7);
S          = 0;
n_exp      = 2;

Q_good = 0.5;
Q_bad  = 0.5;

% tier初始化
tier_good = 1;
tier_bad = 1;
prev_invest_good = NaN; % 上一次对good的投资
prev_invest_bad = NaN;  % 上一次对bad的投资

rounds = repmat(struct(), nRounds, 1);

for t = 1:nRounds
    partner = lower(partner_seq{t});
    % 更新tier（只有同一类型连续出现才比较）
    if t > 1 && strcmp(partner, 'good')
        last_good_idx = find(strcmp({rounds(1:t-1).partner}, 'good'), 1, 'last');
        if ~isempty(last_good_idx)
            prev_x = rounds(last_good_idx).investment;
            if x > prev_x
                tier_good = min(tier_good + 1, 7);
            end
        end
    elseif t > 1 && strcmp(partner, 'bad')
        last_bad_idx = find(strcmp({rounds(1:t-1).partner}, 'bad'), 1, 'last');
        if ~isempty(last_bad_idx)
            prev_x = rounds(last_bad_idx).investment;
            if x < prev_x
                tier_bad = min(tier_bad + 1, 7);
            end
        end
    end
    % 根据partner类型选择当前tier
    if strcmp(partner, 'good')
        tier = tier_good;
    else
        tier = tier_bad;
    end

    % 计算反馈分布
    if strcmp(partner, 'good')
        p200 = 0.3333 + (tier - 1) * 0.10;
        p200 = min(p200, 0.9333);
        remaining = 1 - p200;
        p150 = remaining / 2;
        p100 = remaining / 2;
        outcomes = [2, 1.5, 1];
        probs = [p200, p150, p100];
        Q_current = Q_good;
    elseif strcmp(partner, 'bad')
        p50 = 0.3333 + (tier - 1) * 0.10;
        p50 = min(p50, 0.9333);
        remaining = 1 - p50;
        p100 = remaining / 2;
        p75 = remaining / 2;
        outcomes = [1, 0.75, 0.5];
        probs = [p100, p75, p50];
        Q_current = Q_bad;
    end

    % 均值、方差
    mu = sum(outcomes .* probs);
    sigma2 = sum(probs .* (outcomes - mu).^2);

    % 计算每个投资选项的期望效用并softmax
    U = zeros(1, length(options_invest));
    for i = 1:length(options_invest)
        invest = options_invest(i);
        EU = (10 - invest) + 3 * invest * Q_current;
        riskPenalty = lambda * sigma2 * (invest / 10)^n_exp;
        strategyBonus = S;
        U(i) = EU^gamma - riskPenalty + strategyBonus;
    end
    expU = exp(beta * U);
    prob_options = expU / sum(expU);

    % 按反馈分布采样获得反馈比例
    feedback_ratio = randsample(outcomes, 1, true, probs);
    % 按分布采样选择投资
    x = randsample(options_invest, 1, true, prob_options);


    % 计算反馈金额
    if x > 0
        feedback_amount =  x * feedback_ratio;
    else
        feedback_amount = 0;
    end

    % 记录
    rounds(t).partner = partner;
    rounds(t).investment = x;
    rounds(t).feedback = feedback_amount;
    rounds(t).tier = tier;

    % belief更新

    if x > 0
        r_ratio = feedback_amount / (3 * x);
    else
         r_ratio = Q_current;
%         r_ratio=0;
    end

    predError = r_ratio - Q_current;
    if strcmp(partner, 'good')
        valueUpdate = alpha_good * predError;
        interference = eta * (Q_bad - Q_good);
            if x > 0
        Q_good = Q_good + valueUpdate + interference;
            end
        Q_good = min(max(Q_good, 0), 1);
    else
        valueUpdate = alpha_bad * predError;
        interference = eta * (Q_good - Q_bad);

        Q_bad = Q_bad + valueUpdate + interference;

        Q_bad = min(max(Q_bad, 0), 1);
    end


end

    subject.subject_id = subjID;
    subject.group = 'simulated';
subject.rounds = rounds;
end