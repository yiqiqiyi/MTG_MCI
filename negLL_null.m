function nLL = negLL_null(subject)
% negLL_null 计算空模型的负对数似然
% 假设每个投资选项的概率均为 1/5
options_invest = [0, 2, 5, 8, 10];
p = 1/length(options_invest);
nRounds = length(subject.rounds);
nLL = -nRounds * log(p);
end
