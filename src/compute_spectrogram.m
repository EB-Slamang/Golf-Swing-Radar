%Ebrahiem Slamang
%EEE4022S
%======= Sprectrogram function =======

function [S, f, t] = compute_spectrogram(x, fs, frameLen, overlapFrac, win, nfft)
    x = x(:).';
    N = length(x);
    if overlapFrac<=1 % so either overlap % as a fraction or hopsize as an integer can be input
        hop = round(frameLen*(1 - overlapFrac));
    else
        hop = overlapFrac;
    end
    numFrames = floor((N - frameLen)/hop) + 1;
    S = zeros(nfft, numFrames);
 
    for k = 1:numFrames
        startIdx = (k-1)*hop + 1;
        stopIdx  = startIdx + frameLen - 1;
        segment  = x(startIdx:stopIdx);
        segment  = segment .* win;
        segment = segment - mean(segment); %removes DC components/offsets
        spectrum = fft(segment, nfft);
        S(:,k)   = fftshift(spectrum);
    end
 
    f = (-floor(nfft/2) : ceil(nfft/2)-1) * (fs/nfft);
    t = ((0:numFrames-1)*hop + frameLen/2) / fs;
end