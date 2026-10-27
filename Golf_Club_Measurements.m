% GOLF_CLUB_MEASUREMENTS - Run the complete offline golf-radar pipeline.
%
% QUICK START
%   Keep this script, RecordingSelection.m, src and Datasets together.
%   Open this script in MATLAB and press Run. No local configuration is needed.
%   The selected recordings are listed in RecordingSelection.m, not found by
%   scanning the dataset automatically. Only uncomment recordings to process.
%
% WORKSPACE OUTPUTS
%   AllSwingMetrics : one row of events, speeds and diagnostics per recording.
%   AllSwingTraces  : raw/filled/smoothed envelopes and decision evidence.
%   Comparison     : compact results table with empty video-reference columns.
%   CSV writing is deliberately disabled at the bottom until a filename is chosen.
%
% PROCESSING ORDER
%   WAV -> complex STFT -> power/background conditioning -> selected CFAR ->
%   original-power gate -> DBSCAN -> envelope -> supported peak/top/onset.
%   This script clears its workspace and closes figures when it starts.
%   Clustering requires Statistics and Machine Learning Toolbox (dbscan).
%
% MEASUREMENT DEFINITIONS
%   Speeds are magnitudes of the radial component, not total 3-D club speed.
%   DownswingDuration_s is the selected top-to-smoothed-speed-peak interval.
%   No impact time is measured. An event timestamp can be inferred from a gap
%   or a zero-speed extrapolation, so always inspect status and trace diagnostics.

%Ebrahiem Slamang
%EEE4022S

clear;
close all;

%% Project Folder setup
projectRoot = fileparts(mfilename('fullpath'));

addpath(fullfile(projectRoot, 'src'));

% The recordings are bundled with this project. Build paths from the main
% script's own location, not from a username or the current working folder.
% Keep the Datasets folder beside this file when copying the project.
assert(isfolder(fullfile(projectRoot, 'Datasets')), ...
    'The bundled Datasets folder must be beside Golf_Club_Measurements.m.');

%% Recording selection
% Keep the recording list separate so the processing script stays readable.
run(fullfile(projectRoot, 'RecordingSelection.m'));
if isempty(wavFile_CW_All)
    error('Uncomment the recordings to process in RecordingSelection.m.');
end

%% radar and spectrogram parameters
% The assumed carrier sets the conversion from Doppler frequency to speed:
%   radial speed = abs(Doppler frequency) * lambda/2.
% The transmitted carrier is not measured by this software. Changing fc changes
% all reported speeds; it does not change the recorded audio samples.
fc = 24e9;             %radar centre frequency (Hz)
c = 3e8;               %speed of light (m/s)
lambda = c/fc;         %radar wavelength (m)

% CPI is a REQUESTED frame duration, not the update interval. The script rounds
% the requested sample count up to a power of two. At 44.1 kHz, 10 ms becomes
% 512 measured samples = 11.610 ms. NFFT equals this length: no zero-padding.
% A 95% requested overlap gives a 26-sample hop = 0.58957 ms at this setting.
% maxSpeed limits both tested CFAR rows and the displayed positive-speed band.
% The fixed dt below only converts the main moving-median duration to frames;
% the event function derives its other timing intervals from the returned axis.
CPI = 0.01;            %coherent processing interval (s)
overlapFrac = 0.95;    %overlap between spectrogram frames
maxSpeed = 55;         %upper speed limit for CFAR and plots (m/s)
dt = 5.8957e-04;      % Original time step used ONLY to set the main median width

%% CFAR parameters
% PFA is the nominal target-free false-alarm probability per tested cell under
% the CFAR background model. It is not a whole-recording error probability.
% RefWindow is the TOTAL number of background cells from both sides combined.
% GuardCells excludes this many rows on EACH side, in addition to the CUT.
% Larger guards protect against target leakage but move references farther away.
% A larger reference count can improve background sampling or include more target
% energy; it is not automatically better. Run Test_CFAR to check calibration.
PFA = 1e-5;                   %desired probability of false alarm
RefWindowCA = 42;             %CA-CFAR total number of reference cells
GuardCellsCA = 20; 

RefWindowOS = 42;             %OS-CFAR total number of reference cells
GuardCellsOS = 20;            %OS-CFAR guard cells on each side

MinimumDetectionSpeed = 0;  % lower speed limit for CFAR and plots (m/s) 

