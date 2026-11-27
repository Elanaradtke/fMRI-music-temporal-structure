%% ========================================================================
%% FIRST-LEVEL CHECK: EINZELPROBANDEN-DATEN & OUTLIER-INSPEKTION
%% ========================================================================

clearvars; clc;

% --- CONFIGURATION & PATHS ---
second_level_dir = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana/derivatives/spm_second_level_newfast/contrast_02_music_vs_noise'; 
target_voxel_mm  = [-50, 2, -6]; 
contrast_label   = 'Original > Noise';

% --- 1. LOAD DATA & EXTRACT CONTRAST VALUES ---
spm_mat_path = fullfile(second_level_dir, 'SPM.mat');

if ~exist(spm_mat_path, 'file')
    error('SPM.mat nicht gefunden unter: %s', spm_mat_path);
end

fprintf('Lade SPM.mat aus: %s\n', second_level_dir);
fprintf('Extrahiere Voxel-Werte für MNI [%d, %d, %d]...\n', target_voxel_mm);
load(spm_mat_path);

% MNI-Koordinate in Voxel-Koordinaten umrechnen
V_first     = SPM.xY.VY(1);
voxel_coord = inv(V_first.mat) * [target_voxel_mm, 1]';
voxel_coord = round(voxel_coord(1:3))';

n_sub          = length(SPM.xY.VY);
con_values     = zeros(n_sub, 1);
subject_labels = cell(n_sub, 1);

for i = 1:n_sub
    con_path = SPM.xY.VY(i).fname;
    
    if ~exist(con_path, 'file')
        error('First-Level Datei nicht gefunden: %s', con_path);
    end
    
    % Voxelwert extrahieren
    V_con           = spm_vol(con_path);
    con_values(i) = spm_sample_vol(V_con, voxel_coord(1), voxel_coord(2), voxel_coord(3), 0);
    
    % Subjekt-ID aus dem Pfad auslesen
    [~, sub_name] = fileparts(fileparts(con_path));
    if startsWith(sub_name, 'sub-')
        subject_labels{i} = sub_name;
    else
        subject_labels{i} = sprintf('sub-%02d', i);
    end
end

% --- 2. STATISTIK: OUTLIER-ERKENNUNG (1.5 * IQR) ---
Q1          = quantile(con_values, 0.25);
Q3          = quantile(con_values, 0.75);
IQR_val     = Q3 - Q1;
outlier_idx = (con_values < (Q1 - 1.5 * IQR_val)) | (con_values > (Q3 + 1.5 * IQR_val));

% --- 3. PLOTTING (LÄNGLICHES FORMAT) ---
figure('Position', [150, 150, 580, 680], 'Color', 'w'); 

% Längliches Achsen-Format
ax = axes('Position', [0.22, 0.15, 0.56, 0.73]);
hold on;

colors = lines(n_sub);

% Boxplot
h_box   = boxplot(con_values, 'Widths', 0.25, 'Symbol', '');
h_boxes = findobj(gca, 'Tag', 'Box');
h_whisk = findobj(gca, 'Tag', 'Whisker');
h_caps  = findobj(gca, 'Tag', 'Cap');
h_med   = findobj(gca, 'Tag', 'Median');

set(h_boxes, 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
set(h_whisk, 'Color', [0.6 0.6 0.6], 'LineStyle', '--', 'LineWidth', 0.8);
set(h_caps,  'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);
set(h_med,   'Color', [0.1 0.1 0.1], 'LineWidth', 1.2);

% Jitter-Berechnung
rng(42); 
jitter = (rand(n_sub, 1) - 0.5) * 0.18;

% Datenpunkte & Labels direkt am Punkt plotten
for i = 1:n_sub
    x_pos  = 1 + jitter(i);
    y_pos  = con_values(i);
    
    if outlier_idx(i)
        plot(x_pos, y_pos, 'o', ...
            'MarkerSize', 5.5, ...
            'MarkerFaceColor', colors(i, :), ...
            'MarkerEdgeColor', [0.85 0.2 0.2], ...
            'LineWidth', 1.2);
            
        text(x_pos + 0.04, y_pos, sprintf('%s*', subject_labels{i}), ...
            'Color', [0.8 0.15 0.15], ...
            'FontSize', 8.5, ...
            'FontWeight', 'normal', ...
            'Interpreter', 'none', ...
            'Clipping', 'off');
    else
        plot(x_pos, y_pos, 'o', ...
            'MarkerSize', 5, ...
            'MarkerFaceColor', colors(i, :), ...
            'MarkerEdgeColor', 'none');
            
        text(x_pos + 0.04, y_pos, subject_labels{i}, ...
            'Color', colors(i, :) * 0.8, ...
            'FontSize', 8.5, ...
            'FontWeight', 'normal', ...
            'Interpreter', 'none', ...
            'Clipping', 'off');
    end
end

% Layout & Achsen
xlim([0.6, 1.4]);
ylabel('Contrast Weight (a.u.)', 'FontSize', 11);

% Sauberer XTickLabel-Aufruf ohne Syntaxfehler
set(ax, 'XTick', 1, 'XTickLabel', {contrast_label}, ...
    'FontSize', 10, 'TickDir', 'out', 'Box', 'off');

% Titel in schwebender, eleganter Höhe
annotation('textbox', [0.15, 0.90, 0.70, 0.06], ...
    'String', sprintf('Individual Contrast Weights (Peak MNI: [%d, %d, %d])', target_voxel_mm), ...
    'FontSize', 11, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'LineStyle', 'none');

grid on;
ax.GridAlpha = 0.15;
ax.LineWidth = 0.8;

hold off;

% --- EXPORT FIGURE ---
print(gcf, 'neu_boxplot_-50_2_-6.pdf', '-dpdf', '-painters');
print(gcf, 'neu_boxplot_-50_2_-6.png', '-dpng', '-r600');