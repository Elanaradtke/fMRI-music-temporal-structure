base_dir = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana';
output_base_dir = fullfile(base_dir, 'preprocessed_data');

subjects = {'sub-07', 'sub-08', 'sub-09', 'sub-10', ...
            'sub-11', 'sub-12'};

spm('defaults', 'FMRI');
spm_jobman('initcfg');

for i = 1:length(subjects)
    sub = subjects{i};
    sub_dir = fullfile(base_dir, sub);
    sub_out_dir = fullfile(output_base_dir, sub);
    
    fprintf('\n===================================================\n');
    fprintf('Hole Normalize & Smooth nach für: %s\n', sub);
    fprintf('===================================================\n');
    
    % Deformationsfeld suchen
    y_file = fullfile(sub_dir, 'y_t1w.nii');
    if ~exist(y_file, 'file')
        % Falls es schon im Zielordner liegt, von dort holen
        y_file = fullfile(sub_out_dir, 'y_t1w.nii');
    end
    
    if ~exist(y_file, 'file')
        warning('Kein Deformationsfeld y_t1w.nii für %s gefunden!', sub);
        continue;
    end
    
    % Schleife über die tatsächlich existierenden "a"-Dateien
    for r = 1:2
        a_file = fullfile(sub_dir, sprintf('amebold_task-musicloc%d.nii', r));
        if ~exist(a_file, 'file')
            % Falls die Datei schon im preprocessed_data Ordner liegt
            a_file = fullfile(sub_out_dir, sprintf('amebold_task-musicloc%d.nii', r));
        end
        
        if exist(a_file, 'file')
            fprintf('-> Verarbeite existierenden Run %d...\n', r);
            a_vols = cellstr(spm_select('expand', a_file));
            
            clear run_batch;
            run_batch{1}.spm.spatial.normalise.write.subj.def = {y_file};
            run_batch{1}.spm.spatial.normalise.write.subj.resample = a_vols;
            run_batch{1}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
            run_batch{1}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
            run_batch{1}.spm.spatial.normalise.write.woptions.interp = 4;
            run_batch{1}.spm.spatial.normalise.write.woptions.prefix = 'w';
            
            run_batch{2}.spm.spatial.smooth.data(1) = cfg_dep('Normalize: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files'));
            run_batch{2}.spm.spatial.smooth.fwhm = [6 6 6];
            run_batch{2}.spm.spatial.smooth.prefix = 's';
            
            try
                spm_jobman('run', run_batch);
                
                % Sofort im Anschluss die neuen w* und sw* Dateien in den Zielordner verschieben
                [path, name, ext] = fileparts(a_file);
                movefile(fullfile(path, ['w' name ext]), sub_out_dir);
                movefile(fullfile(path, ['sw' name ext]), sub_out_dir);
            catch ME
                fprintf('Fehler bei Run %d: %s\n', r, ME.message);
            end
        else
            if r == 1
                fprintf('-> Kein Run 1 für %s gefunden.\n', sub);
            end
        end
    end
    fprintf('SUCCESS: %s erfolgreich nachbereitet.\n', sub);
end