% Use more cells above the CUT because the upper side of the club return
% normally has cleaner noise than the lower-speed side and less likely to self-mask.
UseAsymmetricCFAR = true;

AsymmetricMaxSpeed = 60;        % Max speed where asymmetric CFAR is used, symmetric used for higher speeds

% With 42 total references, ceil(0.1*42) requests five below and 37 above the
% CUT. These are requested allocations away from the selected speed boundaries;
% the detector transfers unavailable references to the opposite side near edges.
% The current 55 m/s band is entirely below the 60 m/s asymmetry transition.
LowerRefCellsOS = ceil(0.1*RefWindowOS);  % proportion of total ref cells used for ref cells below CUT
LowerRefCellsCA = ceil(0.1*RefWindowCA);

UseOSCFAR =  true;             % False selects CA-CFAR for the complete event path

Rank = ceil(0.3* RefWindowOS); % Rank of the reference power (13th smallest)

%% detection cleaning parameters
% This second gate uses ORIGINAL power relative to the largest power in the
% retained band of the same recording. It removes CFAR crossings that are weak
% relative to that maximum. The gate is not an absolute receiver sensitivity.
% Raising it, for example from -50 to -40 dB, retains fewer candidate cells.
MinimumDetectionPowerDB = -50; % minimum power used to filter out lower power noise (dB)

%% DBSCAN Clustering parameters
% DBSCAN works in scaled time-speed coordinates with scalar radius one.
% TimeRadius and SpeedRadius specify the ellipse's physical semi-axes.
% MinPoints counts neighbouring detected CELLS, including the tested cell;
% several cells can occur in one frame. It does not count distinct frames.
% Increasing either radius can link fragmented returns but can also merge
% unrelated features. Sparse points are rejected as clustering noise.
TimeRadius = 0.002;    % Neighbourhood time radius: 2 ms
SpeedRadius = 2.0;     % Neighbourhood speed radius: 2 m/s
MinPoints = 5;         % Minimum nearby detected cells for a core point, including itself

%% Swing detection parameters 
% Linked motion runs define the detected onset before zero-speed extrapolation.
SwingParameters.MotionThreshold_mps = 0;            % Finite non-negative speeds qualify  
% Accept a continuous motion run only when frame count * actual hop time >= 30 ms.
SwingParameters.MinimumMotionDuration_s = 0.03;
% Search up to 1 s before the START of the selected low-speed region.
SwingParameters.BackswingSearchWindow_s = 1;
% Link qualifying motion runs backwards while their separation is <= 0.6 s.
SwingParameters.MaximumMotionGap_s = 0.6;

% Smoothed speeds <= 5 m/s define possible low-speed turnaround regions.
SwingParameters.TopThreshold_mps = 5;
% Require a low-speed run lasting >= 100 ms (frame count * hop time).
SwingParameters.MinimumTopDuration_s = 0.1;
% Look for low-speed regions within 1.5 s before the smoothed peak timestamp.
SwingParameters.TopSearchWindow_s = 1.5;
% Hybrid top rule: supported measured valley or largest eligible raw gap.
% In hybrid mode, use the largest eligible gap midpoint if no robust valley exists
% OR its bounding-observation separation exceeds 35 ms (strictly greater, with tolerance).
% The hybrid rule is not simply the lowest smoothed sample. It compares a
% supported raw-only valley with missing intervals inside the selected slow
% region. A long eligible gap can override a measured-valley candidate.
% GapOverrideDuration uses separation BETWEEN the measured bounding samples;
% MaxInterpolationGap uses the number of missing frames times the actual hop.
% They are different duration definitions and control different decisions.
SwingParameters.GapOverrideDuration_s = 0.035;

% Fill an internal raw-envelope gap only if missing frame count * hop time <= 0.4 s
SwingParameters.MaxInterpolationGap_s = 0.4;
% Allow interpolation only when the two IMMEDIATE measured endpoints differ by <= 4 m/s.
SwingParameters.MaxInterpolationSpeedGap_mps = 4; % Maximum endpoint difference
% For low-speed-region grouping only, bridge an unfilled gap of <= 100 ms
SwingParameters.MaxTopGap_s = 0.1;           % Group unknown gaps bounded by low speeds
% Requested main median width: converted to frames using the script dt assigned above.
medianWindow_s = 0.030;
% Convert medianWindow_s to an odd frame count, with a minimum of three frames.
SwingParameters.MedianFilterFrames = ...
    max(3, 2*floor(medianWindow_s/(2*dt))+1);
