%Ebrahiem Slamang
%EEE4022S

function [DetectionMap, Threshold] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank)
    % Apply OS-CFAR to each time column using linear power, not dB.
    % CUT = cell under test; RefWindow is the total reference count.
    % GuardCells is the number of excluded cells on EACH side of the CUT.
    % Rank selects the kth smallest reference power, starting at 1.
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


    % PFA = product((RefWindow-i)/(RefWindow-i+alpha)), i = 0:Rank-1.
    % Use a sum of logs to avoid multiplying many small fractions.
    % Solved in log form
    i = 0:(Rank - 1);

    thresholdEquation = @(a) sum(log((RefWindow - i) ./ (RefWindow - i + a))) - log(PFA);
    
    % Double the upper bound until the root is bracketed for fzero.
    upperBound = 1;
    while thresholdEquation(upperBound) > 0
        upperBound = 2*upperBound;
    end
    
    % Solve for the threshold multiplier once, before processing the CUTs.
    alpha = fzero(thresholdEquation, [0 upperBound]);

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

     availableLower = max(0,  speedIdx - speedIdxs(1) - GuardCells);
     availableUpper = max(0, speedIdxs(end) - speedIdx - GuardCells);
        
     % Move missing reference cells to the opposite side near speed limits.
     %if # num of available bins in lower or upper ref cells is 
     % < assigned ref cells, adjust ref cells to above/below CUT 

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

        referenceCells = PowerData(upperIdx, :);

    else
        lowerIdx = (speedIdx - GuardCells - nLower):(speedIdx - GuardCells - 1);

        upperIdx = (speedIdx + GuardCells + 1):(speedIdx + GuardCells + nUpper);

        referenceCells = PowerData([lowerIdx(:); upperIdx(:)], :);
    end


    % Pool both sides, then sort each time column independently.
    sortedReferenceCells = sort(referenceCells, 1, 'ascend');
    % Take the kth smallest power independently in each time frame.
    referenceLevel = sortedReferenceCells(Rank, :);
    Threshold(speedIdx, :) = alpha * referenceLevel;

     % Compare this speed row against its threshold in every time frame.
    DetectionMap(speedIdx, :) = PowerData(speedIdx, :) >= Threshold(speedIdx, :);

    end


end


