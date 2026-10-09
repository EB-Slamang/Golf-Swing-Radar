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
        

        %E.S Second Session Recordings
        %XONAR
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test1_3_5m.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test2_2m.wav')
        %Sound Blaster
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test3_3_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test4_2m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test5_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test6_2_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing_Test7_3m_SoundBlaster_StraightArm.wav')

     % fullfile('P001', 'session2', '7Iron_FullSwing_Test1_2_5m_SoundBlaster.wav')
     % fullfile('P001', 'session2', '7Iron_FullSwing_Test2_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', '7Iron_FullSwing_Test3_2m_SoundBlaster.wav')

     % fullfile('P001', 'session2', 'Driver_FullSwing1_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing2_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing3_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing4_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing5_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing6_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing7_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing8_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing9_3m_SoundBlaster.wav')
     % fullfile('P001', 'session2', 'Driver_FullSwing10_3m_SoundBlaster.wav')

        %E.S Third Session recordings
        %XONAR
            %Tests
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test1_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test2_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test3_3m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test4_2_5m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test5_2m_LineInput.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test6_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing_Test7_3m_StraightArm.wav')
    % fullfile('P001', 'session3', 'Headless.wav')
    
        %Dataset
    % fullfile('P001', 'session3', 'Driver_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', 'Driver_FullSwing10_3m.wav')

    % fullfile('P001', 'session3', '7Iron_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', '7Iron_FullSwing10_3m.wav')

    % fullfile('P001', 'session3', 'Wedge_FullSwing1_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing2_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing3_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing4_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing5_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing6_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing7_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing8_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing9_3m.wav')
    % fullfile('P001', 'session3', 'Wedge_FullSwing10_3m.wav')

        %J.M First Session Recordings
        %Tests
    % fullfile('P002', 'session1', 'Headless1.wav')
    % fullfile('P002', 'session1', 'Headless2.wav')
    % fullfile('P002', 'session1', 'Ball1.wav')
    % fullfile('P002', 'session1', 'Ball2.wav')
    % fullfile('P002', 'session1', 'Ball3.wav')

        %Dataset
    % fullfile('P002', 'session1', 'Driver_FullSwing1.wav')  
    % fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing5.wav')
    % fullfile('P002', 'session1', 'Driver_FullSwing6_stoponfollowthru.wav')

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
    % fullfile('P002', 'session1', '7Iron_Fullswing7_stoponfollowthru.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_BackSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_BackSwing2.wav')
    % 
    % fullfile('P002', 'session1', 'Wedge_DownSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_DownSwing2.wav')
    % % 
    % fullfile('P002', 'session1', 'Wedge_FullSwing1.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing2.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing3.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing4.wav')
    % fullfile('P002', 'session1', 'Wedge_FullSwing5.wav')
  

        %J.M Second Session Recordings
        %Tests
    % fullfile('P002', 'session2', 'Practice.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m.wav')

    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_10deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_10deg_23cm.wav')

    %  fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_15deg_23cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_15deg_23cm.wav')

    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_2_5m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3m_15deg_41cm.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing_Test_3_5m_15deg_41cm.wav')

        %Dataset
    % fullfile('P002', 'session2', 'Driver_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', 'Driver_Fullswing10_3m.wav')

    % fullfile('P002', 'session2', '7Iron_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', '7Iron_Fullswing10_3m.wav')
    
    % fullfile('P002', 'session2', 'Wedge_Fullswing1_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing2_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing3_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing4_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing5_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing6_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing7_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing8_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing9_3m.wav')
    % fullfile('P002', 'session2', 'Wedge_Fullswing10_3m.wav')
    
    
    
                    };
           

%% radar and spectrogram parameters
fc = 24e9;             %radar centre frequency (Hz)
c = 3e8;               %speed of light (m/s)
lambda = c/fc;         %radar wavelength (m)

CPI = 0.01;            %coherent processing interval (s)
overlapFrac = 0.95;    %overlap between spectrogram frames
maxSpeed = 80;         %maximum speed shown on the plots (m/s)
dt = 5.8957e-04;


%% CFAR parameters
PFA = 1e-5;                   %desired probability of false alarm
RefWindowCA = 36;             %CA-CFAR total number of reference cells
GuardCellsCA = 24;            %CA-CFAR guard cells on each side

RefWindowOS = 42;             %OS-CFAR total number of reference cells :60 ref cells
GuardCellsOS = 20;            %OS-CFAR guard cells on each side : 20 G cells