% After the median filter, average over 10 frames in each finite supported section.
SwingParameters.MovingAverageFrames = 10;
% Accept the highest raw peak with support in +/- 40 ms and +/- 4 m/s.
% Select the smoothed timing locally; phase durations use that timestamp.
SwingParameters.PeakSearchHalfWidth_s = 0.04;
SwingParameters.PeakSupportSpeedRange_mps = 4;
SwingParameters.PeakMinimumSupportDuration_s = 0.020;

% Separate 30 ms median window applied directly to RAW speeds with NaNs omitted.
SwingParameters.TopMedianWindow_s = 0.030;
% Require raw observations in >= 10% of each median window.
SwingParameters.TopMinimumMeasuredFraction = 0.10;
% The event function defaults TopSpeedTolerance_mps to half a speed bin.
% Require a contiguous supported near-minimum valley lasting >= 50 ms.
SwingParameters.MinimumValleyDuration_s = 0.05;
% Report raw missing runs lasting >= 1 ms, entirely within the selected low-speed region.
SwingParameters.MinimumGapReport_s = 0.001;

% These settings control an OPTIONAL estimate before the first retained onset.
% The detected run is selected by linked motion support before this fit begins.
% Only the initial part of that first linked run is fitted. Accepted interpolation
% may contribute, but smoothed speeds are not used as the fitting observations.
% A rejected fit leaves the detected onset in place; it never forces a zero root.
% R2 measures line-fit agreement, not event confidence or percentage accuracy.
SwingParameters.ExtrapolateBackswingStart = true;
SwingParameters.StartFitUseInterpolated = true;

% StartFitWindow: maximum initial fitting interval after the detected start.
% StartFitBin: time-bin width for reducing points to robust median samples.
% StartFitMaxGap: stop using points after a larger unsupported time separation.
% StartFitMinSpan: minimum supported time span, before and after binning.
% StartFitMinRise: required fitted increase across the binned interval.
% StartFitMinR2: minimum fit agreement; larger values reject more curved/noisy fits.
% StartMaxExtrapolation: maximum backward correction; a farther root is rejected.
SwingParameters.StartFitWindow_s = 0.100;
SwingParameters.StartFitBin_s = 0.005;
SwingParameters.StartFitMaxGap_s = 0.010;

SwingParameters.StartFitMinSpan_s = 0.025;
SwingParameters.StartFitMinRise_mps = 0.30;
SwingParameters.StartFitMinR2 = 0.60;
SwingParameters.StartMaxExtrapolation_s = 0.200;

%% plot settings
SpectrogramBounds = [-50 0];

AllSwingMetrics = table; % Reset results whenever the full script is run
AllSwingTraces = cell(numel(wavFile_CW_All),1);

