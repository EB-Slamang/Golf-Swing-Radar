function [metrics, trace] = DetectSwingEvents(clusterMap, speed, t, p)
% Detect one dominant swing from clustered speed-time detections.
% Inputs: clusterMap (speed rows x time columns), speed (m/s), t (s).
% p is the parameter structure in the calling script. No extra toolbox needed.
% metrics contains event times and durations; trace contains diagnostic arrays.
% Hybrid top rule: robust measured valley, overridden by the largest eligible
% raw-data gap midpoint if the robust candidate is absent or the gap's
% bounding-observation separation exceeds p.GapOverrideDuration_s (35 ms).
% A gap midpoint is an inferred timestamp, never a measured zero speed.
% 'minimum' is a compatibility alias for 'hybrid'; 'rise' retains the rise rule.
% Robust candidate calculation is included below; no external helper needed.

    % Normalize orientations so time masks/indexing are row-based and speeds are columns.
    t = t(:).';
    speed = speed(:);
    
   % Supply only these optional hybrid settings when absent. Existing fields win.
    % Other parameters must already be supplied by the caller. The defaults here
    % take precedence over the helper's fallback values because p is passed onward.
    p = setDefault(p,'GapOverrideDuration_s',0.035);
    p = setDefault(p,'TopMedianWindow_s',0.030);
    p = setDefault(p,'TopMinimumMeasuredFraction',0.10);
    p = setDefault(p,'TopSpeedTolerance_mps',0.5*median(diff(speed)));
    p = setDefault(p,'MinimumValleyDuration_s',0.005);
    p = setDefault(p,'MinimumGapReport_s',0.001);
    
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
    names = {'PeakRadialSpeed_mps','PeakSpeedTime_s','RawPeakTime_s', ...
        'TopOfBackswingTime_s','BackswingStartTime_s','BackswingDuration_s', ...
        'DownswingDuration_s','TempoRatio','MinimumCandidateTime_s', ...
        'RiseCandidateTime_s','TopRegionStartTime_s','TopRegionEndTime_s', ...
        'BackswingSearchStartTime_s','RobustMinimumCandidateTime_s', ...
        'GapMidpointCandidateTime_s','LargestGapStartTime_s', ...
        'LargestGapEndTime_s','LargestGapDuration_s', ...
        'LargestGapMissingDuration_s'};
    for k = 1:numel(names)
        metrics.(names{k}) = NaN;
    end
    metrics.TopMethod = string(p.TopMethod);
    metrics.TopUsesMissingData = false;
    metrics.TopIsGapEstimate = false;
    metrics.TopSource = "none";
    metrics.TopSelectionReason = "No candidate";
    metrics.MinimumTieCount = 0;
    metrics.BackswingTouchesSearchStart = false;
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
    if ~any(isfinite(smoothed))
        return;
    end

    %% Locate the smoothed peak, but measure amplitude on the RAW envelope
    measured = find(isfinite(raw) & isfinite(smoothed));
    [~, localPeak] = max(smoothed(measured));
    peakIndex = measured(localPeak);
    metrics.PeakSpeedTime_s = t(peakIndex);
    % Recover a raw peak amplitude locally, rather than report the reduced smoothed
    % amplitude. RawPeakTime_s may differ from PeakSpeedTime_s; the latter remains
    % the downswing-duration endpoint used later.
    peakWindow = find(abs(t-t(peakIndex)) <= p.PeakSearchHalfWidth_s & isfinite(raw));
    [metrics.PeakRadialSpeed_mps, localPeak] = max(raw(peakWindow));
    metrics.RawPeakTime_s = t(peakWindow(localPeak));

    %% Find the last sustained low-speed region before the peak
    search = t >= t(peakIndex)-p.TopSearchWindow_s & t < t(peakIndex);
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

    %% Candidate 1: lowest smoothed value at a genuinely measured location
    candidates = region(isfinite(raw(region)) & isfinite(smoothed(region)));
    if ~isempty(candidates)
        lowest = min(smoothed(candidates));
        tied = candidates(smoothed(candidates) == lowest);
        metrics.MinimumCandidateTime_s = t(tied(1)); % First exact tie
        metrics.MinimumTieCount = numel(tied);
    end

    %% Candidate 2: start of a sustained upward trend near the slow region
    % Compare up to six time intervals, not every highly overlapped frame.
    % Require mostly positive changes, enough net gain, and no large drop.
    riseSteps = max(1, ceil(p.RiseWindow_s/dt));
    for j = candidates
        last = j + riseSteps;
        if last > peakIndex
            break;
        end
        idx = j:last;
        if any(~isfinite(smoothed(idx)))
            continue; % Do not infer a trend across an unfilled gap.
        end
        if mean(isfinite(raw(idx))) < p.MinimumMeasuredFraction
            continue;
        end
        gain = smoothed(last)-smoothed(j);
        checkpoints = unique(round(linspace(j,last,min(7,numel(idx)))));
        changes = diff(smoothed(checkpoints));
        risingFraction = mean(changes > 0);
        if gain >= p.MinimumRise_mps && risingFraction >= p.MinimumRisingFraction && ...
                all(changes >= -p.RiseDropTolerance_mps)
            metrics.RiseCandidateTime_s = t(j);
            break; % First confirmed rise beginning inside the selected region
        end
    end

    %% Robust measured candidate and eligible gaps in RAW data
    % Use raw, not filled/smoothed, so interpolation cannot hide a gap.
    % Build a second median envelope from raw measurements only. The helper returns
    % one sustained supported valley plus all eligible raw missing intervals.
    % Raw gaps remain detectable even when filled earlier for envelope smoothing.
    comparison = selectTopCandidates(t, raw, trace.TopRegionMask, p, median(diff(speed)));
    metrics.RobustMinimumCandidateTime_s = comparison.MeasuredMinimumTime_s;
    trace.RobustEnvelope = comparison.RobustEnvelope;

    if ~isempty(comparison.GapIntervals_s)
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

    %% Select top: robust measured candidate OR largest-gap midpoint
    % 'rise' never falls back to a valley or midpoint. For 'hybrid'/'minimum',
    % an eligible gap wins if the valley is absent OR the gap duration exceeds
    % the override limit. Otherwise retain the robust valley. No candidate -> NaN.
    % A midpoint may fall between frames and is not assigned a measured speed.
    if strcmp(p.TopMethod,'rise')
        metrics.TopOfBackswingTime_s = metrics.RiseCandidateTime_s;
        if isfinite(metrics.TopOfBackswingTime_s)
            metrics.TopSource = "rise";
            metrics.TopSelectionReason = "Explicit rise method";
        end
    else
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
        % Discard short motion runs first. In linked mode, traverse the remaining
        % runs backwards from the last. A short discarded run does not reset the
        % gap test; the test measures separation between qualifying run endpoints.
        if strcmp(p.BackswingStartMode, 'first')
            selected = valid(1); % Can include earlier arcs despite a longer gap
        else
            selected = valid(end);
            for k = numel(valid)-1:-1:1
                previous = valid(k);
                gap = t(starts(selected))-t(ends(previous));
                if gap > p.MaximumMotionGap_s
                    break;
                end
                selected = previous;
            end
        end
        startIndex = starts(selected);
        metrics.BackswingStartTime_s = t(startIndex);
        metrics.BackswingTouchesSearchStart = startIndex == find(backSearch,1);
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
    else
        metrics.Status = "Invalid event order";
    end
