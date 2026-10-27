function [spectrogramFigure, envelopeFigure] = PlotSwingEvents( ...
    t, speed, powerDB, bounds, metrics, trace, recording)
% PLOTSWINGEVENTS - Explain stored event decisions in two independent figures.
%
% INPUTS: t in s; speed in m/s; powerDB is ORIGINAL relative power, not CFAR
% linear power; bounds are display dB limits. metrics and trace come from the
% same DetectSwingEvents call. recording is a label only, not a path to load.
%
% OUTPUTS: spectrogramFigure and envelopeFigure are handles for optional saving.
% Calling without outputs still creates both figures. No event is recomputed.
% The selected phase endpoint is the smoothed-peak TIME. The raw-peak marker
% can occur at another time; its speed is the supported raw candidate amplitude.
%
% Envelope colours: grey measured points, blue smoothed values, brown accepted
% interpolation. Orange highlights the selected gap or measured-valley interval;
% other eligible gaps are grey. Green fit data/line explain accepted onset
% extrapolation, while the original detected onset remains separately marked.
% The peak-support box and points show the local time/speed acceptance evidence.
% Make two separate figures. This function only displays stored decisions;
% it does not recalculate events or change the envelope.
% Returned figure handles can be used with exportgraphics or savefig.

    t = t(:).';
    speed = speed(:);
    raw = trace.RawEnvelope(:).';
    smooth = trace.SmoothedEnvelope(:).';
    filled = trace.FilledEnvelope(:).';
    interpolated = logical(trace.InterpolatedMask(:).');
    startColour = [0.05 0.50 0.25];
    topColour = [0.85 0.40 0.05];
    rawPeakColour = [0.65 0.05 0.18];
    smoothPeakColour = [0.45 0.15 0.70];
    brown = [0.65 0.34 0.12];

    % The selected speed-peak timestamp belongs to the smoothed envelope.
    smoothPeak = NaN;
    if isfinite(metrics.PeakSpeedTime_s)
        [~, peakFrame] = min(abs(t-metrics.PeakSpeedTime_s));
        smoothPeak = smooth(peakFrame);
    end
    metricText = sprintf(['Backswing %.3f s | Top-to-peak %.3f s | Tempo %.2f\n' ...
        'Raw peak %.2f m/s | Smoothed peak %.2f m/s'], ...
        metrics.BackswingDuration_s, metrics.DownswingDuration_s, ...
        metrics.TempoRatio, metrics.PeakRadialSpeed_mps, smoothPeak);

    %% Figure 1: final events on the original-power spectrogram
    spectrogramFigure = figure('Name',[char(recording) ' - event spectrogram'], ...
        'Color','w','Position',[100 100 1100 650]);
    axes('Position',[0.09 0.17 0.79 0.69]);
    imagesc(t,speed,powerDB,bounds);
    axis xy;
    hold on;
    colormap(spectrogramFigure,'jet');
    cb = colorbar;
    cb.Label.String = 'Relative original power (dB)';
    cb.FontSize = 10;
    plot(t,smooth,'w-','LineWidth',1.1,'HandleVisibility','off');
    drawEventLines(metrics, [1 1 1], [1 0.85 0.2], [1 0.7 1]);
    if isfinite(metrics.RawPeakTime_s)
        plot(metrics.RawPeakTime_s,metrics.PeakRadialSpeed_mps,'o', ...
            'MarkerEdgeColor','k','MarkerFaceColor','w','MarkerSize',7, ...
            'DisplayName',sprintf('Raw %.2f m/s at %.3f s', ...
                metrics.PeakRadialSpeed_mps,metrics.RawPeakTime_s));
    end
    if isfinite(metrics.PeakSpeedTime_s)
        plot(metrics.PeakSpeedTime_s,smoothPeak,'d', ...
            'MarkerEdgeColor','k','MarkerFaceColor',[1 0.75 1],'MarkerSize',7, ...
            'DisplayName',sprintf('Smoothed %.2f m/s at %.3f s', ...
                smoothPeak,metrics.PeakSpeedTime_s));
    end
    xlabel('Recording time (s)');
    ylabel('Radial-speed magnitude (m/s)');
    title(char(recording),'Interpreter','none','FontWeight','normal');
    set(gca,'FontSize',11);
    if isfinite(metrics.RawPeakTime_s)
        legend('Location','northeast','FontSize',10);
    end
    annotation(spectrogramFigure,'textbox',[0.09 0.02 0.86 0.10], ...
        'String',metricText,'EdgeColor','none','FontSize',11, ...
        'Interpreter','none','HorizontalAlignment','center');

    %% Figure 2: measured, interpolated and smoothed envelope with evidence
    envelopeFigure = figure('Name',[char(recording) ' - event evidence'], ...
        'Color','w','Position',[130 130 1150 750]);
    axes('Position',[0.09 0.27 0.87 0.61]);
    hold on;
    finiteSpeeds = [raw(isfinite(raw)) smooth(isfinite(smooth))];
    if isempty(finiteSpeeds)
        upperSpeed = 10;
    else
        upperSpeed = max(10,1.18*max(finiteSpeeds));
    end
    ylim([0 upperSpeed]);
    xlim([t(1) t(end)]);

    % Shading denotes absent raw observations, not zero speed.
    gaps = trace.TopComparison.GapIntervals_s;
    for k = 1:size(gaps,1)
        shadeInterval(gaps(k,:),upperSpeed,[0.8 0.8 0.8],0.18, ...
            'Other eligible top gaps',k == 1);
    end
    if metrics.TopIsGapEstimate
        shadeInterval([metrics.LargestGapStartTime_s metrics.LargestGapEndTime_s], ...
            upperSpeed,topColour,0.15,'Gap used for selected top',true);
    elseif isfinite(metrics.RobustMinimumCandidateTime_s)
        shadeInterval(trace.TopComparison.MeasuredMinimumInterval_s, ...
            upperSpeed,topColour,0.15,'Selected measured valley',true);
    end

    % NaNs break the measured line; it never joins across missing observations.
    plot(t,raw,'.-','Color',[0.60 0.60 0.60],'MarkerSize',5, ...
        'LineWidth',0.5,'DisplayName','Measured upper envelope');
    plot(t,smooth,'b-','LineWidth',1.4,'DisplayName','Smoothed envelope');
    if any(interpolated)
        values = filled;
        values(~interpolated) = NaN;
        plot(t,values,'.--','Color',brown,'MarkerSize',6,'LineWidth',1, ...
            'DisplayName','Accepted interpolation');
    end

    % Show the neighbouring measured points that supported the accepted raw peak.
    if isfield(trace,'PeakSupportMask') && any(trace.PeakSupportMask)
        q = trace.PeakSupportMask;
        plot(t(q),raw(q),'.','Color',rawPeakColour,'MarkerSize',7, ...
            'DisplayName','Raw-peak support');
        halfWidth = trace.Parameters.PeakSearchHalfWidth_s;
        speedRange = trace.Parameters.PeakSupportSpeedRange_mps;
        rectangle('Position',[metrics.RawPeakTime_s-halfWidth, ...
            metrics.PeakRadialSpeed_mps-speedRange,2*halfWidth,2*speedRange], ...
            'EdgeColor',rawPeakColour,'LineStyle',':','LineWidth',1);
    end

    fit = trace.BackswingStartFit;
    if ~isempty(fit.FitSampleTime_s)
        plot(fit.FitSampleTime_s,fit.FitSampleSpeed_mps,'s', ...
            'Color',startColour,'MarkerSize',4,'DisplayName','Binned onset-fit data');
    end
    if fit.Accepted
        plot(fit.LineTime_s,fit.LineSpeed_mps,'--','Color',startColour, ...
            'LineWidth',1.6,'DisplayName','Accepted zero-speed extrapolation');
    end
    if isfinite(metrics.DetectedBackswingStartTime_s)
        xline(metrics.DetectedBackswingStartTime_s,':','Detected onset', ...
            'Color',startColour,'LabelVerticalAlignment','bottom', ...
            'FontSize',10,'HandleVisibility','off');
    end
    if metrics.TopIsGapEstimate && isfinite(metrics.RobustMinimumCandidateTime_s)
        xline(metrics.RobustMinimumCandidateTime_s,':','Measured-valley candidate', ...
            'Color',topColour,'LabelVerticalAlignment','bottom', ...
            'FontSize',10,'HandleVisibility','off');
    end
    drawEventLines(metrics,startColour,topColour,smoothPeakColour);
    if isfinite(metrics.RawPeakTime_s)
        plot(metrics.RawPeakTime_s,metrics.PeakRadialSpeed_mps,'o', ...
            'Color',rawPeakColour,'MarkerFaceColor','w','MarkerSize',8, ...
            'DisplayName',sprintf('Raw peak %.2f m/s at %.3f s', ...
                metrics.PeakRadialSpeed_mps,metrics.RawPeakTime_s));
    end
    if isfinite(metrics.PeakSpeedTime_s)
        plot(metrics.PeakSpeedTime_s,smoothPeak,'d', ...
            'Color',smoothPeakColour,'MarkerFaceColor',smoothPeakColour, ...
            'MarkerSize',7,'DisplayName',sprintf('Smoothed peak %.2f m/s',smoothPeak));
    end
    xlabel('Recording time (s)');
    ylabel('Radial-speed magnitude (m/s)');
    title(char(recording),'Interpreter','none','FontWeight','normal');
    set(gca,'FontSize',11);
    grid on;
    legend('Location','northeast','NumColumns',2,'FontSize',9);

    % Explain the actual choice, including fallback when the onset fit is rejected.
    decisionText = sprintf('%s\nTop: %s. %s\nStart: %s', ...
        metricText,char(metrics.TopSource),char(metrics.TopSelectionReason), ...
        char(metrics.BackswingStartSelectionReason));
    if isfield(trace,'PeakSupportRequired') && isfinite(trace.PeakSupportRequired)
        decisionText = sprintf('%s\nPeak support: %d other frames (required %d).', ...
            decisionText,trace.PeakSupportCount,trace.PeakSupportRequired);
    end
    annotation(envelopeFigure,'textbox',[0.09 0.015 0.87 0.20], ...
        'String',decisionText,'EdgeColor','none','FontSize',10, ...
        'Interpreter','none','HorizontalAlignment','left');
end

function drawEventLines(m,startColour,topColour,peakColour)
% Draw only finite timestamps. These are selected estimates, not directly
% observed impacts. Colour choices can differ between dark and light backgrounds.
% The raw-peak time is deliberately not the phase-duration endpoint.
% Use the smoothed-peak time as the phase endpoint, not the raw-peak time.
    times = [m.BackswingStartTime_s m.TopOfBackswingTime_s m.PeakSpeedTime_s];
    names = {'Selected start','Selected top','Smoothed peak'};
    colours = {startColour,topColour,peakColour};
    for k = 1:3
        if isfinite(times(k))
            xline(times(k),'--',sprintf('%s %.3f s',names{k},times(k)), ...
                'Color',colours{k},'LineWidth',1.2,'FontSize',10, ...
                'LabelVerticalAlignment','top','HandleVisibility','off');
        end
    end
end

function shadeInterval(bounds,upperSpeed,colour,opacity,name,showLegend)
% Shade an interval without inserting artificial speed samples. The bounds
% are time coordinates; the vertical extent only makes missing support visible.
% Repeated categories are hidden from the legend to avoid duplicate entries.
    if ~all(isfinite(bounds)), return; end
    h = patch(bounds([1 2 2 1]),[0 0 upperSpeed upperSpeed],colour, ...
        'EdgeColor','none','FaceAlpha',opacity,'DisplayName',name);
    if ~showLegend, h.HandleVisibility = 'off'; end
end
