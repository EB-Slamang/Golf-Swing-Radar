% clear;
% close all;
% clc;

%% Project setup
projectRoot = fileparts(mfilename('fullpath'));

addpath(fullfile(projectRoot, 'src'));

configFile = fullfile(projectRoot, 'config_local.m');

if ~isfile(configFile)
    error('Create config_local.m from config_local.example.m and set your dataset paths.');
end

run(configFile);

assert(isfolder(dataRoot), 'Dataset folder does not exist: %s', dataRoot);

%% Recording selection
wavFile_CW_All = {
    fullfile('P002', 'session1', 'Driver_FullSwing1.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing5.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing6_stoponfollowthru.wav')
    % fullfile('P002', 'session1', 'Driver_DownSwing2.wav')
    
    
                    };
            
% wavFile_CW_All = {
%                   % '7Iron_Backswing1.wav';
%                   % '7Iron_Backswing2.wav';
%                   % '7Iron_Backswing3.wav';
%                   % 
%                   % '7Iron_Downswing1.wav';
%                   % '7Iron_Downswing2.wav';
%                   % '7Iron_Downswing3.wav';
% 
%                   % '7Iron_Fullswing1_Slow.wav';
%                   % '7Iron_Fullswing2.wav';
%                   % '7Iron_Fullswing3.wav';
%                   % '7Iron_Fullswing4.wav';
%                   % '7Iron_Fullswing5.wav';
%                   % '7Iron_Fullswing6_stoponfollowthru.wav';
%                   
% 
%                   % 'Driver_BackSwing1.wav';
%                   % 'Driver_BackSwing2.wav';
%                   % 
%                   % 'Driver_DownSwing1.wav';
%                   % 'Driver_DownSwing2.wav';
% 
%                   'Driver_FullSwing1.wav';
%                   % 'Driver_FullSwing2.wav';
%                   % 'Driver_FullSwing3.wav'; 
%                   % 'Driver_FullSwing4.wav';
%                   % 'Driver_FullSwing5.wav';
%                   % 'Driver_FullSwing6_stoponfollowthru.wav';
% 
%                   % 'Wedge_BackSwing1.wav';
%                   % 'Wedge_BackSwing2.wav';
%                   % 
%                   % 'Wedge_DownSwing1.wav';
%                   % 'Wedge_DownSwing2.wav';
%                   % 
%                   % 'Wedge_FullSwing1.wav';
%                   % 'Wedge_FullSwing2.wav';
%                   % 'Wedge_FullSwing3.wav';
%                   % 'Wedge_FullSwing4.wav';
%                   % 'Wedge_FullSwing5.wav';
%                   % 
%                   % 
%                   % 'Driverless1.wav';
%                   % 'Driverless2.wav';
%                   % 
%                   % 'Ball.wav';
%                   % 'Ball2.wav';
%                   % 'Ball3.wav';
%                     };

%% radar and spectrogram parameters
fc = 24e9;             %radar centre frequency (Hz)
c = 3e8;               %speed of light (m/s)
lambda = c/fc;         %radar wavelength (m)

CPI = 0.01;            %coherent processing interval (s)
overlapFrac = 0.95;    %overlap between spectrogram frames
maxSpeed = 60;         %maximum speed shown on the plots (m/s)


%% CFAR parameters
PFA = 1e-4;                 %desired probability of false alarm
RefWindowCA = 36;             %total number of reference cells
GuardCellsCA = 24;            %keeps the wide club return out of the references

RefWindowOS = 48;             %total number of reference cells
GuardCellsOS = 24;            %keeps the wide club return out of the references

MinimumDetectionSpeed = 1.5; %m/s

% Use more cells above the CUT because the upper side of the club return
% normally has cleaner noise than the lower-speed side.
UseAsymmetricCFAR = true;
UseOSCFAR =  true;
AsymmetricMaxSpeed = 60;
LowerRefCells = round(0.1*RefWindowOS);

Rank = ceil(0.75* RefWindowOS); % OS CFAR parameter for kth smallest detection

%% detection cleaning parameters
MinimumDetectionPowerDB = -35;


ClusterGapBins = 2; % Split whenever at least one speed bin is missing

% 0 gives the cluster centre and 1 gives its upper edge
UpperEdgeWeight = 0.3; % Start at the power-weighted centre; 0.9 follows the upper edge

%larger values pull the centroid towards the stronger bins
PowerWeightExponent = 10;

MarkerSpeedWidth = 4;   % m/s: one marker per occupied speed interval

M = 3;                  % Minimum number of supporting time columns
N = 5;                  % Number of time columns in the window; must be odd
ToleranceBins = 2;      % Allowed speed-bin distance above/below the candidate

%% Marker reduction inside DBSCAN clusters
FrameStep = 6; % Every nth occupied column, plus each cluster's last column
WithinClusterMode = 'upper_band'; % 'all_bands' Or 'upper_band' for the upper band per cluster