end

function [starts, ends] = findRuns(mask)
% Locate continuous true runs, including runs touching either edge.
    % Pad with false so edge-touching runs also have an entry/exit transition.
    % +1 is the first true frame; -1 is the frame after the last true frame.
    changes = diff([false mask(:).' false]);
    starts = find(changes == 1);
    ends = find(changes == -1)-1;
end

function result = selectTopCandidates(t, raw, regionMask, p, dv)
%  robust-minimum comparison
% Does not interpolate raw data or replace missing speeds with zero.
% dv is the speed-bin spacing in m/s.
% optional settings below use seconds rather than a fixed number of frames.

% MeasuredMinimumTime_s is a central MEASURED frame of one contiguous
% near-minimum interval. GapMidpoint_s values are separate interpolation
% assumptions, 
    % Normalize orientations so time masks/indexing are row-based and speeds are columns.
    % Positive cluster labels are retained detections; zero/background and -1/noise
    % are ignored. Cluster identities are not tracked through time by this function.
    % Inputs contain radial speeds, not total 3-D club speed or motion direction.
    t = t(:).';
    raw = raw(:).';
    regionMask = logical(regionMask(:).');
    
    dt = median(diff(t));
    
    window_s = option(p,'TopMedianWindow_s',0.015);
    fraction = option(p,'TopMinimumMeasuredFraction',0.60);
    tolerance = option(p,'TopSpeedTolerance_mps',0.5*dv);
    duration_s = option(p,'MinimumValleyDuration_s',0.010);
    gapReport_s = option(p,'MinimumGapReport_s',0.020);
    assert(window_s>0 && fraction>0 && fraction<=1 && tolerance>=0);
    assert(duration_s>0 && gapReport_s>0 && p.TopThreshold_mps>=0);
    % Centered odd window. Derive its length from the actual hop time.
    % Convert seconds to a centered odd frame window (at least three frames).
    n = max(3, 2*floor(window_s/(2*dt))+1);
    measured = isfinite(raw);
    robust = movmedian(raw,n,'omitnan');
    % Denominator is the actual truncated window length at recording edges.
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
% Read an optional field without changing p. Normally outer defaults already exist.
function value = option(p,name,fallback)
    if isfield(p,name), value = p.(name); else, value = fallback; end
end
% Fixed diagnostic schema for both normal execution and early-return paths.
function result = emptyTopComparison(t)
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
    if ~isfield(p,name), p.(name) = value; end
end
