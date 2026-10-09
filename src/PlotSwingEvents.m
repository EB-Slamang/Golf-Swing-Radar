function PlotSwingEvents(t, speed, powerDB, bounds, metrics, trace, recording)
% Show what was measured, what was interpolated, and where events were chosen.
    t = t(:).';
    figure('Name',char(recording));
    ax1 = subplot(2,1,1);
    imagesc(t,speed,powerDB,bounds);
    axis xy;
    hold on;
    plot(t,trace.SmoothedEnvelope,'k','LineWidth',1.3);
    drawEvents(metrics,'w');
    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    title({char(recording), sprintf( ...
        '%s | Peak %.2f m/s | Back %.3f s | Top-to-peak %.3f s | Ratio %.2f', ...
        char(metrics.TopMethod), metrics.PeakRadialSpeed_mps, ...
        metrics.BackswingDuration_s, metrics.DownswingDuration_s, metrics.TempoRatio)}, ...
        'Interpreter','none');
    colorbar;
    colormap('jet');

    ax2 = subplot(2,1,2);
    plot(t,trace.RawEnvelope,'.','Color',[0.65 0.65 0.65], ...
        'DisplayName','Measured envelope');
    hold on;
    plot(t,trace.SmoothedEnvelope,'b','DisplayName','Smoothed');
    mask = trace.InterpolatedMask;
    plot(t(mask),trace.FilledEnvelope(mask),'mo','MarkerSize',3, ...
        'DisplayName','Short-gap interpolation');
    mask = trace.TopRegionMask & isfinite(trace.SmoothedEnvelope);
    plot(t(mask),trace.SmoothedEnvelope(mask),'r.','MarkerSize',10, ...
        'DisplayName','Selected low-speed region');
    % Missing samples shown at zero are STATUS markers, not zero-speed data.
    mask = ~isfinite(trace.FilledEnvelope);
    plot(t(mask),zeros(1,nnz(mask)),'x','Color',[0.65 0.65 0.65], ...
        'MarkerSize',3,'DisplayName','Unknown speed (markers at baseline)');
    yline(trace.Parameters.MotionThreshold_mps,':','Motion threshold', ...
        'HandleVisibility','off');
    yline(trace.Parameters.TopThreshold_mps,':','Top threshold', ...
        'HandleVisibility','off');
    if isfinite(metrics.BackswingSearchStartTime_s)
        xline(metrics.BackswingSearchStartTime_s,':','Back search begins', ...
            'HandleVisibility','off');
    end
    drawEvents(metrics,'k');
    if isfinite(metrics.MinimumCandidateTime_s)
        xline(metrics.MinimumCandidateTime_s,':r','Minimum candidate', ...
            'HandleVisibility','off');
    end
    if isfinite(metrics.RiseCandidateTime_s)
        xline(metrics.RiseCandidateTime_s,':m','Rise candidate', ...
            'HandleVisibility','off');
    end
    ylim([0 max(8,2*trace.Parameters.TopThreshold_mps)]);
    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    title(char(metrics.Status),'Interpreter','none');
    grid on;
    legend('Location','best');
    linkaxes([ax1 ax2],'x');
end

function drawEvents(m, colour)
    times = [m.BackswingStartTime_s m.TopOfBackswingTime_s m.RawPeakTime_s];
    labels = {'Backswing start','Top candidate','Peak radial speed'};
    for k = 1:numel(times)
        if isfinite(times(k))
            xline(times(k),'--','Color',colour,'Label',labels{k}, ...
                'LineWidth',1.1,'HandleVisibility','off');
        end
    end
end