MinimumDetectionSpeed = 0;  % lower speed limit for CFAR and detection plots 2 (m/s) 

% Use more cells above the CUT because the upper side of the club return
% normally has cleaner noise than the lower-speed side and less likely to self-mask.
UseAsymmetricCFAR = true;

AsymmetricMaxSpeed = 60;        % Max speed where asymmetric CFAR is used, symmetric used for higher speeds

LowerRefCellsOS = ceil(0.1*RefWindowOS);  % proportion of total ref cells used for ref cells below CUT
LowerRefCellsCA = ceil(0.1*RefWindowCA);

UseOSCFAR =  true;             % True to use OS-CFAR for clustering computation

Rank = ceil(0.3* RefWindowOS); % OS CFAR parameter for kth smallest detection: 0.3

%% detection cleaning parameters
MinimumDetectionPowerDB = -55; % minimum power used to filter out lower power noise (dB)

%% DBSCAN Clustering parameters
TimeRadius = 0.002;    % Neighbourhood time radius: 2 ms
SpeedRadius = 2.0;     % Neighbourhood speed radius: 2 m/s
MinPoints = 5;         % Minimum nearby detected cells for a core point: 4

%% Swing detection parameters 
% Smoothed speeds >= 0.1 m/s count as motion in the backswing search.
SwingParameters.MotionThreshold_mps = 0.1;            %2 m/s  
% Accept a continuous motion run only when frame count * actual hop time >= 30 ms.
SwingParameters.MinimumMotionDuration_s = 0.03;
% Search up to 1 s before the START of the selected low-speed region.
SwingParameters.BackswingSearchWindow_s = 1;
% 'first': earliest qualifying motion run in that search window.
% 'linked': start at the latest qualifying run and link earlier valid runs backwards.
SwingParameters.BackswingStartMode = 'linked'; % 'first' or 'linked' rule
% In 'linked' mode, allow <= 300 ms between the last frame of an earlier
% valid motion run and the first frame of the currently linked run. Stop at a larger gap.
SwingParameters.MaximumMotionGap_s = 0.3;   % Only used in 'linked' mode : 0.03

% Smoothed speeds <= 4 m/s define possible low-speed turnaround regions.
SwingParameters.TopThreshold_mps = 4;
% Require a low-speed run lasting >= 100 ms (frame count * hop time).
SwingParameters.MinimumTopDuration_s = 0.1; %0.05
% Look for low-speed regions within 1.5 s before the smoothed peak timestamp.
SwingParameters.TopSearchWindow_s = 1.5;
% Top selection mode: 'hybrid' and compatibility alias 'minimum' use the same rule.
% 'rise' selects the sustained-rise candidate with no hybrid fallback.
SwingParameters.TopMethod = 'hybrid';       % 'minimum' or 'rise' or 'hybrid'
% In hybrid mode, use the largest eligible gap midpoint if no robust valley exists
% OR its bounding-observation separation exceeds 35 ms (strictly greater, with tolerance).
SwingParameters.GapOverrideDuration_s = 0.035;

% Fill an internal raw-envelope gap only if missing frame count * hop time <= 0.5 s
SwingParameters.MaxInterpolationGap_s = 0.5; % Fill only internal gaps <= 50 ms
% Allow interpolation only when the two IMMEDIATE measured endpoints differ by <= 4 m/s.
SwingParameters.MaxInterpolationSpeedGap_mps = 4; % Maximum endpoint difference
% For low-speed-region grouping only, bridge an unfilled gap of <= 100 ms
SwingParameters.MaxTopGap_s = 0.1;           % Group unknown gaps bounded by low speeds
% Requested main median width: converted to frames using the script dt assigned above.
medianWindow_s = 0.030; %  0.015
% Convert medianWindow_s to an odd frame count, with a minimum of three frames.
SwingParameters.MedianFilterFrames = ...
    max(3, 2*floor(medianWindow_s/(2*dt))+1);
% After the median filter, average over 10 frames in each finite supported section.
SwingParameters.MovingAverageFrames = 10;     %3
% After locating the smoothed peak at a measured frame, inspect RAW observations
% within +/- 40 ms. Report their maximum amplitude and its own RawPeakTime_s.
% Phase durations still use PeakSpeedTime_s (the smoothed-peak timestamp).
SwingParameters.PeakSearchHalfWidth_s = 0.04;

