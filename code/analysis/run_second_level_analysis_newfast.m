% =========================================================================
% AUTOMATISIERTE SECOND-LEVEL ANALYSE (NEWFAST) MIT LOG-FILE
% Liest aus: 'spm_first_level_newfast'
% Schreibt in: 'spm_second_level_newfast'
% =========================================================================

clear; clc;

% --- PFAD-DEFINITIONEN ---
base_dir         = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana/';
first_level_dir  = fullfile(base_dir, 'derivatives', 'spm_first_level_newfast');
second_level_dir = fullfile(base_dir, 'derivatives', 'spm_second_level_newfast');

% Ordner erstellen, falls noch nicht vorhanden
if ~exist(second_level_dir, 'dir')
    mkdir(second_level_dir);
end

% --- LOG-FILE STARTEN ---
% Neues Log-File wird direkt im newfast Second-Level-Ordner abgelegt
log_file = fullfile(second_level_dir, 'second_level_analysis_newfast.log');
diary(log_file); 

fprintf('=========================================================================\n');
fprintf('START DER GRUPPENANALYSE NEWFAST (SECOND-LEVEL): %s\n', datestr(now));
fprintf('Input:  %s\n', first_level_dir);
fprintf('Output: %s\n', second_level_dir);
fprintf('=========================================================================\n');

% SPM-Defaults initialisieren
if ~isempty(which('spm'))
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
end

% Probanden-Liste (Alle 12 Probanden inklusive sub-06)
subjects = {'01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'};

% Definition aller 4 Kontraste (Name & Kontrastnummer im First-Level)
contrast_folders = {
    'contrast_01_music_vs_scrambled', 1; ...
    'contrast_02_music_vs_noise',     2; ...
    'contrast_03_scrambled_vs_noise', 3; ...
    'contrast_04_music_vs_all',       4  ...
};

% --- SCHLEIFE ÜBER ALLE KONTRASTE ---
for c = 1:size(contrast_folders, 1)
    con_folder_name = contrast_folders{c, 1};
    con_number      = contrast_folders{c, 2};
    
    fprintf('\n===================================================\n');
    fprintf('Starte Second-Level (NEWFAST) für Kontrast %d: %s\n', con_number, con_folder_name);
    fprintf('===================================================\n');
    
    % Zielordner für diesen spezifischen Gruppen-T-Test
    out_dir = fullfile(second_level_dir, con_folder_name);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    % Batch initialisieren
    matlabbatch = {};
    
    % ---------------------------------------------------------------------
    % 1. SPEZIFIKATION DES ONE-SAMPLE T-TESTS
    % ---------------------------------------------------------------------
    matlabbatch{1}.spm.stats.factorial_design.dir = {out_dir};
    
    % Sammle die con-Bilder aller Probanden aus 'spm_first_level_newfast'
    con_files = cell(length(subjects), 1);
    for s = 1:length(subjects)
        con_file_path = fullfile(first_level_dir, sprintf('sub-%s', subjects{s}), sprintf('con_%04d.nii', con_number));
        
        % Vorab-Prüfung, ob die Datei wirklich existiert
        if ~exist(con_file_path, 'file')
            error('CRITICAL ERROR: Kontrastdatei fehlt: %s\nAbbruch.', con_file_path);
        end
        
        con_files{s} = [con_file_path, ',1'];
    end
    
    matlabbatch{1}.spm.stats.factorial_design.des.t1.scans = con_files;
    
    % Standard-Einstellungen für One-Sample T-Test in SPM12
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 1; 
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1; 
    matlabbatch{1}.spm.stats.factorial_design.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.glonorm.g_omit = 1;
    
    % ---------------------------------------------------------------------
    % 2. MODELL-SCHÄTZUNG (ESTIMATION)
    % ---------------------------------------------------------------------
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', ...
        substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    % ---------------------------------------------------------------------
    % 3. GRUPPENKONTRAST DEFINIEREN
    % ---------------------------------------------------------------------
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', ...
        substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = sprintf('Gruppeneffekt: %s', con_folder_name);
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = 1; 
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    matlabbatch{3}.spm.stats.con.deletecons = 1;
    
    % ---------------------------------------------------------------------
    % BATCH AUSFÜHREN
    % ---------------------------------------------------------------------
    try
        spm_jobman('run', matlabbatch);
        fprintf('SUCCESS: Second-Level NEWFAST für %s erfolgreich berechnet.\n', con_folder_name);
    catch ME
        warning('FEHLER bei %s: %s', con_folder_name, ME.message);
    end
end

fprintf('\n=========================================================================\n');
fprintf('ALLE SECOND-LEVEL NEWFAST ANALYSEN BEENDET: %s\n', datestr(now));
fprintf('=========================================================================\n');

% --- LOG-FILE SCHLIEßEN ---
diary off;