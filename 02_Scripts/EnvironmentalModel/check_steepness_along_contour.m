clear

load('ArtificialTimeSeries503years.mat')
G = 9.81;
TZ_TO_TP = 1.2796;
Hs = A.Hs;
V = A.V;
Tp = A.Tp;
Sz = A.S;
Sp = 1 / TZ_TO_TP.^2 * Sz;

percentile = 99;
[w,thresh]=statplot(V,Hs,1,'prctile',[],[],'k-o',2,percentile);
load('hdc_2d_maxsteepness.csv')
HDC.v = hdc_2d_maxsteepness(:,1);
HDC.hs = hdc_2d_maxsteepness(:,2);

figure('Position', [100 100 760 350])
sz = 40;
layout = tiledlayout(1,2);
nexttile
hold on
step_size = 50;
ax1 = scatter(V(1:step_size:end), Hs(1:step_size:end), [], Sp(1:step_size:end), 'filled');
plot(HDC.v, HDC.hs, 'k-');
text(8, 8, 'HD contour', 'horizontalalignment', 'center');
scatter(HDC.v + 0.5, HDC.hs, sz, maxSteepnessAtV(HDC.v), 'filled', '^', 'MarkerEdgeColor', 'k')
%scatter(HDC.v - 0.5, HDC.hs, sz, highSteepnessAtV(HDC.v), 'filled', 'v', 'MarkerEdgeColor', 'k')
scatter(HDC.v - 0.5, HDC.hs, sz, medianSteepnessAtV(HDC.v), 'filled', 'v', 'MarkerEdgeColor', 'k')
plot(w, thresh, '-k', 'linewidth', 2)
text(w(end - 20) + 1, thresh(end - 20), [num2str(percentile) 'th percentile'], ...
    'fontweight', 'bold');
ylabel('Significant wave height (m)');
ylim([0 20])
c = colorbar;
c.Label.String = 'Steepness (-)';
c.Location = 'north';
set(gca, 'Layer', 'top')

% ax2 = nexttile;
% hold on
% [w2, thresh2] = statplot(V, Sp, 1, 'prctile',[],[],'k-o', 2, 50);
% step_size = 10;
% scatter(V(1:step_size:end), Sp(1:step_size:end), '.k')
% plot(w2, thresh2, 'xr', 'linewidth',1, 'markersize', 5);
% %plot(w2(end), thresh2(end), 'vk', 'markerfacecolor', [0.5 0.5 0.5], 'markeredgecolor', 'k');
% plot(w2, medianSteepnessAtV(w2), '--k', 'linewidth', 2, 'color', [0.5 0.5 0.5]);
% plot(w2(end), medianSteepnessAtV(w2(end)), 'vk', 'markerfacecolor', [0.5 0.5 0.5], 'markeredgecolor', 'k');
% text(21, 0.076, '50th percentile', 'color', 'r', 'fontweight', 'bold', 'horizontalalignment', 'center');
% text(1, 0.003, '0.071 - 0.06 \cdot exp(-0.11 \cdot v)', 'color', [0.5 0.5 0.5], ...
%     'fontweight', 'bold');
% ylabel('Steepness (-)');

Wvals=[];
Svals=[];
Tvals=[];
Hvals=[];
sMedianInBin = nan(length(w), 1);
for i=1:length(w)
    bin = V>w(i)-0.5 & V<=w(i)+0.5 & Hs>=thresh(i);
    Wvals=[Wvals;V(bin)];
    Svals=[Svals;Sp(bin)];
    sMedianInBin(i) = median(Sp(bin));
    Tvals=[Tvals;Tp(bin)];
    Hvals=[Hvals;Hs(bin)/max(Hs(bin))];
end


ax2 = nexttile;
hold on
scatter(Wvals,Svals, '.k')
plot(w(1:end-9), sMedianInBin(1:end-9), 'xr', 'linewidth', 2);


v = [0:1:40];
%sMedian = 0.012 + 0.021 ./ (1 + exp(-0.3*(v - 10)));
sMedian = medianSteepnessAtV(v);
sMax = maxSteepnessAtV(v);
plot(v, sMedian, '-', 'color', 'r', 'linewidth', 1);
plot(v(end), sMedian(end), 'v', 'markerfacecolor', 'r', 'markeredgecolor', 'k');
plot(v, sMax, '--', 'color', 'b', 'linewidth', 1);
plot(v(end), sMax(end), '^', 'markerfacecolor', 'b', 'markeredgecolor', 'k');
%sMax = highSteepnessAtV(v);
%plot(v, sMax, '--', 'color', [0.5 0.5 0.5], 'linewidth', 2);
%plot(v(end), sMax(end), 'v', 'markerfacecolor', [0.5 0.5 0.5], 'markeredgecolor', 'k');
%(v <= 19) .* (0.021 + (0.054 - 0.021) / 19 * v) + (v > 19) .* 0.054;
text(1, 0.048, '0.021 + 0.0017 \cdot v', 'fontweight', 'bold', 'color', 'blue')
text(26, 0.008, '0.012 + 0.0021 / (1 + exp[-0.3 \cdot (v - 10)])', 'fontweight', ...
    'bold', 'color', 'red', 'horizontalalignment', 'center')

linkaxes([ax1 ax2] , 'x');
xlabel(layout, 'Wind speed (m s^{-1})');
ylabel('Steepness at highest 1% h_s (-)');

layout.Padding = 'compact';

exportgraphics(layout, 'gfx/SteepnessAt2dContour.jpg') 
exportgraphics(layout, 'gfx/SteepnessAt2dContour.pdf') 


function sMax = maxSteepnessAtV(v)
   sMax = (v <= 19) .* (0.021 + (0.054 - 0.021) / 19 * v) + (v > 19) .* 0.054;
end
