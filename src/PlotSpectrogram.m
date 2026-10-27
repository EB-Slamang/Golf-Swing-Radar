function [] = PlotSpectrogram(S,f,t,wavFile_CW,Intensity_bnds)
% PLOTSPECTROGRAM - Display the signed-frequency STFT without changing results.
% S is complex STFT output; f is in Hz and t in seconds. Intensity_bnds are
% display colour limits in dB. This helper uses 20*log10(abs(S)) directly,
% without the recording-maximum normalisation used by PlotSpeedvsTime.
% A zero magnitude can therefore display as -Inf and saturate at the colour floor.
% Mirrored positive/negative components of real input do not establish direction.
% The function creates a figure but does not save it or run detection.

S_db = 20*log10(abs(S));
figure;


imagesc(t,f,S_db,Intensity_bnds); %to plot frequency spectrogram
axis xy;    
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title(sprintf('Spectrogram of %s ', wavFile_CW), 'Interpreter', 'none');
colorbar;
ylabel(colorbar,'Intensity (dB)');
colormap('jet');