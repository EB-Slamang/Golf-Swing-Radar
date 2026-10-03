%Ebrahiem Slamang
%EEE4022S

clear;
close all;

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
    % fullfile('P001', 'session1', 'BackgroundTest.wav')
    %  fullfile('P001', 'session1', 'Driver_FullSwing_Test1_1_5m.wav')
     % fullfile('P001', 'session1', 'Driver_FullSwing_Test1_2m.wav')
     % fullfile('P001', 'session1', 'Driver_FullSwing_Test2_2m.wav')
     % fullfile('P001', 'session1', '7Iron_FullSwing_Test1_2m.wav')
     % fullfile('P001', 'session1', '7Iron_FullSwing_Test2_2m.wav')
     
    fullfile('P002', 'session1', 'Driver_FullSwing1.wav')  
    fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
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

%% Marker Swing Phase Detection Parameters

MotionThreshold_mps = 2;
TopThreshold_mps = 4.0;

MinimumMotionDuration_s = 0.03;
MinimumTopDuration_s = 0.05;
MaximumMotionGap_s = 0.05; % Allow a short gap between backswing arcs

TopSearchWindow_s = 1.5;

MedianFilterFrames = 3;
MovingAverageFrames = 3;

PeakSearchHalfWidth_s = 0.04;

DownswingThreshold_mps = 4.0;       % Speed required to accept downswing motion
MinimumDownswingDuration_s = 0.03; % Require 30 ms of sustained motion


%% plot settings
SpectrogramBounds = [-50 0];
ShowPowerGatedCandidates = true; % Toggle faint candidate overlays
AllMarkerResults = cell(numel(wavFile_CW_All),2); % CA and OS marker tables

AllSwingMetrics = table; % Reset results whenever the full script is run

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
    % figure;
    % hold on;
    % 
    % % Points DBSCAN could not assign to a cluster
    % [noiseRows, noiseCols] = find(ClusterMap == -1);
    % 
    % scatter(t(noiseCols), DisplaySpeed(noiseRows),8, 'kx');
    % 
    % % Plot each cluster in its own colour
    % clusterIDs = unique(ClusterMap(ClusterMap > 0));
    % colours = lines(numel(clusterIDs));
    % 
    % for k = 1:numel(clusterIDs)
    % 
    %     [rows, cols] = find(ClusterMap == clusterIDs(k));
    % 
    %     scatter(t(cols), DisplaySpeed(rows), 12, colours(k,:), 'filled');
    % end
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title(sprintf('%s: %s clusters', wavFile_CW, detectorName),'Interpreter', 'none');
    % 
    % grid on;
    % axis tight;
    
    %% Compare markers from independently clustered CA and OS detections
    
    % Cluster each detector separately so their marker results are independent.
    candidateMaps = {CandidatesCA, CandidatesOS};
    detectorNames = {'CA-CFAR', 'OS-CFAR'};


    MarkerResults = cell(1,2); % {1} = CA, {2} = OS, current recording
    ClusterMaps = cell(1,2);

    % figure;
    % comparisonAxes = gobjects(2,1);

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

        % comparisonAxes(detectorIdx) = subplot(2,1,detectorIdx);
        % imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
        % axis xy;
        % hold on;
        % 
        % % Candidate overlays to show detector results in magenta
        % if ShowPowerGatedCandidates
        %     [candidateRows, candidateCols] = find(candidateMaps{detectorIdx});
        %     plot(t(candidateCols), DisplaySpeed(candidateRows), 'mx', 'MarkerSize', 2);
        % end

        % % Plot Markers
        % plot(markerTimes,markerSpeeds,'kx','MarkerSize',6,'LineWidth',1);
        % 
        % title(sprintf('%s: %s reduced markers', wavFile_CW, detectorNames{detectorIdx}), 'Interpreter', 'none');
        % xlabel('Time (s)');
        % ylabel('Radial speed (m/s)');
        % colorbar;

        fprintf('%s: %d clustered cells -> %d markers\n', detectorNames{detectorIdx}, ...
            nnz(currentClusterMap > 0),  numel(markerTimes));
    end
    % linkaxes(comparisonAxes, 'xy');
    % colormap('jet');

    % Preserve each recording's marker tables if several files are selected.
    AllMarkerResults{i,1} = MarkerResults{1};
    AllMarkerResults{i,2} = MarkerResults{2};
    %% OS-CFAR clusters with reduced markers overlaid
    
    % Reuse the OS results calculated above for this recording.
    osClusterMap = ClusterMaps{2};
    osMarkers = AllMarkerResults{i,2};

    % 
    % figure;
    % hold on;
    % 
    % % Noise: small grey x's.
    % [noiseRows, noiseCols] = find(osClusterMap == -1);
    % 
    % noiseHandle = scatter( ...
    %     t(noiseCols), DisplaySpeed(noiseRows), ...
    %     10, [0.6 0.6 0.6], 'x', 'DisplayName', 'DBSCAN noise');
    % 
    % % Get each cluster ID
    % clusterIDs = unique(osClusterMap(osClusterMap > 0));
    % colours = lines(numel(clusterIDs));
    % 
    % % Plot each cluster once.
    % for k = 1:numel(clusterIDs)
    % 
    %     [rows, cols] = find(osClusterMap == clusterIDs(k));
    % 
    %     scatter(t(cols), DisplaySpeed(rows),12, colours(k,:), 'filled', ...
    %         'MarkerFaceAlpha', 0.25, 'HandleVisibility', 'off');
    % end
    % 
    % 
    % markerHandle = plot(osMarkers.Time_s, osMarkers.Speed_mps, ...
    %     'kx', 'LineStyle', 'none', ...
    %     'MarkerSize', 6, 'LineWidth', 1.2);
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % 
    % title(sprintf('%s: OS-CFAR clusters and reduced markers', ...
    %     wavFile_CW), 'Interpreter', 'none');
    % 
    % legend([noiseHandle, markerHandle], {'DBSCAN noise', 'Reduced OS-CFAR markers'}, ...
    %     'Location', 'best');
    % 
    % grid on;
    % axis tight;
    % 
    % fprintf('OS-CFAR overlay: %d clustered cells -> %d reduced markers\n', ...
    %     nnz(osClusterMap > 0), height(osMarkers));

 

