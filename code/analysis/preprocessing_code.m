% =========================================================================
% SPM12 Preprocessing Pipeline 
% =========================================================================

base_dir = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana';
output_base_dir = fullfile(base_dir, 'preprocessed_data');

if ~exist(output_base_dir, 'dir'), mkdir(output_base_dir); end

subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', ...
            'sub-06', 'sub-07', 'sub-08', 'sub-09', 'sub-10', ...
            'sub-11', 'sub-12'};

spm('defaults', 'FMRI');
spm_jobman('initcfg');

for i = 1:length(subjects)
    sub = subjects{i};
    sub_dir = fullfile(base_dir, sub);
    sub_out_dir = fullfile(output_base_dir, sub);
    
    fprintf('\n===================================================\n');
    fprintf('Starte Preprocessing für: %s\n', sub);
    fprintf('===================================================\n');
    
    t1_file = fullfile(sub_dir, 't1w.nii');
    if ~exist(t1_file, 'file')
        warning('Kein t1w.nii für %s gefunden! Überspringe...', sub);
        continue;
    end
    
    session_data = {};
    slice_timings = [];
    TR = [];
    
    for r = 1:2
        func_file = fullfile(sub_dir, sprintf('mebold_task-musicloc%d.nii', r));
        json_file = fullfile(sub_dir, sprintf('mebold_task-musicloc%d.json', r));
        
        if exist(func_file, 'file')
            vols = spm_select('expand', func_file);
            session_data{end+1} = cellstr(vols); %#ok<AGROW>
            fprintf('-> musicloc%d gefunden.\n', r);
            
            if isempty(slice_timings) && exist(json_file, 'file')
                try
                    json_str = fileread(json_file);
                    json_data = jsondecode(json_str);
                    slice_timings = json_data.SliceTiming;
                    TR = json_data.RepetitionTime;
                    fprintf('-> Slice-Timings erfolgreich extrahiert.\n');
                catch
                    warning('Fehler beim Lesen der JSON-Datei.');
                end
            end
        end
    end
    
    if isempty(session_data), continue; end
    num_slices = length(slice_timings);
    ref_slice = min(slice_timings);
    
    clear matlabbatch;
    
    % --- SCHRITT 1: REALIGN ---
    matlabbatch{1}.spm.spatial.realign.estwrite.data = session_data;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = 2;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

    % --- SCHRITT 2: SLICE TIMING CORRECTION ---
    for s = 1:length(session_data)
        matlabbatch{2}.spm.temporal.st.scans{s} = cfg_dep(sprintf('Realign: Estimate & Reslice: Resliced Images (Sess %d)', s), substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{s}, '.','cfiles'));
    end
    matlabbatch{2}.spm.temporal.st.nslices = num_slices;
    matlabbatch{2}.spm.temporal.st.tr = TR;
    matlabbatch{2}.spm.temporal.st.ta = 0;
    matlabbatch{2}.spm.temporal.st.so = slice_timings';
    matlabbatch{2}.spm.temporal.st.refslice = ref_slice;
    matlabbatch{2}.spm.temporal.st.prefix = 'a';

    % --- SCHRITT 3: COREGISTER ---
    matlabbatch{3}.spm.spatial.coreg.estimate.ref(1) = cfg_dep('Realign: Estimate & Reslice: Mean Image', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rmean'));
    matlabbatch{3}.spm.spatial.coreg.estimate.source = { t1_file };
    matlabbatch{3}.spm.spatial.coreg.estimate.other = {''};
    matlabbatch{3}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{3}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{3}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{3}.spm.spatial.coreg.estimate.fwhm = [7 7];

    % --- SCHRITT 4: SEGMENT ---
    spm_path = fileparts(which('spm'));
    matlabbatch{4}.spm.spatial.preproc.channel.vols(1) = cfg_dep('Coregister: Estimate: Coregistered Images', substruct('.','val', '{}',{3}, '.','val', '{}',{3}, '.','val', '{}',{3}), substruct('.','cfiles'));
    matlabbatch{4}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{4}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{4}.spm.spatial.preproc.channel.write = [0 0];
    
    for t = 1:6
        matlabbatch{4}.spm.spatial.preproc.tissue(t).tpm = {fullfile(spm_path, 'tpm', sprintf('TPM.nii,%d', t))};
        matlabbatch{4}.spm.spatial.preproc.tissue(t).ngaus = t;
        matlabbatch{4}.spm.spatial.preproc.tissue(t).native = [1 0];
        matlabbatch{4}.spm.spatial.preproc.tissue(t).warped = [0 0];
    end
    matlabbatch{4}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{4}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{4}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{4}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{4}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{4}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{4}.spm.spatial.preproc.warp.write = [0 1];

    % --- SCHRITT 5: NORMALIZE (Jetzt sauber für jede Session getrennt) ---
    matlabbatch{5}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{4}, '.','val', '{}',{4}, '.','val', '{}',{4}), substruct('.','fordef'));
    
    matlabbatch{5}.spm.spatial.normalise.write.subj.resample = cfg_dep('Slice Timing: Slice Timing Correction: Slice Timing Corr. Images', substruct('.','val', '{}',{2}, '.','val', '{}',{2}, '.','val', '{}',{2}), substruct('.','files'));
    
    matlabbatch{5}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70; 78 76 85];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.vox = [2 2 2];
    matlabbatch{5}.spm.spatial.normalise.write.woptions.interp = 4;
    matlabbatch{5}.spm.spatial.normalise.write.woptions.prefix = 'w';

    % --- SCHRITT 6: SMOOTH ---
    matlabbatch{6}.spm.spatial.smooth.data(1) = cfg_dep('Normalize: Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{5}, '.','val', '{}',{5}, '.','val', '{}',{5}), substruct('.','files'));
    matlabbatch{6}.spm.spatial.smooth.fwhm = [6 6 6];
    matlabbatch{6}.spm.spatial.smooth.dtype = 0;
    matlabbatch{6}.spm.spatial.smooth.im = 0;
    matlabbatch{6}.spm.spatial.smooth.prefix = 's';

    try
        spm_jobman('run', matlabbatch);
        fprintf('SUCCESS: Preprocessing für %s beendet.\n', sub);
        
        if ~exist(sub_out_dir, 'dir'), mkdir(sub_out_dir); end
        
        % Verschiebe alle erzeugten Dateien in den Output-Ordner
        movefile(fullfile(sub_dir, 's*.nii'), sub_out_dir);
        movefile(fullfile(sub_dir, 'w*.nii'), sub_out_dir);
        movefile(fullfile(sub_dir, 'a*.nii'), sub_out_dir);
        movefile(fullfile(sub_dir, 'r*.nii'), sub_out_dir);
        movefile(fullfile(sub_dir, 'mean*.nii'), sub_out_dir);
        movefile(fullfile(sub_dir, 'rp_*.txt'), sub_out_dir);
        movefile(fullfile(sub_dir, 'y_*.nii'), sub_out_dir);
        
    catch ME
        fprintf('ERROR: Preprocessing für %s fehlgeschlagen!\n', sub);
        fprintf('Fehlermeldung: %s\n', ME.message);
    end
end