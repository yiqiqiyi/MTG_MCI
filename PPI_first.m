%% SPM12 PPI (Physiological-Psychological Interaction) Analysis
% Project: MTG fMRI - vmPFC Connectivity
% Description: This script extracts VOI time series, computes PPI terms 
%              using spm_peb_ppi, and runs a new GLM for connectivity.
% Author: [Your Name/GitHub Username]
% Date: 2026-04-14

clc; clear;
spm('defaults', 'fmri');
spm_jobman('initcfg');

%% ======================== CONFIGURATION ========================
% Paths
base_dir   = '/mnt/user02_3/MTGanalysis/firstlevel'; % First-level GLM root
rp_base    = '/mnt/user02_3/MTGfmri';               % Base dir for realignment params
results_file = '/mnt/user02_3/MTGanalysis/model_fit_results.mat';

% PPI Parameters
cond_name  = 'PE';          % Psychological variable name
voi_name   = 'vmPFC';       % Seed region name
sphere_xyz = [10 8 69];     % Sphere coordinates
sphere_rad = 6;             % Sphere radius (mm)

% Get subject list
cd(base_dir);
filenames = dir('5*'); % Subjects starting with '5'
subjects  = {filenames.name};

%% ======================== MAIN PROCESSING LOOP ========================
for i = 1:length(subjects)
    subj = subjects{i};
    subj_dir = fullfile(base_dir, subj);
    fprintf('>>> Starting PPI Analysis: %s (%d/%d)\n', subj, i, length(subjects));

    % --- Step 1: VOI Extraction (Session 1 & 2) ---
    % We extract time series for both sessions separately
    for sess = 1:2
        matlabbatch = [];
        matlabbatch{1}.spm.util.voi.spmmat  = {fullfile(subj_dir, 'SPM.mat')};
        matlabbatch{1}.spm.util.voi.adjust  = 0; % Adjust for F-contrast if needed
        matlabbatch{1}.spm.util.voi.session = sess;
        matlabbatch{1}.spm.util.voi.name    = voi_name;
        matlabbatch{1}.spm.util.voi.roi{1}.sphere.centre = sphere_xyz;
        matlabbatch{1}.spm.util.voi.roi{1}.sphere.radius = sphere_rad;
        matlabbatch{1}.spm.util.voi.roi{1}.sphere.move.fixed = 1;
        matlabbatch{1}.spm.util.voi.expression = 'i1';
        spm_jobman('run', matlabbatch);
    end

    % --- Step 2: Construct PPI Terms ---
    % Uu matrix defines the psychological variable: [Sess, Cond, Weight]
    % Adjust [2, 2, 1] based on your specific contrast in the original GLM
    Uu = [1, 1, 0; 1, 2, 0; 2, 1, 0; 2, 2, 1]; 
    SPMname = fullfile(subj_dir, 'SPM.mat');
    
    % Session 1 PPI
    VOI1 = fullfile(subj_dir, sprintf('VOI_%s_1.mat', voi_name));
    PPI1 = spm_peb_ppi(SPMname, 'ppi', VOI1, Uu, 'ppi_PE', 0);
    
    % Session 2 PPI
    VOI2 = fullfile(subj_dir, sprintf('VOI_%s_2.mat', voi_name));
    PPI2 = spm_peb_ppi(SPMname, 'ppi', VOI2, Uu, 'ppi_PE2', 0);

    % --- Step 3: Setup PPI GLM Directory ---
    ppi_model_dir = fullfile(subj_dir, ['PPI_' cond_name]);
    if exist(ppi_model_dir, 'dir'), rmdir(ppi_model_dir, 's'); end
    mkdir(ppi_model_dir);

    % --- Step 4: Build PPI Model Batch ---
    load(SPMname);
    matlabbatch = [];
    matlabbatch{1}.spm.stats.fmri_spec.dir          = {ppi_model_dir};
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT    = 1.5;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t  = 72;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 3;
    matlabbatch{1}.spm.stats.fmri_spec.sess.scans   = cellstr(SPM.xY.P);

    % Regressor 1: PPI Interaction Term (Physiological x Psychological)
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(1).name = 'PPI-interaction';
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(1).val  = [PPI1.ppi; PPI2.ppi];
    
    % Regressor 2: Psychological Term (e.g., PE vector)
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(2).name = 'Psych-Variable';
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(2).val  = [PPI1.P; PPI2.P];
    
    % Regressor 3: Physiological Term (Seed Time Series)
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(3).name = 'Phys-Seed';
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(3).val  = [PPI1.Y; PPI2.Y];
    
    % Regressor 4: Session Block Effect
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(4).name = 'Block';
    matlabbatch{1}.spm.stats.fmri_spec.sess.regress(4).val  = [ones(348,1); zeros(348,1)];

    % --- Step 5: Movement Parameters (Nuisance Regressors) ---
    rp1 = dir(fullfile(rp_base, 'RealignParameter',  subj, 'rp_*.txt'));
    rp2 = dir(fullfile(rp_base, 'RealignParameter1', subj, 'rp_*.txt'));
    R1 = load(fullfile(rp1.folder, rp1.name));
    R2 = load(fullfile(rp2.folder, rp2.name));
    
    combined_rp = [R1; R2];
    rp_file_path = fullfile(subj_dir, 'combined_rp_ppi.txt');
    save(rp_file_path, 'combined_rp', '-ascii');
    
    matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = {rp_file_path};
    matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

    % --- Step 6: Execute Model Estimation & Contrast ---
    % 6a. Specification
    spm_jobman('run', matlabbatch);
    
    % 6b. Estimation
    clear matlabbatch;
    matlabbatch{1}.spm.stats.fmri_est.spmmat = {fullfile(ppi_model_dir, 'SPM.mat')};
    spm_jobman('run', matlabbatch);
    
    % 6c. Contrast Manager (Testing the Interaction term)
    clear matlabbatch;
    matlabbatch{1}.spm.stats.con.spmmat = {fullfile(ppi_model_dir, 'SPM.mat')};
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.name    = 'PPI_Interaction_Positive';
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.weights = [1 0 0 0]; % Weight for Regressor 1
    matlabbatch{1}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    spm_jobman('run', matlabbatch);

    fprintf('✅ Subject %s PPI Complete.\n', subj);
end