%Ebrahiem Slamang
%EEE4022S

% clear;
% close all;

%% Project Folder setup
projectRoot = fileparts(mfilename('fullpath'));

addpath(fullfile(projectRoot, 'src'));

configFile = fullfile(projectRoot, 'config_local.m');

if ~isfile(configFile)
    error('Create config_local.m from config_local.example.m and set your dataset paths.');
end

% Load the local dataset location without hard-coding it in this script.
run(configFile);

assert(isfolder(dataRoot), 'Dataset folder does not exist: %s', dataRoot);

%% Recording selection
% To process other recordings just uncomment them.
wavFile_CW_All = {
    fullfile('P002', 'session1', 'Driver_FullSwing1.wav')  
    % fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing5.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing6_stoponfollowthru.wav')
    % 
    % fullfile('P002', 'session1', 'Driver_BackSwing1.wav')
    % fullfile('P002', 'session1', 'Driver_BackSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Driver_DownSwing1.wav')
    % fullfile('P002', 'session1', 'Driver_DownSwing2.wav')
    % 
    % fullfile('P002', 'session1', '7Iron_BackSwing1.wav')
    % fullfile('P002', 'session1', '7Iron_BackSwing2.wav')
    % fullfile('P002', 'session1', '7Iron_BackSwing3.wav')
    % 
    % fullfile('P002', 'session1', '7Iron_DownSwing1.wav')
    % fullfile('P002', 'session1', '7Iron_DownSwing2.wav')
    % fullfile('P002', 'session1', '7Iron_DownSwing3.wav')
    % 
    % fullfile('P002', 'session1', '7Iron_Fullswing1_Slow.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing2.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing3.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing4.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing5.wav')
    % fullfile('P002', 'session1', '7Iron_Fullswing6_stoponfollowthru.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_BackSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_BackSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_DownSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_DownSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_FullSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing5.wav')
    % 
    % 
    % fullfile('P002', 'session1', 'Headless1.wav')
    % fullfile('P002', 'session1', 'Headless2.wav')
    % 
    % fullfile('P002', 'session1', 'Ball1.wav')
    % fullfile('P002', 'session1', 'Ball2.wav')
    % fullfile('P002', 'session1', 'Ball3.wav')
    
    
                    };
           

%% radar and spectrogram parameters
fc = 24e9;             %radar centre frequency (Hz)
c = 3e8;               %speed of light (m/s)
lambda = c/fc;         %radar wavelength (m)

CPI = 0.01;            %coherent processing interval (s)
overlapFrac = 0.95;    %overlap between spectrogram frames
maxSpeed = 60;         %maximum speed shown on the plots (m/s)


%% CFAR parameters
PFA = 1e-4;                   %desired probability of false alarm
RefWindowCA = 36;             %CA-CFAR total number of reference cells
GuardCellsCA = 24;            %CA-CFAR guard cells on each side

RefWindowOS = 60;             %OS-CFAR total number of reference cells
GuardCellsOS = 20;            %OS-CFAR guard cells on each side

MinimumDetectionSpeed = 1.5;  % lower speed limit for CFAR and detection plots (m/s) 

% Use more cells above the CUT because the upper side of the club return
% normally has cleaner noise than the lower-speed side and less likely to self-mask.
UseAsymmetricCFAR = true;

AsymmetricMaxSpeed = 60;        % Max speed where asymmetric CFAR is used, symmetric used for higher speeds

LowerRefCellsOS = ceil(0.1*RefWindowOS);  % proportion of total ref cells used for ref cells below CUT
LowerRefCellsCA = ceil(0.1*RefWindowCA);

UseOSCFAR =  true;             % True to use OS-CFAR for clustering computation

Rank = ceil(0.3* RefWindowOS); % OS CFAR parameter for kth smallest detection

%% detection cleaning parameters
MinimumDetectionPowerDB = -35; % minimum power used to filter out lower power noise (dB)

%% Marker reduction after DBSCAN clusters

ClusterGapBins = 2; % maximum missing speed bins allowed within one band when creating markers

% 0 gives the cluster centre and 1 gives its upper edge
UpperEdgeWeight = 0.3; % Weight used to determine how markers are position in speed groups

%larger values pull the centroid towards the stronger bins
PowerWeightExponent = 10;   %exponent used to weight marker position relative to higher power bins

MarkerSpeedWidth = 4;   % (m/s) marker group vertical width

