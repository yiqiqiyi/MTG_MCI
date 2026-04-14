%% SPM12 First-level Analysis Automation Script
% Project: MTG fMRI Study
% Description: Automates GLM specification, estimation, and contrast manager.
% Author: [Your Name/GitHub Username]
% Date: 2026-04-13

clc; clear;

%% ======================== PATH CONFIGURATION ========================
% Define root directories (Modify these to match your local setup)
rootDir     = '/mnt/user02_3/MTGfmri';
analysisDir = '/mnt/user02_3/MTGanalysis';
sourceDir   = fullfile(rootDir, 'FunImg');
outputBase  = fullfile(analysisDir, 'firstlevel');

% Get subject list from the functional imaging directory
subList = dir(sourceDir);
subList(1:2) = []; % Remove '.' and '..' folders

%% ======================== LOAD BEHAVIORAL DATA ========================
% Load onsets, model results, and reaction time data
load(fullfile(analysisDir, 'onsettime.mat'));       % variable: onsettime
load(fullfile(analysisDir, 'model_fit_results.mat')); % variable: results
load(fullfile(analysisDir, 'RTdata.mat'));          % variable: total_data

%% ======================== MAIN PROCESSING LOOP ========================
for subIdx = 1:length(subList)
    subName = subList(subIdx).name;
    fprintf('--- Processing Subject: %s (%d/%d) ---\n', subName, subIdx, length(subList));
    
    % Create output directory for the current subject
    subjectOutputDir = fullfile(outputBase, subName);
    if ~exist(subjectOutputDir, 'dir'), mkdir(subjectOutputDir); end

    % --- Step 1: Model Specification (Batch Init) ---
    matlabbatch{1}.spm.stats.fmri_spec.dir = {subjectOutputDir};
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = 1.5;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 72;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 3;

    % Locate subject data in behavioral structure
    targetSubID = find(strcmp({onsettime.ID}, subName) == 1);
    if isempty(targetSubID)
        warning('Data for subject %s not found in onsettime.mat. Skipping...', subName);
        continue;
    end
    
    % Extract behavioral variables
    allOnsets   = onsettime(targetSubID).reoly;
    conditions  = onsettime(targetSubID).partner;
    predictionErrors = results(targetSubID).debugInfo.predErrors;

    % Define session metadata for loop
    sessNames   = {'FunImgRWS1', 'FunImgRWS'};
    paramNames  = {'RealignParameter1', 'RealignParameter'};
    numScans    = 348;

    % --- Step 2: Loop through Sessions (Run 1 and Run 2) ---
    for sessIdx = 1:2
        % A. Handle Functional Scans
        currentScanDir = fullfile(rootDir, sessNames{sessIdx}, subName);
        scanFiles = dir(fullfile(currentScanDir, 'swr*.img')); % Use .img or .nii
        
        fileList = cell(numScans, 1);
        for f = 1:numScans
            fileList{f} = [fullfile(scanFiles(1).folder, scanFiles(1).name), ',', num2str(f)];
        end
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).scans = fileList;

        % B. Handle Conditions (Good vs Bad)
        % Map indices: Sess1 (1-30), Sess2 (31-60)
        idxOffset = (sessIdx - 1) * 30;
        currSessIdx = (1:30) + idxOffset;
        
        currOnsets = allOnsets(currSessIdx);
        currConds  = conditions(currSessIdx);
        currPEs    = predictionErrors(currSessIdx);

        % Condition 1: GOOD
        goodMask = (currConds == 1);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).name     = 'Good';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).onset    = currOnsets(goodMask);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).duration = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).pmod(1).name  = 'PE';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).pmod(1).param = currPEs(goodMask);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).pmod(1).poly  = 1;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(1).orth = 1;

        % Condition 2: BAD
        badMask = (currConds == 2);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).name     = 'Bad';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).onset    = currOnsets(badMask);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).duration = 0;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).pmod(1).name  = 'PE';
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).pmod(1).param = currPEs(badMask);
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).pmod(1).poly  = 1;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).cond(2).orth = 1;

        % C. Multiple Regressors (Realignment Parameters)
        rpDir = fullfile(rootDir, paramNames{sessIdx}, subName);
        rpFile = dir(fullfile(rpDir, 'rp_*.txt'));
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).multi_reg = {fullfile(rpFile.folder, rpFile.name)};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sessIdx).hpf = 128;
    end

    % Global Model Settings
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [1 0]; % HRF with time derivative
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
    
    % Execute Model Specification
    spm_jobman('run', matlabbatch);
    clear matlabbatch;

    % --- Step 3: Model Estimation ---
    matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(subjectOutputDir, 'SPM.mat')};
    matlabbatch{1}.spm.stats.fmri_est.method.Classical = 1;
    spm_jobman('run', matlabbatch);
    clear matlabbatch;

    % --- Step 4: Contrast Manager ---
    matlabbatch{1}.spm.stats.con.spmmat = {fullfile(subjectOutputDir, 'SPM.mat')};
    
    % Define T-contrasts (Name and Weight Vector)
    % Note: Ensure weight vector length matches your design matrix columns
    tContrasts = { ...
        'G',           [0 1 0 0 0 0 0 0 0 0 0 0];
        'B',           [0 0 0 0 0 0 0 1 0 0 0 0];
        'G_PE',        [0 0 0 1 0 0 0 0 0 0 0 0];
        'BG_PE',       [0 0 0 0 0 0 0 0 0 1 0 0];
        'G_modify',    [1 0 0 0 0 0 0 0 0 0 0 0];
        'B_modify',    [0 0 0 0 0 0 1 0 0 0 0 0] ...
    };

    for conIdx = 1:size(tContrasts, 1)
        matlabbatch{1}.spm.stats.con.consess{conIdx}.tcon.name    = tContrasts{conIdx, 1};
        matlabbatch{1}.spm.stats.con.consess{conIdx}.tcon.weights = tContrasts{conIdx, 2};
        matlabbatch{1}.spm.stats.con.consess{conIdx}.tcon.sessrep = 'repl';
    end
    
    spm_jobman('run', matlabbatch);
    clear matlabbatch;
    
    fprintf('Subject %s completed successfully.\n', subName);
end

fprintf('================ ALL SUBJECTS PROCESSED ================\n');