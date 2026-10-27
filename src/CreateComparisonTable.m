function Comparison = CreateComparisonTable(AllSwingMetrics, AllSwingTraces)
% CREATECOMPARISONTABLE - Prepare one export row per processed recording.
%
% AllSwingMetrics is the accumulated struct2table output. AllSwingTraces is a
% cell array in exactly the same recording order. Do not sort one independently.
% The helper returns a new table; it does not read or write any files itself.
%
% The raw peak comes from the supported raw candidate. The smoothed value is
% looked up at PeakSpeedTime_s on the matching trace. These two values can have
% different timestamps; smoothed speed is not the global smoothed maximum.
% The five video/reference fields are NEW empty placeholders, not loaded data.
% An empty metrics table returns an empty comparison table.
% Build the original CSV layout without overwriting any video results.
% The old Downswing field means selected top to smoothed speed-peak time.
% The video speed column name is retained for compatibility; it does not
% establish that video and radar measure the same projection of motion.

    Comparison = table;
    if isempty(AllSwingMetrics)
        return;
    end
    nRecordings = height(AllSwingMetrics);
    assert(numel(AllSwingTraces) == nRecordings, ...
        'Each metrics row needs its corresponding trace.');

    Comparison.Recording = string(AllSwingMetrics.Recording);
    Comparison.Pipeline_BackswingDuration_s = AllSwingMetrics.BackswingDuration_s;
    Comparison.Pipeline_DownswingDuration_s = AllSwingMetrics.DownswingDuration_s;
    Comparison.Pipeline_RawPeakRadialSpeed_mps = AllSwingMetrics.PeakRadialSpeed_mps;
    Comparison.Pipeline_SmoothedPeakRadialSpeed_mps = nan(nRecordings,1);

    for k = 1:nRecordings
        peakTime = AllSwingMetrics.PeakSpeedTime_s(k);
        trace = AllSwingTraces{k};
        if ~isfinite(peakTime) || isempty(trace) || isempty(trace.Time_s)
            continue;
        end
        [~, frame] = min(abs(trace.Time_s-peakTime));
        Comparison.Pipeline_SmoothedPeakRadialSpeed_mps(k) = ...
            trace.SmoothedEnvelope(frame);
    end

    Comparison.Pipeline_TempoRatio = AllSwingMetrics.TempoRatio;
    % NaN means not yet annotated. It must not be interpreted as zero error or
    % zero duration. The legacy video speed column name is kept for compatibility;
    % its name alone does not establish identical radar/camera projection geometry.
    Comparison.Video_BackswingDuration_s = nan(nRecordings,1);
    Comparison.Video_DownswingDuration_s = nan(nRecordings,1);
    Comparison.Video_PeakRadialSpeed_mps = nan(nRecordings,1);
    Comparison.Video_TempoRatio = nan(nRecordings,1);
    Comparison.Reference_Notes = strings(nRecordings,1);
end
