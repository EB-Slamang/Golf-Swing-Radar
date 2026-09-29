%Ebrahiem Slamang
%EEE4022S

function [markerTimes, markerSpeeds, markerClusterIDs, markerColumns] = ...
    SelectClusterMarkers(ClusterMap, Power, speed, t, ClusterGapBins, ...
    FrameStep, UpperEdgeWeight, PowerWeightExponent, WithinClusterMode,MarkerSpeedWidth)
% Reduce each DBSCAN cluster to representative speed-time markers.
% Use linear original power (DisplayPower), not dB.
% WithinClusterMode: 'all_bands' or 'upper_band'.
% Each disconnected speed band in a column is treated separately.
% MarkerSpeedWidth splits each retained band into intervals in m/s.
% More than one marker can be produced per selected time column.
% speed must be in ascending order; Power must be linear and nonnegative.
% Cluster IDs are DBSCAN labels
% FrameStep selects every Kth occupied column in each cluster; the final
% occupied column is also included. 

    speed = speed(:);
    t = t(:);


    markerTimes = [];
    markerSpeeds = [];
    markerClusterIDs = [];
    markerColumns = [];

    % Ignore empty cells (0) and DBSCAN noise (-1).
    clusterIDs = unique(ClusterMap(ClusterMap > 0));

    for clusterID = clusterIDs(:).'
        
        % Sample occupied columns for each ID, always keeping the final column.
        occupiedCols = find(any(ClusterMap == clusterID, 1));
        selectedCols = occupiedCols(1:FrameStep:end);
        selectedCols = unique([selectedCols(:); occupiedCols(end)]);

        for col = selectedCols(:).'

            rows = find(ClusterMap(:,col) == clusterID);

            % Split speed bands instead of averaging across an empty gap.
            % A row jump of K+1 corresponds to K missing speed bins.
            bandStarts = [1; find(diff(rows) > ClusterGapBins + 1) + 1];
            bandEnds = [bandStarts(2:end)-1; numel(rows)];
            
            % upper_band keeps the highest band, then still splits its width.
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
                speedGroup = floor( (bandSpeeds - bandSpeeds(1)) / MarkerSpeedWidth);
            
                groupIDs = unique(speedGroup);
    
                for groupID = groupIDs(:).'
            
                    % Only use detected cells belonging to this speed interval.
                    groupRows = bandRows(speedGroup == groupID);
            
                    groupSpeeds = speed(groupRows);
                    groupPower = Power(groupRows, col);
            
                    
                    % Weight the cells within this interval only.
                    % Normalise before the exponent to keep weights bounded.
                    if max(groupPower) > 0
                        weights = (groupPower / max(groupPower)).^PowerWeightExponent;
                    else
                        % Use equal weights if all powers in the group are zero.
                        weights = ones(size(groupPower));
                    end
                    
                    % Find the power-weighted centre of this speed group.
                    centreSpeed = sum(groupSpeeds .* weights) / sum(weights);
            
                    upperSpeed = max(groupSpeeds);
                    
                    % Blend the centre with the highest detected speed in the group.
                    selectedSpeed = (1-UpperEdgeWeight)*centreSpeed + ...
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
