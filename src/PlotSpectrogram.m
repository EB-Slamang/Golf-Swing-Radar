function [] = PlotSpectrogram(S,f,t,wavFile_CW,Intensity_bnds)

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