function TestDetectSwingEvents
% Synthetic logic tests. Run from the update/project folder in MATLAB.
% These test event rules; they do not validate real swing biomechanics.
    addpath(fullfile(fileparts(mfilename('fullpath')),'src'));
    p.MotionThreshold_mps = 2;
    p.MinimumMotionDuration_s = 0.03;
    p.BackswingSearchWindow_s = 1.5;
    p.BackswingStartMode = 'first';
    p.MaximumMotionGap_s = 0.05;
    p.TopThreshold_mps = 4;
    p.MinimumTopDuration_s = 0.05;
    p.TopSearchWindow_s = 1.5;
    p.TopMethod = 'minimum';
    p.MaxInterpolationGap_s = 0.03;
    p.MaxTopGap_s = 0.15;
    p.MedianFilterFrames = 1;
    p.MovingAverageFrames = 1;
    p.PeakSearchHalfWidth_s = 0.04;
    p.RiseWindow_s = 0.06;
    p.MinimumRise_mps = 1.5;
    p.MinimumRisingFraction = 0.70;
    p.RiseDropTolerance_mps = 0.10;
    p.MinimumMeasuredFraction = 0.50;

    t = (0:300)/100;
    v = 1.5*ones(size(t));
    v(51:71) = 6;  % First backswing arc: 0.50-0.70 s
    v(76:96) = 9;  % Second arc: 0.75-0.95 s
    v(121:126) = 3; % Small ridge within the low-speed interval
    v(142:171) = linspace(1.6,30,30);
    v(172:end) = 8; % Keep post-peak motion out of the top search
    [map,speed] = makeMap(v);
    [m,d] = DetectSwingEvents(map,speed,t,p);
    assert(abs(m.BackswingStartTime_s-0.50) < 1e-9);
    assert(abs(m.MinimumCandidateTime_s-0.96) < 1e-9);
    assert(m.MinimumTieCount > 1);
    assert(m.TopOfBackswingTime_s < m.PeakSpeedTime_s);
    assert(isfinite(m.RiseCandidateTime_s));
    assert(abs(m.BackswingDuration_s+m.DownswingDuration_s - ...
        (m.PeakSpeedTime_s-m.BackswingStartTime_s)) < 1e-9);

    % Short gaps fill; larger gaps and missing edges remain unknown.
    gapV = v;
    gapV(1:3) = NaN;
    gapV(106:108) = NaN;
    gapV(130:137) = NaN;
    [map,speed] = makeMap(gapV);
    [m,d] = DetectSwingEvents(map,speed,t,p);
    assert(all(d.InterpolatedMask(106:108)));
    assert(all(isnan(d.SmoothedEnvelope(130:137))));
    assert(all(isnan(d.FilledEnvelope(1:3))));
    assert(all(d.TopRegionMask(130:137))); % Grouping is NOT interpolation
    assert(m.TopUsesMissingData);

    % The bounded earliest-run rule includes an earlier arc despite a long gap.
    ridgeV = v;
    ridgeV(97:106) = 1.5;
    ridgeV(108:113) = 6;
    [map,speed] = makeMap(ridgeV);
    mFirst = DetectSwingEvents(map,speed,t,p);
    p.BackswingStartMode = 'linked';
    mLinked = DetectSwingEvents(map,speed,t,p);
    assert(mFirst.BackswingStartTime_s < mLinked.BackswingStartTime_s);
    p.BackswingStartMode = 'first';

    % Column time input is accepted; rise mode has no silent minimum fallback.
    p.TopMethod = 'rise';
    [map,speed] = makeMap(v);
    m = DetectSwingEvents(map,speed,t(:),p);
    assert(m.TopOfBackswingTime_s == m.RiseCandidateTime_s);
    p.MinimumRise_mps = 100;
    m = DetectSwingEvents(map,speed,t,p);
    assert(isnan(m.TopOfBackswingTime_s) && isnan(m.TempoRatio));

    % Empty detections and absence of any slow region must not throw errors.
    [m,d] = DetectSwingEvents(zeros(1,numel(t)),1.5,t,p);
    assert(isnan(m.PeakSpeedTime_s) && all(isnan(d.RawEnvelope)));
    m = DetectSwingEvents(ones(1,numel(t)),10,t,p);
    assert(isnan(m.TopOfBackswingTime_s));
    disp('Synthetic swing-detection tests passed.');
end

function [map,speed] = makeMap(v)
% Encode a synthetic envelope as a single detected speed in each column.
    speed = unique(v(isfinite(v))).';
    map = zeros(numel(speed),numel(v));
    for k = 1:numel(v)
        if isfinite(v(k))
            map(speed == v(k),k) = 1;
        end
    end
end
