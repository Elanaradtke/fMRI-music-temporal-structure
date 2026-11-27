% =========================================================================
% Diagnostik & Paired-Line Plot für Contrast 1 (Original vs. Scrambled)
% =========================================================================

clear; clc;

% 1. Pfade und Probanden-Liste
base_dir = '/hpc/workspace/2026-0458-MUSLOC/data/proc_elana/derivatives/spm_first_level_newfast';
subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
            'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12'};

% Peak für Contrast 1 
peak_mni = [44, 0, 50]; 

% Array für Ergebnisse (12 Probanden x 2 Bedingungen)
% Spalte 1: Original, Spalte 2: Scrambled
beta_data = zeros(length(subjects), 2);

for i = 1:length(subjects)
    sub_folder = fullfile(base_dir, subjects{i});
    spm_path   = fullfile(sub_folder, 'SPM.mat');
    
    if ~exist(spm_path, 'file')
        error('Datei nicht gefunden: %s', spm_path);
    end
    
    SPM_struct = load(spm_path);
    V = SPM_struct.SPM.Vbeta(1);
    voxel_coord = inv(V.mat) * [peak_mni 1]';
    voxel_coord = round(voxel_coord(1:3))';
    
    % Beta-Dateien für Original (beta_0001) und Scrambled (beta_0002)
    beta_files = {
        fullfile(sub_folder, 'beta_0001.nii'); ...
        fullfile(sub_folder, 'beta_0002.nii')      ...
    };
    
    for cond = 1:2
        V_beta = spm_vol(beta_files{cond});
        beta_data(i, cond) = spm_sample_vol(V_beta, voxel_coord(1), voxel_coord(2), voxel_coord(3), 0);
    end
end

% =========================================================================
% Visualisierung 
% =========================================================================

figure('Position', [100, 100, 750, 580], 'Color', 'w'); 

% Achsen-Position: Left von 0.18 auf 0.22 erhöht, Width auf 0.54 verkleinert (macht ihn schmaler & zentrierter)
ax = axes('Position', [0.22, 0.18, 0.54, 0.62]);
hold on; 

grid on;
ax.GridAlpha = 0.15;
ax.LineWidth = 0.8;
ax.FontSize = 10;

colors = lines(12);

% Daten für die Text-Entzerrung vorbereiten (Sortierung nach Y-Wert am rechten Rand)
end_y_values = beta_data(:, 2);
[sorted_y, sort_idx] = sort(end_y_values);

% Minimaler Abstand zwischen Textlabels, damit sie sich nicht überlappen
y_range = max(end_y_values) - min(end_y_values);
min_dist = y_range * 0.08; 

text_y_offsets = zeros(12, 1);
for k = 2:12
    prev_y = sorted_y(k-1) + text_y_offsets(sort_idx(k-1));
    curr_y = sorted_y(k);
    if (curr_y - prev_y) < min_dist
        text_y_offsets(sort_idx(k)) = (prev_y + min_dist) - curr_y;
    end
end

% 1. Einzellinien plotten
for idx = 1:12
    i = sort_idx(idx); 
    x_data = [1, 2];
    y_data = beta_data(i, :);
    
    % Linie plotten
    plot(x_data, y_data, 'o-', ...
         'Color', [colors(i, :), 0.45], ...
         'LineWidth', 1.0, ...
         'MarkerSize', 5, ...
         'MarkerFaceColor', colors(i, :));
    
    % Korrigierte Y-Position für den Text berechnen
    final_text_y = y_data(2) + text_y_offsets(i);
    
    % Beschriftung am rechten Rand (FontWeight auf 'normal' gesetzt)
    text(2.06, final_text_y, sprintf('sub-%02d', i), ...
         'Color', colors(i, :) * 0.8, ... 
         'FontSize', 8.5, ...
         'FontWeight', 'normal', ...
         'Clipping', 'off');
end

% 2. Mittelwert-Linie über die 2 Bedingungen
mean_data = mean(beta_data, 1);
plot([1, 2], mean_data, '-o', ...
     'Color', [0.1 0.1 0.1], ...     
     'LineWidth', 2.8, ...           
     'MarkerSize', 8, ...
     'MarkerFaceColor', [0.1 0.1 0.1]);

% Layout-Feinabstimmung (X-Limits enger gezogen, damit kein leerer Raum links entsteht)
xlim([0.85, 2.15]);
xticks([1, 2]);
xticklabels({'Original', 'Scrambled'});

ylabel('Beta-Weight (Signal Intensity)', 'FontSize', 11);

% Titel in gewohnter, eleganter Höhe
annotation('textbox', [0.15, 0.84, 0.70, 0.08], ...
    'String', sprintf('Parameter-Estimates: Original > Scrambled (Peak MNI: [%d, %d, %d])', peak_mni), ...
    'FontSize', 11, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'LineStyle', 'none');

hold off;

% --- EXPORT FIGURE ---

print(gcf, 'neu_scatterplot_44_0_50.pdf', '-dpdf', '-painters');

print(gcf, 'neu_scatterboxplot_44_0_50.png', '-dpng', '-r600');