%% Clustering parameters
TimeRadius = 0.003;    % Neighbourhood time radius: 3 ms
SpeedRadius = 2.0;     % Neighbourhood speed radius: 2 m/s
MinPoints = 4;         % Minimum nearby detected cells for a core point

%% plot settings
SpectrogramBounds = [-50 0];
ShowPowerGatedCandidates = true; % Toggle faint candidate overlays
AllMarkerResults = cell(numel(wavFile_CW_All),2); % CA and OS marker tables

%% process each recording
for i = 1:length(wavFile_CW_All)

    recordingRelativePath = wavFile_CW_All{i};

    wavPath = fullfile(dataRoot, recordingRelativePath);

    assert(isfile(wavPath), 'Recording not found: %s', wavPath);

    % Keep a short filename for plot titles.
    [~, recordingName, recordingExtension] = fileparts(wavPath);
    wavFile_CW = [recordingName recordingExtension];

    fprintf('Loading %s...\n', wavFile_CW);
    [Y, fs] = audioread(wavPath);
    

     % Use the first audio channel as the radar baseband signal
    y = Y(:,1);
    
    %% form the spectrogram
    framelen = 2^(nextpow2(round(CPI*fs)));
    n_fft = framelen;

    n = 0:framelen-1;
    win = 0.54 - 0.46*cos(2*pi*n/(framelen-1));

    [S,f,t] = compute_spectrogram(y,fs,framelen,overlapFrac,win,n_fft);

    f = f(:);
    t = t(:).';

    %% convert Doppler frequency to radial speed
    speed = f*lambda/2;
    
    %% square-law detector
    
    RawPowerData = abs(S).^2;
    
    % Estimate the normal noise level separately for every Doppler bin.
    % The median is used because the golf swing only occupies a small
    % portion of the complete recording.
    NoiseFloorPerBin = median(RawPowerData,2);
    
    % Normalise each Doppler bin by its usual background level.
    PowerData = RawPowerData ./ max(NoiseFloorPerBin,eps); % eps used to avoid Inf error
    
    % Light averaging over time helps connect adjacent detections.
    % Only three frames are used so that fast transitions are not blurred.
    PowerData = movmean(PowerData,3,2);
    
    [nSpeedBins,nTimeBins] = size(PowerData);

    %% Apply CA-CFAR
    [DetectionMapCA, ThresholdCA] = CA_CFAR(PowerData, speed, ...
    PFA, RefWindowCA, GuardCellsCA, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells);

    %% Apply OS-CFAR
    [DetectionMapOS, ThresholdOS] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindowOS, GuardCellsOS, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank);


    %% select the detector output used for plotting
    if UseOSCFAR
        DetectionMapRaw = DetectionMapOS;
        Threshold = ThresholdOS;
    else
        DetectionMapRaw = DetectionMapCA;
        Threshold = ThresholdCA;
    end
    
    %% keep the speed range used for the plots
    speedRegionMask = speed >= MinimumDetectionSpeed & speed <= maxSpeed;

    displayIdx = find(speedRegionMask);
    DisplaySpeed = speed(displayIdx);

    % Original power is used for plotting and selecting the strongest return.
    DisplayPower = RawPowerData(displayIdx,:);

    % Whitened power is used by CFAR.
    DisplayCFARPower = PowerData(displayIdx,:); 
    DisplayDetectionMapRaw = DetectionMapRaw(displayIdx,:);

     %% normalise and convert to dB for plotting
    normalisationPower = max(max(DisplayPower(:)),eps);
    DisplayPowerDB = 10*log10(DisplayPower/normalisationPower + eps);

  
    %% Apply the same power gate to both detectors
    PowerGate = DisplayPowerDB >= MinimumDetectionPowerDB;
    
    CandidatesCA = DetectionMapCA(displayIdx, :) & PowerGate;
    CandidatesOS = DetectionMapOS(displayIdx, :) & PowerGate;

    %% Select detections to cluster
    if UseOSCFAR
        DetectionCandidates = CandidatesOS;
       
            detectorName = 'OS-CFAR';
    else
        DetectionCandidates = CandidatesCA;
        detectorName = 'CA-CFAR';
    end

    %% Cluster detections
    [DetectionClustered, ClusterMap] = ClusterDetections( ...
        DetectionCandidates, DisplaySpeed, t, ...
        TimeRadius, SpeedRadius, MinPoints);
    
    fprintf('Candidates before clustering: %d\n', ...
        nnz(DetectionCandidates));
    
    fprintf('Detections retained in clusters: %d\n', ...
        nnz(DetectionClustered));
    
    fprintf('Number of clusters: %d\n', ...
        max([0; ClusterMap(:)]));

     %% Display clusters
    figure;
    hold on;

    % Points DBSCAN could not assign to a cluster
    [noiseRows, noiseCols] = find(ClusterMap == -1);

    scatter(t(noiseCols), DisplaySpeed(noiseRows), ...
        8, 'kx');

    % Plot each cluster in its own colour
    clusterIDs = unique(ClusterMap(ClusterMap > 0));
    colours = lines(numel(clusterIDs));

    for k = 1:numel(clusterIDs)

        [rows, cols] = find(ClusterMap == clusterIDs(k));

        scatter(t(cols), DisplaySpeed(rows), 12, colours(k,:), 'filled');
    end

    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    title(sprintf('%s: %s clusters', wavFile_CW, detectorName),'Interpreter', 'none');

    grid on;
    axis tight;
    
    %% Compare markers from independently clustered CA and OS detections
    % Keep the selected detector's cluster plot above. Here, build both
    % comparison panels independently 
    candidateMaps = {CandidatesCA, CandidatesOS};
    detectorNames = {'CA-CFAR', 'OS-CFAR'};


    MarkerResults = cell(1,2); % {1} = CA, {2} = OS, current recording
    ClusterMaps = cell(1,2);
    figure;
    comparisonAxes = gobjects(2,1);

    for detectorIdx = 1:2
        [~, currentClusterMap] = ClusterDetections( ...
            candidateMaps{detectorIdx}, DisplaySpeed, t, ...
            TimeRadius, SpeedRadius, MinPoints);

        [markerTimes, markerSpeeds, markerClusterIDs, markerColumns] = ...
            SelectClusterMarkers(currentClusterMap, DisplayPower, ...
                DisplaySpeed, t, ClusterGapBins, FrameStep, ...
                UpperEdgeWeight, PowerWeightExponent, WithinClusterMode, MarkerSpeedWidth);

        ClusterMaps{detectorIdx} = currentClusterMap;
        MarkerResults{detectorIdx} = table(markerTimes, markerSpeeds, ...
            markerClusterIDs, markerColumns, 'VariableNames', ...
            {'Time_s','Speed_mps','ClusterID','TimeColumn'});

        comparisonAxes(detectorIdx) = subplot(2,1,detectorIdx);
        imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
        axis xy;
        hold on;

        % Candidate overlays are optional and faint to keep markers legible.
        if ShowPowerGatedCandidates
            [candidateRows, candidateCols] = find(candidateMaps{detectorIdx});
            plot(t(candidateCols), DisplaySpeed(candidateRows), 'mx', 'MarkerSize', 2);
        end

        % Plot points only: a shared DBSCAN ID is not a fitted trajectory.
        plot(markerTimes,markerSpeeds,'kx','MarkerSize',6,'LineWidth',1);

        title(sprintf('%s: %s reduced markers', wavFile_CW, detectorNames{detectorIdx}), 'Interpreter', 'none');
        xlabel('Time (s)');
        ylabel('Radial speed (m/s)');
        colorbar;

        fprintf('%s: %d clustered cells -> %d markers\n', ...
            detectorNames{detectorIdx}, nnz(currentClusterMap > 0), ...
            numel(markerTimes));
    end
    linkaxes(comparisonAxes, 'xy');
    colormap('jet');

    % Preserve each recording's marker tables if several files are selected.
    AllMarkerResults{i,1} = MarkerResults{1};
    AllMarkerResults{i,2} = MarkerResults{2};
