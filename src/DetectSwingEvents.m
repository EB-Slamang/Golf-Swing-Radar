function [metrics, trace] = DetectSwingEvents(clusterMap, speed, t, p)
% DETECTSWINGEVENTS - Extract one set of swing metrics from clustered detections.
%
% INPUTS
%   clusterMap : speed rows by time columns; only positive labels are retained.
%   speed      : ascending speed-row coordinates in m/s.
%   t          : matching frame-centre times in seconds, with at least two frames.
%   p          : settings from the main script. Explicit caller values override
%                the optional defaults added here. The final main settings are
%                authoritative; helper defaults are not a second tuned baseline.
%
% OUTPUTS
%   metrics : scalar results and selection/status diagnostics for this recording.
%   trace   : intermediate arrays, masks, candidate comparisons, fit data and
%             effective parameters, allowing decisions to be inspected later.
%
% DECISION ORDER
%   1. Keep the highest speed among ALL positive cluster labels at each frame.
%   2. Interpolate only eligible internal gaps; smooth finite sections separately.
%   3. Select the highest raw candidate with neighbouring TIME and SPEED support,
%      then locate the nearby raw-supported smoothed maximum for event timing.
%   4. Find the last sustained low-speed region before that selected peak.
%   5. Select a raw-supported robust valley or the largest eligible gap midpoint.
%   6. Link qualifying pre-transition runs backwards; optionally extrapolate the
%      earliest linked run's initial fitted motion to zero radial speed.
%   7. Form durations only when final start < top < smoothed peak.
%
% NaN indicates an unavailable value, not zero motion. An early return preserves
% whatever has already been computed and leaves unavailable metrics missing.
% Clustering support and a valid event order do not prove club-head attribution.
% A gap midpoint and an extrapolated onset are estimates between/before returns.
% DownswingDuration_s is retained as a field name for TOP-TO-PEAK, not impact.
% No additional toolbox is used by this function.
% Detect one dominant swing from clustered speed-time detections.
% Inputs: clusterMap (speed rows x time columns), speed (m/s), t (s).
% p is the parameter structure in the calling script. No extra toolbox needed.
% metrics contains event times and durations; trace contains diagnostic arrays.
% Hybrid top rule: robust measured valley, overridden by the largest eligible
% raw-data gap midpoint if the robust candidate is absent or the gap's
% bounding-observation separation exceeds p.GapOverrideDuration_s (35 ms).
% A gap midpoint is an inferred timestamp, never a measured zero speed.
% Peak: highest locally supported raw value, then nearby smoothed timing.
% Only the final hybrid top rule and linked backswing-onset rule are used.
% Robust candidate calculation is included below; no external helper needed.

    % Normalize orientations so time masks/indexing are row-based and speeds are columns.
    t = t(:).';
    speed = speed(:);
    
   % Supply only these optional hybrid settings when absent. Existing fields win.
    % Other parameters must already be supplied by the caller.
    p = setDefault(p,'GapOverrideDuration_s',0.035);
    p = setDefault(p,'TopMedianWindow_s',0.030);
    p = setDefault(p,'TopMinimumMeasuredFraction',0.10);
    p = setDefault(p,'TopSpeedTolerance_mps',0.5*median(diff(speed)));
    % This 5 ms fallback is only for a caller that omits the field. The main
    % script explicitly supplies 50 ms; setDefault preserves that supplied value.
    p = setDefault(p,'MinimumValleyDuration_s',0.005);
    p = setDefault(p,'MinimumGapReport_s',0.001);
    % Simple local support check for the raw peak.
    p = setDefault(p,'PeakSupportSpeedRange_mps',4);
    p = setDefault(p,'PeakMinimumSupportDuration_s',0.020);
    
    % Optional zero-speed onset estimate. Existing callers need no new fields.
    % A short initial rising arc is approximated by v(t) = slope*(t-tDetected)+offset.
    % This estimates radial-motion onset; it cannot observe motion removed near DC.
    p = setDefault(p,'ExtrapolateBackswingStart',true);
    % true: use measured + already accepted interpolated speeds (not smoothed).
    % false: use raw measurements only, restoring the previous fit-data policy.
    p = setDefault(p,'StartFitUseInterpolated',true);
    p = setDefault(p,'StartFitMaxGap_s',0.010);      % Max spacing between available fit points
    p = setDefault(p,'StartFitWindow_s',0.100);      % Initial arc only, not full backswing
    p = setDefault(p,'StartFitBin_s',0.005);         % Median bins reduce isolated spikes
    p = setDefault(p,'StartFitMinSpan_s',0.025);     % Supported fit span, not frame count
    p = setDefault(p,'StartFitMinRise_mps',0.30);    % Minimum fitted gain across fit bins
    p = setDefault(p,'StartFitMinR2',0.60);          % Line agreement on binned raw data
    % Likewise, this 300 ms fallback is not the main-run value. The main script
    % explicitly supplies 200 ms. Changing this default does not change main calls
    % unless the explicit setting is removed.
    p = setDefault(p,'StartMaxExtrapolation_s',0.300); % Reject, rather than clip, distant roots
    validateStartParameters(p);

    % Use the returned frame spacing for event durations, rather than the
    % requested CPI or the main script's fixed median-conversion dt. Adjacent
    % frames overlap, so this spacing is not the independent temporal resolution.
    dt = median(diff(t));

    %% Extract the highest clustered speed in each time frame
    raw = nan(size(t));
    for k = 1:numel(t)
        rows = find(clusterMap(:,k) > 0);
        if ~isempty(rows)
            raw(k) = max(speed(rows));
        end
    end

    %% Fill short INTERNAL gaps only, bounded in time AND speed
    
    filled = raw;
    interpolated = false(size(t));
    
    [starts, ends] = findRuns(isnan(raw));
    
    for k = 1:numel(starts)
        a = starts(k);
        b = ends(k);
    
        left  = a - 1;
        right = b + 1;
    
        % Require measured observations on both sides.
        if left < 1 || right > numel(t)
            continue;
        end
        if ~isfinite(raw(left)) || ~isfinite(raw(right))
            continue;
        end

        % This duration counts missing frames only
        gapDuration = (b - a + 1)*dt;
        speedGap = abs(raw(right) - raw(left));
    
        % Small numerical tolerance avoids rejecting an equal-boundary case due to rounding.
        timeAllowed = gapDuration <= p.MaxInterpolationGap_s + 1e-9;
        speedAllowed = speedGap <= p.MaxInterpolationSpeedGap_mps + 1e-9;
    
        if timeAllowed && speedAllowed
            filled(a:b) = interp1(t([left right]), raw([left right]), t(a:b), 'linear');
    
            interpolated(a:b) = true;
        end
    end

    % Filter each supported section separately so long gaps stay missing.
    smoothed = nan(size(t));
    [starts, ends] = findRuns(isfinite(filled));
    for k = 1:numel(starts)
        idx = starts(k):ends(k);
        section = movmedian(filled(idx), p.MedianFilterFrames);
        smoothed(idx) = movmean(section, p.MovingAverageFrames);
    end
    
    % Initialize every metric/trace field before any early return
    % Initialise a consistent output schema before testing for absent returns.
    % This lets the main script append failed and successful recordings to one
    % table without discarding a recording simply because an event was unavailable.
    names = {'PeakRadialSpeed_mps','PeakSpeedTime_s','RawPeakTime_s', ...
        'TopOfBackswingTime_s','BackswingStartTime_s','BackswingDuration_s', ...
        'DownswingDuration_s','TempoRatio','TopRegionStartTime_s','TopRegionEndTime_s', ...
        'BackswingSearchStartTime_s','RobustMinimumCandidateTime_s', ...
        'GapMidpointCandidateTime_s','LargestGapStartTime_s', ...
        'LargestGapEndTime_s','LargestGapDuration_s', ...
        'LargestGapMissingDuration_s','DetectedBackswingStartTime_s', ...
        'ExtrapolatedBackswingStartTime_s','BackswingStartCorrection_s', ...
        'BackswingStartSlope_mps2','BackswingStartFitR2', ...
        'BackswingStartFitInterpolatedFraction'};
    for k = 1:numel(names)
        metrics.(names{k}) = NaN;
    end
    metrics.TopMethod = "hybrid";
    metrics.TopUsesMissingData = false;
    metrics.TopIsGapEstimate = false;
    metrics.TopSource = "none";
    metrics.TopSelectionReason = "No candidate";
    metrics.BackswingTouchesSearchStart = false;
    metrics.BackswingStartIsExtrapolated = false;
    metrics.BackswingStartSource = "none";
    metrics.BackswingStartSelectionReason = "No sustained backswing motion";
    metrics.Status = "No envelope";
    trace.Time_s = t;
    trace.RawEnvelope = raw;
    trace.FilledEnvelope = filled;
    trace.SmoothedEnvelope = smoothed;
    trace.InterpolatedMask = interpolated;
    trace.TopRegionMask = false(size(t));
    trace.BackswingSearchMask = false(size(t));
    trace.Parameters = p;
    trace.RobustEnvelope = nan(size(t));
    trace.TopComparison = emptyTopComparison(t);
    trace.BackswingStartFit = emptyStartFit();
    trace.PeakSupportMask = false(size(t));
    trace.PeakSupportRequired = NaN;
    trace.PeakSupportCount = 0;
    if ~any(isfinite(smoothed))
        return;
    end

    %% Choose a raw peak with nearby detections in TIME and SPEED
    % Try the highest raw speeds first. Reject short, isolated patches.
    measured = find(isfinite(raw) & isfinite(smoothed));
    [~, order] = sort(raw(measured), 'descend');
    % This converts a support-time parameter into a COUNT of other frames.
    % Those frames need not form one continuous run. At a 26/44100 s hop,
    % ceil(0.020/dt)=34 other measured frames are required; interpolation is excluded.
    minimumOtherFrames = max(1, ceil(p.PeakMinimumSupportDuration_s/dt));
    peakIndex = [];

    for j = 1:numel(order)
        candidate = measured(order(j));

        % Both masks must hold for the SAME raw observation. A high point far away
        % in speed cannot support this candidate merely because it is close in time.
        % The candidate itself is excluded from the final support count below.
        nearTime = abs(t-t(candidate)) <= p.PeakSearchHalfWidth_s;
        nearSpeed = abs(raw-raw(candidate)) <= p.PeakSupportSpeedRange_mps;
        nearby = nearTime & nearSpeed & isfinite(raw);
        nearby(candidate) = false; % Do not count the candidate itself.

        if nnz(nearby) < minimumOtherFrames
            continue; % Try the next-highest raw speed.
        end

        % Accepted raw peak: use a nearby smoothed maximum for event timing.
        rawPeakIndex = candidate;
        peakWindow = find(nearTime & nearSpeed & isfinite(smoothed));
        [~, localPeak] = max(smoothed(peakWindow));
        peakIndex = peakWindow(localPeak);
        break;
    end

    if isempty(peakIndex)
        metrics.Status = "No peak with nearby raw-speed support";
        return; % Existing event and duration outputs remain NaN.
    end

    trace.PeakSupportMask = nearby;
    trace.PeakSupportRequired = minimumOtherFrames;
    trace.PeakSupportCount = nnz(nearby);
    metrics.PeakSpeedTime_s = t(peakIndex);
    metrics.PeakRadialSpeed_mps = raw(rawPeakIndex);
    metrics.RawPeakTime_s = t(rawPeakIndex);

    %% Find the last sustained low-speed region before the peak
    search = t >= t(peakIndex)-p.TopSearchWindow_s & t < t(peakIndex);
    % This low-speed mask is for locating a region, not measuring a physical
    % turnaround directly. A weak or perpendicular return can also have low radial
    % speed, so the hybrid rule retains evidence about how its final top was chosen.
    low = isfinite(smoothed) & smoothed <= p.TopThreshold_mps;

    % A bounded unknown gap can connect LOW regions without inventing speeds.
    % Long gaps, leading gaps and gaps beside high speeds are not accepted.
    [starts, ends] = findRuns(isnan(smoothed));
    for k = 1:numel(starts)
        a = starts(k); b = ends(k);
        if a > 1 && b < numel(t) && (b-a+1)*dt <= p.MaxTopGap_s + 1e-9
            if low(a-1) && low(b+1)
                low(a:b) = true;
            end
        end
    end
    [starts, ends] = findRuns(low & search);
    valid = find((ends-starts+1)*dt >= p.MinimumTopDuration_s - 1e-9);
    if isempty(valid)
        metrics.Status = "No sustained low-speed region";
        return;
    end
    a = starts(valid(end)); b = ends(valid(end));
    region = a:b;
    trace.TopRegionMask(region) = true;
    metrics.TopRegionStartTime_s = t(a);
    metrics.TopRegionEndTime_s = t(b);
    metrics.TopUsesMissingData = any(isnan(raw(region)));

    %% Robust measured candidate and eligible gaps in RAW data
    % Use raw, not filled/smoothed, so interpolation cannot hide a gap.
    % Build a second median envelope from raw measurements only. The helper returns
    % one sustained supported valley plus all eligible raw missing intervals.
    % Raw gaps remain detectable even when filled earlier for envelope smoothing.
    comparison = selectTopCandidates(t, raw, trace.TopRegionMask, p);
    metrics.RobustMinimumCandidateTime_s = comparison.MeasuredMinimumTime_s;
    trace.RobustEnvelope = comparison.RobustEnvelope;

    if ~isempty(comparison.GapIntervals_s)
        % Gap intervals use the timestamps of the immediate measured endpoints.
        % Their separation includes the missing interval plus one hop. Keep this
        % separate from GapMissingDuration_s, which counts missing frames only.
        durations = diff(comparison.GapIntervals_s,1,2);
        longest = max(durations);
        % Equal longest gaps: choose the later one, nearer the downswing peak.
        gapIndex = find(abs(durations-longest)<=1e-9,1,'last');
        bounds = comparison.GapIntervals_s(gapIndex,:);
        metrics.LargestGapStartTime_s = bounds(1);
        metrics.LargestGapEndTime_s = bounds(2);
        metrics.LargestGapDuration_s = durations(gapIndex);
        metrics.LargestGapMissingDuration_s = ...
            comparison.GapMissingDuration_s(gapIndex);
        metrics.GapMidpointCandidateTime_s = mean(bounds);
    end

    %% Hybrid top: robust measured valley or largest eligible gap midpoint
    % A large gap overrides the valley; its midpoint remains an inferred event.
    hasRobust = isfinite(metrics.RobustMinimumCandidateTime_s);
    hasGap = isfinite(metrics.GapMidpointCandidateTime_s);
    gapOverrides = hasGap && ...
        metrics.LargestGapDuration_s > p.GapOverrideDuration_s + 1e-9;
    if hasGap && (~hasRobust || gapOverrides)
        metrics.TopOfBackswingTime_s = metrics.GapMidpointCandidateTime_s;
        metrics.TopSource = "gap_midpoint";
        metrics.TopIsGapEstimate = true;
        metrics.TopUsesMissingData = true;
        if ~hasRobust
            metrics.TopSelectionReason = "No robust measured candidate";
        else
            metrics.TopSelectionReason = "Largest gap exceeds override threshold";
        end
    elseif hasRobust
        metrics.TopOfBackswingTime_s = metrics.RobustMinimumCandidateTime_s;
        metrics.TopSource = "robust_measured";
        metrics.TopSelectionReason = "Robust candidate retained";
    else
        metrics.TopSelectionReason = "No robust candidate or eligible gap";
    end
    comparison.SelectedTime_s = metrics.TopOfBackswingTime_s;
    comparison.SelectedSource = metrics.TopSource;
    comparison.SelectionReason = metrics.TopSelectionReason;
    trace.TopComparison = comparison;

    %% Search backwards from the START of the slow region, within a fixed window
    % Search before the low-region start a, not before the selected top timestamp.
    % Clip the window to the recording. Motion uses the main smoothed envelope,
    % so accepted interpolation can contribute to qualifying motion duration.
    searchStart = max(t(1), t(a)-p.BackswingSearchWindow_s);
    backSearch = t >= searchStart & t < t(a);
    trace.BackswingSearchMask = backSearch;
    metrics.BackswingSearchStartTime_s = searchStart;
    motion = isfinite(smoothed) & smoothed >= p.MotionThreshold_mps & backSearch;
    [starts, ends] = findRuns(motion);
    valid = find((ends-starts+1)*dt >= p.MinimumMotionDuration_s - 1e-9);
    if ~isempty(valid)
        % Start at the latest qualifying run, then link earlier runs backwards.
        % The gap is measured between endpoints of qualifying runs.
        % Start from the LAST qualifying run, then visit earlier valid runs in
        % reverse order. A separation above MaximumMotionGap_s stops linking; a small
        % rejected run does not independently reset this separation test.
        selected = valid(end);
        for k = numel(valid)-1:-1:1
            previous = valid(k);
            gap = t(starts(selected))-t(ends(previous));
            if gap > p.MaximumMotionGap_s
                break;
            end
            selected = previous;
        end
        startIndex = starts(selected);
        metrics.BackswingStartTime_s = t(startIndex);
        metrics.BackswingTouchesSearchStart = startIndex == find(backSearch,1);

        % Preserve the linked-run result before estimating a hidden onset.
        metrics.DetectedBackswingStartTime_s = t(startIndex);
        metrics.BackswingStartSource = "detected";
        metrics.BackswingStartCorrection_s = 0;
        metrics.BackswingStartSelectionReason = "Extrapolation disabled";

        if p.ExtrapolateBackswingStart
            % Fit ONLY the first selected motion run. Linking may identify later
            % runs as part of the backswing, but they must not determine its initial slope.
            fit = extrapolateStart(t, raw, filled, interpolated, startIndex, ends(selected), ...
                metrics.BackswingTouchesSearchStart, p);
            trace.BackswingStartFit = fit;
            metrics.BackswingStartSlope_mps2 = fit.Slope_mps2;
            metrics.BackswingStartFitR2 = fit.R2;
            metrics.BackswingStartFitInterpolatedFraction = fit.InterpolatedFraction;
            metrics.BackswingStartSelectionReason = fit.Reason;
            if fit.Accepted
                metrics.ExtrapolatedBackswingStartTime_s = fit.ZeroTime_s;
                metrics.BackswingStartTime_s = fit.ZeroTime_s;
                metrics.BackswingStartCorrection_s = t(startIndex)-fit.ZeroTime_s;
                metrics.BackswingStartIsExtrapolated = true;
                metrics.BackswingStartSource = "zero_speed_extrapolation";
            end
            % Rejection leaves the original detected start in effect, never a
            % clipped root. Inspect Source/SelectionReason to identify this fallback.
        end
    end

    %% Use the chosen top candidate as the common phase boundary
    % Only compute durations for strictly ordered start < top < smoothed peak.
    % Backswing = top - start; downswing proxy = peak - top; tempo = their ratio.
    if ~isfinite(metrics.TopOfBackswingTime_s)
        metrics.Status = "Selected top method found no candidate";
    elseif ~isfinite(metrics.BackswingStartTime_s)
        metrics.Status = "No sustained backswing motion";
    elseif metrics.BackswingStartTime_s < metrics.TopOfBackswingTime_s && ...
            metrics.TopOfBackswingTime_s < metrics.PeakSpeedTime_s
        metrics.BackswingDuration_s = metrics.TopOfBackswingTime_s - metrics.BackswingStartTime_s;
        metrics.DownswingDuration_s = metrics.PeakSpeedTime_s - metrics.TopOfBackswingTime_s;
        metrics.TempoRatio = metrics.BackswingDuration_s / metrics.DownswingDuration_s;
        if metrics.TopIsGapEstimate
            metrics.Status = "Candidate events found; top inferred from gap midpoint";
        else
            metrics.Status = "Candidate events found; verify against video";
        end
        if metrics.BackswingStartIsExtrapolated
            metrics.Status = metrics.Status + "; start extrapolated to zero radial speed";
        end
    else
        metrics.Status = "Invalid event order";
    end
