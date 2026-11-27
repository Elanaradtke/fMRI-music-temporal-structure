% =========================================================================
% AUTOMATISIERTES FIRST-LEVEL GLM, EXPLICIT MASKING & INVERSE KONTRASTE
% =========================================================================

clear; clc;

% --- NEU: SEPARATES LOG-FILE STARTEN ---
diary('first_level_analysis_new.log'); 

if ~isempty(which('spm')), spm('defaults', 'FMRI'); end

% --- PFAD-DEFINITIONEN ---
base_dir         = '/mnt/beegfs/workspace/2026-0458-MUSLOC/data/proc_elana/';
prep_data_dir    = fullfile(base_dir, 'preprocessed_data');
onset_data_dir   = fullfile(base_dir, 'derivatives', 'spm_onsets');
analysis_out_dir = fullfile(base_dir, 'derivatives', 'spm_first_level_newfast');

% Parameter
TR = 1.1152; % Repetitionszeit aus den Logfiles

% Probanden-Liste (sub-01 bis sub-12)
subjects = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};

% --- SCHLEIFE ÜBER ALLE PROBANDEN ---
for s = 1:length(subjects)
    subj_id = subjects{s};
    fprintf('\n===================================================\n');
    fprintf('Starte erweitertes First-Level für: sub-%s\n', subj_id);
    fprintf('===================================================\n');
    
    % Spezifischer Ausgabeordner für die neuen SPM-Ergebnisse
    subj_analysis_dir = fullfile(analysis_out_dir, sprintf('sub-%s', subj_id));
    if ~exist(subj_analysis_dir, 'dir'), mkdir(subj_analysis_dir); end
    
    % Batch-Struktur initialisieren
    matlabbatch = {};
    
    % Wohin soll die SPM.mat gespeichert werden?
    matlabbatch{1}.spm.stats.fmri_spec.dir = {subj_analysis_dir};
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;
    
    % --- ERKENNUNG VERFÜGBARER RUNS ---
    subj_prep_dir = fullfile(prep_data_dir, sprintf('sub-%s', subj_id));
    
    run_idx = 0;
    for r = [6, 7]
        task_label = sprintf('musicloc%d', r-5);
        
        % Pfade prüfen
        sw_file = fullfile(subj_prep_dir, sprintf('swamebold_task-%s.nii', task_label));
        rp_file = fullfile(subj_prep_dir, sprintf('rp_mebold_task-%s.txt', task_label));
        onset_file = fullfile(onset_data_dir, sprintf('sub-%s', subj_id), sprintf('sub-%s_run-%02d_desc-musicloc_events.mat', subj_id, r));
        
        if exist(sw_file, 'file') && exist(rp_file, 'file') && exist(onset_file, 'file')
            run_idx = run_idx + 1;
            fprintf('  -> Füge Session %d hinzu (Run %02d, %s)\n', run_idx, r, task_label);
            
            % 1. Funktionale Scans auswählen
            vols = spm_select('Expand', sw_file);
            matlabbatch{1}.spm.stats.fmri_spec.sess(run_idx).scans = cellstr(vols);
            
            % 2. Multiple Conditions einladen
            matlabbatch{1}.spm.stats.fmri_spec.sess(run_idx).multi = {onset_file};
            
            % 3. Multiple Regressors einladen
            matlabbatch{1}.spm.stats.fmri_spec.sess(run_idx).multi_reg = {rp_file};
            
            % High-pass filter
            matlabbatch{1}.spm.stats.fmri_spec.sess(run_idx).hpf = 128;
        else
            fprintf('  INFO: Run %02d (%s) nicht vollständig vorhanden. Übersprungen.\n', r, task_label);
        end
    end
    
    % --- NEU: EXPLICIT MASKING KONFIGURATION ---
    % Wir setzen den standardmäßigen impliziten Schwellenwert auf 0 (oder -Inf), 
    % da wir eine echte, explizite Maske definieren.
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mthresh = -Inf; % Deaktiviert implizites Masking, damit die explizite Maske greift
    
    % Pfad zur Maske aus dem alten spm_first_level Verzeichnis dynamisch holen
    subj_mask_file = fullfile(base_dir, 'derivatives', 'spm_first_level', sprintf('sub-%s', subj_id), 'mask.nii');
    if exist(subj_mask_file, 'file')
        matlabbatch{1}.spm.stats.fmri_spec.mask = {subj_mask_file};
        fprintf('  -> Explizite Maske geladen: %s\n', 'mask.nii');
    else
        % Fallback, falls die Maske nicht existiert
        matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
        matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
        warning('  WARNUNG: Keine mask.nii gefunden! Nutze SPM-Standard-Threshold (0.8).');
    end
    
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'FAST'; % geändert!
    
    % 2. MODELL-SCHÄTZUNG (ESTIMATION)
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    % 3. KONTRAST-DEFINITIONEN (Inklusive negativer Richtungen)
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    
    % Kontrast 1: Original > Scrambled (Positiv)
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Original > Scrambled';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'repl';
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = [1 -1 0]; % [Original Scrambled Noise]
    
    % Kontrast 2: Original > Noise (Positiv)
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = 'Original > Noise';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'repl';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.convec = [1 0 -1]; % [Original Scrambled Noise]
    
    % NEU - Kontrast 3: Scrambled > Original (Negativ / Inverse)
    matlabbatch{3}.spm.stats.con.consess{3}.tcon.name = 'Scrambled > Original';
    matlabbatch{3}.spm.stats.con.consess{3}.tcon.sessrep = 'repl';
    matlabbatch{3}.spm.stats.con.consess{3}.tcon.convec = [-1 1 0]; % [Original Scrambled Noise]
    
    % NEU - Kontrast 4: Noise > Original (Negativ / Inverse)
    matlabbatch{3}.spm.stats.con.consess{4}.tcon.name = 'Noise > Original';
    matlabbatch{3}.spm.stats.con.consess{4}.tcon.sessrep = 'repl';
    matlabbatch{3}.spm.stats.con.consess{4}.tcon.convec = [-1 0 1]; % [Original Scrambled Noise]
    
    matlabbatch{3}.spm.stats.con.delete = 1; 
    
    % --- BATCH AUSFÜHREN ---
    try
        spm_jobman('run', matlabbatch);
        fprintf('SUCCESS: Erweitertes First-Level für sub-%s beendet.\n', subj_id);
    catch ME
        warning('FEHLER bei sub-%s: %s', subj_id, ME.message);
    end
end

disp('=========================================================================');
disp('ALLE ERWEITERTEN FIRST-LEVEL-ANALYSEN BERCHNET (NEUE ORDNERSTRUKTUR)!');
disp('=========================================================================');

diary off;