%% Plot Reduced Markers on Seperate Figure
% Column 2 always contains OS-CFAR results, regardless of UseOSCFAR.
% Markers = MarkerResults{2};
% 
% figure;
% 
% plot(Markers.Time_s, Markers.Speed_mps, 'k.', ...
%     'LineStyle', 'none', 'MarkerSize', 6, 'LineWidth', 1);
% 
% xlabel('Time (s)');
% ylabel('Radial speed (m/s)');
% title('OS-CFAR reduced markers');
% grid on;

%% Swing detection

    ClubSpeedEnvelope = nan(1,length(t));
   

    for timeIndex = 1:length(t)

        detectedRows = find(osClusterMap(:,timeIndex) > 0);

        if ~isempty(detectedRows)

            ClubSpeedEnvelope(timeIndex) =  max(DisplaySpeed(detectedRows));
           

        end

    end

    % figure;
    % 
    % imagesc(t,DisplaySpeed,DisplayPowerDB,SpectrogramBounds);
    % axis xy;
    % hold on;
    % 
    % plot(t,ClubSpeedEnvelope,'k.', 'MarkerSize',8, 'DisplayName','Raw envelope');
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title('Raw club-speed envelope');
    %  legend('Location','best');
    % colorbar;
    % colormap('jet');



    FrameTime_s = median(diff(t));

    MedianFilterDuration_s =  MedianFilterFrames * FrameTime_s;

    MovingAverageDuration_s = MovingAverageFrames * FrameTime_s;
    ClubSpeedMedian = movmedian(ClubSpeedEnvelope, MedianFilterFrames, 'omitnan');

    ClubSpeedSmoothed = movmean( ClubSpeedMedian, MovingAverageFrames, 'omitnan');

    % figure;
    % hold on;
    % 
    % plot(t,ClubSpeedEnvelope,'.', 'DisplayName','Raw envelope');
    % 
    % plot(t,ClubSpeedMedian,'--', 'LineWidth',1.2, 'DisplayName','Median filtered');
    % 
    % plot(t,ClubSpeedSmoothed,'-', 'LineWidth',1.5, 'DisplayName','Smoothed');
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title('Effect of filtering on club-speed envelope');
    % legend('Location','best');
    % grid on;

    [~,PeakSpeedIndex] =  max(ClubSpeedSmoothed,[],'omitnan');

    PeakSpeedTime_s = t(PeakSpeedIndex);

    PeakSearchHalfWidth_s = 0.04;

    PeakSearchStart_s =  PeakSpeedTime_s - PeakSearchHalfWidth_s;

    PeakSearchEnd_s = PeakSpeedTime_s + PeakSearchHalfWidth_s;

    PeakSearchMask =  t >= PeakSearchStart_s &  t <= PeakSearchEnd_s;

    PeakRadialSpeed_mps =  max(ClubSpeedEnvelope(PeakSearchMask),[], 'omitnan');

    figure;
    hold on;

    plot(t,ClubSpeedEnvelope,'.', 'DisplayName','Raw envelope');

    plot(t,ClubSpeedSmoothed,'-', 'LineWidth',1.5, 'DisplayName','Smoothed envelope');

    xline(PeakSearchStart_s,'--','Search start');
    xline(PeakSpeedTime_s,'-','Detected peak time');
    xline(PeakSearchEnd_s,'--','Search end');

    plot(PeakSpeedTime_s, ClubSpeedSmoothed(PeakSpeedIndex), 'o','MarkerSize',8);

    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');

    title(sprintf('Peak radial speed = %.2f m/s', PeakRadialSpeed_mps));
    legend('Location','best');
    grid on;




    % Step 5: top of the backswing
    TopSearchWindow_s = 1.5;

    TopSearchStart_s =  PeakSpeedTime_s - TopSearchWindow_s;

    TopSearchMask =  t >= TopSearchStart_s &  t < PeakSpeedTime_s;

    TopCandidateMask = ClubSpeedSmoothed <= TopThreshold_mps;

    TopOfBackswingIndex = NaN;
    TopOfBackswingTime_s = NaN;

    % NaN means the CFAR/DBSCAN found nothing, and NaN <= 4 is false, so by default
    % those frames are NOT counted as slow. If the top of the backswing is a gap in
    % the envelope (club too slow to be detected), set this to true and re-check the plot.
    TreatNaNAsLowSpeed = true;
    if TreatNaNAsLowSpeed
        TopCandidateMask = TopCandidateMask | isnan(ClubSpeedSmoothed);
    end



    MinimumTopFrames = ceil( MinimumTopDuration_s / FrameTime_s);

    % % Which point of the slow region counts as "the top": 'start', 'middle' or 'end'
    TopEventMode = 'end';

    % only keep frames that are slow AND inside the backwards search window
    TopValidMask = TopCandidateMask & TopSearchMask;

    % find where each run of consecutive slow frames starts and ends
    % (padding with false so runs touching the edges are still picked up)
    paddedMask = [false, TopValidMask, false];
    TopRunStarts = find(diff(paddedMask) == 1);
    TopRunEnds   = find(diff(paddedMask) == -1) - 1;
    TopRunLengths = TopRunEnds - TopRunStarts + 1;

    % throw away runs that are shorter than MinimumTopFrames (brief dips)
    keepRuns = TopRunLengths >= MinimumTopFrames;
    TopRunStarts = TopRunStarts(keepRuns);
    TopRunEnds   = TopRunEnds(keepRuns);

    if isempty(TopRunStarts)
        % nothing sustained in the window, so leave the event as NaN and warn
        
        TopRunStart = NaN;
        TopRunEnd = NaN;
        warning(['No sustained low-speed region found before the peak. ' ...
            'Try a higher TopThreshold_mps, a shorter MinimumTopDuration_s, ' ...
            'a longer TopSearchWindow_s or TreatNaNAsLowSpeed = true.']);
    else
        % the last run is the one closest to the peak, i.e. the most recent
        % sustained slow region before the downswing
        TopRunStart = TopRunStarts(end);
        TopRunEnd   = TopRunEnds(end);

        switch TopEventMode
            case 'start'
                TopOfBackswingIndex = TopRunStart;
            case 'end'
                TopOfBackswingIndex = TopRunEnd;
            otherwise % 'middle'
                TopOfBackswingIndex = round((TopRunStart + TopRunEnd)/2);
        end
        TopOfBackswingTime_s = t(TopOfBackswingIndex);
    end

    % figure;
    % hold on;
    % 
    % plot(t,ClubSpeedSmoothed,'LineWidth',1.5,'DisplayName','Smoothed envelope');
    % yline(TopThreshold_mps,'--','Top threshold');
    % xline(TopSearchStart_s,'--','Search start');
    % xline(PeakSpeedTime_s,'--','Peak speed');
    % 
    % % only draw the detected top if one was actually found
    % if ~isnan(TopOfBackswingIndex)
    %     % highlight the slow region that got picked
    %     plot(t(TopRunStart:TopRunEnd), ClubSpeedSmoothed(TopRunStart:TopRunEnd), ...
    %         'r.', 'MarkerSize',12, 'DisplayName','Selected low-speed region');
    %     xline(TopOfBackswingTime_s,'-','Detected top');
    % end
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title('Top-of-backswing detection');
    % legend('Location','best');
    % grid on;

    fprintf('Top of backswing: %.3f s (%.3f s before peak speed)\n', ...
        TopOfBackswingTime_s, PeakSpeedTime_s - TopOfBackswingTime_s);

    % Step 6

    BackswingStartIndex = NaN;
    BackswingStartTime_s = NaN;

    MinimumMotionFrames = ceil(MinimumMotionDuration_s / FrameTime_s);

    if ~isnan(TopOfBackswingIndex)
        % Search only before the detected top. NaNs do not count as motion.
        MotionMask = ClubSpeedSmoothed >= MotionThreshold_mps & t < t(TopRunStart);

        % +1 marks the start of a motion run; -1 marks the frame after its end.
        MotionTransitions = diff([false MotionMask false]);
        MotionRunStarts = find(MotionTransitions == 1);
        MotionRunEnds = find(MotionTransitions == -1) - 1;

        % Keep runs that stay above the threshold for long enough.
        MotionRunLengths = MotionRunEnds - MotionRunStarts + 1;
        ValidRuns = find(MotionRunLengths >= MinimumMotionFrames);

        if ~isempty(ValidRuns)

            % Start with the last sustained motion run before the top.
            selectedRun = ValidRuns(end);

            % Include earlier sustained runs if the separating gap is short.
            for k = length(ValidRuns)-1:-1:1

                previousRun = ValidRuns(k);

                gap_s = t(MotionRunStarts(selectedRun)) - ...
                        t(MotionRunEnds(previousRun));

                if gap_s > MaximumMotionGap_s
                    break; % A longer gap separates this from earlier movement.
                end

                selectedRun = previousRun;
            end

            BackswingStartIndex = MotionRunStarts(selectedRun);
            BackswingStartTime_s = t(BackswingStartIndex);

        else
            warning('No sustained backswing motion found for %s.', wavFile_CW);
        end
    end

    % figure;
    % plot(t,ClubSpeedSmoothed,'LineWidth',1.5);
    % hold on;
    % yline(MotionThreshold_mps,'--','Motion threshold');
    % if ~isnan(BackswingStartTime_s)
    %     xline(BackswingStartTime_s,'-','Detected backswing start');
    % end
    % if ~isnan(TopOfBackswingTime_s)
    %     xline(TopOfBackswingTime_s,'--','Top of backswing');
    % end
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title('Backswing-start detection');
    % grid on;

    %% Detect the start of the downswing
    % DownswingStartIndex = NaN;
    % DownswingStartTime_s = NaN;
    % 
    % MinimumDownswingFrames = ceil( ...
    %     MinimumDownswingDuration_s / FrameTime_s);
    % 
    % if ~isnan(TopOfBackswingIndex)
    % 
    %     % Search after the selected slow region and before peak speed.
    %     DownswingMask = ClubSpeedSmoothed >= DownswingThreshold_mps & ...
    %                     t > t(TopRunEnd) & t < PeakSpeedTime_s;
    % 
    %     % Find the start and end of each continuous motion run.
    %     transitions = diff([false DownswingMask false]);
    %     runStarts = find(transitions == 1);
    %     runEnds = find(transitions == -1) - 1;
    % 
    %     % Select the first run that lasts long enough.
    %     runLengths = runEnds - runStarts + 1;
    %     firstValidRun = find( ...
    %         runLengths >= MinimumDownswingFrames, 1, 'first');
    % 
    %     if ~isempty(firstValidRun)
    %         DownswingStartIndex = runStarts(firstValidRun);
    %         DownswingStartTime_s = t(DownswingStartIndex);
    %     else
    %         warning('No sustained downswing onset found for %s.', wavFile_CW);
    %     end
    % end