%% OS-CFAR clusters with reduced markers overlaid

% Reuse the OS results calculated above for this recording.
osClusterMap = ClusterMap;
osMarkers = AllMarkerResults{i,2};


figure;
hold on;

% Noise: small grey dots.
[noiseRows, noiseCols] = find(osClusterMap == -1);

noiseHandle = scatter( ...
    t(noiseCols), DisplaySpeed(noiseRows), ...
    10, [0.6 0.6 0.6], 'x', ...
    'DisplayName', 'DBSCAN noise');
% Get each cluster ID once.
clusterIDs = unique(osClusterMap(osClusterMap > 0));
colours = lines(numel(clusterIDs));

% Plot each cluster once.
for k = 1:numel(clusterIDs)

    [rows, cols] = find(osClusterMap == clusterIDs(k));

    scatter(t(cols), DisplaySpeed(rows), ...
        12, colours(k,:), 'filled', ...
        'MarkerFaceAlpha', 0.25, ...
        'HandleVisibility', 'off');
end


markerHandle = plot(osMarkers.Time_s, osMarkers.Speed_mps, ...
    'kx', 'LineStyle', 'none', ...
    'MarkerSize', 6, 'LineWidth', 1.2);

xlabel('Time (s)');
ylabel('Radial speed (m/s)');

title(sprintf('%s: OS-CFAR clusters and reduced markers', ...
    wavFile_CW), 'Interpreter', 'none');

legend([noiseHandle, markerHandle], ...
    {'DBSCAN noise', 'Reduced OS-CFAR markers'}, ...
    'Location', 'best');

grid on;
axis tight;

fprintf('OS-CFAR overlay: %d clustered cells -> %d reduced markers\n', ...
    nnz(osClusterMap > 0), height(osMarkers));
     %% original spectrogram and speed-time plot
    SpectrogramBounds = [-50 0]; %intensity color bounds in dB
    
    % PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    
    % PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);

 
end 


