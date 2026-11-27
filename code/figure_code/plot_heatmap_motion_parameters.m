%% ========================================================================
%% CHECK TASK-CORRELATED MOTION & HEAD MOTION PARAMETERS
%% ========================================================================

clearvars; clc;

% --- PATHS & CONFIGURATION ---
base_dir = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana/derivatives';
first_level_dir = fullfile(base_dir, 'spm_first_level_newfast');

n_subs = 12;
motion_names = {'Tx', 'Ty', 'Tz', 'Rx', 'Ry', 'Rz'};

max_motion = zeros(n_subs, 6);
task_corr  = cell(n_subs, 1);
task_names = {'Original', 'Scrambled', 'Noise'};

fprintf('Analysiere Kopfbewegungen für %d Subjekte...\n', n_subs);

for i = 1:n_subs
    sub_id  = sprintf('sub-%02d', i);
    sub_dir = fullfile(first_level_dir, sub_id);
    
    spm_path = fullfile(sub_dir, 'SPM.mat');
    if ~exist(spm_path, 'file')
        error('SPM.mat nicht gefunden für %s: %s', sub_id, spm_path);
    end
    load(spm_path);
    
    % 1. Motion-Parameter extrahieren
    rp_data = [];
    
    if isfield(SPM, 'Sess') && ~isempty(SPM.Sess(1).C.C)
        rp_data = SPM.Sess(1).C.C(:, 1:6);
    else
        rp_path = '';
        if isfield(SPM.Sess(1), 'mreg') && ~isempty(SPM.Sess(1).mreg)
            rp_path = SPM.Sess(1).mreg{1};
        end
        
        if isempty(rp_path) || ~exist(rp_path, 'file')
            alt_rp = dir(fullfile(base_dir, '**', sprintf('rp_%s*.txt', sub_id)));
            if ~isempty(alt_rp)
                rp_path = fullfile(alt_rp(1).folder, alt_rp(1).name);
            end
        end
        
        if ~isempty(rp_path) && exist(rp_path, 'file')
            rp_data = load(rp_path);
            rp_data = rp_data(:, 1:6);
        end
    end
    
    if isempty(rp_data)
        warning('Keine Motion-Daten für %s gefunden.', sub_id);
        continue;
    end
    
    % Maximale absolute Bewegung bestimmen
    max_motion(i, :) = max(abs(rp_data - mean(rp_data)), [], 1);
    
    % 2. Task-Regressoren identifizieren
    X = SPM.xX.X;
    
    if isfield(SPM, 'Sess') && ~isempty(SPM.Sess(1).U)
        n_conds = length(SPM.Sess(1).U);
        if isempty(task_names)
            for c = 1:n_conds
                task_names{c} = SPM.Sess(1).U(c).name{1};
            end
        end
        task_cols = SPM.Sess(1).col(1:n_conds);
    else
        reg_names = SPM.xX.name;
        task_cols = find(contains(reg_names, 'bf(1)'));
        if isempty(task_cols), task_cols = 1:3; end
        if isempty(task_names)
            for c = 1:length(task_cols)
                task_names{c} = sprintf('Condition_%d', c);
            end
        end
    end
    
    % 3. Sichere Längenanpassung & Korrelation berechnen
    n_scans = min(size(X, 1), size(rp_data, 1)); % Gemeinsames Minimum
    n_tasks = length(task_cols);
    corr_matrix = zeros(n_tasks, 6);
    
    for t = 1:n_tasks
        task_vec   = X(1:n_scans, task_cols(t));
        
        for m = 1:6
            motion_vec = rp_data(1:n_scans, m);
            
            % Abfangen konstanter Vektoren vor Korrelation
            if std(task_vec) > 0 && std(motion_vec) > 0
                r = corrcoef(task_vec, motion_vec);
                corr_matrix(t, m) = r(1, 2);
            else
                corr_matrix(t, m) = 0;
            end
        end
    end
    task_corr{i} = corr_matrix;
end

valid_subs = find(~cellfun(@isempty, task_corr));
if isempty(valid_subs)
    error('Keine gültigen Motion-Daten extrahiert.');
end

n_tasks = length(task_names);

% --- PLOTTING: TASK-MOTION CORRELATION HEATMAP ---
figure('Color', [1 1 1], 'Position', [100 100 750 550]);

mean_corr = zeros(n_tasks, 6);
for t = 1:n_tasks
    for m = 1:6
        vals = [];
        for s = valid_subs'
            if t <= size(task_corr{s}, 1)
                vals(end+1) = task_corr{s}(t, m);
            end
        end
        mean_corr(t, m) = mean(vals);
    end
end

% Feintuning der Position: [Left, Bottom, Width, Height]
ax = axes('Position', [0.22, 0.16, 0.56, 0.62]);

imagesc(mean_corr, [-0.5, 0.5]);
colormap(coolwarm_map()); 

% Colorbar erstellen und Label direkt zuweisen
cb = colorbar;
cb.Label.String = 'Correlation Coefficient (r)';
cb.Label.FontSize = 9.5;

set(ax, 'XTick', 1:6, 'XTickLabel', motion_names, ...
        'YTick', 1:n_tasks, 'YTickLabel', task_names, ...
        'FontSize', 10, 'TickDir', 'out', 'Box', 'off');

xlabel('Motion Parameter', 'FontWeight', 'normal');
ylabel('Condition', 'FontWeight', 'normal');

% Titel über Annotation
annotation('textbox', [0.15, 0.84, 0.70, 0.08], ...
    'String', sprintf('Task-Correlated Head Motion (r) across 3 Conditions (N=%d)', length(valid_subs)), ...
    'FontSize', 11, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'LineStyle', 'none');

for t = 1:n_tasks
    for m = 1:6
        text(m, t, sprintf('%.2f', mean_corr(t, m)), ...
            'HorizontalAlignment', 'center', ...
            'Color', [0.1 0.1 0.1], 'FontSize', 9.5, 'FontWeight', 'bold');
    end
end

grid off;

% --- EXPORT FIGURE ---

% Hochwertige PDF (Vektorformat)
print(gcf, 'Task_Motion_Heatmap.pdf', '-dpdf', '-painters');

% Hochauflösendes PNG
print(gcf, 'Task_Motion_Heatmap.png', '-dpng', '-r600');

exportgraphics(gcf, 'Task_Motion_Heatmap.png', ...
    'Resolution', 600);

function cmap = coolwarm_map()
    r = [linspace(0.2, 1, 64), linspace(1, 0.8, 64)]';
    g = [linspace(0.4, 1, 64), linspace(1, 0.2, 64)]';
    b = [linspace(0.8, 1, 64), linspace(1, 0.2, 64)]';
    cmap = [r, g, b];
end