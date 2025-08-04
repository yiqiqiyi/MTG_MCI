clc;clear;
cd C:\Users\90553\Desktop\MTGdata
trust_tet=xlsread('C:\Users\90553\Desktop\MTGdata\trust_MTG.xlsx');
% 载入数据
% 数据文件 'behavior_data.mat' 中应包含变量 data，data 为结构体数组，
% 每个元素代表一个被试，其字段包括：
%   subject_id: 被试编号
%   group: 分组信息 ('MCI' 或 'HC')
%   rounds: 一个结构体数组，每一轮包含字段：
%           - partner: 'good' 或 'bad'
%           - investment: 投资选择（应在预定义的选项 [0, 2.5, 5, 7.5, 10] 内）
%           - feedback: 该轮观察到的返还比例
MCIi = find (trust_tet(:,10)==0)
HCi = find (trust_tet(:,10)==1)
testidx=[7,8,9,43,14,28,41,30,19,29,33,38,32,13,31,5];
testname={'Age','Gender','Education','MMSE','Rey-recall','AVLT','DST','TMT-B','Stroop','TMT-A','SDMT','CVFT','BNT','Rey-copy','CDT','Lottery game'}
for ii=1:length(testidx)
meansd(ii,1)=mean(trust_tet(MCIi,testidx(ii)));
meansd(ii,2)=std (trust_tet(MCIi,testidx(ii)));
meansd(ii,3)=mean(trust_tet(HCi,testidx(ii)));
meansd(ii,4)=std (trust_tet(HCi,testidx(ii)));
[p,h,t]=ranksum(trust_tet(MCIi,testidx(ii)),trust_tet(HCi,testidx(ii)));
meansd(ii,5)=t.zval;
meansd(ii,6)=p;
end
%%
cd C:\Users\90553\Desktop\MTGdata\code\newcode2
load ('model_fit_results2.mat')
%parameter test
for ii=1:length(results)
paramet(ii,:)=results(ii).params
end
paradatag=[paramet trust_tet(:,5)];
[bahavorr2par,pp]=corr(paradatag(:,5),trust_tet(:,5),'Type','Spearman')
[bahavorr2par,pp]=corr(paradatag(:,6),trust_tet(:,30),'Type','Spearman')


mci_allgrp1=find(paradatag(:,end)==0);
hc_allgrp1=find(paradatag(:,end)==1);
    MCIexclued=[2 5 29 30];
    HCexclued=[12 16 24 30 44];
mci_allgrp1=setdiff(mci_allgrp1,MCIexclued);
hc_allgrp1=setdiff(hc_allgrp1,HCexclued);
for idx_t=1:length(results(1).params)
meanvalue(idx_t,:)=[mean(paramet(mci_allgrp1,idx_t)),std(paramet(mci_allgrp1,idx_t))...
    mean(paramet(hc_allgrp1,idx_t)),std(paramet(hc_allgrp1,idx_t))]
[p1(idx_t), h1(idx_t), stats1(idx_t)]=ranksum(round(paramet(mci_allgrp1,idx_t),3),round(paramet(hc_allgrp1,idx_t),3));
[a(idx_t),b(idx_t)]=partialcorr(paramet([mci_allgrp1;hc_allgrp1],idx_t),...
    [ones(1,length(mci_allgrp1)),ones(1,length(hc_allgrp1))*2]',...
    trust_tet([mci_allgrp1;hc_allgrp1],[7 8 9]),'Type','Spearman')

end
meanvalue
%%
%figure

figure;
scatter (paradatag(:,5),trust_tet(:,5));hold on;
ce=polyfit(paradatag(:,5),trust_tet(:,5),1);
xx=min(paradatag(:,5)):0.1:max(paradatag(:,5));
yy=ce(1)*xx+ce(2);
plot(xx,yy,'k');
corrMatrix = corrcoef(paradatag(:,1:end-2));  % 计算皮尔逊相关系数矩阵

