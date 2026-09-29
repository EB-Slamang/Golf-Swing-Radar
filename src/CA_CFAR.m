%Ebrahiem Slamang
%EEE4022S

function [DetectionMap, Threshold] = CA_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells)
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


