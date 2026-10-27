% TEST_CFAR - Standalone detector verification; no bundled recordings required.
% TEST 1: independent exponential powers check the nominal threshold model.
% TEST 2: real Gaussian noise passes through the Hamming STFT and conditioning.
% TEST 3: one flat and three parabolic Doppler tracks test exact-bin and nearby-bin
% hits. Separate target-free portions estimate false alarms in each signal record.
%
% PFA = false alarms / cells with finite thresholds in the scored noise region.
% PD  = known-target frame hits / scored active frames. Nearby-bin PD is a separate
% score allowing +/-NearbyBins. These are not complete swing-recognition rates.
% All methods/arcs share noise for comparison; overlapping decisions are correlated.
% SaveResults and SavePlots write into a new timestamped CFAR_Check_* folder.

% Ebrahiem Slamang
% EEE4022S
% I use two noise-only checks and four known arcs to check my CFAR detectors.
% Run this script from the pipeline folder, beside the src folder.
% This does not call clustering, event extraction or the original-power gate.
% This is a SCRIPT called Test_CFAR.m. I run it without input arguments.
% I keep exact-bin PD, nearby-bin PD and noise-only PFA as different scores.
% I do not change my actual CA_CFAR, OS_CFAR or spectrogram functions.

clear all;


%% Radar and spectrogram settings
scriptFolder = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptFolder,'src'));
assert(exist('CA_CFAR','file') && exist('OS_CFAR','file') && ...
    exist('compute_spectrogram','file'),'Place this script beside the pipeline src folder.');
fs = 44100;
lambda = 3e8/24e9;
requestedCPI = 0.01;
overlap = 0.95;
L = 2^nextpow2(round(requestedCPI*fs));
H = round(L*(1-overlap));
n = 0:L-1;
w = 0.54-0.46*cos(2*pi*n/(L-1)); %  symmetric Hamming window.

%% Detector settings: I use the same window geometry for both detectors
p.PFA = 1e-5;
p.RefCA = 42; p.GuardCA = 20;
p.RefOS = 42; p.GuardOS = 20;   
p.LowerCA = ceil(0.1*p.RefCA);
p.LowerOS = ceil(0.1*p.RefOS);
p.Rank = ceil(0.3*p.RefOS);         %0.3
p.MinSpeed = 0; p.MaxSpeed = 55;
p.Asymmetric = true;
p.AsymmetricMaxSpeed = 60;
% Matching these settings controls the window geometry. The measured PFA can
% still differ because CA and OS use different background estimates.

%% Test settings
Seed = 4022;
rng(Seed);                     % Can repeat the same test by keeping this seed.
NoiseColumns = 100000;         % Number of independent noise-only columns.
BatchSize = 1000;              % I process these columns in smaller memory blocks.
NoiseRecords = 10;             % Separate 3-second noise records for the STFT check.
NoiseStd = 1;                  % Standard deviation of the real Gaussian noise.
SignalAmplitude = 1;         % Amplitude of the real cosine BEFORE adding noise.
recordDuration = 3;
trackStart = 1;
trackDuration = [0.6 0.6 0.6 0.20]; % The last arc changes speed much faster.
peakSpeed = 45;
edgeDrop = [0 5 15 40];        % Endpoint speeds: 45, 40, 30 and 5 m/s.
NearbyBins = 1;                % Extra score: a detection within +/-1 FFT bin.
% The steep arc has maximum |dv/dt| = 4*40/0.20 = 800 m/s^2.
% The previous steep arc was 4*30/0.6 = 200 m/s^2.

