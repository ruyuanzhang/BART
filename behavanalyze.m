% quick data analysis on BART
clear all;close all;clc;

%% read data
cd data;
datafiles = matchfiles('*subj98*');
datatmp = {};
for i=1:numel(datafiles)
    datatmp = [datatmp load(datafiles{i})];
end
cd ..;

%%
allSteps = cellfun(@(x) x.sp.steps,datatmp,'UniformOutput',0);
allSteps = cell2mat(allSteps);
allResult = cellfun(@(x) x.sp.result,datatmp,'UniformOutput',0);
allResult = cell2mat(allResult);
allWhichDisk = cellfun(@(x) x.sp.design(:,2)',datatmp,'UniformOutput',0);
allWhichDisk = cell2mat(allWhichDisk);

%% calculate EV function
a=0.01;
EV_24 = zeros(1,24);
pBurst_24 = zeros(1,24);
for i=1:length(EV_24), EV_24(i) = i*(1-1/24)^i;pBurst_24(i) = (1-1/24)^i*1/24;end
EV_12 = zeros(1,12);
pBurst_12 = zeros(1,12);
for i=1:length(EV_12), EV_12(i) = i*(1-1/12)^i;pBurst_12(i) = (1-1/12)^i*1/12;end

%% stop point
burstRate24 = sum(allResult==1 & allWhichDisk==1)/320;
burstRate12 = sum(allResult==1 & allWhichDisk==2)/320;

%% histogram of steps
close all;
h = cpsfigure(2,2);
ax(1) = subplot(2,2,1);
histogram(allSteps(allResult==2 & allWhichDisk==1)); hold on;
histogram(allSteps(allResult==2 & allWhichDisk==2));
legend('24 steps','12 steps');
xlabel('Stopping Steps');ylabel('# of trials');
set(gca,'Box','Off');

ax(2) = subplot(2,2,2);
histogram(allSteps(allResult==1 & allWhichDisk==1)); hold on;
histogram(allSteps(allResult==1 & allWhichDisk==2));
legend('24 steps','12 steps');
xlabel('steps when burst');ylabel('# of trials');
set(gca,'Box','Off');

ax(3) = subplot(2,2,3);
myplot([],EV_24);
myplot([],EV_12);
xlabel('steps');ylabel('EV');
legend('24 steps','12 steps');

ax(4) = subplot(2,2,4);
myplot([],pBurst_24);
myplot([],pBurst_12);
xlabel('steps');ylabel('probability to burst');
legend('24 steps','12 steps');

%%