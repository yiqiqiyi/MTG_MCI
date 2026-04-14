%% SPM12 Second-Level Analysis: Group Comparisons
% Project: MTG fMRI - MCI vs HC Comparison
% Description: This script automates second-level t-contrasts for 
%              parameter-based group analysis across multiple contrasts.
% Author: [Your Name/GitHub Username]
% Date: 2026-04-13

clc; clear;

%% ======================== PATH CONFIGURATION ========================
% Define base directory for second-level analysis results
secondLevelBase = '/mnt/user02_3/MTGanalysis/secondlevelpara';
analysisDir     = '/mnt/user02_3/MTGanalysis';

%% ======================== LOAD GROUP METADATA ========================
% Load model results and behavioral mapping
load(fullfile(analysisDir, 'model_fit_results.mat')); % Contains .group info
load(fullfile(analysisDir, 'onsettime.mat'));         % Contains .ID info

% Identify indices for Mild Cognitive Impairment (MCI) and Healthy Controls (HC)
MCIidx = find(strcmp({results.group}, 'MCI') == 1);
HCidx  = find(strcmp({results.group}, 'HC')  == 1);

% Extract IDs for verification if needed
MCIsubject = {onsettime(MCIidx).ID};
HCsubject  = {onsettime(HCidx).ID};

% Load behavioral parameters (e.g., learning rates, influence factors)
paradata = xlsread("parameter.xlsx");
learnb   = paradata([MCIidx, HCidx], 2);
inffa    = paradata([MCIidx, HCidx], 6);

%% ======================== CONTRAST PROCESSING LOOP ========================
% Iterate through 16 first-level contrasts
for conNum = 1:16
    fprintf('>>> Updating Contrasts for conT%02d...\n', conNum);
    
    % Define the directory containing the SPM.mat for this group analysis
    pathdir = fullfile(secondLevelBase, sprintf('conT%d', conNum));
    spmMatPath = fullfile(pathdir, 'SPM.mat');
    
    % Check if SPM.mat exists before proceeding
    if ~exist(spmMatPath, 'file')
        warning('SPM.mat not found in %s. Skipping...', pathdir);
        continue;
    end

    % Clear batch for each iteration
    clear matlabbatch;

    % --- Batch Setup: Contrast Manager ---
    matlabbatch{1}.spm.stats.con.spmmat = {spmMatPath};
    
    % Contrast 1: MCI > HC (Learning Parameter Effect)
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.name    = 'MCI > HC learn';
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.weights = [0 0 1 -1];
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    
    % Contrast 2: HC > MCI (Learning Parameter Effect)
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.name    = 'HC > MCI learn';
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.weights = [0 0 -1 1];
    matlabbatch{1}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    
    % Contrast 3: MCI > HC (Influence Factor Interaction)
    matlabbatch{1}.spm.stats.con.consess{3}.tcon.name    = 'MCI > HC inter';
    matlabbatch{1}.spm.stats.con.consess{3}.tcon.weights = [0 0 0 0 1 -1];
    matlabbatch{1}.spm.stats.con.consess{3}.tcon.sessrep = 'none';
    
    % Contrast 4: HC > MCI (Influence Factor Interaction)
    matlabbatch{1}.spm.stats.con.consess{4}.tcon.name    = 'HC > MCI inter';
    matlabbatch{1}.spm.stats.con.consess{4}.tcon.weights = [0 0 0 0 -1 1];
    matlabbatch{1}.spm.stats.con.consess{4}.tcon.sessrep = 'none';

    % General settings
    matlabbatch{1}.spm.stats.con.delete = 0; % Do not delete existing contrasts

    % --- Run Contrast Manager ---
    spm('defaults', 'FMRI');
    spm_jobman('run', matlabbatch);
end

fprintf('================ SECOND LEVEL CONTRASTS DONE ================\n');