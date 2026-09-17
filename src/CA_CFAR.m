function [DetectionMap, Threshold] = CA_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells)

    [nSpeedBins, nTimeBins] = size(PowerData);

    DetectionMap = false(nSpeedBins, nTimeBins);
    Threshold = nan(nSpeedBins, nTimeBins);

    % Scaling factor for the SUM of reference-cell powers
    alpha = PFA^(-1/RefWindow) - 1;

    speedIdxs = find(speed >= MinimumDetectionSpeed & speed <= maxSpeed);

    for speedIdx = speedIdxs(:).'

        % Choose reference cells on each side
        if UseAsymmetricCFAR && speed(speedIdx) <= AsymmetricMaxSpeed
            nLower = LowerRefCells;
            nUpper = RefWindow - nLower;
        else
            nLower = RefWindow/2;
            nUpper = RefWindow/2;
        end

        % Available cells outside the guard region
        availableLower = max(0, speedIdx - GuardCells - 1);
        availableUpper = max(0, nSpeedBins - speedIdx - GuardCells);

        % Move unavailable reference cells to the opposite side
        if nLower > availableLower
            nUpper = nUpper + (nLower - availableLower);
            nLower = availableLower;
        end

        if nUpper > availableUpper
            nLower = nLower + (nUpper - availableUpper);
            nUpper = availableUpper;
        end

        if nLower > availableLower || nUpper > availableUpper
            continue;
        end

        % Reference-cell indices
        lowerIdx = (speedIdx - GuardCells - nLower): ...
                   (speedIdx - GuardCells - 1);

        upperIdx = (speedIdx + GuardCells + 1): ...
                   (speedIdx + GuardCells + nUpper);

        % Sum reference powers for every time column
        referencePower = sum(PowerData(lowerIdx, :), 1) + ...
                         sum(PowerData(upperIdx, :), 1);

        Threshold(speedIdx, :) = alpha * referencePower;

        DetectionMap(speedIdx, :) = ...
            PowerData(speedIdx, :) >= Threshold(speedIdx, :);
    end
end