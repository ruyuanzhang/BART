% Balloon analouge risk task (BART) for intracranial recording patients
%
% History:
%   20180809 created by RZ

%% 
clear all; close all; clc;

sp.subj = 95;  % 99,97,RZ; 98, TZ; 96, Roberto;95,
sp.runNo = 3;  % 

addpath(genpath('./utils'));

%% debug purpose
sp.wantFrameFiles = 0; % 1, save all pictures;0, do not save
sp.blank = 4;  % secs, blanck at the begining and the end
%mp = getmonitorparams('uminn7tpsboldscreen');
%mp = getmonitorparams('uminnofficedesk');
mp = getmonitorparams('uminnmacpro');
sp.respKeys = {'upArrow','Enter'};

%% monitor parameter (mp)
%mp = getmonitorparams('uminn7tpsboldscreen');
mp.monitorRect = [0 0 mp.resolution(1) mp.resolution(2)];

%% stimulus parameters (sp)
% parameters
sp.expName = 'BART';
sp.nTrials = 64;  % number of trials in a run
sp.nSteps = 64; % maximum number of steps subject can go
sp.maxRadius = 15; % visual,deg, max radius you can have
sp.minRadius = 2; % visual,deg, max radius you can have
sp.steps = zeros(1,sp.nTrials);
sp.result = zeros(1,sp.nTrials); %0,reach maximum steps;1, burst;2,stop
sp.diskColor = [255,125,125];
sp.COLOR_GRAY = 127;
sp.COLOR_BLACK = 0;
sp.COLOR_WHITE = 254;
sp.ITI = 1.5; % 3 secs
sp.feedbackTime = 1;

% Do some calculation
sp.maxRadiusPix = round(sp.maxRadius * mp.pixPerDeg(1));
sp.minRadiusPix = round(sp.minRadius * mp.pixPerDeg(1));
sp.stepSizePix = (sp.maxRadiusPix -sp.minRadiusPix)/sp.nSteps;

%reward and pBurst function
sp.rewardFunc = @(x) 2*x;
sp.pBurstFunc = @(x) 1/sp.nSteps;
%% MRI related preparation
% some auxillary variables
sp.timeKeys = {};
sp.triggerKey = '5'; % the key to start the experiment
sp.timeFrames=[];
sp.allowedKeys = zeros(1, 256);
sp.allowedKeys([20 41 40 46 82]) = 1;  %20,'q';40,'Return';41,'ESCAPE'; 82, 'UpArrow';46?+
sp.updateOrNot = zeros(1, sp.nTrials);  % a marker to show that already update money in this trial, more button press will not update again
getOutEarly = 0;
when = 0;
glitchcnt = 0;
sp.deviceNum = 1; % devicenumber to record input
frameCnt = 0;
%kbQueuecheck setup
KbQueueCreate(1,sp.allowedKeys);

