%Ebrahiem Slamang
%EEE4022S

function [DetectionMap, Threshold] = CA_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells)
% CA_CFAR - Adaptive detection down speed rows, separately in each time column.
%
% PowerData is a speed/frequency-row by time-column matrix of LINEAR power.
% Its row order must match the ascending speed vector in m/s. This function
% returns two matrices of the same shape: DetectionMap (logical crossings)
% and Threshold (linear-power threshold; NaN means the CUT was not tested).
%
% PFA is a nominal probability under independent, homogeneous exponential
% background powers. RefWindow is total reference count; GuardCells is per side.
% The selected speed limits restrict both the CUT and its reference rows.
% UseAsymmetricCFAR requests LowerRefCells below and the remainder above a CUT
% at or below AsymmetricMaxSpeed. Otherwise half are requested on each side.
% Use an even RefWindow when a symmetric allocation can be selected.
%
% Near a selected-band boundary, missing references move to the opposite side.
% If the total still cannot fit, the row remains untested: no wrapping occurs.
% The final comparison is inclusive (power >= threshold). Input conditioning
% and correlation can change achieved PFA; verify empirically with Test_CFAR.
% Apply CA-CFAR to each time column using linear power, not dB.
% CUT = cell under test; RefWindow is the total reference count.
% GuardCells is the number of excluded cells on EACH side of the CUT.
% References stay within the selected speed range; they do not wrap.
% Threshold is NaN where a CUT is outside the range or cannot be tested.

    [nSpeedBins, nTimeBins] = size(PowerData);
    speed = speed(:);



    % Check the full array can fit the nominal reference and guard window.
    assert(RefWindow + 2*GuardCells + 1 <= nSpeedBins, ...
        'PowerData needs at least RefWindow + 2*GuardCells + 1 speed rows.');

    DetectionMap = false(nSpeedBins, nTimeBins);
    % Untested cells remain false, with no threshold value.
    Threshold = nan(nSpeedBins, nTimeBins);

    % CFAR constant for the sum of RefWindow reference powers.
    % CA uses the SUM of reference powers below. Therefore its factor is
    % PFA^(-1/N)-1. If a MEAN were used instead, the factor would be N times as
    % large. These two conventions yield the same threshold when used correctly.
    alpha = PFA^(-1/RefWindow) - 1;

    % Both CUTs and reference cells are restricted to this speed range.
    speedIdxs = find(speed >= MinimumDetectionSpeed & speed <= maxSpeed);

    nSelectedBins = numel(speedIdxs);

    for localIdx = 1:nSelectedBins

    % Convert the position within the selected range into a PowerData row.
    speedIdx = speedIdxs(localIdx);

    % Choose how many reference cells to use on each side.
    if UseAsymmetricCFAR && speed(speedIdx) <= AsymmetricMaxSpeed
        nLower = LowerRefCells;
        nUpper = RefWindow - nLower;
    else
        nLower = RefWindow/2;
        nUpper = RefWindow/2;
    end

    % Count usable cells after excluding guards at the selected speed limits.
    availableLower = max(0,  speedIdx - speedIdxs(1) - GuardCells);
    availableUpper = max(0, speedIdxs(end) - speedIdx - GuardCells);

    % Move missing reference cells to the opposite side near speed limits.
     if nLower > availableLower
        nUpper = nUpper + (nLower - availableLower);
        nLower = availableLower;
     end
     if nUpper > availableUpper
        nLower = nLower + (nUpper - availableUpper);
        nUpper = availableUpper;
     end
     % Skip this CUT if both sides together cannot provide enough cells.
     if nLower > availableLower || nUpper > availableUpper
        continue;
     end

    % Leave guard cells out of the noise estimate.
    if nLower == 0

        upperIdx = (speedIdx + GuardCells + 1):(speedIdx + GuardCells + nUpper);

        referencePower = sum(PowerData(upperIdx, :),1);
    else
        lowerIdx = (speedIdx - GuardCells - nLower):(speedIdx - GuardCells - 1);

        upperIdx = (speedIdx + GuardCells + 1):(speedIdx + GuardCells + nUpper);

        referencePower = sum(PowerData(lowerIdx(:), :), 1) + sum(PowerData(upperIdx(:), :), 1);
    end

  
    Threshold(speedIdx, :) = alpha * referencePower;
    % Compare this speed row against its threshold in every time frame.
    DetectionMap(speedIdx, :) = PowerData(speedIdx, :) >= Threshold(speedIdx, :);



    end

end


