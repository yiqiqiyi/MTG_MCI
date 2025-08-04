function [nLL, debugInfo] = negLL(params, subject)
% negLL_diff_alpha calculates the negative log-likelihood for a subject's data
% and outputs predictive error and value update information for each trial,
% using different learning rates for "good" and "bad" partner conditions.
%
% INPUTS:
%   params - Model parameter vector [alpha_good, alpha_bad, beta, gamma, lambda, eta, S, n]
%       alpha_good : Learning rate for "good" condition.
%       alpha_bad  : Learning rate for "bad" condition.
%       beta       : Inverse temperature parameter for the softmax decision rule.
%       gamma      : Reward sensitivity exponent, introducing non-linearity to expected utility.
%       lambda     : Risk sensitivity parameter.
%       eta        : Interference factor, reflecting cross-influence between partner beliefs.
%       S          : Strategy variable representing long-term planning bias.
%       n          : Exponent for non-linear risk amplification (e.g., fixed at 2).
%
%   subject - A structure containing fields:
%       subject_id, group, rounds
%       rounds is an array of structures for each trial, with fields:
%           partner    - 'good' or 'bad'
%           investment - Investment amount.
%           feedback   - Feedback amount (actual returned money).
%           tier       - Tier of the partner's condition (1 to 7).
%
% OUTPUTS:
%   nLL       - Negative log-likelihood value.
%   debugInfo - A structure containing arrays:
%                 debugInfo.predErrors: Predictive error for each trial.
%                 debugInfo.valueUpdates: Value update (belief change) for each trial.
%
% The model works by maintaining separate beliefs for "good" and "bad" partners.
% On each trial, the model calculates a predicted error (r_ratio - Q_current) and
% updates the belief using a learning rate specific to the condition. Additionally,
% an interference term is added, which pulls the belief toward the belief of the
% opposite partner type.
%
% References:
% [1] IBM, What Is an AI Model? https://www.ibm.com/think/topics/ai-model  
% [2] NIH, Computational Mechanisms of Belief Updating https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7990420/  
% [3] GitHub, Risk Model Documentation https://github.com/Scorpi000/QSDoc/blob/master/docs/%E9%A3%8E%E9%99%A9%E6%A8%A1%E5%9E%8B.rst  
% [4] Zhihu, Learning Rate and Model Performance https://zhuanlan.zhihu.com/p/64864995  
% [5] CSDN, Learning Rate Settings https://blog.csdn.net/xq151750111/article/details/125789981  
% [6] MathWorks, fmincon Documentation https://www.mathworks.com/help/stats/multcompare.html

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
