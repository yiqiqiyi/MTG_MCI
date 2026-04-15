%% SPM12 Second-Level PPI Analysis: Two-Sample T-Test
% Project: MTG fMRI - MCI vs HC PPI Comparison
% Description: This script performs group-level analysis on PPI contrasts 
%              extracted from the first-level analysis.
% Author: [Your Name/GitHub Username]
% Date: 2026-04-14

clc; clear;

%% ======================== PATH CONFIGURATION ========================
% Define root directories
analysisDir     = '/mnt/user02_3/MTGanalysis';
firstLevelBase  = fullfile(analysisDir, 'firstlevel');
secondLevelPPI  = fullfile(analysisDir, 'secondlevel_ppi');

% Load group metadata and behavioral mapping
load(fullfile(analysisDir, 'model_fit_results.mat')); % Contains .group info
load(fullfile(analysisDir, 'onsettime.mat'));         % Contains .ID info

%% ======================== GROUP IDENTIFICATION =======================
% Find indices for Mild Cognitive Impairment (MCI) and Healthy Controls (HC)
MCIidx = find(strcmp({results.group}, 'MCI') == 1);
HCidx  = find(strcmp({results.group}, 'HC')  == 1);

% Extract Subject IDs
MCIsubject = {onsettime(MCIidx).ID};
HCsubject  = {onsettime(HCidx).ID};

%% ======================== SECOND-LEVEL BATCH ========================
% Iterate through the desired contrasts (e.g., contrast 1)
for conNum = 1
    % Format the contrast filename (e.g., spmT_0001.nii)
    contrastFile = sprintf('spmT_%04d.nii,1', conNum);
    
    % Define and create output directory for this group-level contrast
    targetDir = fullfile(secondLevelPPI, sprintf('conT%d', conNum));
    if ~exist(targetDir, 'dir'), mkdir(targetDir); end

    clear matlabbatch;

    % --- 1. Factorial Design Specification ---
    matlabbatch{1}.spm.stats.factorial_design.dir = {targetDir};
    
    % Group 1: MCI Scans
    mciScans = cell(length(MCIsubject), 1);
    for m = 1:length(MCIsubject)
        mciScans{m} = fullfile(firstLevelBase, MCIsubject{m}, 'PPI_PE', contrastFile);
    end
    
    % Group 2: HC Scans
    hcScans = cell(length(HCsubject), 1);
    for h = 1:length(HCsubject)
        hcScans{h} = fullfile(firstLevelBase, HCsubject{h}, 'PPI_PE', contrastFile);
    end

    % Two-sample T-test configuration
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = mciScans;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = hcScans;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept     = 0; % Independent
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1; % Unequal variance
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca    = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova   = 0;
    
    % Masking and Global Normalization
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    % --- 2. Model Estimation ---
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', ...
        substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    % --- 3. Contrast Manager ---
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', ...
        substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    
    % Contrast 1: MCI > HC
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name    = 'MCI > HC';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    
    % Contrast 2: HC > MCI
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name    = 'HC > MCI';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.weights = [-1 1];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    
    matlabbatch{3}.spm.stats.con.delete = 0;

    % --- Run Batch ---
    spm('defaults', 'FMRI');
    spm_jobman('run', matlabbatch);
    
    fprintf('>>> Second-level PPI for conT%d finished.\n', conNum);
end