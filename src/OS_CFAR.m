%Ebrahiem Slamang
%EEE4022S

function [DetectionMap, Threshold] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank)
% OS-CFAR using circular reference indexing along the speed rows.
% PowerData must contain finite, nonnegative LINEAR power, not dB.
% RefWindow is the TOTAL reference count; GuardCells is the count PER SIDE.
% Speed limits select CUTs only. References wrap across ALL PowerData rows.
% The theoretical PFA assumes independent exponential noise powers.

    [nSpeedBins, nTimeBins] = size(PowerData);
    speed = speed(:);



    % Keep reference cells, guards and CUT within array range
    assert(RefWindow + 2*GuardCells + 1 <= nSpeedBins, ...
        'PowerData needs at least RefWindow + 2*GuardCells + 1 speed rows.');

    DetectionMap = false(nSpeedBins, nTimeBins);
    Threshold = nan(nSpeedBins, nTimeBins);


    % PFA = product((RefWindow-i)/(RefWindow-i+alpha)), i = 0:Rank-1.
    % Solve in log form once
    i = 0:(Rank - 1);

    thresholdEquation = @(a) ...
        sum(log((RefWindow - i) ./ (RefWindow - i + a))) - log(PFA);

    upperBound = 1;
    while thresholdEquation(upperBound) > 0
        upperBound = 2*upperBound;
    end

    alpha = fzero(thresholdEquation, [0 upperBound]);

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
     if nLower > availableLower || nUpper > availableUpper
        continue;
     end


    % % Reference positions relative to the selected speed range.
    % lowerLocal = (localIdx - GuardCells - nLower): (localIdx - GuardCells - 1);
    % 
    % upperLocal = (localIdx + GuardCells + 1): (localIdx + GuardCells + nUpper);

    if nLower == 0

        upperIdx = (speedIdx + GuardCells + 1):(speedIdx + GuardCells + nUpper);

        referenceCells = PowerData(upperIdx, :);

    else
        lowerIdx = (speedIdx - GuardCells - nLower):(speedIdx - GuardCells - 1);

        upperIdx = (speedIdx + GuardCells + 1):(speedIdx + GuardCells + nUpper);

        referenceCells = PowerData([lowerIdx(:); upperIdx(:)], :);
    end



    % Wrap within the selected range only.
    % lowerLocal = mod(lowerLocal - 1, nSelectedBins) + 1;
    % upperLocal = mod(upperLocal - 1, nSelectedBins) + 1;

    % Convert wrapped positions back into original PowerData row indices.
    % lowerIdx = speedIdxs(lowerLocal);
    % upperIdx = speedIdxs(upperLocal);

     % Pool both sides, then sort each time column independently.
     % referenceCells = PowerData([lowerIdx(:); upperIdx(:)], :);
     sortedReferenceCells = sort(referenceCells, 1, 'ascend');
     referenceLevel = sortedReferenceCells(Rank, :);
     Threshold(speedIdx, :) = alpha * referenceLevel;



    DetectionMap(speedIdx, :) = PowerData(speedIdx, :) >= Threshold(speedIdx, :);



    end


end


% function [DetectionMap, Threshold] = OS_CFAR(PowerData, speed, ...
%     PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
%     UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank)
% % OS-CFAR using circular reference indexing along the speed rows.
% % PowerData must contain finite, nonnegative LINEAR power, not dB.
% % RefWindow is the TOTAL reference count; GuardCells is the count PER SIDE.
% % Speed limits select CUTs only. References wrap across ALL PowerData rows.
% % The theoretical PFA assumes independent exponential noise powers.
% 
%     [nSpeedBins, nTimeBins] = size(PowerData);
%     speed = speed(:);
% 
% 
%     % Keep reference cells, guards and CUT distinct after circular wrapping.
%     assert(RefWindow + 2*GuardCells + 1 <= nSpeedBins, ...
%         'PowerData needs at least RefWindow + 2*GuardCells + 1 speed rows.');
% 
%     DetectionMap = false(nSpeedBins, nTimeBins);
%     Threshold = nan(nSpeedBins, nTimeBins);
% 
% 
%     % PFA = product((RefWindow-i)/(RefWindow-i+alpha)), i = 0:Rank-1.
%     % Solve in log form 
% 
%     i = 0:(Rank - 1);
% 
%     thresholdEquation = @(a) ...
%         sum(log((RefWindow - i) ./ (RefWindow - i + a))) - log(PFA);
% 
%     upperBound = 1;
%     while thresholdEquation(upperBound) > 0
%         upperBound = 2*upperBound;
%     end
% 
%     alpha = fzero(thresholdEquation, [0 upperBound]);
% 
%     speedIdxs = find(speed >= MinimumDetectionSpeed & speed <= maxSpeed);
% 
%     for speedIdx = speedIdxs(:).'
%         if UseAsymmetricCFAR && speed(speedIdx) <= AsymmetricMaxSpeed
%             nLower = LowerRefCells;
%             nUpper = RefWindow - nLower;
%         else
%             nLower = RefWindow/2;
%             nUpper = RefWindow/2;
%         end
% 
%         % Indices before wrapping (may lie outside 1:nSpeedBins).
%         lowerIdx = (speedIdx - GuardCells - nLower): (speedIdx - GuardCells - 1);
%         upperIdx = (speedIdx + GuardCells + 1): (speedIdx + GuardCells + nUpper);
% 
%         % Wrap around the full speed axis, separately within each time column.
%         % A side with zero reference cells remains an empty index vector.
%         lowerIdx = mod(lowerIdx - 1, nSpeedBins) + 1;
%         upperIdx = mod(upperIdx - 1, nSpeedBins) + 1;
% 
%         % Pool both sides, then sort each time column independently.
%         referenceCells = PowerData([lowerIdx upperIdx], :);
%         sortedReferenceCells = sort(referenceCells, 1, 'ascend');
%         referenceLevel = sortedReferenceCells(Rank, :);
%         Threshold(speedIdx, :) = alpha * referenceLevel;
% 
%         DetectionMap(speedIdx, :) = ...
%             PowerData(speedIdx, :) >= Threshold(speedIdx, :);
%     end
% end