FrameStep = 6; % Every nth occupied column, plus each cluster's last column

WithinClusterMode = 'upper_band'; % 'all_bands' Or 'upper_band' for the upper band per cluster

%% DBSCAN Clustering parameters
TimeRadius = 0.002;    % Neighbourhood time radius: 3 ms
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
    % Round the requested CPI up to a power-of-two number of samples.
    % The actual frame duration is framelen/fs, so it may exceed CPI.
    framelen = 2^(nextpow2(round(CPI*fs)));
    n_fft = framelen;

    n = 0:framelen-1;
    win = 0.54 - 0.46*cos(2*pi*n/(framelen-1));     %Hamming window

    [S,f,t] = compute_spectrogram(y,fs,framelen,overlapFrac,win,n_fft);

    f = f(:);
    t = t(:).';

    %% convert Doppler frequency to radial speed
    speed = f*lambda/2;
    
    %% square-law detector
    % Keep original power for display and marker weighting.

    RawPowerData = abs(S).^2;
    
    % Estimate the normal noise level separately for every Doppler bin.
    % The median is used because the golf swing only occupies a small
    % portion of the complete recording.
    NoiseFloorPerBin = median(RawPowerData,2);
    
    % Normalise each Doppler bin by its usual background level.
    PowerData = RawPowerData ./ max(NoiseFloorPerBin,eps); % eps used to avoid Inf error
    
    % Light averaging over time
    % Only three frames are used so that fast transitions are not blurred.
    PowerData = movmean(PowerData,3,2);
    
    [nSpeedBins,nTimeBins] = size(PowerData);

    %% Apply CA-CFAR
    [DetectionMapCA, ThresholdCA] = CA_CFAR(PowerData, speed, ...
    PFA, RefWindowCA, GuardCellsCA, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCellsCA);

    %% Apply OS-CFAR
    [DetectionMapOS, ThresholdOS] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindowOS, GuardCellsOS, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCellsOS, Rank);


    %% select the detector output used for plotting
    if UseOSCFAR
        DetectionMapRaw = DetectionMapOS;
        Threshold = ThresholdOS;
    else
        DetectionMapRaw = DetectionMapCA;
        Threshold = ThresholdCA;
    end
    
    %% speed range used for the plots
    speedRegionMask = speed >= MinimumDetectionSpeed & speed <= maxSpeed;

    displayIdx = find(speedRegionMask);
    DisplaySpeed = speed(displayIdx);

    % Original power is used for plotting and selecting the strongest return.
    DisplayPower = RawPowerData(displayIdx,:);

    % Whitened power is used by CFAR.
    DisplayCFARPower = PowerData(displayIdx,:); 
    DisplayDetectionMapRaw = DetectionMapRaw(displayIdx,:);

    %% normalise and convert to dB for plotting
    % Set the largest original power in this display region to 0 dB.
    normalPower = max(max(DisplayPower(:)),eps);
    DisplayPowerDB = 10*log10(DisplayPower/normalPower + eps);

  
    %% Apply the same power gate to both detectors
    % Keep cells that pass both CFAR and the original-power gate.
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

    %% Cluster detections using DBSCAN
    [DetectionClustered, ClusterMap] = ClusterDetections( ...
        DetectionCandidates, DisplaySpeed, t, ...
        TimeRadius, SpeedRadius, MinPoints);
    
    fprintf('Candidates before clustering: %d\n', nnz(DetectionCandidates));
    
    fprintf('Detections retained in clusters: %d\n', nnz(DetectionClustered));
    
    fprintf('Number of clusters: %d\n', max([0; ClusterMap(:)]));

     %% Display clusters
    figure;
    hold on;

    % Points DBSCAN could not assign to a cluster
    [noiseRows, noiseCols] = find(ClusterMap == -1);

    scatter(t(noiseCols), DisplaySpeed(noiseRows),8, 'kx');

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
    
    % Cluster each detector separately so their marker results are independent.
    candidateMaps = {CandidatesCA, CandidatesOS};
    detectorNames = {'CA-CFAR', 'OS-CFAR'};


    MarkerResults = cell(1,2); % {1} = CA, {2} = OS, current recording
    ClusterMaps = cell(1,2);

    figure;
    comparisonAxes = gobjects(2,1);

    %loop through CFAR detectors and plot Markers onto detections after
    %dbscan
    for detectorIdx = 1:2 
        [~, currentClusterMap] = ClusterDetections( ...
            candidateMaps{detectorIdx}, DisplaySpeed, t, ...
            TimeRadius, SpeedRadius, MinPoints);
        
        %create reduced markers from dbscan clusters
        [markerTimes, markerSpeeds, markerClusterIDs, markerColumns] = ...
            SelectClusterMarkers(currentClusterMap, DisplayPower, ...
                DisplaySpeed, t, ClusterGapBins, FrameStep, ...
                UpperEdgeWeight, PowerWeightExponent, WithinClusterMode, MarkerSpeedWidth);

        ClusterMaps{detectorIdx} = currentClusterMap;
        % Retain cluster labels and original time-column indices for later analysis.
        MarkerResults{detectorIdx} = table(markerTimes, markerSpeeds, ...
            markerClusterIDs, markerColumns, 'VariableNames', ...
            {'Time_s','Speed_mps','ClusterID','TimeColumn'});

        comparisonAxes(detectorIdx) = subplot(2,1,detectorIdx);
        imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
        axis xy;
        hold on;

        % Candidate overlays to show detector results in magenta
        if ShowPowerGatedCandidates
            [candidateRows, candidateCols] = find(candidateMaps{detectorIdx});
            plot(t(candidateCols), DisplaySpeed(candidateRows), 'mx', 'MarkerSize', 2);
        end

        % Plot Markers
        plot(markerTimes,markerSpeeds,'kx','MarkerSize',6,'LineWidth',1);

        title(sprintf('%s: %s reduced markers', wavFile_CW, detectorNames{detectorIdx}), 'Interpreter', 'none');
        xlabel('Time (s)');
        ylabel('Radial speed (m/s)');
        colorbar;

        fprintf('%s: %d clustered cells -> %d markers\n', detectorNames{detectorIdx}, ...
            nnz(currentClusterMap > 0),  numel(markerTimes));
    end
    linkaxes(comparisonAxes, 'xy');
    colormap('jet');

    % Preserve each recording's marker tables if several files are selected.
    AllMarkerResults{i,1} = MarkerResults{1};
    AllMarkerResults{i,2} = MarkerResults{2};
    %% OS-CFAR clusters with reduced markers overlaid
    
    % Reuse the OS results calculated above for this recording.
    osClusterMap = ClusterMaps{2};
    osMarkers = AllMarkerResults{i,2};
    
    
    figure;
    hold on;
    
    % Noise: small grey x's.
    [noiseRows, noiseCols] = find(osClusterMap == -1);
    
    noiseHandle = scatter( ...
        t(noiseCols), DisplaySpeed(noiseRows), ...
        10, [0.6 0.6 0.6], 'x', 'DisplayName', 'DBSCAN noise');

    % Get each cluster ID
    clusterIDs = unique(osClusterMap(osClusterMap > 0));
    colours = lines(numel(clusterIDs));
    
    % Plot each cluster once.
    for k = 1:numel(clusterIDs)
    
        [rows, cols] = find(osClusterMap == clusterIDs(k));
    
        scatter(t(cols), DisplaySpeed(rows),12, colours(k,:), 'filled', ...
            'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
    end
    
    
    markerHandle = plot(osMarkers.Time_s, osMarkers.Speed_mps, ...
        'kx', 'LineStyle', 'none', ...
        'MarkerSize', 6, 'LineWidth', 1.2);
    
    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    
    title(sprintf('%s: OS-CFAR clusters and reduced markers', ...
        wavFile_CW), 'Interpreter', 'none');
    
    legend([noiseHandle, markerHandle], {'DBSCAN noise', 'Reduced OS-CFAR markers'}, ...
        'Location', 'best');
    
    grid on;
    axis tight;
    
    fprintf('OS-CFAR overlay: %d clustered cells -> %d reduced markers\n', ...
        nnz(osClusterMap > 0), height(osMarkers));

 

%% Plot Reduced Markers on Seperate Figure
% Column 2 always contains OS-CFAR results, regardless of UseOSCFAR.
Markers = MarkerResults{2};

figure;

plot(Markers.Time_s, Markers.Speed_mps, 'k.', ...
    'LineStyle', 'none', 'MarkerSize', 6, 'LineWidth', 1);

xlabel('Time (s)');
ylabel('Radial speed (m/s)');
title('OS-CFAR reduced markers');
grid on;



     %% original spectrogram and speed-time plot
    SpectrogramBounds = [-50 0]; %intensity color bounds in dB
    
    % PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    
    PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);

 
end 


