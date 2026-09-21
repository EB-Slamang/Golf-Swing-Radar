function [DetectionMap, Threshold] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank)

    [nSpeedBins, nTimeBins] = size(PowerData);

    DetectionMap = false(nSpeedBins, nTimeBins);
    Threshold = nan(nSpeedBins, nTimeBins);

    % Check the parameters needed for threshold calculation
    assert(PFA > 0 && PFA < 1, 'PFA must be between 0 and 1.');
    assert(Rank >= 1 && Rank <= RefWindow && Rank == floor(Rank), ...
        'Rank must be an integer between 1 and RefWindow.');

    % OS-CFAR requires its own threshold scaling factor.
    % Solve the theoretical false-alarm equation in logarithmic form.
    j = (RefWindow - Rank + 1):RefWindow;

    thresholdEquation = @(a) ...
        sum(log(j ./ (j + a))) - log(PFA);

    upperBound = 1;

    while thresholdEquation(upperBound) > 0
        upperBound = 2 * upperBound;
    end

    alpha = fzero(thresholdEquation, [0 upperBound]);

    % Select speed bins to test
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

        % Collect reference powers from both sides
        referenceCells = PowerData([lowerIdx upperIdx], :);

        % Sort each time column from smallest to largest power
        sortedReferenceCells = sort(referenceCells, 1, 'ascend');

        % Select the Rank-th smallest power in each time column
        referenceLevel = sortedReferenceCells(Rank, :);

        % Calculate the threshold and test the CUT
        Threshold(speedIdx, :) = alpha * referenceLevel;

        DetectionMap(speedIdx, :) = ...
            PowerData(speedIdx, :) >= Threshold(speedIdx, :);
    end
end