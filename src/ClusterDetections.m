%Ebrahiem Slamang
%EEE4022S

function [DetectionClustered, ClusterMap] = ClusterDetections( ...
    DetectionMap, speed, t, TimeRadius, SpeedRadius, MinPoints)
% Group detections in speed-time space using DBSCAN.
% Requires Statistics and Machine Learning Toolbox (dbscan).
% TimeRadius is in seconds; SpeedRadius is in m/s.
% MinPoints counts detected cells in a neighbourhood, including the point
% itself. It does not count distinct time frames.
% ClusterMap: 0 = no input detection, -1 = DBSCAN noise, 1,2,... = clusters.
% DetectionClustered keeps all points assigned to clusters, including borders.

    speed = speed(:);
    t = t(:);


    ClusterMap = zeros(size(DetectionMap));
    DetectionClustered = false(size(DetectionMap));

    % Convert candidate cells to speed-time coordinates.
    [rows, cols] = find(DetectionMap);

    if isempty(rows)
        return;
    end

    pointTimes = t(cols);
    pointSpeeds = speed(rows);

    % Scale the two axes separately to define an elliptical neighbourhood.
    points = [(pointTimes - t(1)) / TimeRadius, pointSpeeds / SpeedRadius];

    % Too few detections cannot form a DBSCAN core point.
    if numel(rows) < MinPoints
        labels = -ones(numel(rows), 1);
    else
        % Unit radius in scaled coordinates gives the requested ellipse.
        labels = dbscan(points, 1, MinPoints, 'Distance', 'euclidean');
    end

    % Put each label back at the corresponding detection's matrix location.
    indices = sub2ind(size(DetectionMap), rows, cols);
    ClusterMap(indices) = labels;

    DetectionClustered = ClusterMap > 0;
end
