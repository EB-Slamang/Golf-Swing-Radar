function [metrics, trace] = DetectSwingEvents(clusterMap, speed, t, p)
% Detect one dominant swing from clustered speed-time detections.
% Inputs: clusterMap (speed rows x time columns), speed (m/s), t (s).
% p is the parameter structure in the calling script. No extra toolbox needed.
% metrics contains event times and durations; trace contains diagnostic arrays.
% A detected top is a radar candidate, not a video-validated turnaround.

    t = t(:).';
    speed = speed(:);
    assert(numel(t) >= 2 && all(isfinite(t)) && all(diff(t) > 0), ...
        't must contain at least two finite, increasing times.');
    assert(isequal(size(clusterMap), [numel(speed), numel(t)]), ...
        'clusterMap must have one row per speed and one column per time.');
    assert(all(isfinite(speed)), 'speed must be finite.');
    dt = median(diff(t));
    assert(max(abs(diff(t)-dt)) < 0.01*dt, 'Time frames must be uniformly spaced.');
    assert(any(strcmp(p.TopMethod, {'minimum','rise'})), 'Unknown TopMethod.');
    assert(any(strcmp(p.BackswingStartMode, {'first','linked'})), ...
        'Unknown BackswingStartMode.');

    %% Extract the highest clustered speed in each time frame
    raw = nan(size(t));
    for k = 1:numel(t)
        rows = find(clusterMap(:,k) > 0);
        if ~isempty(rows)
            raw(k) = max(speed(rows));
        end
    end

    %% Fill short INTERNAL gaps only; never extrapolate recording edges
    filled = raw;
    interpolated = false(size(t));
    [starts, ends] = findRuns(isnan(raw));
    for k = 1:numel(starts)
        a = starts(k); b = ends(k);
        gapDuration = (b-a+1)*dt;
        if a > 1 && b < numel(t) && gapDuration <= p.MaxInterpolationGap_s + 1e-9
            filled(a:b) = interp1(t([a-1 b+1]), raw([a-1 b+1]), t(a:b), 'linear');
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

    names = {'PeakRadialSpeed_mps','PeakSpeedTime_s','RawPeakTime_s', ...
        'TopOfBackswingTime_s','BackswingStartTime_s','BackswingDuration_s', ...
        'DownswingDuration_s','TempoRatio','MinimumCandidateTime_s', ...
        'RiseCandidateTime_s','TopRegionStartTime_s','TopRegionEndTime_s', ...
        'BackswingSearchStartTime_s'};
    for k = 1:numel(names)
        metrics.(names{k}) = NaN;
    end
    metrics.TopMethod = string(p.TopMethod);
    metrics.TopUsesMissingData = false;
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
    if ~any(isfinite(smoothed))
        return;
    end

    %% Locate the smoothed peak, but measure amplitude on the RAW envelope
    measured = find(isfinite(raw) & isfinite(smoothed));
    [~, localPeak] = max(smoothed(measured));
    peakIndex = measured(localPeak);
    metrics.PeakSpeedTime_s = t(peakIndex);
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

    if strcmp(p.TopMethod, 'minimum')
        metrics.TopOfBackswingTime_s = metrics.MinimumCandidateTime_s;
    else
        metrics.TopOfBackswingTime_s = metrics.RiseCandidateTime_s;
    end

    %% Search backwards from the START of the slow region, within a fixed window
    % Keep this anchor independent of the minimum/rise choice.
    searchStart = max(t(1), t(a)-p.BackswingSearchWindow_s);
    backSearch = t >= searchStart & t < t(a);
    trace.BackswingSearchMask = backSearch;
    metrics.BackswingSearchStartTime_s = searchStart;
    motion = isfinite(smoothed) & smoothed >= p.MotionThreshold_mps & backSearch;
    [starts, ends] = findRuns(motion);
    valid = find((ends-starts+1)*dt >= p.MinimumMotionDuration_s - 1e-9);
    if ~isempty(valid)
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
    if ~isfinite(metrics.TopOfBackswingTime_s)
        metrics.Status = "Selected top method found no candidate";
    elseif ~isfinite(metrics.BackswingStartTime_s)
        metrics.Status = "No sustained backswing motion";
    elseif metrics.BackswingStartTime_s < metrics.TopOfBackswingTime_s && ...
            metrics.TopOfBackswingTime_s < metrics.PeakSpeedTime_s
        metrics.BackswingDuration_s = metrics.TopOfBackswingTime_s - metrics.BackswingStartTime_s;
        metrics.DownswingDuration_s = metrics.PeakSpeedTime_s - metrics.TopOfBackswingTime_s;
        metrics.TempoRatio = metrics.BackswingDuration_s / metrics.DownswingDuration_s;
        metrics.Status = "Candidate events found; verify against video";
    else
        metrics.Status = "Invalid event order";
    end
end

function [starts, ends] = findRuns(mask)
% Locate continuous true runs, including runs touching either edge.
    changes = diff([false mask(:).' false]);
    starts = find(changes == 1);
    ends = find(changes == -1)-1;
end
