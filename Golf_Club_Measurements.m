clear;
close all;
clc;

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
    fullfile('P002', 'session1', 'Driver_FullSwing2.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing3.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing4.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing5.wav')
    fullfile('P002', 'session1', 'Driver_FullSwing6_stoponfollowthru.wav')
    
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

fc = 24e9; %center frequency (Hz)
% CPI_arr = [0.01 0.02 0.05 0.075 0.1]; %array to check different CPI's
CPI = 0.02; % seconds (chosen for finer time resolution to track faster moving objects)
%0.2 for Backswing, 0.02 for Downswing and Fullswing Tests

% PFA          = 1e-3;   % relaxed back up now that binary integration handles the specks
% RefWindow    = 48;
% GuardCells   = 8;       % widened to cover the ridge's Doppler extent, avoid self-masking
% MinSpeed     = 1.5;
% MinRunLength = 3;       % require a detection to persist 3+ consecutive time columns

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
    
    framelen =  2^(nextpow2(round(CPI*fs))); % chosen as closest power of 2
    overlapFrac = 0.95; 
    n_fft = framelen;
    
    maxSpeed = 60; % (m/s) maximum speed to display (times by 3.6 to get km/h)
    %used 4 m/s for pendulum test, 10 for Backswing Tests, 12 for Downswing Tests and 23 Fullswing Tests
    n = 0:framelen-1;
    win = 0.54 - 0.46*cos(2*pi*n/(framelen-1)); % creating hamming window
    
    
    
    [S, f, t] = compute_spectrogram(y, fs, framelen, overlapFrac, win, n_fft);
    
    bnds = [-50 0]; %intensity color bounds in dB
    
    % PlotSpectrogram(S,f,t,wavFile_CW,bnds);

    
    PlotSpeedvsTime(S,f,t,fc,wavFile_CW,maxSpeed,bnds);

    % end
end 