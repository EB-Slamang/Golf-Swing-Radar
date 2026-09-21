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
%                   % '7Iron_Fullswing6_stoponfollowthru.wav';
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

CPI = 0.02;            %coherent processing interval (s)
overlapFrac = 0.95;    %overlap between spectrogram frames
maxSpeed = 60;         %maximum speed shown on the plots (m/s)


%% CA-CFAR parameters
PFA = 1e-3;                 %desired probability of false alarm
RefWindow = 32;             %total number of reference cells
GuardCells = 30;            %keeps the wide club return out of the references
MinimumDetectionSpeed = 1.5; %m/s

% Use more cells above the CUT because the upper side of the club return
% normally has cleaner noise than the lower-speed side.
UseAsymmetricCFAR = true;
UseOSCFAR = true;
AsymmetricMaxSpeed = 25;
LowerRefCells = 2;

Rank = ceil(0.33 * RefWindow); % OS CFAR parameter for kth smallest detection i.e 24th smallest reference power with refWindow =32

%% detection cleaning parameters
MinimumDetectionPowerDB = -40;


M = 3;                  % Minimum number of supporting time columns
N = 5;                  % Number of time columns in the window; must be odd
ToleranceBins = 2;      % Allowed speed-bin distance above/below the candidate
%% plot settings
SpectrogramBounds = [-50 0];
ShowPowerGatedCandidates = true;
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
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
    UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells);

    %% Apply OS-CFAR
    [DetectionMapOS, ThresholdOS] = OS_CFAR(PowerData, speed, ...
    PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
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

    %% Inspect a point in a missing section
    CheckTime = 2.53;     % Change to match the current recording
    CheckSpeed = 25;      % m/s; choose a point on the visible return
    
    [~, timeIdx] = min(abs(t - CheckTime));
    [~, displayRow] = min(abs(DisplaySpeed - CheckSpeed));
    
    speedIdx = displayIdx(displayRow);
    
    cutPower = PowerData(speedIdx, timeIdx);
    osThreshold = ThresholdOS(speedIdx, timeIdx);
    
    cfarMarginDB = 10*log10( ...
        max(cutPower, eps) / max(osThreshold, eps));
    
    gateMarginDB = DisplayPowerDB(displayRow, timeIdx) ...
        - MinimumDetectionPowerDB;
    
    fprintf('\nChecking t = %.4f s, speed = %.2f m/s\n', ...
        t(timeIdx), DisplaySpeed(displayRow));
    
    fprintf('OS-CFAR margin: %.2f dB\n', cfarMarginDB);
    fprintf('Power-gate margin: %.2f dB\n', gateMarginDB);
    %% Apply the same power gate to both detectors
    PowerGate = DisplayPowerDB >= MinimumDetectionPowerDB;
    
    CandidatesCA = DetectionMapCA(displayIdx, :) & PowerGate;
    CandidatesOS = DetectionMapOS(displayIdx, :) & PowerGate;
    
    %% Compare detection maps
    figure;
    
    subplot(2,1,1);
    imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
    axis xy;
    hold on;
    
    [rowsCA, colsCA] = find(CandidatesCA);
    plot(t(colsCA), DisplaySpeed(rowsCA), 'kx', 'MarkerSize', 4);
    
    title([wavFile_CW ' — CA-CFAR'], 'Interpreter', 'none');
    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    colorbar;
    
    subplot(2,1,2);
    imagesc(t, DisplaySpeed, DisplayPowerDB, SpectrogramBounds);
    axis xy;
    hold on;
    
    [rowsOS, colsOS] = find(CandidatesOS);
    plot(t(colsOS), DisplaySpeed(rowsOS), 'kx', 'MarkerSize', 4);
    
    title(sprintf('%s — OS-CFAR, rank %d/%d', ...
        wavFile_CW, Rank, RefWindow), 'Interpreter', 'none');
    xlabel('Time (s)');
    ylabel('Radial speed (m/s)');
    colorbar;
    
    colormap('jet');

    figure;

    plot(DisplaySpeed, ...
        10*log10(max(PowerData(displayIdx, timeIdx), eps)), ...
        'b', 'LineWidth', 1.2);
    hold on;
    
    plot(DisplaySpeed, ...
        10*log10(max(ThresholdCA(displayIdx, timeIdx), eps)), ...
        'r', 'LineWidth', 1.2);
    
    plot(DisplaySpeed, ...
        10*log10(max(ThresholdOS(displayIdx, timeIdx), eps)), ...
        'k', 'LineWidth', 1.2);
    
    xlabel('Radial speed (m/s)');
    ylabel('Whitened, averaged power / threshold (dB)');
    title(sprintf('CFAR comparison at %.4f s', t(timeIdx)));
    legend('Input power', 'CA threshold', 'OS threshold');
    grid on;
    
     %% original spectrogram and speed-time plot
    SpectrogramBounds = [-50 0]; %intensity color bounds in dB
    
    % PlotSpectrogram(S,f,t,wavFile_CW,SpectrogramBounds);

    
    PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,SpectrogramBounds);

    % %% choose which markers to display
    % [markerTimes,markerSpeeds] = selectDetectionMarkers( ...
    %     DetectionCandidates,DisplaySpeed,t);

    % %% speed-time plot with the detections
    % figure;
    % imagesc(t,DisplaySpeed,DisplayPowerDB,SpectrogramBounds);
    % axis xy;
    % hold on;
    % 
    % if ShowPowerGatedCandidates
    %     [candidateRows,candidateCols] = find(DetectionCandidates);
    %     plot(t(candidateCols),DisplaySpeed(candidateRows),'mx','MarkerSize',4);
    % end
    % 
    % plot(markerTimes,markerSpeeds, ...
    %     'kx','MarkerSize',6,'LineWidth',1);
    % 
    % xlabel('Time (s)');
    % ylabel('Radial speed magnitude (m/s)');
    % title(sprintf('%s: column-wise CA-CFAR detections',wavFile_CW), ...
    %       'Interpreter','none');
    % colorbarHandle = colorbar;
    % ylabel(colorbarHandle,'Normalised intensity (dB)');
    % colormap('jet');

   

end 


%%functions

function [markerTimes,markerSpeeds] = selectDetectionMarkers( ...
    detectionMap,displaySpeed, timeVector)

    [~,nTimeBins] = size(detectionMap);
    markerTimes = [];
    markerSpeeds = [];

    for timeIdx = 1:nTimeBins
        detectedRows = find(detectionMap(:,timeIdx));

        if isempty(detectedRows)
            continue;
        end

        selectedSpeeds = displaySpeed(detectedRows);
        
        markerTimes = [markerTimes; repmat(timeVector(timeIdx),numel(selectedSpeeds),1)];
        markerSpeeds = [markerSpeeds; selectedSpeeds(:)];
    end
end