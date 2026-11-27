clear; clc;

% --- PARAMETER ---
power_target = 0.80;
alpha        = 0.001; % Unkorrigierter Cluster-Forming Threshold (one-tailed)
N_vec        = 6:0.5:120;
d_vec        = zeros(size(N_vec));

% --- EXAKTE GLATTE POWER-KURVE (80% Power) ---
for i = 1:length(N_vec)
    n  = N_vec(i);
    df = n - 1;
    t_crit = tinv(1 - alpha, df);
    d_vec(i) = fzero(@(d) (1 - nctcdf(t_crit, df, d * sqrt(n))) - power_target, [0.1, 5.0]);
end

% A-priori Benchmarks (d = 0.50 und d = 0.80)
d_apriori = [0.50, 0.80];
n_apriori = zeros(size(d_apriori));
for k = 1:length(d_apriori)
    n_apriori(k) = ceil(fzero(@(n) (1 - nctcdf(tinv(1 - alpha, n - 1), n - 1, d_apriori(k) * sqrt(n))) - power_target, [5, 300]));
end

% Referenzpunkt aktuelle Stichprobe (N = 12)
n_curr = 12;
d_curr = fzero(@(d) (1 - nctcdf(tinv(1 - alpha, n_curr - 1), n_curr - 1, d * sqrt(n_curr))) - power_target, [0.1, 5.0]);

% --- PLOTTING (konsistent mit Task-Motion Heatmap) ---
figure('Color', [1 1 1], 'Position', [100 100 750 550]);

% Achsenposition mit etwas mehr Platz unten & links für die abgesetzten Labels: [Left, Bottom, Width, Height]
ax = axes('Position', [0.18, 0.18, 0.70, 0.60]);
hold(ax, 'on');

% 1. Glatte Hauptkurve
plot(ax, d_vec, N_vec, 'Color', [0.15 0.15 0.15], 'LineWidth', 1.8);

% 2. Aktuelle Stichprobe (N = 12) -> dezent in Hellgrau als Hintergrund-Referenz
col_gray = [0.60 0.60 0.60];
plot(ax, [0.35, d_curr], [n_curr, n_curr], ':', 'Color', col_gray, 'LineWidth', 1.0);
plot(ax, [d_curr, d_curr], [0, n_curr], ':', 'Color', col_gray, 'LineWidth', 1.0);
plot(ax, d_curr, n_curr, 'o', 'MarkerSize', 5.5, 'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', col_gray, 'LineWidth', 1.2);
text(ax, d_curr + 0.04, n_curr + 3.0, sprintf('Current sample reference: N = 12 (d = %.2f)', d_curr), ...
    'FontSize', 8.5, 'Color', [0.45 0.45 0.45], 'FontAngle', 'italic');

% 3. A-priori Benchmarks (d = 0.50 und d = 0.80) -> klar hervorgehoben (Dunkelblau/Schiefer)
col_apriori = [0.12 0.35 0.55];
labels_apriori = {sprintf('A-priori moderate effect: d = 0.50 (N = %d)', n_apriori(1)), ...
                  sprintf('A-priori large effect: d = 0.80 (N = %d)', n_apriori(2))};

for k = 1:length(d_apriori)
    plot(ax, [0.35, d_apriori(k)], [n_apriori(k), n_apriori(k)], '--', 'Color', col_apriori, 'LineWidth', 0.9);
    plot(ax, [d_apriori(k), d_apriori(k)], [0, n_apriori(k)], '--', 'Color', col_apriori, 'LineWidth', 0.9);
    plot(ax, d_apriori(k), n_apriori(k), 'o', 'MarkerSize', 6, 'MarkerFaceColor', col_apriori, 'MarkerEdgeColor', col_apriori);
    text(ax, d_apriori(k) + 0.04, n_apriori(k) + 3.0, labels_apriori{k}, ...
        'FontSize', 8.5, 'Color', col_apriori, 'FontWeight', 'normal');
end

% Achsen & Layout
xlim(ax, [0.35 2.35]);
ylim(ax, [0 100]);
xticks(ax, 0.4:0.2:2.2);
yticks(ax, 0:20:100);

grid(ax, 'on');
ax.GridAlpha = 0.12;
ax.GridLineStyle = ':';
ax.LineWidth = 0.8;
set(ax, 'FontSize', 10, 'TickDir', 'out', 'Box', 'off', 'XColor', [0.3 0.3 0.3], 'YColor', [0.3 0.3 0.3]);

% Achsenbeschriftungen mit vergrößertem Abstand zu den Tick-Zahlen
xl = xlabel(ax, 'Hypothetical Population Effect Size (Cohen''s d)', 'FontSize', 10, 'FontWeight', 'normal', 'Color', [0.15 0.15 0.15]);
yl = ylabel(ax, 'Required Sample Size (N) at 80% Power', 'FontSize', 10, 'FontWeight', 'normal', 'Color', [0.15 0.15 0.15]);

xl.Position(2) = xl.Position(2) - 4.5;   % X-Label weiter nach unten
yl.Position(1) = yl.Position(1) - 0.09;  % Y-Label weiter nach links

% Titel über Annotation (exakt wie bei der Heatmap positioniert)
annotation('textbox', [0.15, 0.84, 0.70, 0.08], ...
    'String', 'A-Priori Voxel-Wise Power Curve (p_{unc} = .001, One-Tailed)', ...
    'FontSize', 11, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'LineStyle', 'none', ...
    'Color', [0.1 0.1 0.1]);

hold(ax, 'off');

% --- EXPORT FIGURE ---
print(gcf, 'neu_powerplot.pdf', '-dpdf', '-painters');
print(gcf, 'neu_powerplot.png', '-dpng', '-r600');
exportgraphics(gcf, 'neu_powerplot.png', 'Resolution', 600, 'BackgroundColor', 'white');