% Alternative top rule: sustained rise beginning within the low-speed region.
% Test a 60 ms forward interval from each measured candidate in the low-speed region.
SwingParameters.RiseWindow_s = 0.06;    % 60 ms
% Require a net smoothed-speed increase >= 1.2 m/s over the rise interval.
SwingParameters.MinimumRise_mps = 1.2;  %1.5 m/s
% Require >= 60% of up to six checkpoint-to-checkpoint changes to be strictly positive.
SwingParameters.MinimumRisingFraction = 0.60;       %0.70
% Reject the rise if any checkpoint change is below -0.15 m/s.
SwingParameters.RiseDropTolerance_mps = 0.15;       % 0.10   m/s  
% For the rise candidate only, require >= 30% of interval frames to have raw detections.
SwingParameters.MinimumMeasuredFraction = 0.30;     % 0.5

% Separate 30 ms median window applied directly to RAW speeds with NaNs omitted.
SwingParameters.TopMedianWindow_s = 0.030; % compare 0.010, 0.020, 0.030 too
% Require raw observations in >= 10% of each median window.
SwingParameters.TopMinimumMeasuredFraction = 0.10;      %0.70
% Set TopSpeedTolerance_mps after computing the speed-bin spacing in main code.
% Require a contiguous supported near-minimum valley lasting >= 50 ms.
SwingParameters.MinimumValleyDuration_s = 0.05;     %0.005
% Report raw missing runs lasting >= 1 ms, entirely within the selected low-speed region.
SwingParameters.MinimumGapReport_s = 0.001;         %0.010




%% plot settings
SpectrogramBounds = [-55 0];
ShowPowerGatedCandidates = true; % Toggle faint candidate overlays

AllSwingMetrics = table; % Reset results whenever the full script is run
AllSwingTraces = cell(numel(wavFile_CW_All),1);

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
    
    %% Compare CA and OS detections
    
    % Cluster each detector separately so their marker results are independent.
    candidateMaps = {CandidatesCA, CandidatesOS};
    detectorNames = {'CA-CFAR', 'OS-CFAR'};

    ClusterMaps = cell(1,2);

    figure;
    comparisonAxes = gobjects(2,1);

    %loop through CFAR detectors and plot detections
    for detectorIdx = 1:2 
        [~, currentClusterMap] = ClusterDetections( ...
            candidateMaps{detectorIdx}, DisplaySpeed, t, ...
            TimeRadius, SpeedRadius, MinPoints);

        ClusterMaps{detectorIdx} = currentClusterMap;

        comparisonAxes(detectorIdx) = subplot(2,1,detectorIdx);
        imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
        axis xy;
        hold on;

        % Candidate overlays to show detector results in magenta
        
        [candidateRows, candidateCols] = find(candidateMaps{detectorIdx});
        plot(t(candidateCols), DisplaySpeed(candidateRows), 'mx', 'MarkerSize', 8);
 
        title(sprintf('%s: %s Candidate Detection', wavFile_CW, detectorNames{detectorIdx}), 'Interpreter', 'none');
        xlabel('Time (s)');
        ylabel('Radial speed (m/s)');
        colorbar;

    end
    linkaxes(comparisonAxes, 'xy');
    colormap('jet');
 
    %% Detect swing events using OS-CFAR clusters

    % Reuse the OS results calculated above for this recording.
    osClusterMap = ClusterMaps{2};
    % metrics: event timestamps, durations and selection/status diagnostics.
    % trace: raw/filled/smoothed envelopes, masks, robust comparison and effective parameters.
    [metrics, trace] = DetectSwingEvents(osClusterMap, DisplaySpeed, t, SwingParameters);

    % Retain the competing robust-valley and gap candidates for inspection.
    comparison = trace.TopComparison;
    fprintf('Selected top: %s | %s | %.6f s\n', ...
        char(metrics.TopSource), char(metrics.TopSelectionReason), ...
        metrics.TopOfBackswingTime_s);
    % One row per recording; preserve NaNs/status strings when detection is incomplete.
    SwingMetrics = struct2table(metrics);
    SwingMetrics.Recording = string(recordingRelativePath);
    AllSwingMetrics = [AllSwingMetrics; SwingMetrics];
    AllSwingTraces{i} = trace; % Includes raw/filled data, masks and parameters
    disp(SwingMetrics);

    PlotSwingEvents(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds, ...
        metrics, trace, wavFile_CW);
    
    % PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    % PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);
end

%% Results for all selected recordings
 disp(AllSwingMetrics);
 % Optional exports (uncomment if needed).
 % writetable(AllSwingMetrics,fullfile(projectRoot,'SwingMetrics.csv'));
 % save(fullfile(projectRoot,'SwingDetectionResults.mat'), ...
 %     'AllSwingMetrics','AllSwingTraces','SwingParameters');