arcNames = {'Flat','Gentle','Moderate','Steep'};
methodNames = {'CA','OS'};
SaveResults = false;
SavePlots = false;             % I can save the open figures manually instead.
outputFolder = fullfile(scriptFolder,['CFAR_Check_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);
if SaveResults || SavePlots
    mkdir(outputFolder);
end

% I use my actual spectrogram function to obtain its frequency and time axes.
sampleTime = (0:round(recordDuration*fs)-1)'/fs;
[~,f,t] = compute_spectrogram(zeros(size(sampleTime)),fs,L,overlap,w,L);
t = t(:).';
speed = f(:)*lambda/2;
rows = find(speed >= p.MinSpeed & speed <= p.MaxSpeed);
fprintf('\nActual CPI: %.3f ms | hop: %.6f ms | FFT length: %d\n',1000*L/fs,1000*H/fs,L);
fprintf('Desired PFA: %.3g | signal amplitude: %.2f | noise std: %.2f\n', ...
    p.PFA,SignalAmplitude,NoiseStd);
fprintf('Nominal active-signal time-domain SNR: %.2f dB\n', ...
    10*log10(SignalAmplitude^2/(2*NoiseStd^2)));

% I draw the signal-test noise now, so changing the number of noise-only checks
% does not change the four arc comparisons.
signalNoise = NoiseStd*randn(size(sampleTime));

%% TEST 1: independent noise power -- check the nominal CFAR calibration
% Exponential power is the background model used by the threshold formulas.
% There is NO target, so every detection is a false alarm.
falseAlarms = zeros(2,1); testedCells = zeros(2,1);
idealFigures = gobjects(2,1);
for first = 1:BatchSize:NoiseColumns
    columns = min(BatchSize,NoiseColumns-first+1);
    P = -log(max(rand(numel(speed),columns),realmin)); % Mean-one exponential power.
    for method = 1:2
        [D,T] = applyDetector(P,speed,p,method);
        valid = isfinite(T) & speed >= p.MinSpeed & speed <= p.MaxSpeed;
        falseAlarms(method) = falseAlarms(method)+nnz(D & valid);
        testedCells(method) = testedCells(method)+nnz(valid);
        if first == 1
            idealFigures(method) = showResult(P,D & valid,1:columns,speed,p, ...
                [methodNames{method} ': independent noise'],[],[]);
            xlabel('Independent noise column');
        end
    end
end
IdealPFA = table(string(methodNames(:)),falseAlarms,testedCells, ...
    p.PFA*testedCells,falseAlarms./testedCells, ...
    'VariableNames',{'Method','FalseAlarms','TestedCells','NominalExpectedAlarms','MeasuredPFA'});
IdealPFA.DesiredPFA = repmat(p.PFA,2,1);
IdealPFA.PFADeviationPercent = 100*(IdealPFA.MeasuredPFA/p.PFA-1);
fprintf('\nTEST 1: INDEPENDENT NOISE POWER\n'); disp(IdealPFA);
for method = 1:2
    figure(idealFigures(method));
    title(sprintf('%s: ideal-noise PFA = %.3g',methodNames{method},IdealPFA.MeasuredPFA(method)));
    if SavePlots, exportgraphics(gcf,fullfile(outputFolder,[methodNames{method} '_IndependentNoise.png']),'Resolution',300); end
end

%% TEST 2: Gaussian noise through my STFT and conditioning -- practical PFA
% I still inject NO target. I now include the preprocessing used in my pipeline.
falseAlarms = zeros(2,1); testedCells = zeros(2,1);
processedFigures = gobjects(2,1);
for record = 1:NoiseRecords
    noise = NoiseStd*randn(size(sampleTime));
    [S,~,~] = compute_spectrogram(noise,fs,L,overlap,w,L);
    P = abs(S).^2;
    P = P./max(median(P,2),eps);
    P = movmean(P,3,2);
    for method = 1:2
        [D,T] = applyDetector(P,speed,p,method);
        valid = isfinite(T) & speed >= p.MinSpeed & speed <= p.MaxSpeed;
        falseAlarms(method) = falseAlarms(method)+nnz(D & valid);
        testedCells(method) = testedCells(method)+nnz(valid);
        if record == 1
            processedFigures(method) = showResult(P,D & valid,t,speed,p, ...
                [methodNames{method} ': processed noise'],[],[]);
        end
    end
end
ProcessedPFA = table(string(methodNames(:)),falseAlarms,testedCells, ...
    p.PFA*testedCells,falseAlarms./testedCells, ...
    'VariableNames',{'Method','FalseAlarms','TestedCells','NominalExpectedAlarms','MeasuredPFA'});
ProcessedPFA.DesiredPFA = repmat(p.PFA,2,1);
ProcessedPFA.PFADeviationPercent = 100*(ProcessedPFA.MeasuredPFA/p.PFA-1);
fprintf('\nTEST 2: NOISE AFTER STFT AND CONDITIONING\n'); disp(ProcessedPFA);
for method = 1:2
    figure(processedFigures(method));
    title(sprintf('%s: processed-noise PFA = %.3g',methodNames{method},ProcessedPFA.MeasuredPFA(method)));
    if SavePlots, exportgraphics(gcf,fullfile(outputFolder,[methodNames{method} '_ProcessedNoise.png']),'Resolution',300); end
end

%% TEST 3: four known arcs -- exact-bin PD, nearby-bin PD and background PFA
% I keep the same noise for all arcs and both detectors.
% The last arc is shorter as well as steeper. I report its own frame count;
% this is a fast-motion stress test, not a curvature-only controlled comparison.
% The signal is a simple synthetic target and does not reproduce all real echoes.
noise = signalNoise;
u = sampleTime-trackStart;
margin = L/(2*fs)+H/fs; % STFT half-frame plus the three-frame averaging support.
PD = zeros(4,2); NearbyPD = zeros(4,2);
HitFrames = zeros(4,2); NearbyHitFrames = zeros(4,2);
FramesPerArc = zeros(4,1);
SignalFalseAlarms = zeros(4,2); SignalTestedCells = zeros(4,2);
MedianTargetPower = zeros(4,1); MedianThreshold = zeros(4,2);
MaxSlope = 4*edgeDrop./trackDuration;

for arc = 1:4
    duration = trackDuration(arc);
    active = u >= 0 & u < duration;
    v = peakSpeed-edgeDrop(arc)*(2*u/duration-1).^2;
    doppler = 2*v(active)/lambda;
    % Frequency is cycles per second. Accumulating frequency/fs gives cycles
    % per sample history; multiplying by 2*pi produces the cosine phase in radians.
    % Integrating frequency is necessary: cos(2*pi*f(t)*t) would not generally have
    % the intended time-varying instantaneous frequency.
    phase = 2*pi*cumsum(doppler)/fs;
    clean = zeros(size(sampleTime));
    clean(active) = SignalAmplitude*cos(phase);

    % I score PD only where the complete processing window contains the target.
    scoreFrames = find(t >= trackStart+margin & t <= trackStart+duration-margin);

    FramesPerArc(arc) = numel(scoreFrames);

    % I score PFA only before and after the injected signal. I also exclude
    % frames that overlap its start/end through the STFT or the moving mean.
    % Every frequency cell in these frames is target-free before conditioning.
    noiseFrames = find(t+margin < trackStart | t-margin >= trackStart+duration);
    

    % I find one known target bin per frame from the NOISE-FREE STFT.
    [cleanS,~,~] = compute_spectrogram(clean,fs,L,overlap,w,L);
    [~,localRow] = max(abs(cleanS(rows,:)).^2,[],1);
    truthRow = rows(localRow);
    truthRow = truthRow(:).';
    % sub2ind converts each known row/column pair into a linear matrix index.
    % The same indices then select power, threshold and detection at the truth bin.
    % Truth comes from the NOISE-FREE signal, never from noisy detector output.
    truthIndex = sub2ind(size(cleanS),truthRow,1:numel(t));

    [S,~,~] = compute_spectrogram(clean+noise,fs,L,overlap,w,L);
    rawPower = abs(S).^2;
    P = rawPower./max(median(rawPower,2),eps);
    P = movmean(P,3,2);
    targetPower = P(truthIndex(scoreFrames));
    MedianTargetPower(arc) = median(targetPower);
    targetThreshold = zeros(numel(scoreFrames),2);

    for method = 1:2
        [D,T] = applyDetector(P,speed,p,method);
        

        % My original strict PD: did CFAR detect the exact known target bin?
        hits = D(truthIndex(scoreFrames));
        HitFrames(arc,method) = nnz(hits);
        PD(arc,method) = nnz(hits)/numel(scoreFrames);

        % My extra score allows a detection one bin either side of that bin.
        % I keep this separate so it cannot silently inflate the original PD.
        nearbyHits = false(size(hits));
        for offset = -NearbyBins:NearbyBins
            nearRow = truthRow(scoreFrames)+offset;
            nearRow = max(rows(1),min(rows(end),nearRow));
            nearIndex = sub2ind(size(D),nearRow,scoreFrames);
            nearbyHits = nearbyHits | (D(nearIndex) & isfinite(T(nearIndex)));
        end
        NearbyHitFrames(arc,method) = nnz(nearbyHits);
        NearbyPD(arc,method) = nnz(nearbyHits)/numel(scoreFrames);

        % These are actual noise-only CUTs within the signal-containing record.
        % I do NOT call other detections during the arc false alarms: they may
        % belong to its broadened main lobe or sidelobes.
        validNoise = isfinite(T(:,noiseFrames)) & ...
            speed >= p.MinSpeed & speed <= p.MaxSpeed;
        SignalTestedCells(arc,method) = nnz(validNoise);
        SignalFalseAlarms(arc,method) = nnz(D(:,noiseFrames) & validNoise);

        targetThreshold(:,method) = T(truthIndex(scoreFrames)).';
        MedianThreshold(arc,method) = median(targetThreshold(:,method));
        measuredPFA = SignalFalseAlarms(arc,method)/SignalTestedCells(arc,method);
        pfaDeviation = 100*(measuredPFA/p.PFA-1);
        fprintf('%s | %s | exact PD %.1f%% | nearby PD %.1f%% | PFA %.3g (%+.1f%%)\n', ...
            methodNames{method},arcNames{arc},100*PD(arc,method), ...
            100*NearbyPD(arc,method),measuredPFA,pfaDeviation);

        % Red crosses are ALL threshold crossings, not just false alarms.
        % Green circles are exact target-bin hits and purple squares are misses.
        valid = isfinite(T) & speed >= p.MinSpeed & speed <= p.MaxSpeed;
        referencePower = max(rawPower(rows,:),[],'all');
        relativePower = rawPower/max(referencePower,eps);
        label = sprintf('%s: %s | exact PD %.1f%% | nearby PD %.1f%%', ...
            methodNames{method},arcNames{arc},100*PD(arc,method),100*NearbyPD(arc,method));
        showResult(relativePower,D & valid,t,speed,p,label, ...
            t(scoreFrames),peakSpeed-edgeDrop(arc)*(2*(t(scoreFrames)-trackStart)/duration-1).^2);
        plot(t(scoreFrames(hits)),speed(truthRow(scoreFrames(hits))), ...
            'go','MarkerSize',4,'DisplayName','Exact-bin hits');
        plot(t(scoreFrames(~hits)),speed(truthRow(scoreFrames(~hits))), ...
            'ms','MarkerSize',3,'DisplayName','Exact-bin misses');
        title({label,sprintf('Target-free frames: PFA %.3g | nominal %.3g | deviation %+.1f%%', ...
            measuredPFA,p.PFA,pfaDeviation)},'Interpreter','none');
        xlim([trackStart-0.08 trackStart+duration+0.08]);
        caxis([-50 0]);
        cb = colorbar; cb.Label.String = 'Original relative power (dB)';
        legend('show','Location','southoutside','NumColumns',2,'FontSize',11);
        if SavePlots
            exportgraphics(gcf,fullfile(outputFolder,[methodNames{method} '_' arcNames{arc} '.png']),'Resolution',300);
        end
    end

    % This shows directly WHY a known target bin passes or fails the detector.
    figure('Color','white','Units','centimeters','Position',[2 2 18 10]);
    plot(t(scoreFrames),targetPower,'k','LineWidth',1.2); hold on;
    plot(t(scoreFrames),targetThreshold(:,1),'b','LineWidth',1.2);
    plot(t(scoreFrames),targetThreshold(:,2),'r','LineWidth',1.2);
    xlabel('Time (s)'); ylabel('Conditioned linear power');
    title([arcNames{arc} ': known target-bin power and thresholds']);
    legend('Known target-bin power','CA threshold','OS threshold','Location','best');
    grid on; set(gca,'FontSize',14,'FontName','Times New Roman');
    if SavePlots
        exportgraphics(gcf,fullfile(outputFolder,[arcNames{arc} '_TargetThresholds.png']),'Resolution',300);
    end
end

SignalPD = table(string(arcNames(:)),trackDuration(:),peakSpeed-edgeDrop(:), ...
    MaxSlope(:),FramesPerArc,HitFrames(:,1),HitFrames(:,2),PD(:,1),PD(:,2), ...
    NearbyHitFrames(:,1),NearbyHitFrames(:,2),NearbyPD(:,1),NearbyPD(:,2), ...
    MedianTargetPower,MedianThreshold(:,1),MedianThreshold(:,2), ...
    'VariableNames',{'Arc','Duration_s','EndpointSpeed_mps','MaxAbsSlope_mps2', ...
    'FramesPerArc','CAHits','OSHits','CA_PD','OS_PD','CANearbyHits','OSNearbyHits', ...
    'CA_NearbyPD','OS_NearbyPD','MedianTargetPower','MedianCAThreshold','MedianOSThreshold'});

% I keep the injected-record PFA results in a separate table for clarity.
% Each arc appears twice: CA first and OS second.
ArcColumn = repelem(string(arcNames(:)),2);
MethodColumn = repmat(string(methodNames(:)),4,1);
AlarmColumn = reshape(SignalFalseAlarms.',[],1);
CellColumn = reshape(SignalTestedCells.',[],1);
SignalPFA = table(ArcColumn,MethodColumn,AlarmColumn,CellColumn, ...
    p.PFA*CellColumn,AlarmColumn./CellColumn,repmat(p.PFA,8,1), ...
    100*((AlarmColumn./CellColumn)/p.PFA-1), ...
    'VariableNames',{'Arc','Method','FalseAlarms','TestedCells', ...
    'NominalExpectedAlarms','MeasuredPFA','DesiredPFA','PFADeviationPercent'});

fprintf('\nTEST 3: DETECTION OF THE KNOWN SIGNAL\n'); disp(SignalPD);
fprintf('\nTEST 3: TARGET-FREE FRAMES OF THE INJECTED-SIGNAL RECORD\n'); disp(SignalPFA);
fprintf('PFA deviation = 100*(measured PFA / desired PFA - 1).\n');
fprintf('The signal-record PFA excludes the arc and all boundary-overlap frames.\n');
fprintf('Only a few false alarms are expected per signal record: use Test 2 for a larger noise check.\n');
fprintf('Exact-bin PD and nearby-bin PD are different scores; neither includes clustering.\n');
fprintf('Frames overlap and the arcs share noise: do not treat the decisions as independent trials.\n');
fprintf('Noise figures show only the first batch/record; their PFA uses ALL noise data.\n');
fprintf('The median normalisation uses the complete record, including the injected arc.\n');
fprintf('A flat trace can raise its own frequency-row median more than a moving trace.\n');
fprintf('Threshold diagnostic plots use conditioned linear power, not raw display dB.\n');

if SaveResults
    writetable(IdealPFA,fullfile(outputFolder,'Ideal_Noise_PFA.csv'));
    writetable(ProcessedPFA,fullfile(outputFolder,'Processed_Noise_PFA.csv'));
    writetable(SignalPD,fullfile(outputFolder,'Signal_PD.csv'));
    writetable(SignalPFA,fullfile(outputFolder,'Signal_PFA.csv'));
    save(fullfile(outputFolder,'CFAR_Verification.mat'),'IdealPFA','ProcessedPFA', ...
        'SignalPD','SignalPFA','p','Seed','fs','L','H','w','requestedCPI','overlap', ...
        'NoiseColumns','BatchSize','NoiseRecords','NoiseStd','SignalAmplitude', ...
        'recordDuration','trackStart','trackDuration','peakSpeed','edgeDrop','NearbyBins');
    fprintf('Results saved in:\n%s\n',outputFolder);
end

%% I keep the two repeated operations below so the test itself stays readable.
function [D,T] = applyDetector(P,speed,p,method)
% Use method=1 for CA and method=2 for OS, retaining the two sets of explicit
% test parameters. This helper does not apply the main pipeline's power gate,
% DBSCAN or event extraction; those stages are outside this benchmark.
if method == 1
    [D,T] = CA_CFAR(P,speed,p.PFA,p.RefCA,p.GuardCA,p.MinSpeed,p.MaxSpeed, ...
        p.Asymmetric,p.AsymmetricMaxSpeed,p.LowerCA);
else
    [D,T] = OS_CFAR(P,speed,p.PFA,p.RefOS,p.GuardOS,p.MinSpeed,p.MaxSpeed, ...
        p.Asymmetric,p.AsymmetricMaxSpeed,p.LowerOS,p.Rank);
end
end

function fig = showResult(P,D,t,speed,p,label,truthTime,truthSpeed)
% Create a diagnostic power image and overlay ALL supplied crossings.
% The input P is linear; this helper only converts it to dB for display.
% Red crosses may be target-associated or false: scoring elsewhere establishes
% which cells/frames count as false alarms. The optional yellow line is truth.
fig = figure('Color','white','Name',label,'Units','centimeters', ...
    'Position',[2 2 18 10]);
imagesc(t,speed,10*log10(max(P,eps))); axis xy; hold on;
[rows,cols] = find(D);
plot(t(cols),speed(rows),'rx','MarkerSize',3,'DisplayName','All CFAR threshold crossings');
if ~isempty(truthTime)
    plot(truthTime,truthSpeed,'y-','LineWidth',1.5,'DisplayName','Injected speed');
end
ylim([p.MinSpeed p.MaxSpeed]);
xlabel('Time (s)','FontSize',15); ylabel('Radial speed (m/s)','FontSize',15);
title(label,'Interpreter','none');
cb = colorbar; cb.Label.String = 'Detector input power (dB)';
set(gca,'FontSize',14,'FontName','Times New Roman'); cb.FontSize = 14;
cb.Label.FontSize = 14;
colormap(parula);
legend('show','Location','southoutside','FontSize',11);
end
