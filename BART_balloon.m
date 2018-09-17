% Balloon analouge risk task (BART) for intracranial recording patients
%
% History:
%   20180918 RZ add the error handlers
%   20180807 created by RZ


%%
clear all; close all; clc;


try
    sp.subj = input('Please input subject number: ');  %
    sp.runNo = input('Please input run number: ');  %
    sp.place = 'laptop';
    
    %
    sp.wantRecording = 0; % whether want recording, it will send trigger
    sp.wantFormattedString = 1; % hospital computer 0; laptop, 1
    % Trigger
    sp.trigger.pump = 1; % Every update of the Balloon
    sp.trigger.pop = 2; % 2. onset of balloon pop feedback
    sp.trigger.stop = 3; % 2. onset of the stop feedback
    sp.trigger.trialStart = 4; % onset of each trial, the start of the 1st trial is the start of the entire run
    sp.trigger.trialEnd = 5; % onset of the ITI
    sp.trigger.keyPress = 10; % 10. keyPress
    sp.trigger.runEnd = 21; % 21. onset of flip timestamp (onset of the blank at ending)
    %% debug purpose
    switch sp.place
        case 'laptop'  % run the exp on Ruyuan's laptop
            mp = getmonitorparams('uminnmacpro');
            sp.deviceNum = 1; % devicenumber to record input
        case 'psphlab' % run the exp in cmrr psychophysical lab
            mp = getmonitorparams('cmrrpsphlab');
            sp.deviceNum = GetKeyboardIndices; % devicenumber to record input
            sp.deviceNum = sp.deviceNum(1); % devicenumber to record input
        case 'hospital' % run the exp in hospital
            mp = getmonitorparams('uminnintracranialpatient');
            sp.deviceNum = GetKeyboardIndices; % devicenumber to record input
            sp.deviceNum = sp.deviceNum(1); % devicenumber to record input
    end
    sp.allowedKeys = zeros(1, 256);
    sp.allowedKeys([KbName('q') KbName('=+') KbName('Return')]) = 1;
    sp.respKeys = {'=+','Enter'}; % keys to pump, stop
    
    sp.pythonInterp = 'C:/Users/brain/Anaconda2/python'; % path of python intepreter
    %% monitor parameter (mp)
    %mp = getmonitorparams('uminn7tpsboldscreen');
    mp.monitorRect = [0 0 mp.resolution(1) mp.resolution(2)];
    balloon = imread('balloon.jpg');
    pop = imread('poppedballoon.jpg');
    sp.balloonSize = subscript(size(balloon),[1 2]);
    sp.popSize = subscript(size(pop),[1 2]);
    %% stimulus parameters (sp)
    addpath(genpath('./utils'));
    % parameters
    sp.expName = 'BART';
    sp.nTrials = 30; % number of trials in a run
    sp.nSteps = 128; % maximum number of steps subject can go
    sp.maxSize = 3 ; % max resize times, maximum can be # times than original image
    sp.minSize = 0.5; % min resize times
    sp.steps = zeros(1,sp.nTrials);
    sp.result = zeros(1,sp.nTrials); %1, pop; 2,stop
    sp.COLOR_GRAY = 127;
    sp.COLOR_BLACK = 0;
    sp.COLOR_WHITE = 254;
    sp.blank = 4;  % secs, blanck at the begining and the end of a run
    sp.ITI = 1.5; %secs
    sp.feedbackTime = 1; %secs
    
    % reset random seeds
    rng('default');
    rng(sum(100*clock)); % set the random seed
    sp.pumpSteps = linspace(sp.minSize, sp.maxSize, sp.nSteps+1);
    
    % precompute the images
    sp.balloons = {};
    sp.popBalloons = {};
    for i=1:sp.nSteps+1
        sp.balloons{i} = imresize(balloon,sp.pumpSteps(i));
        sp.popBalloons{i} = imresize(pop,sp.pumpSteps(i));
    end
    
    % position to show text
    sp.cumMoneyTxtPos = [mp.monitorRect(3)-350 , 50]; %
    sp.trialTxtPos = [50, 50];
    sp.rewardNowTxtPos = [mp.resolution(1)/2-40, mp.resolution(2)/2-20]; % need to make sure here
    sp.stopNowTxtPos = [mp.resolution(1)/2-60, mp.resolution(2)/2-20]; % need to make sure here
    
    %reward and pBurst function
    sp.rewardFunc = @(x) 0.05*x; % x is steps
    sp.pBurstFunc = @(x) 1/(sp.nSteps+1-x); % x is steps, x starts from 1
    %% MRI related preparation
    % some auxillary variables
    sp.triggerKey = '5'; % the key to start the experiment
    sp.timeKeys = {}; % record timing for key pres
    sp.timeFrames={}; % record timing for critical events
    sp.randNum = cell(1,sp.nTrials); % % record rand number in each pump and in each trial
    getOutEarly = 0;
    when = 0;
    glitchcnt = 0;
    frameCnt = 0;
    
    % get information about the PT setup
    oldclut = pton([],[],[],1);
    win = firstel(Screen('Windows'));
    winRect = Screen('Rect',win);
    Screen('BlendFunction',win,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    mfi = Screen('GetFlipInterval',win);  % re-use what was found upon initialization!
    assert(all(winRect == mp.monitorRect), 'Window Rect is different from retrieved monitor parameters');
    
    %% wait for a key press to start, start to show stimulus
    Screen('TextSize',win,30);Screen('TextFont',win,'Arial');
    welcomeText = '<color=0.,0.,0.>Balloon Analogue Risk Task\nPress "5" to start experiment. \n Press "+" to increase reward. \n Press "Enter" to stop and accept the offer';
    Screen('FillRect',win,sp.COLOR_WHITE,winRect);
    if sp.wantFormattedString
        DrawFormattedText2(welcomeText,'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
    else
        
    end
    Screen('Flip',win);
    fprintf('press a key to begin the movie. (make sure to turn off network, energy saver, spotlight, software updates! mirror mode on!)\n');
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
    %kbQueuecheck setup
    tic;
    KbQueueCreate(sp.deviceNum,sp.allowedKeys);
    KbQueueStart(sp.deviceNum);
    %% now run the real trials
    sp.cumMoney = 0;
    for iTrial = 1:sp.nTrials
        
        %% do it
        steps=1;
        stop=0;
        while 1
            % makeTexture
            imgtmp = sp.balloons{steps};
            popimgtmp = sp.popBalloons{steps};
            srcRect = [0 0 size(imgtmp,2) size(imgtmp,1)];
            destRect = CenterRect(srcRect,winRect);
            tex = Screen('MakeTexture',win, imgtmp);
            popTex = Screen('MakeTexture',win, popimgtmp);
            rewardNow = sp.rewardFunc(steps-1);
            
            % draw the balloon
            Screen('DrawText', win, sprintf('Balloon #: %d', iTrial), sp.trialTxtPos(1), sp.trialTxtPos(2), 0);
            Screen('DrawText', win, sprintf('Total won: $%2.2f', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 0);
            Screen('DrawTexture', win, tex, srcRect,destRect);
            if sp.wantFormattedString
                DrawFormattedText2(sprintf('<color=1.,1.,1.>$%2.2f',rewardNow),'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
            else
                Screen('DrawText', win, sprintf('$%2.2f', rewardNow), sp.rewardNowTxtPos(1), sp.rewardNowTxtPos(2), 0);
            end
            [VBLTimestamp,~,~,~,~] = Screen('Flip',win); % should sent the trigger here!
            if steps ==1
                if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp,sp.trigger.trialStart));end % sent trigger
                sp.timeFrames = {sp.timeFrames {VBLTimestamp,'trialStart'}};
            else
                if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp,sp.trigger.pump));end % sent trigger
                sp.timeFrames = {sp.timeFrames {VBLTimestamp,'pumpBalloon'}};
            end
            
            % detect button responses
            KbQueueFlush(sp.deviceNum);
            kn='';
            while 1
                [keyIsDown,secs] = KbQueueCheck(sp.deviceNum);  % all devices, only check 'q','esc','1'-'5', left/right/up/down
                if keyIsDown
                    if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp,sp.trigger.keyPress));end % sent trigger
                    sp.timeFrames = {sp.timeFrames {secs(find(secs)),'keyPress'}};
                    %get the name of the key and record it
                    kn = KbName(secs);
                    if iscell(kn); kn = kn{end};end % avoid multiple button
                    sp.timeKeys = [sp.timeKeys; {secs(find(secs)) kn}];
                    %check if ESCAPE was pressed
                    if isequal(kn,'ESCAPE') || isequal(kn,'q')
                        fprintf('Escape key detected.  Exiting prematurely.\n');
                        break;
                    end
                    break;
                end
            end
            if getOutEarly
                sca;
                return;
            end
            %% judge whether burst
            sp.randNum{iTrial} = [sp.randNum{iTrial} rand];
            sp.pBurstFunc(steps)
            burst = sp.randNum{iTrial}(end) < sp.pBurstFunc(steps);
            if burst % burst
                rewardNow = 0;
                Screen('DrawText', win, sprintf('Balloon #: %d', iTrial), sp.trialTxtPos(1), sp.trialTxtPos(2), 0);
                Screen('DrawText', win, sprintf('Total winnings: $%2.2f', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 0);
                %DrawFormattedText2('Burst, fail, $0','win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                Screen('DrawTexture', win, popTex, srcRect,destRect);
                %Screen('DrawText', win, sprintf('$%2.2f', 0), sp.rewardNowTxtPos(1), sp.rewardNowTxtPos(2), 0);
                [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win);
                if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp,sp.trigger.pop));end % sent trigger
                sp.timeFrames = {sp.timeFrames {secs(find(secs)),'pop'}};
                WaitSecs(sp.feedbackTime);
            else % no burst, continue
                if strcmp(kn,'Return') % stop
                    Screen('DrawText', win, sprintf('Balloon #: %d', iTrial), sp.trialTxtPos(1), sp.trialTxtPos(2), 0);
                    Screen('DrawText', win, sprintf('Total winnings: $%2.2f', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 0);
                    if sp.wantFormattedString
                        DrawFormattedText2(sprintf('Stop, win: $%2.2f', rewardNow),'win',win,'sx','center','sy','center','xalign','center','yalign','center','xlayout','center');
                    else
                        Screen('DrawText', win, sprintf('Stop, win: $%2.2f', rewardNow), sp.stopNowTxtPos(1), sp.stopNowTxtPos(2), 0);
                    end
                    [VBLTimestamp,~,~,~,~] = Screen('Flip',win);
                    if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp, sp.trigger.stop));end % sent trigger
                    sp.timeFrames = {sp.timeFrames {VBLTimestamp,'stop'}};
                    WaitSecs(sp.feedbackTime);
                    stop=1;
                elseif strcmp(kn,sp.respKeys{1}) % increase the stop
                    steps = steps+1;
                end
            end
            
            if burst || stop
                break;
            end
            % close the texture
            Screen('Close', tex);
            Screen('Close', popTex);
        end
        
        % record result
        sp.stepsRecord(iTrial)=steps;
        if stop
            sp.result(iTrial)=2; %stop by the user
        end
        if burst
            sp.result(iTrial)=1; %burst
        end
        sp.cumMoney = sp.cumMoney + rewardNow;
        %% inter-trial interval
        Screen('DrawText', win, sprintf('Balloon #: %d', iTrial), sp.trialTxtPos(1), sp.trialTxtPos(2), 0);
        Screen('DrawText', win, sprintf('Total winnings: $%2.1f', sp.cumMoney),sp.cumMoneyTxtPos(1), sp.cumMoneyTxtPos(2), 0);
        [VBLTimestamp,~,~,Missed,~] = Screen('Flip',win);
        if sp.wantRecording, system(sprintf('%s output_rz.py %d',sp.pythonInterp,sp.trigger.trialEnding));end % sent trigger
        
    end
    %%
    toc
    ptoff(oldclut);
    KbQueueRelease(sp.deviceNum);
    %% clean up and save data
    rmpath(genpath('./utils'));  % remove the utils path
    c = fix(clock);
    filename=sprintf('%d%02d%02d%02d%02d%02d_exp%s_subj%02d_run%02d',c(1),c(2),c(3),c(4),c(5),c(6),sp.expName,sp.subj,sp.runNo);
    save(filename); % save everything to the file;
    
    
catch BARTerror  % deal with errors
    sca;
    rmpath(genpath('./utils'));  % remove the utils path
    c = fix(clock);
    filename=sprintf('%d%02d%02d%02d%02d%02d_exp%s_subj%02d_run%02d_error',c(1),c(2),c(3),c(4),c(5),c(6),sp.expName,sp.subj,sp.runNo);
    save filename; % for debug purpose
    rethrow(BARTerror);
end