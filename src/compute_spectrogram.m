%Ebrahiem Slamang
%EEE4022S
%======= Sprectrogram function =======

function [S, f, t] = compute_spectrogram(x, fs, frameLen, overlapFrac, win, nfft)
% COMPUTE_SPECTROGRAM - Complex short-time Fourier transform, one frame per column.
%
% INPUTS
%   x           : sampled real or complex signal; reshaped into a row here.
%   fs          : sampling frequency in Hz.
%   frameLen    : measured samples per frame (L), chosen by the calling script.
%   overlapFrac : value <= 1 means an overlap fraction; value > 1 is a hop in
%                 samples. For valid use, the resulting hop must be positive
%                 and integer. Use 0 <= fraction < 1 for fraction-based input.
%   win         : row-vector window with frameLen weights.
%   nfft        : FFT length; use nfft >= frameLen to avoid truncating the frame.
%
% OUTPUTS
%   S : complex, fftshift-centred spectra, size nfft by number of complete frames.
%   f : signed frequency-bin centres in Hz, in the same row order as S.
%   t : frame-centre timestamps in seconds, one entry per column.
%
% The function does not square magnitudes, convert to speed or normalise power.
% The caller makes the Hamming window and rounds the requested CPI. This helper
% uses exactly the supplied lengths. It discards an incomplete trailing frame.
% For arbitrary external use, supply at least one complete frame and valid sizes.
    x = x(:).';
    N = length(x);
    if overlapFrac<=1 % so either overlap % as a fraction or hopsize as an integer can be input
        hop = round(frameLen*(1 - overlapFrac));
    else
        hop = overlapFrac;
    end
    % The last start index must leave frameLen measured samples available.
    % Flooring the frame count excludes any incomplete recording tail.
    numFrames = floor((N - frameLen)/hop) + 1;
    S = zeros(nfft, numFrames);
 
    for k = 1:numFrames
        startIdx = (k-1)*hop + 1;
        stopIdx  = startIdx + frameLen - 1;
        segment  = x(startIdx:stopIdx);
        segment  = segment .* win;
        % The mean is subtracted AFTER applying the window, matching this project's
        % implementation. This suppresses the FFT's zero-frequency coefficient; it is
        % not a general removal of all low-frequency clutter.
        segment = segment - mean(segment); %removes DC components/offsets
        spectrum = fft(segment, nfft);
        S(:,k)   = fftshift(spectrum);
    end
 
    % fftshift puts negative bins first and the zero bin near the middle.
    % The axis expression works for even and odd FFT lengths. The time expression
    % uses the implementation's frameLen/2 convention for a frame-centre timestamp.
    f = (-floor(nfft/2) : ceil(nfft/2)-1) * (fs/nfft);
    t = ((0:numFrames-1)*hop + frameLen/2) / fs;
end