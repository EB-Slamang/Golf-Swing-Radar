%Ebrahiem Slamang
%EEE4022S

function [DetectionClustered, ClusterMap] = ClusterDetections( ...
    DetectionMap, speed, t, TimeRadius, SpeedRadius, MinPoints)
% CLUSTERDETECTIONS - Group candidate cells using DBSCAN in scaled time-speed space.
%
% INPUTS: DetectionMap is logical (speed rows by time columns); speed is in m/s;
% t is in seconds. TimeRadius and SpeedRadius are positive scales; MinPoints
% is the minimum neighbourhood population, counting the tested cell itself.
%
% OUTPUTS: DetectionClustered is true for retained core/border points. ClusterMap
% stores 0 for cells never offered to DBSCAN, -1 for rejected input points, and
% positive integers for clusters. Cluster identities are not physical object IDs.
%
% All positive labels are retained; this function does not select one club-head
% cluster or estimate events. Statistics and Machine Learning Toolbox is required
% for dbscan when enough candidate points exist to attempt clustering.
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
    % Dividing each coordinate by its own scale makes the distance dimensionless.
    % With epsilon=1, a neighbour satisfies (deltaTime/TimeRadius)^2 +
    % (deltaSpeed/SpeedRadius)^2 <= 1. These are ellipse semi-axes in physical units.
    % Subtracting t(1) only changes the origin, not any pairwise time distance.
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