%% process each recording
for i = 1:length(wavFile_CW_All)

    recordingRelativePath = wavFile_CW_All{i};

    wavPath = fullfile(projectRoot, 'Datasets', recordingRelativePath);

    assert(isfile(wavPath), 'Recording not found: %s', wavPath);

    % Keep a short filename for plot titles.
    [~, recordingName, recordingExtension] = fileparts(wavPath);
    wavFile_CW = [recordingName recordingExtension];

    fprintf('Loading %s...\n', wavFile_CW);
    % audioread returns samples scaled to floating-point audio values and the
    % sampling rate stored in this WAV. The first column is the radar channel;
    % there is no conversion of these audio values into calibrated volts here.
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

    % S is complex and is not yet a power spectrogram. Squared magnitude gives
    % nonnegative power-like values. Keep these original values separate from the
    % conditioned input because plotting and the later relative-power gate use them.
    RawPowerData = abs(S).^2;
    
    % Estimate the normal noise level separately for every Doppler bin.
    % The median is used because the golf swing only occupies a small
    % portion of the complete recording.
    % Rows correspond to fixed Doppler/speed bins. A separate median over TIME
    % estimates each row's usual level. A target present at a row for much of the
    % record can raise this estimate, so normalisation can also suppress that target.
    NoiseFloorPerBin = median(RawPowerData,2);
    
    % Normalise each Doppler bin by its usual background level.
    PowerData = RawPowerData ./ max(NoiseFloorPerBin,eps); % eps used to avoid Inf error
    
    % Light averaging over time
    % Only three frames are used so that fast transitions are not blurred.
    % This averages three neighbouring frame columns. It reduces fluctuations,
    % but also correlates outputs. The average is still LINEAR power, not dB.
    PowerData = movmean(PowerData,3,2);

    %% Run the chosen detector
    % The switch controls detection, clustering AND event extraction.
    if UseOSCFAR
        [DetectionMap, ~] = OS_CFAR(PowerData, speed, ...
            PFA, RefWindowOS, GuardCellsOS, MinimumDetectionSpeed, maxSpeed, ...
            UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCellsOS, Rank);
        detectorName = 'OS-CFAR';
    else
        [DetectionMap, ~] = CA_CFAR(PowerData, speed, ...
            PFA, RefWindowCA, GuardCellsCA, MinimumDetectionSpeed, maxSpeed, ...
            UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCellsCA);
        detectorName = 'CA-CFAR';
    end

    %% speed range used for the plots
    speedRegionMask = speed >= MinimumDetectionSpeed & speed <= maxSpeed;

    displayIdx = find(speedRegionMask);
    DisplaySpeed = speed(displayIdx);

    % Original power is used for plotting and selecting the strongest return.
    DisplayPower = RawPowerData(displayIdx,:);

    %% normalise and convert to dB for plotting
    % Set the largest original power in this display region to 0 dB.
    normalPower = max(max(DisplayPower(:)),eps);
    DisplayPowerDB = 10*log10(DisplayPower/normalPower + eps);

    %% Retain CFAR crossings that also pass the original-power gate
    PowerGate = DisplayPowerDB >= MinimumDetectionPowerDB;
    DetectionCandidates = DetectionMap(displayIdx,:) & PowerGate;

    %% Cluster detections using DBSCAN
    [DetectionClustered, ClusterMap] = ClusterDetections( ...
        DetectionCandidates, DisplaySpeed, t, ...
        TimeRadius, SpeedRadius, MinPoints);
    
    fprintf('Candidates before clustering: %d\n', nnz(DetectionCandidates));
    
    fprintf('Detections retained in clusters: %d\n', nnz(DetectionClustered));
    
    fprintf('Number of clusters: %d\n', max([0; ClusterMap(:)]));

    %% Extract events from the selected detector's clusters
    [metrics, trace] = DetectSwingEvents( ...
        ClusterMap, DisplaySpeed, t, SwingParameters);
    trace.DetectorName = detectorName;

    fprintf('Selected top: %s | %s | %.6f s\n', ...
        char(metrics.TopSource), char(metrics.TopSelectionReason), ...
        metrics.TopOfBackswingTime_s);
    % One row per recording; preserve NaNs/status strings when detection is incomplete.
    SwingMetrics = struct2table(metrics);
    SwingMetrics.Recording = string(recordingRelativePath);
    AllSwingMetrics = [AllSwingMetrics; SwingMetrics];
    AllSwingTraces{i} = trace; % Includes raw/filled data, masks and parameters
    disp(SwingMetrics);

    % These are plotting calls only. The metrics were already chosen above.
    % PlotSwingEvents opens separate spectrogram and envelope-evidence figures.
    % The two following helpers retain the earlier frequency and speed displays.
    PlotSwingEvents(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds, ...
        metrics, trace, wavFile_CW);

    PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);
end

%% Results for all selected recordings
 disp(AllSwingMetrics);

%% Build the comparison table, leaving video-reference columns empty
% The comparison helper does not load, overwrite or merge any existing CSV.
% It creates NEW missing video values for manual entry. Save to a new filename
% rather than replacing Results files that already contain video annotations.
Comparison = CreateComparisonTable(AllSwingMetrics, AllSwingTraces);
disp(Comparison);

% Export stays disabled until I choose a filename. This avoids overwriting
% a CSV into which I have already entered video measurements.
% resultsFolder = fullfile(projectRoot, 'Results');
% if ~isfolder(resultsFolder), mkdir(resultsFolder); end
% comparisonCSV = fullfile(resultsFolder, ...
%     ['SwingMetrics_Comparison_' datestr(now,'yyyymmdd_HHMMSS_FFF') '.csv']);
% writetable(Comparison, comparisonCSV);
