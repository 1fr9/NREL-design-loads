SHAPE = 'free';
N_BLOCKS = 60;

%load('OvrDataEmulator');
Ovr(1,:,:,:) = NaN;
Ovr(:,9,4,:) = NaN;
maxr = max(Ovr,[],4);
gridSize = size(maxr);
maxr(maxr==0)=NaN;
currentNrEntries = sum(sum(sum(maxr>0)))
load 'CalmSeaComplete.mat'; % its variable v will be overwritten in next call
FormatConventionForMomentTimeSeries % to get the variables: v, hs, tp(hs, idx)


% Checking whether the results make sense:
c1 = [0, 0.4470, 0.7410];
c2 = [0.8500, 0.3250, 0.0980];
c3 = [0.9290, 0.6940, 0.1250];
c4 = [0.4660, 0.6740, 0.1880];
colorsTp = {c1, c2, c3, c4};
darker = 0.6;
darker_colors = [c1; c2; c3; c4] * darker;
vid = 16;
hsid = 2;
figure('Position', [100 100 900 900])
subplot(6, 1, 1:2);

OvrAllSeeds = [Ovr_S1; Ovr_S2; Ovr_S3; Ovr_S4; Ovr_S5; Ovr_S6];
OvrAllSeeds = OvrAllSeeds(:, 1:18);
hold on
ms = 50;
vv = [3:2:25 26 30 35 40 45 50];
for i = 1 : 6
    h = scatter(vv, OvrAllSeeds(i,:), ms, 'MarkerFaceColor', [0.5 0.5 0.5], ...
    'MarkerFaceAlpha', 0.5, 'MarkerEdgeColor', 'k', 'DisplayName', 'Hs = 0 m');
    if i > 1 
        set(h, 'HandleVisibility', 'off')
    end
end
hold on


for i = 1 : 4
    h = scatter(v, maxr(:, hsid, i), ms, 'MarkerFaceColor', colorsTp{i}, ...
        'MarkerFaceAlpha', 0.5, 'MarkerEdgeColor', 'k', 'DisplayName', ['Hs = ' num2str(hs(hsid)) ' m, Tp = ' num2str(tp(hs(hsid), i))]);
end
legend('box', 'off', 'location', 'eastoutside')
limsy=get(gca,'YLim');
set(gca,'Ylim',[0 limsy(2)]);
xlabel('1-hour wind speed (m/s)');
ylabel('Max 1-hour overturning moment (Nm)');

for i = 1 : 4
    subplot(6, 1, 3 + (i-1));
    plot(minutes(Time/60), squeeze(Ovr(vid, hsid, i, :)), 'color', colorsTp{i})
    ylabel('Overturning moment (Nm)');
    box off
    legend(['V = ' num2str(v(vid)) ' m/s, Hs = ' num2str(hs(hsid)) ' m, Tp = ' num2str(tp(hs(hsid), i))], 'box', 'off', 'location', 'eastoutside');
    box off
end

exportgraphics(gcf, 'gfx/ValidtyCheckHs1.jpg') 


[vgrid, hgrid] = meshgrid(v, hs);

% GEV parameters
xis = nan([size(vgrid), 4]);
sigmas = nan([size(vgrid), 4]);
mus = nan([size(vgrid), 4]);

R = ResponseEmulator;
for i = 1 : gridSize(1)
    for j = 1 : gridSize(2)
        for k = 1 : gridSize(3)
            if maxr(i, j, k) > 0 
                r = Ovr(i, j, k, :);
                pd = gevToBlockMaxima(r, N_BLOCKS, SHAPE);
                xis(j, i, k) = pd.k;
                sigmas(j, i, k) = pd.sigma;
                mus(j, i, k) = pd.mu;
            else
                xis(j, i, k) = NaN;
                sigmas(j, i, k) = NaN;
                mus(j, i, k) = NaN;
            end
        end
    end
end


for i = 1 : 4
    t2d = squeeze(tp(hgrid, i));
    temp = [vgrid(:), hgrid(:), t2d(:)];
    xi2d = squeeze(xis(:,:,i));
    sigma2d = squeeze(sigmas(:,:,i));
    mu2d = squeeze(mus(:,:,i));
    if i == 1
        X = temp;
        yk = xi2d(:);
        ysigma = sigma2d(:);
        ymu = mu2d(:);
    else
        X = [X; temp];
        yk = [yk; xi2d(:)];
        ysigma = [ysigma; sigma2d(:)];
        ymu = [ymu; mu2d(:)];
    end