end

function [starts, ends] = findRuns(mask)
% Return inclusive start/end indices of consecutive true entries.
% Padding with false makes runs at either edge behave like internal runs.
% A duration based on these inclusive indices is (end-start+1)*hop.
% Locate continuous true runs, including runs touching either edge.
    % Pad with false so edge-touching runs also have an entry/exit transition.
    % +1 is the first true frame; -1 is the frame after the last true frame.
    changes = diff([false mask(:).' false]);
    starts = find(changes == 1);
    ends = find(changes == -1)-1;
end

function result = selectTopCandidates(t, raw, regionMask, p)
% Build a SECOND median representation using RAW samples only.
% A usable centre must itself be measured and have enough measured neighbours.
% Only a sustained, contiguous near-minimum valley supplies a measured top.
% Eligible gaps are found from the raw missing mask, even if another stage
% interpolated them. This helper compares candidates but does not choose which
% one overrides the other; the parent function makes that final decision.
% Compare a supported measured valley with raw missing intervals.
% Missing speeds stay missing, even if they were interpolated for smoothing.
    t = t(:).';
    raw = raw(:).';
    regionMask = logical(regionMask(:).');
    
    dt = median(diff(t));
    
    window_s = p.TopMedianWindow_s;
    fraction = p.TopMinimumMeasuredFraction;
    tolerance = p.TopSpeedTolerance_mps;
    duration_s = p.MinimumValleyDuration_s;
    gapReport_s = p.MinimumGapReport_s;
    assert(window_s>0 && fraction>0 && fraction<=1 && tolerance>=0);
    assert(duration_s>0 && gapReport_s>0 && p.TopThreshold_mps>=0);
    % Centered odd window. Derive its length from the actual hop time.
    % Convert seconds to a centered odd frame window (at least three frames).
    n = max(3, 2*floor(window_s/(2*dt))+1);
    measured = isfinite(raw);
    robust = movmedian(raw,n,'omitnan');
    % Denominator is the actual truncated window length at recording edges.
    % coverage is the fraction of raw samples present in this local median
    % window. It is a support diagnostic for a top candidate, NOT detection PD
    % and not a proportion of the entire dataset that was successfully processed.
    coverage = movmean(double(measured),n);
    support = measured & coverage >= fraction;
    robust(~support) = NaN;

    result = emptyTopComparison(t);
    result.RobustEnvelope = robust;
    result.MeasuredCoverage = coverage;
    selected = find(regionMask & support & isfinite(robust));
    if ~isempty(selected)
        % Find the lowest supported robust speed inside the chosen top region.
        % Admit speeds within tolerance of that floor AND below the low-speed limit.
        % The supported mask excludes all missing centers, splitting disconnected valleys.
        floorValue = min(robust(selected));
        nearFloor = regionMask & support & isfinite(robust) & ...
            robust <= floorValue + tolerance & robust <= p.TopThreshold_mps;
        [a,b] = findRuns(nearFloor);
        valid = find((b-a+1)*dt >= duration_s-1e-9);
        if ~isempty(valid)
            % Never take the median time of disconnected minima.
            % Select lowest median-speed interval; ties favor longer support.
            level = zeros(numel(valid),1); span = zeros(numel(valid),1);
            for j = 1:numel(valid)
                q = valid(j);
                level(j) = median(robust(a(q):b(q)));
                span(j) = (b(q)-a(q)+1)*dt;
            end
            % Ascending level chooses the lowest interval; ascending negative span
            % chooses the longest among equal levels. Remaining ties follow run order.
            % round selects the later of the two middle frames for an even-length run.
            [~,order] = sortrows([level -span],[1 2]);
            q = valid(order(1)); idx=a(q):b(q);
            center = idx(round((numel(idx)+1)/2));
            result.MeasuredMinimumTime_s = t(center);
            result.MeasuredMinimumInterval_s = t([idx(1) idx(end)]);
            result.MeasuredPlateauCount = numel(idx);
            result.Status = 'Measured valley candidate; require phase/video confirmation';
        end
    end
    % Find raw missing runs, regardless of whether the original routine filled them. 
    [a,b] = findRuns(~measured);
    for j = 1:numel(a)
        left = a(j)-1;
        right = b(j)+1;
        if left<1 || right>numel(t), continue; end
        if (b(j)-a(j)+1)*dt < gapReport_s-1e-9, continue; end
        % All missing frames must lie in the chosen region; endpoints may lie just
        % outside it. Raw endpoint speeds must be low even if smoothing made them low.
        if ~all(regionMask(a(j):b(j))), continue; end
        if raw(left)>p.TopThreshold_mps || raw(right)>p.TopThreshold_mps
            continue;
        end
        bracket = t([left right]);
        result.GapIntervals_s(end+1,:) = bracket;
        result.GapMidpoint_s(end+1,1) = mean(bracket);
        result.GapMissingDuration_s(end+1,1) = (b(j)-a(j)+1)*dt;
    end
    result.HasGapAmbiguity = ~isempty(result.GapIntervals_s);
    if result.HasGapAmbiguity
        result.Status='Low-speed gap present: point estimate may be unidentifiable';
    end
end
% Fixed diagnostic schema for both normal execution and early-return paths.
function result = emptyTopComparison(t)
% Provide the same candidate-diagnostic fields on every execution path.
% Empty gap arrays have two time-bound columns; absent scalar candidates are NaN.
% These defaults describe missing evidence, not a confirmed no-motion event.
    result.MeasuredMinimumTime_s = NaN;
    result.MeasuredMinimumInterval_s = [NaN NaN];
    result.MeasuredPlateauCount = 0;
    result.GapIntervals_s = zeros(0,2);
    result.GapMidpoint_s = zeros(0,1);
    result.GapMissingDuration_s = zeros(0,1);
    result.HasGapAmbiguity = false;
    result.RobustEnvelope = nan(size(t));
    result.MeasuredCoverage = zeros(size(t));
    result.Status = 'No supported measured candidate';
    result.SelectedTime_s = NaN;
    result.SelectedSource = "none";
    result.SelectionReason = "No candidate";
end
% Add a missing field only; never overwrite an explicitly supplied setting.
function p = setDefault(p,name,value)
% Add an optional setting only when the caller omitted that field.
% Do not overwrite a supplied zero/false value with a fallback. Keeping defaults
% here supports direct function calls, while the main script supplies final values.
    if ~isfield(p,name), p.(name) = value; end
end

function result = emptyStartFit()
% Initialise fit results so rejected, disabled and unattempted cases can be
% plotted and saved with the same field names as an accepted fit. Accepted=false
% means a proposed zero intercept must not replace the detected onset.
% Fixed schema, including no-motion, disabled and rejected-fit cases.
    result.Accepted = false;
    result.Reason = "Not attempted";
    result.DetectedTime_s = NaN;
    result.ZeroTime_s = NaN;
    result.Slope_mps2 = NaN;
    result.OffsetAtDetected_mps = NaN;
    % Compare the fitted line's squared error with a constant-mean predictor.
    % R2 can be negative for this robust line fit. A high value means good line
    % agreement on these bin values, not a probability of a correct physical onset.
    result.R2 = NaN;
    result.DataSource = "none";
    result.UsedInterpolation = false;
    result.InterpolatedFraction = NaN;
    result.MeasuredPointCount = 0;
    result.InterpolatedPointCount = 0;
    result.InputTime_s = zeros(0,1);
    result.InputSpeed_mps = zeros(0,1);
    result.InputIsInterpolated = false(0,1);
    result.FitSampleInterpolatedFraction = zeros(0,1);
    result.FitSampleTime_s = zeros(0,1);
    result.FitSampleSpeed_mps = zeros(0,1);
    result.FittedSampleSpeed_mps = zeros(0,1);
    result.LineTime_s = zeros(0,1);
    result.LineSpeed_mps = zeros(0,1);
end

function result = extrapolateStart(t, raw, filled, interpolated, startIndex, runEnd, truncated, p)
% Fit only the INITIAL portion of the selected onset run, not later linked arcs.
% Bin the available raw/accepted-interpolated speeds by time, use median bin
% values, then use median pairwise slopes and a median intercept (Theil-Sen).
% For fitted speed a*(t-tDetected)+b, the zero intercept is tDetected-b/a.
% The routine rejects insufficient support, non-rising/poor fits, later roots,
% roots before the recording and excessive backward corrections. Rejection does
% not clip a root to a permitted boundary; the parent retains the detected start.
% Estimate the zero intercept of the initial supported rising arc. No toolbox needed.
% Linear speed growth means locally constant RADIAL acceleration; it is an
% approximation, not a claim that the entire backswing has constant acceleration.
% Optionally use FILLED speeds: measured values plus only the linear interpolation
% accepted earlier by MaxInterpolationGap_s and MaxInterpolationSpeedGap_mps.
% No new gaps are filled here; the smoothed envelope is not used as fit data.
% Interpolated frames are estimates, not independent measured observations.
% Medians within short time bins reduce isolated upper-envelope spikes.
    result = emptyStartFit();
    detected = t(startIndex);
    result.DetectedTime_s = detected;
    if truncated
        result.Reason = "Fallback: detected run touches search boundary";
        return;
    end
    if p.StartFitUseInterpolated
        fitData = filled;
        result.DataSource = "measured_and_interpolated";
    else
        fitData = raw;
        result.DataSource = "measured_only";
    end
    idx = startIndex:runEnd;
    idx = idx(t(idx) <= detected+p.StartFitWindow_s+1e-9);
    idx = idx(isfinite(fitData(idx)) & fitData(idx)>=0);
    if numel(idx)<3
        result.Reason = "Fallback: insufficient initial fit points";
        return;
    end

    % Accepted interpolation supplies finite points across a raw dropout, so it
    % no longer terminates the fit. Remaining unsupported gaps are still bounded.
    % For a coarse time grid, allow at least one ordinary consecutive-frame hop.
    dt = median(diff(t));
    cut = find(diff(t(idx))>max(p.StartFitMaxGap_s,1.01*dt)+1e-9,1);
    if ~isempty(cut), idx=idx(1:cut); end
    if numel(idx)<3 || t(idx(end))-t(idx(1)) < p.StartFitMinSpan_s-1e-9
        result.Reason = "Fallback: initial supported span too short";
        return;
    end

    % Describe point provenance separately from fit quality. A high R2 can be
    % produced by interpolation itself and is not a confidence probability.
    usedInterpolation = interpolated(idx) & p.StartFitUseInterpolated;
    result.InputTime_s = t(idx).';
    result.InputSpeed_mps = fitData(idx).';
    result.InputIsInterpolated = usedInterpolation(:);
    result.InterpolatedPointCount = nnz(usedInterpolation);
    result.MeasuredPointCount = nnz(~usedInterpolation);
    result.UsedInterpolation = any(usedInterpolation);
    result.InterpolatedFraction = mean(usedInterpolation);

    bins = floor((t(idx)-detected)/p.StartFitBin_s+1e-9);
    ids = unique(bins);
    x = zeros(numel(ids),1); y = x;
    binFraction = x;
    for k=1:numel(ids)
        q = idx(bins==ids(k));
        x(k) = median(t(q))-detected;
        y(k) = median(fitData(q));
        binFraction(k) = mean(interpolated(q) & p.StartFitUseInterpolated);
    end
    result.FitSampleTime_s = detected+x;
    result.FitSampleSpeed_mps = y;
    result.FitSampleInterpolatedFraction = binFraction;
    if numel(x)<3 || x(end)-x(1)<p.StartFitMinSpan_s-1e-9
        result.Reason = "Fallback: insufficient binned fit support";
        return;
    end

    % Theil-Sen straight line: median slope of ALL distinct-time pairs, then
    % median intercept. Negative pair slopes are included, not discarded.
    % This resists isolated bad bins without requiring robustfit/toolboxes.
    slopes = zeros(numel(x)*(numel(x)-1)/2,1);
    pos = 0;
    for j=1:numel(x)-1
        q = j+1:numel(x);
        n = numel(q);
        slopes(pos+(1:n)) = (y(q)-y(j))./(x(q)-x(j));
        pos = pos+n;
    end
    slope = median(slopes);
    offset = median(y-slope*x);
    fitted = slope*x+offset;
    result.Slope_mps2 = slope;
    result.OffsetAtDetected_mps = offset;
    result.FittedSampleSpeed_mps = fitted;
    total = sum((y-mean(y)).^2);
    if total<=eps(max(1,sum(y.^2)))
        result.Reason = "Fallback: initial speeds are effectively constant";
        return;
    end
    result.R2 = 1-sum((y-fitted).^2)/total;
    if ~isfinite(slope) || slope<=0 || ...
            slope*(x(end)-x(1)) < p.StartFitMinRise_mps
        result.Reason = "Fallback: insufficient positive initial speed rise";
        return;
    end
    if result.R2 < p.StartFitMinR2
        result.Reason = "Fallback: initial trajectory is not sufficiently linear";
        return;
    end

    % Solve 0 = slope*(tZero-detected)+offset analytically. Centering time at
    % detected improves numerical conditioning without forcing the fit through it.
    zero = detected-offset/slope;
    if ~isfinite(zero) || zero>=detected
        result.Reason = "Fallback: zero intercept does not precede detected start";
        return;
    end
    if detected-zero > p.StartMaxExtrapolation_s+1e-9
        result.Reason = "Fallback: required backward extrapolation is too long";
        return;
    end
    if zero<t(1)
        result.Reason = "Fallback: zero intercept precedes the recording";
        return;
    end

    result.Accepted = true;
    result.ZeroTime_s = zero;
    if result.UsedInterpolation
        result.Reason = "Accepted zero-speed intercept using measured/interpolated trajectory";
    else
        result.Reason = "Accepted robust initial-arc zero-speed intercept";
    end
    % Two points suffice to overlay this straight line, including inferred onset.
    % These are diagnostic model values; raw/filled/smoothed arrays stay unchanged.
    result.LineTime_s = [zero; detected+x(end)];
    result.LineSpeed_mps = [0; fitted(end)];
end

function validateStartParameters(p)
% Fail early on invalid onset-fit controls, before attempting a fit.
% These checks protect arithmetic and interpretation; they do not optimise values
% or establish that the resulting onset is physically correct.
% Validate added controls; leave existing detector parameter handling unchanged.
    assert(isscalar(p.ExtrapolateBackswingStart) && ...
        (islogical(p.ExtrapolateBackswingStart) || isnumeric(p.ExtrapolateBackswingStart)) && ...
        any(p.ExtrapolateBackswingStart==[0 1]), ...
        'ExtrapolateBackswingStart must be a scalar logical or 0/1.');
    assert(isscalar(p.StartFitUseInterpolated) && ...
        (islogical(p.StartFitUseInterpolated) || isnumeric(p.StartFitUseInterpolated)) && ...
        any(p.StartFitUseInterpolated==[0 1]), ...
        'StartFitUseInterpolated must be a scalar logical or 0/1.');
    assert(isnumeric(p.StartFitMaxGap_s) && isscalar(p.StartFitMaxGap_s) && ...
        isfinite(p.StartFitMaxGap_s) && p.StartFitMaxGap_s>=0, ...
        'StartFitMaxGap_s must be finite and nonnegative.');
    positive = {'StartFitWindow_s','StartFitBin_s','StartFitMinSpan_s', ...
        'StartFitMinRise_mps','StartMaxExtrapolation_s'};
    for k=1:numel(positive)
        value = p.(positive{k});
        assert(isnumeric(value) && isscalar(value) && isfinite(value) && value>0, ...
            '%s must be finite and positive.',positive{k});
    end
    assert(p.StartFitMinSpan_s<=p.StartFitWindow_s, ...
        'StartFitMinSpan_s must not exceed StartFitWindow_s.');
    assert(p.StartFitBin_s<=p.StartFitWindow_s/2, ...
        'StartFitBin_s must allow at least three bins in the fit window.');
    assert(isnumeric(p.StartFitMinR2) && isscalar(p.StartFitMinR2) && ...
        isfinite(p.StartFitMinR2) && p.StartFitMinR2>=0 && p.StartFitMinR2<=1, ...
        'StartFitMinR2 must lie between 0 and 1.');
end