%% Check the detected onset
    % figure;
    % plot(t,ClubSpeedSmoothed,'LineWidth',1.5);
    % hold on;
    % 
    % yline(DownswingThreshold_mps,'--','Downswing threshold');
    % 
    % if ~isnan(TopOfBackswingTime_s)
    %     xline(TopOfBackswingTime_s,'--','Top candidate');
    % end
    % 
    % if ~isnan(DownswingStartTime_s)
    %     xline(DownswingStartTime_s,'-','Downswing start');
    % end
    % 
    % if ~isnan(PeakSpeedTime_s)
    %     xline(PeakSpeedTime_s,'--','Peak radial speed');
    % end
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed (m/s)');
    % title('Downswing-start detection');
    % grid on;

      %% Step 7: timing metrics
    BackswingDuration_s = TopOfBackswingTime_s - BackswingStartTime_s;


    % Still uses peak radial speed as the endpoint.
    DownswingDuration_s = PeakSpeedTime_s - TopOfBackswingTime_s;


    TempoRatio = BackswingDuration_s / DownswingDuration_s;

    %% Step 8: retain one result row per processed recording
    % Flag tops whose selected low-speed region contains missing measurements.
    TopUsesMissingData = false;
    if ~isnan(TopOfBackswingIndex)
        TopUsesMissingData = any(isnan(ClubSpeedEnvelope(TopRunStart:TopRunEnd)));
    end

    SwingMetrics = table(string(recordingRelativePath), PeakRadialSpeed_mps, ...
        BackswingDuration_s, DownswingDuration_s, TempoRatio, ...
        BackswingStartTime_s, TopOfBackswingTime_s, PeakSpeedTime_s, ...
        TopUsesMissingData, 'VariableNames', ...
        {'Recording','PeakRadialSpeed_mps','BackswingDuration_s', ...
         'DownswingDuration_s','TempoRatio','BackswingStartTime_s', ...
         'TopOfBackswingTime_s','PeakSpeedTime_s','TopUsesMissingData'});

    % SwingMetrics.DownswingStartTime_s = DownswingStartTime_s;
    % SwingMetrics.TransitionDuration_s = TransitionDuration_s;

    AllSwingMetrics = [AllSwingMetrics; SwingMetrics];
    disp(SwingMetrics);

    %% Step 9: final diagnostic plot
    figure;
    imagesc(t,DisplaySpeed,DisplayPowerDB,SpectrogramBounds);
    axis xy;
    hold on;
    plot(t,ClubSpeedSmoothed,'k','LineWidth',1.5);

    % if ~isnan(DownswingStartTime_s)
    % xline(DownswingStartTime_s,'--w','Downswing start','LineWidth',1.2);
    % end
    if ~isnan(BackswingStartTime_s)
        xline(BackswingStartTime_s,'--w','Backswing start','LineWidth',1.2);
    end
    if ~isnan(TopOfBackswingTime_s)
        xline(TopOfBackswingTime_s,'--w','Top of backswing','LineWidth',1.2);
    end
    xline(PeakSpeedTime_s,'--w','Peak radial speed','LineWidth',1.2);

    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    title({wavFile_CW, sprintf( ...
        'Peak %.2f m/s | Backswing %.3f s | Downswing %.3f s | Tempo %.2f', ...
        PeakRadialSpeed_mps, BackswingDuration_s, DownswingDuration_s, ...
        TempoRatio)}, 'Interpreter','none');
    colorbar;
    colormap('jet');


     %% original spectrogram and speed-time plot
    SpectrogramBounds = [-50 0]; %intensity color bounds in dB
    
    % PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    
    % PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);

 
end 

%% Results for all selected recordings
 disp(AllSwingMetrics);