% get information about the PT setup
oldclut = pton([],[],[],1);
win = firstel(Screen('Windows'));
winRect = Screen('Rect',win);
Screen('BlendFunction',win,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
mfi = Screen('GetFlipInterval',win);  % re-use what was found upon initialization!

% Text position
sp.cumMoneyTxtPos = [winRect(3)-300 , 50];
sp.centerMoneyPos = [winRect(3)/2-25, winRect(4)/2-15];
sp.instrTxtPosBurst = [winRect(3)/2-110, winRect(4)/2-15];
sp.instrTxtPosStop = [winRect(3)/2-90, winRect(4)/2-15];
sp.instrTxtPosMax = [winRect(3)/2-80, winRect(4)/2];

%% wait for a key press to start, start to show stimulus
Screen('TextSize',win,30);Screen('TextFont',win,'Arial');
welcomeText = '<color=.5,.5,.5>Balloon Analogue Risk Task\nPress "5" to start experiment. \n Press "+" to increase reward. \n Press "Enter" to stop and accept the offer';
Screen('FillRect',win,sp.COLOR_BLACK,winRect);
DrawFormattedText2(welcomeText,'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
%Screen('DrawText', win, 'Press UpArrow to increase reward \n.Press 5 to start experiment...',winRect(3)/2-250, winRect(4)/2-50, 127);
Screen('Flip',win);
fprintf('press a key to begin the movie. (make sure to turn off network, energy saver, spotlight, software updates! mirror mode on!)\n');
safemode = 0;
tic;
while 1
  [secs,keyCode,deltaSecs] = KbWait(-3, 2);
  temp = KbName(keyCode);
  if isempty(sp.triggerKey) || isequal(temp(1),sp.triggerKey)
        break;
  end
end
fprintf('Experiment starts!\n');
Screen('Flip',win);
% issue the trigger and record it
 
%% now run the experiment
% get trigger
KbQueueStart(sp.deviceNum);
tic;
%% now run the real trials
sp.cumMoney = 0;
for iTrial = 1:sp.nTrials

    if getOutEarly
        break;
    end
    
    %% do it
    steps=0;
    stop= 0;
    diskRadiusPix = 0;
    while 1
        
        if diskRadiusPix >= sp.maxRadiusPix % subject get the reward and transition to the next trial
           fprintf('Exceeds maximum size. Turn to next trial!');
           Screen('DrawText', win, sprintf('Total won: $%d', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 127);
           Screen('FillOval', win,sp.diskColor, diskRect);
           DrawFormattedText2(sprintf('<color=1.,1.,1.>Reach maximum, get %d',rewardNow),'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
           [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win, when);
           WaitSecs(sp.feedbackTime);
           break;
        end
        
        diskRadiusPix = sp.minRadiusPix + steps * sp.stepSizePix;
        diskRect = CenterRect([0,0,diskRadiusPix,diskRadiusPix],mp.monitorRect);
        rewardNow = sp.rewardFunc(steps);
        
        % draw the disk
        Screen('DrawText', win, sprintf('Total won: $%d', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 127);
        Screen('FillOval', win,sp.diskColor, diskRect);
        DrawFormattedText2(sprintf('<color=1.,1.,1.>$%02d',rewardNow),'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
        [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win); % should sent the trigger here!
        
        
        % detect button responses
        kn='';
        while 1
            [keyIsDown,secs] = KbQueueCheck(sp.deviceNum);  % all devices, only check 'q','esc','1'-'5', left/right/up/down
            if keyIsDown
                %get the name of the key and record it
                kn = KbName(secs);
                if iscell(kn); kn = kn{end};end % avoid multiple button
                sp.timeKeys = [sp.timeKeys; {secs(find(secs)) kn}];
                %check if ESCAPE was pressed
                if isequal(kn,'ESCAPE')
                    fprintf('Escape key detected.  Exiting prematurely.\n');
                    getOutEarly = 1;
                    break;
                end
                break;
            end            
        end
        
        % % judge whether burst
        burst = rand<sp.pBurstFunc(steps);
        if burst % burst
            rewardNow = 0;
            Screen('DrawText', win, sprintf('Total won: $%d', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 127);
            DrawFormattedText2('Burst, fail, $0','win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
            [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win); 
            WaitSecs(sp.feedbackTime);
        else % no burst, continue
            if isequal(kn,'Return') % stop
                fprintf('Subject chose to stop here. \n');
                Screen('DrawText', win, sprintf('Total won: $%d', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 127);
                DrawFormattedText2(sprintf('Stop, won: $%d', rewardNow),'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win); 
                WaitSecs(sp.feedbackTime);
                stop=1;
            elseif isequal(kn,'=+') % increase the stop
                steps = steps+1;
            end
        end
        
        if burst || stop
            break;
        end
    end
    
    % record result
    sp.steps(iTrial)=steps;
    if stop
        sp.result(iTrial)=2; %stop by the user
    end
    if burst
        sp.result(iTrial)=1; %burst
    end
    sp.cumMoney = sp.cumMoney + rewardNow;
    PsychHID('KbQueueFlush',sp.deviceNum, 1);
    %% inter-trial interval
    Screen('DrawText', win, sprintf('Total won: $%d', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 127);
    [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win, when);
    if sp.wantFrameFiles;imwrite(Screen('GetImage',win),sprintf('Frame%03d.png',frameCnt));frameCnt=frameCnt+1;end    % write to file if desired
    WaitSecs(sp.ITI);
    
end
%%
toc
ptoff(oldclut);
%% clean up and save data
rmpath(genpath('./utils'));  % remove the utils path
c = fix(clock);
filename=sprintf('%d%02d%02d%02d%02d%02d_exp%s_subj%02d_run%02d',c(1),c(2),c(3),c(4),c(5),c(6),sp.expName,sp.subj,sp.runNo);
save(filename); % save everything to the file;
