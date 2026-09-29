function [] = PlotSpeedvsTime(S,f,t,fc,wavFile,Maxspeed,bnds)

% function [] = PlotSpeedvsTime(S,f,t,fc,wavFile,Maxspeed,bnds)
% 
% Produces a Speed vs Time image of the
% CW radar recording. 
%
%    wavFile = the filename of the .WAV file to process
%     
% 2026 University of Cape Town 


c = 3e8; %speed of light (m/s)

lambda = c/fc; %wavelength

speed = f*lambda/2; % (m/s)
speed_Idx = find((speed <= Maxspeed) & (speed >= 1.5)); %creating indices where speed is between 1.5 m/s and max

SpeedVector = speed(speed_Idx); %applying indices to speed vector for plotting
S_OfInterest = S(speed_Idx, :); %applying indices to Spectrogram values

S_normalized = abs(S_OfInterest)/max(max(abs(S_OfInterest))); % normalizing spectrogram amplitudes
S_normalized_db = 20*log10(S_normalized); % converting linear to dB


figure;
imagesc(t,SpeedVector,S_normalized_db,bnds);
% imagesc(t,f,S_db,clims); %to plot frequency spectrogram
axis xy;    
xlabel('Time (s)');
ylabel('Speed (m/s)');
% ylabel('Frequency (Hz)');
title(sprintf('Speed vs Time of %s spectrogram', wavFile), 'Interpreter', 'none');
% title(sprintf('Spectrogram of %s ', wavFile_CW), 'Interpreter', 'none');
colorbar;
ylabel(colorbar,'Intensity (dB)');
colormap('jet');