h.CellLabelFormat = '%.2f';  % 设置单元格中显示两位小数
n = 256;             % 总色阶数
nHalf = floor(n/2);  % 分为两部分
% 第一部分：红到白
r1 = ones(nHalf, 1);
g1 = linspace(1, 0, nHalf)';
b1 = linspace(1, 0, nHalf)';

% 第二部分：白到蓝
r2 = linspace(0, 1, n - nHalf)';
g2 = linspace(0, 1, n - nHalf)';
b2 = ones(n - nHalf, 1);

% 合并生成自定义 colormap
myColormap = [ [r2;r1], [g2;g1], [b2;b1] ];

% 生成 heatmap
figure;
h = heatmap(corrMatrix);
h.ColorLimits = [-1, 1];    % 根据相关系数的范围设定
h.Colormap = myColormap;    % 应用自定义红白蓝 colormap
h.ColorbarVisible = 'on'; 
disp(corrMatrix);
%normalization 
for idx_t=1:length(results(1).params)
[H1(idx_t), pValue1(idx_t), KSstatistic1(idx_t), criticalValue1(idx_t)]=kstest(paramet(mci_allgrp1,idx_t));
[H2(idx_t), pValue2(idx_t), KSstatistic2(idx_t), criticalValue2(idx_t)]=kstest(paramet(hc_allgrp1,idx_t));
[p(idx_t),stats(idx_t)] =vartestn(paramet([mci_allgrp1;hc_allgrp1],idx_t),...
    [ones(1,length(mci_allgrp1)),ones(1,length(hc_allgrp1))*2]');
end


%comparation model
load ('model_comparison_results.mat')
for ii=1:length(comparisonResults)
paramet(ii,:)=comparisonResults(ii).models.Reduced.params
end
for idx_t=1:5
[H1(idx_t), pValue1(idx_t), KSstatistic1(idx_t), criticalValue1(idx_t)]=kstest(paramet(mci_allgrp1,idx_t));
[H2(idx_t), pValue2(idx_t), KSstatistic2(idx_t), criticalValue2(idx_t)]=kstest(paramet(hc_allgrp1,idx_t));
[p(idx_t),stats(idx_t)] =vartestn(paramet([mci_allgrp1;hc_allgrp1],idx_t),...
    [ones(1,length(mci_allgrp1)),ones(1,length(hc_allgrp1))*2]');
end

for idx_t=1:6
meanvalue(idx_t,:)=[mean(paramet(mci_allgrp1,idx_t)),std(paramet(mci_allgrp1,idx_t))...
    mean(paramet(hc_allgrp1,idx_t)),std(paramet(hc_allgrp1,idx_t))]
[p1(idx_t), h1(idx_t), stats1(idx_t)]=ranksum(paramet(mci_allgrp1,idx_t),paramet(hc_allgrp1,idx_t))
[a(idx_t),b(idx_t)]=partialcorr(paramet([mci_allgrp1;hc_allgrp1],idx_t),...
    [ones(1,length(mci_allgrp1)),ones(1,length(hc_allgrp1))*2]',...
    trust_tet([mci_allgrp1;hc_allgrp1],[7 8 9]),'Type','Spearman')

end
%%
%normality
%% Plot Average Investment with Standard Deviation for MCI and HC in Good and Bad Conditions

% 假设数据存储在 investment_data.mat 中，包含 table 变量 investmentData
load('subjdata.mat');  % 数据表应包含: SubjectID, Group, Partner, Trial, Investment

% 获取唯一试次编号
trialNumbers = 1:30;
investmentData=data;
% 定义组和伙伴类型
groups = {'MCI', 'HC'};
partners = {'good', 'bad'};



% 对每个组合分别计算均值和标准差
for i = 1:length(groups)
    idx(i,:) = strcmp({investmentData.group}, groups{i});
    dataSubset = investmentData(idx(i,:));
    groupm=1:84;
    groupmember=groupm(idx(i,:))
    for t = 1:length(groupmember)
        trialIdx = 1:30;
        
        invValues1 = strcmp({dataSubset(t).rounds.partner},partners(1));
        invValues2 = strcmp({dataSubset(t).rounds.partner},partners(2));
        invValues = [dataSubset(t).rounds.investment];
        subgood(t,:)=invValues(invValues1);
        subbad(t,:)=invValues(invValues2);
         firstinv(t,1)=dataSubset(t).rounds(1).investment;
    end
    meanInvest(i,:) = mean(subgood,1);
    stdInvest(i,:) = std(subgood,0,1)/sqrt(88);
    meanInvest2(i,:) = mean(subbad,1);
    stdInvest2(i,:) = std(subbad,0,1)/sqrt(88);

 if i==1
 MCIgood=subgood;
MCIbad=subbad;
MCIfirstinv=firstinv;
 else
 HCgood=subgood;
HCbad=subbad;
HCfirstinv=firstinv;
 end
     clear subgood subbad firstinv
end
NHCm(:,1)=mean(HCgood,2)
NHCm(:,2)=mean(HCbad,2)
MCIm(:,1)=mean(MCIgood,2)
MCIm(:,2)=mean(MCIbad,2)
[h,p]=kstest(MCIm(:,2))
mean(HCfirstinv)
std(HCfirstinv)
[p, h, stats] = ranksum(MCIfirstinv,HCfirstinv)
        % 绘制带误差条的折线图
        figure;
        hold on;
        colors = lines(4); % 生成4种不同颜色
        colors=[23 114 180]/256
        colors(3,:)=colors(1,:);
        colors(2,:)= [239 71 93]/256
        colors(4,:)= colors(2,:)
        legendEntries = {};
        plotIndex = 1;
        errorbar(trialNumbers, meanInvest(1,:), stdInvest(1,:)/sqrt(39), '-', 'Color', colors(2,:), 'LineWidth', 1.5);
        legendEntries{1} = sprintf('%s %s', groups{1}, partners{1});
        hold on;
        errorbar(trialNumbers, meanInvest(2,:), stdInvest(2,:)/sqrt(45), '-', 'Color', colors(1,:), 'LineWidth', 1.5);
        legendEntries{2} = sprintf('%s %s', groups{2}, partners{1});
        errorbar(trialNumbers, meanInvest2(1,:), stdInvest2(1,:)/sqrt(39), '.-.', 'Color', colors(4,:), 'LineWidth', 1.5);
        legendEntries{3} = sprintf('%s %s', groups{1}, partners{2});
        hold on;
        errorbar(trialNumbers, meanInvest2(2,:), stdInvest2(2,:)/sqrt(45), '.-.', 'Color', colors(3,:), 'LineWidth', 1.5);
        legendEntries{4} = sprintf('%s %s', groups{2}, partners{2});        
        
        xlabel('Trial Number');
        ylabel('Average Investment');
        title('Average Investment Over Trials (with Standard Deviation)');
        legend(legendEntries, 'Location', 'Best');
        grid on;
        hold off;
  %%
          figure;
        hold on;
        colors = lines(4); % 生成4种不同颜色
        colors=[0.6875    0.0898    0.1211]
        colors(3,:)= colors(1,:)+0.1
        colors(4,:)= colors(2,:)+0.1
        legendEntries = {};
        plotIndex = 1;
        plot(trialNumbers, meanInvest(1,:), '-o', 'Color', colors(2,:), 'LineWidth', 1.5);
        legendEntries{1} = sprintf('%s %s', groups{1}, partners{1});
        hold on;
        plot(trialNumbers, meanInvest(2,:), '-o', 'Color', colors(1,:), 'LineWidth', 1.5);
        legendEntries{2} = sprintf('%s %s', groups{2}, partners{1});
        plot(trialNumbers, meanInvest2(1,:), '-.', 'Color', colors(4,:), 'LineWidth', 1.5);
        legendEntries{3} = sprintf('%s %s', groups{1}, partners{2});
        hold on;
        plot(trialNumbers, meanInvest2(2,:), '-.', 'Color', colors(3,:), 'LineWidth', 1.5);
        legendEntries{4} = sprintf('%s %s', groups{2}, partners{2});     
  
  %%
   for ll=1:30
    [p1]=ranksum(subgood);
    [p2]=ranksum();
   end
    
   %%
   %PE
load model_fit_results2.mat 
% 获取唯一试次编号
trialNumbers = 1:30;
investmentData=data;
% 定义组和伙伴类型
groups = {'MCI', 'HC'};
partners = {'good', 'bad'};
% 对每个组合分别计算均值和标准差
for i = 1:length(groups)
    idx(i,:) = strcmp({investmentData.group}, groups{i});
    dataSubset = investmentData(idx(i,:));
    groupm=1:84;
    groupmember=groupm(idx(i,:))
    for t = 1:length(groupmember)
        trialIdx = 1:30;
        
        invValues1 = strcmp({dataSubset(t).rounds.partner},partners(1));
        invValues2 = strcmp({dataSubset(t).rounds.partner},partners(2));
        invValues = results(groupmember(t)).debugInfo.predErrors;
        
        subgood(t,:)=invValues(invValues1);
        subbad(t,:)=invValues(invValues2);
  
    end

%     if i==1
%     MCIexclued=[2 5 29 30];
%     else
%     MCIexclued=[12 16 24 30 44];
%     end
    MCIexclued=[];
    mciinclude=setdiff([1:t],MCIexclued);
    if i==1
      rankmci(:,:,1)=subgood; 
      rankmci(:,:,2)=subbad; 
      else
      rankhc(:,:,1)=subgood;
      rankhc(:,:,2)=subgood;
    
    end
    meanInvest(i,:) = mean(subgood(mciinclude,:),1);
    stdInvest(i,:) = std(subgood(mciinclude,:),0,1)/sqrt(88);;
    meanInvest2(i,:) = mean(subbad(mciinclude,:),1);
    stdInvest2(i,:) = std(subbad(mciinclude,:),0,1)/sqrt(88);;
 
    clear subgood subbad
end
        % 绘制带误差条的折线图
        figure;
        hold on;
        colors = lines(4); % 生成4种不同颜色
        colors=[0.6875    0.0898    0.1211]
        colors(3,:)= colors(1,:)+0.1
        colors(4,:)= colors(2,:)+0.1
        legendEntries = {};
        plotIndex = 1;
        plot(trialNumbers, meanInvest(1,:), '-o', 'Color', colors(2,:), 'LineWidth', 1.5);
        legendEntries{1} = sprintf('%s %s', groups{1}, partners{1});
        hold on;
        plot(trialNumbers, meanInvest(2,:), '-o', 'Color', colors(1,:), 'LineWidth', 1.5);
        legendEntries{2} = sprintf('%s %s', groups{2}, partners{1});
        plot(trialNumbers, meanInvest2(1,:), '-.', 'Color', colors(4,:), 'LineWidth', 1.5);
        legendEntries{3} = sprintf('%s %s', groups{1}, partners{2});
        hold on;
        plot(trialNumbers, meanInvest2(2,:), '-.', 'Color', colors(3,:), 'LineWidth', 1.5);
        legendEntries{4} = sprintf('%s %s', groups{2}, partners{2});        
        
        xlabel('Trial Number');
        ylabel('Average VU');
        title('Average Value Updata Over Trials');
        legend(legendEntries, 'Location', 'Best');
        grid on;
        hold off;
        for tt=1:30
        [p(1,tt), h, stats] = ranksum(rankmci(:,tt,1),rankhc(:,tt,1));
        [p(2,tt), h, stats] = ranksum(rankmci(:,tt,2),rankhc(:,tt,2));
        end