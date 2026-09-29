function [markerTimes, markerSpeeds, markerClusterIDs, markerColumns] = ...
    SelectClusterMarkers(ClusterMap, Power, speed, t, ClusterGapBins, ...
    FrameStep, UpperEdgeWeight, PowerWeightExponent, WithinClusterMode,MarkerSpeedWidth)
% Reduce each DBSCAN cluster to representative speed-time markers.
% Use linear original power (DisplayPower), not dB.
% WithinClusterMode: 'all_bands' or 'upper_band'.
% Each disconnected speed band in a column is treated separately.
% Cluster IDs are DBSCAN labels
% FrameStep selects every Kth occupied column in each cluster; the final
% occupied column is also included. 

    speed = speed(:);
    t = t(:);

    assert(isequal(size(ClusterMap), size(Power)), ...
        'ClusterMap and Power must have the same size.');
    assert(size(ClusterMap,1) == numel(speed) && ...
           size(ClusterMap,2) == numel(t), ...
        'Inputs must have speed rows and time columns.');
    assert(all(diff(speed) > 0) && all(diff(t) > 0), ...
        'Speed and time must be strictly increasing.');
    validateattributes(ClusterGapBins, {'numeric'}, ...
        {'scalar','integer','nonnegative'});
    validateattributes(FrameStep, {'numeric'}, ...
        {'scalar','integer','positive'});
    validateattributes(UpperEdgeWeight, {'numeric'}, ...
        {'scalar','real','finite','>=',0,'<=',1});
    validateattributes(PowerWeightExponent, {'numeric'}, ...
        {'scalar','real','finite','positive'});
    assert(any(strcmp(WithinClusterMode, {'all_bands','upper_band'})), ...
        'WithinClusterMode must be all_bands or upper_band.');

    markerTimes = [];
    markerSpeeds = [];
    markerClusterIDs = [];
    markerColumns = [];

    clusterIDs = unique(ClusterMap(ClusterMap > 0));

    for clusterID = clusterIDs(:).'

        occupiedCols = find(any(ClusterMap == clusterID, 1));
        selectedCols = occupiedCols(1:FrameStep:end);
        selectedCols = unique([selectedCols(:); occupiedCols(end)]);

        for col = selectedCols(:).'

            rows = find(ClusterMap(:,col) == clusterID);

            % Split speed bands instead of averaging across an empty gap.
            bandStarts = [1; find(diff(rows) > ClusterGapBins + 1) + 1];
            bandEnds = [bandStarts(2:end)-1; numel(rows)];

            if strcmp(WithinClusterMode, 'upper_band')
                bandsToUse = numel(bandStarts);
            else
                bandsToUse = 1:numel(bandStarts);
            end

            for band = bandsToUse

    bandRows = rows(bandStarts(band):bandEnds(band));
    bandSpeeds = speed(bandRows);

    % Divide this connected band into smaller speed intervals.
    % Intervals start at the lowest detected speed in this band.
    speedGroup = floor( ...
        (bandSpeeds - bandSpeeds(1)) / MarkerSpeedWidth);

    groupIDs = unique(speedGroup);

    for groupID = groupIDs(:).'

        % Only use detected cells belonging to this speed interval.
        groupRows = bandRows(speedGroup == groupID);

        groupSpeeds = speed(groupRows);
        groupPower = Power(groupRows, col);

        assert(all(isfinite(groupPower) & groupPower >= 0), ...
            'Power must be finite, nonnegative linear power.');

        % Weight the cells within this interval only.
        if max(groupPower) > 0
            weights = ...
                (groupPower / max(groupPower)).^PowerWeightExponent;
        else
            weights = ones(size(groupPower));
        end

        centreSpeed = ...
            sum(groupSpeeds .* weights) / sum(weights);

        upperSpeed = max(groupSpeeds);

        selectedSpeed = ...
            (1-UpperEdgeWeight)*centreSpeed + ...
            UpperEdgeWeight*upperSpeed;

        % Store one marker for this occupied speed interval.
        markerTimes(end+1,1) = t(col);
        markerSpeeds(end+1,1) = selectedSpeed;
        markerClusterIDs(end+1,1) = clusterID;
        markerColumns(end+1,1) = col;
    end
end
        end
    end
end