end

% See: https://de.mathworks.com/help/stats/fitnlm.html
% x(:, 1) = v, x(:, 2) = hs, x(:, 3) = tp
modelfunXi = @(b, x) (x(:,1) <= 25) .* (-0.1 - 0.65 ./ (1 + 0.3 .* (x(:,1) - 12).^2) + 0.3 ./ (1 + 0.3 .* (x(:,1) - 18).^2) + ...
    x(:,2).^(1/3) .* ((b(1) -         (-0.1 - 0.65 ./ (1 + 0.3 .* (x(:,1) - 12).^2) + 0.3 ./ (1 + 0.3 .* (x(:,1) - 18).^2))) ./ 15^(1/3))) + ...
    (x(:,1) > 25) .* (-0.2622 +  x(:,2).^(1/3) .* (b(1) - -0.2622) / 15.^(1/3))
beta0 = [-0.1];
mdlXi = fitnlm(X, yk, modelfunXi, beta0, 'ErrorModel', 'proportional')
xiHat = predict(mdlXi, X);

modelfunSigma = @(b, x) (x(:,3) >= sqrt(2 * pi .* x(:,2) ./ (9.81 .* 1/14.99))) .* ...
    ((((x(:,1) <= 25) .* (b(1) .* x(:,1) + b(2) ./ (1 + 0.064 * (x(:,1) - 11.6).^2) +  b(3) ./ (1 + 0.2 * (x(:,1) - 11.6).^2)) + ...
    (x(:,1) > 25) .* 4700 .* x(:,1).^2).^2.0 + ...
    ((1 + (x(:,1) > 25) * 0.2) .* b(4) .* x(:,2).^1.0 .* (1 + 0.3 ./ (1 + 5 .* (x(:,3) - 3).^2))).^2.0).^(1/2.0));
beta0 = [10^5 10^5 10^5 10^5];
mdlSigma = fitnlm(X, ysigma, modelfunSigma, beta0, 'ErrorModel', 'proportional')
sigmaHat = predict(mdlSigma, X);

modelfunMu = @(b, x) (x(:,3) >= sqrt(2 * pi .* x(:,2) ./ (9.81 .* 1/14.99))) .* ...
    ((((x(:,1) <= 25) .* b(1) .* x(:,1) + b(2) ./ (1 + b(3) * (x(:,1) - 11.6).^2) + ... %.* min([(x(:,1) <= 25) .* 9.5 * 10^7], [b(1) .* x(:,1) + b(2) ./ (1 + b(3) * (x(:,1) - 11.6).^2)]) + ...
    (x(:,1) > 25 ) .* (3.9 * 10^4 .* x(:,1).^2)).^2.0 + ...
    ((1 + (x(:,1) > 25) * 0.2) .* b(5) .* x(:,2).^1.0 .* (1 + 0.3 ./ (1 + 5 .* (x(:,3) - 3).^2))).^2.0).^(1/2.0));
beta0 = [10^6 10^6 0.02 10^6 10^6];
mdlMu = fitnlm(X, ymu, modelfunMu, beta0, 'ErrorModel', 'proportional')
muHat = predict(mdlMu, X);

% xi, sigma, mu over wind speed
figure('Position', [100 100 900 900])
t = tiledlayout(4, 4);
for tpid = 1 : 4
    nexttile
    vv = [0 : 0.1 : 45];
    colorsHs = {'red', 'blue', 'black', 'green'};
    countI = 1;
    for i = [1, 2, 3, 5]
        X = [vv', zeros(length(vv), 1) + hs(i), zeros(length(vv), 1) + tp(hs(i), tpid)];
        hold on
        labelhs = ['H_s = ' num2str(hs(i)) ' m, from 1-hour simulation'];
        plot(v, xis(i, :, tpid), 'o', 'color', colorsHs{countI}, 'DisplayName', labelhs);
        labelhs = ['H_s = ' num2str(hs(i)) ' m, predicted'];
        plot(vv, predict(mdlXi, X), 'color', colorsHs{countI}, 'DisplayName', labelhs);
        countI = countI + 1;
    end
    xlabel('1-hour wind speed (m/s)');
    ylabel('\xi (-)');
    title(['t_{p' num2str(tpid) '}']);
    if tpid == 1
        lh = legend('box', 'off', 'Location','NorthOutside', ...
            'Orientation', 'Horizontal', 'NumColumns', 2);
        lh.Layout.Tile = 'North';
    end
end

for tpid = 1 : 4
    nexttile
    vv = [0 : 0.1 : 45];
    colorsHs = {'red', 'blue', 'black', 'green'};
    countI = 1;
    for i = [1, 2, 3, 5]
        X = [vv', zeros(length(vv), 1) + hs(i), zeros(length(vv), 1) + tp(hs(i), tpid)];
        hold on
        labelhs = ['H_s = ' num2str(hs(i)) ' m, from 1-hour simulation'];
        plot(v, sigmas(i, :, tpid), 'o', 'color', colorsHs{countI}, 'DisplayName', labelhs);
        labelhs = ['H_s = ' num2str(hs(i)) ' m, predicted'];
        plot(vv, predict(mdlSigma, X), 'color', colorsHs{countI}, 'DisplayName', labelhs);
        countI = countI + 1;
    end
    xlabel('1-hour wind speed (m/s)');
    ylabel('\sigma (Nm)');
    title(['t_{p' num2str(tpid) '}']);
end

for tpid = 1 : 4
    nexttile
    vv = [0 : 0.1 : 45];
    colorsHs = {'red', 'blue', 'black', 'green'};
    countI = 1;
    for i = [1, 2, 3, 5]
        X = [vv', zeros(length(vv), 1) + hs(i), zeros(length(vv), 1) + tp(hs(i), tpid)];
        hold on
        plot(v, mus(i, :, tpid), 'o', 'color', colorsHs{countI});
        labelhs = ['H_s = ' num2str(hs(i)) ' m'];
        plot(vv, predict(mdlMu, X), 'color', colorsHs{countI}, 'DisplayName', labelhs);
        countI = countI + 1;
    end
    xlabel('1-hour wind speed (m/s)');
    ylabel('\mu (Nm)');
    title(['t_{p' num2str(tpid) '}']);
end

for tpid = 1 : 4
    nexttile
    vv = [0 : 0.1 : 50];
    colors = {'red', 'blue', 'black'};
    for i = 1 : 3
        X = [vv', zeros(length(vv), 1) + hs(i), zeros(length(vv), 1) + tp(hs(i), tpid)];
        hold on
        plot(v, maxr(:, i, tpid), 'o', 'color', colors{i});
        labelhs = ['H_s = ' num2str(hs(i)) ' m'];
        %plot(vv, predict(mdlMu, X), 'color', colors{i}, 'DisplayName', labelhs);
    end
    xlabel('1-hour wind speed (m/s)');
    ylabel('1-hour maximum moment (Nm)');
    title(['t_{p' num2str(tpid) '}']);
end


figure
t = tiledlayout(1, 2);
ax1 = nexttile;
hold on
plot([v(1:14), v(1:14), v(1:14), v(1:14)], [xis(1, 1:14, 1), xis(1, 1:14, 2), xis(1, 1:14, 3), xis(1, 1:14, 4)], 'o', 'color', 'k');
hold on
plot(v(1:14), mean([xis(1, 1:14, 1); xis(1, 1:14, 2); xis(1, 1:14, 3); xis(1, 1:14, 4)]), '-k');
vv = [0:0.1:25];
k = -0.1 - 0.65 ./ (1 + 0.3 .* (vv - 12).^2) + 0.3 ./ (1 + 0.1 .* (vv - 18).^2);
plot(vv, k)
ax2 = nexttile;
plot([v(15:19), v(15:19), v(15:19), v(15:19)], [xis(1, 15:19, 1), xis(1, 15:19, 2), xis(1, 15:19, 3), xis(1, 15:19, 4)], 'o', 'color', 'k');
hold on
plot([26, 45], [-0.2622, -0.2622]);
linkaxes([ax1 ax2],'y')
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = '\xi (-)';

figure
t = tiledlayout(1, 2);
ax1 = nexttile;
hold on
plot([v(1:14), v(1:14), v(1:14), v(1:14)], [mus(1, 1:14, 1), mus(1, 1:14, 2), mus(1, 1:14, 3), mus(1, 1:14, 4)], 'o', 'color', 'k');
hold on
plot(v(1:14), mean([mus(1, 1:14, 1); mus(1, 1:14, 2); mus(1, 1:14, 3); mus(1, 1:14, 4)]), '-k');
vv = [0:0.1:25];
ax2 = nexttile;
plot([v(15:19), v(15:19), v(15:19), v(15:19)], [mus(1, 15:19, 1), mus(1, 15:19, 2), mus(1, 15:19, 3), mus(1, 15:19, 4)], 'o', 'color', 'k');
hold on
linkaxes([ax1 ax2],'y')
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = '\mu (Nm)';


figure
t = tiledlayout(1, 2);
ax1 = nexttile;
hold on
plot([v(1:14), v(1:14), v(1:14), v(1:14)], [sigmas(1, 1:14, 1), sigmas(1, 1:14, 2), sigmas(1, 1:14, 3), sigmas(1, 1:14, 4)], 'o', 'color', 'k');
hold on
plot(v(1:14), mean([sigmas(1, 1:14, 1); sigmas(1, 1:14, 2); sigmas(1, 1:14, 3); sigmas(1, 1:14, 4)]), '-k');
vv = [0:0.1:25];
ax2 = nexttile;
plot([v(15:19), v(15:19), v(15:19), v(15:19)], [sigmas(1, 15:19, 1), sigmas(1, 15:19, 2), sigmas(1, 15:19, 3), sigmas(1, 15:19, 4)], 'o', 'color', 'k');
hold on
linkaxes([ax1 ax2],'y')
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = '\sigma (Nm)';

% Sigma, mu over hs
figure('Position', [100 100 900 500])
t = tiledlayout(3, 4);
for tpid = 1 : 4
    nexttile
    hss = [0 : 0.1 : 15]';
    colors = {'red', 'blue', 'black'};
    countI = 1;
    for i = [1, 8 15]
        X = [zeros(length(hss), 1) + v(i), hss, tp(hss, tpid)];
        hold on
        labelv = ['V = ' num2str(v(i)) ' m s^{-1}, from 1-hour simulation'];
        plot(hs, sigmas(:, i, tpid), 'o', 'color', colors{countI}, 'DisplayName', labelv);
        labelv = ['V = ' num2str(v(i)) ' m s^{-1}, predicted'];
        plot(hss, predict(mdlSigma, X), 'color', colors{countI}, 'DisplayName', labelv);
        countI = countI + 1;
    end
    xlabel('Significant wave height (m)');
    ylabel('\sigma (Nm)');
    title(['t_{p' num2str(tpid) '}']);
    if tpid == 1
        lh = legend('box', 'off', 'Location','NorthOutside', ...
            'Orientation', 'Horizontal', 'NumColumns', 2);
        lh.Layout.Tile = 'North'; % <----- relative to tiledlayout
    end
end

for tpid = 1 : 4
    nexttile
    hss = [0 : 0.1 : 15]';
    colors = {'red', 'blue', 'black'};
    countI = 1;
    for i = [1, 8 15]
        X = [zeros(length(hss), 1) + v(i), hss, tp(hss, tpid)];
        hold on
        labelv = ['V = ' num2str(v(i)) ' m/s, from 1-hour simulation'];
        plot(hs, mus(:, i, tpid), 'o', 'color', colors{countI}, 'DisplayName', labelv);
        labelv = ['V = ' num2str(v(i)) ' m/s, predicted'];
        plot(hss, predict(mdlMu, X), 'color', colors{countI}, 'DisplayName', labelv);
        countI = countI + 1;
    end
    xlabel('Significant wave height (m)');
    ylabel('\mu (Nm)');
    title(['t_{p' num2str(tpid) '}']);
end

for tpid = 1 : 4
    nexttile
    hss = [0 : 0.1 : 15]';
    colors = {'red', 'blue', 'black'};
    countI = 1;
    for i = [1, 8 15]
        X = [zeros(length(hss), 1) + v(i), hss, tp(hss, tpid)];
        hold on
        labelv = ['V = ' num2str(v(i)) ' m/s, from 1-hour simulation'];
        plot(hs, maxr(i, :, tpid), 'o', 'color', colors{countI}, 'DisplayName', labelv);
        %labelv = ['V = ' num2str(v(i)) ' m/s, predicted'];
        %plot(hss, predict(mdlMu, X), 'color', colors{countI}, 'DisplayName', labelv);
        countI = countI + 1;
    end
    xlabel('Significant wave height (m)');
    ylabel('1-hour maximum moment (Nm)');
    title(['t_{p' num2str(tpid) '}']);
end


% Xi contour plot
figure('Position', [100 100 500 800])
t = tiledlayout(4, 2);
clower = -0.6;
cupper = 0.3;
for ii = 1 : 4
    nexttile
    contourf(vgrid, hgrid, squeeze(xis(:, :, ii)), 10)
    title(['multiphysics, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper])
    nexttile
    ktp1 = nan(size(vgrid));
    for i = 1 : size(vgrid, 1)
        for j = 1 : size(vgrid, 2)
            Xtemp = [vgrid(i, j), hgrid(i, j), tp(hgrid(i, j), ii)];
            ktp1(i, j) = predict(mdlXi, Xtemp);
        end
    end
    contourf(vgrid, hgrid, ktp1, 10);
    title(['predicted, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper])
end

c = colorbar;
c.Label.String = '\xi (-) ';
c.Layout.Tile = 'east';
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = 'Significant wave height (m)';
exportgraphics(gcf, 'gfx/EmulatorFitKFree_k.jpg') 
exportgraphics(gcf, 'gfx/EmulatorFitKFree_k.pdf') 

% Sigma contour plot
figure('Position', [100 100 500 800])
t = tiledlayout(4, 2);
clower = min(sigmas(:));
cupper = max(sigmas(:)) * 0.95;
for ii = 1 : 4
    nexttile
    contourf(vgrid, hgrid, squeeze(sigmas(:, :, ii)), 10)
    title(['multiphysics, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper])
    nexttile
    sigmatp1 = nan(size(vgrid));
    for i = 1 : size(vgrid, 1)
        for j = 1 : size(vgrid, 2)
            Xtemp = [vgrid(i, j), hgrid(i, j), tp(hgrid(i, j), ii)];
            sigmatp1(i, j) = predict(mdlSigma, Xtemp);
        end
    end
    contourf(vgrid, hgrid, sigmatp1, 10);
    title(['predicted, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper])
end

c = colorbar;
c.Label.String = '\sigma (Nm) ';
c.Layout.Tile = 'east';
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = 'Significant wave height (m)';
exportgraphics(gcf, 'gfx/EmulatorFitKFree_Sigma.jpg') 
exportgraphics(gcf, 'gfx/EmulatorFitKFree_Sigma.pdf') 


% Mu contour plot
figure('Position', [100 100 500 800])
t = tiledlayout(4, 2);
clower = min(mus(:));
cupper = 2 * 10^8;
for ii = 1 : 4
    nexttile
    contourf(vgrid, hgrid, squeeze(mus(:, :, ii)), [clower : (cupper - clower) / 10 : cupper])
    title(['multiphysics, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper]);
    nexttile
    mutp1 = nan(size(vgrid));
    for i = 1 : size(vgrid, 1)
        for j = 1 : size(vgrid, 2)
            Xtemp = [vgrid(i, j), hgrid(i, j), tp(hgrid(i, j), ii)];
            mutp1(i, j) = predict(mdlMu, Xtemp);
        end
    end
    contourf(vgrid, hgrid, mutp1, 10);
    title(['predicted, t_{tp' num2str(ii) '} surface'])
    caxis([clower cupper])
end

c = colorbar;
c.Label.String = '\mu (Nm) ';
c.Layout.Tile = 'east';
t.XLabel.String = '1-hour wind speed (m s^{-1})';
t.YLabel.String = 'Significant wave height (m)';
exportgraphics(gcf, 'gfx/EmulatorFitKFree_Mu.jpg') 
exportgraphics(gcf, 'gfx/EmulatorFitKFree_Mu.pdf') 

%sgtitle('mu')