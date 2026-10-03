%Ebrahiem Slamang
%EEE4022S

function MeasuredPFA = Test_CFAR(Method, UseAsymmetricCFAR)
% Test CFAR detector using noise only: every detection is a false alarm.
% Run in Command Window
% Examples: Test_CFAR('CA', true) or Test_CFAR('OS', false).
% Both inputs are required. Method must be 'CA' or 'OS'.
% Checks PFA only

    %% 1. CFAR Parameters
    PFA = 1e-4;
    GuardCells = 24;
    LowerRefCells = 5;
    MinimumDetectionSpeed = 1.5;
    maxSpeed = 60;
    AsymmetricMaxSpeed = 60;

    nSpeedBins = 2000; 
    nColumns = 10000;
    speed = linspace(0, 80, nSpeedBins);

    %% 2. Generate complex noise and calculate linear power
    noise = (randn(nSpeedBins, nColumns) + ...
             1i * randn(nSpeedBins, nColumns)) / sqrt(2);
    Power = abs(noise).^2;

    %% 3. Run the chosen CFAR function
    if strcmp(Method, 'CA')
        RefWindow = 36;
        [DetectionMap, Threshold] = CA_CFAR(Power, speed, ...
            PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
            UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells);

    elseif strcmp(Method, 'OS')
        RefWindow = 48;
        Rank = 36;
        [DetectionMap, Threshold] = OS_CFAR(Power, speed, ...
            PFA, RefWindow, GuardCells, MinimumDetectionSpeed, maxSpeed, ...
            UseAsymmetricCFAR, AsymmetricMaxSpeed, LowerRefCells, Rank);
    else
        error('Use CA or OS for Method.');
    end

    %% 4. Count false alarms and cells actually tested
    FalseAlarms = 0;
    TestedCells = 0;

    for row = 1:nSpeedBins
        if speed(row) >= MinimumDetectionSpeed && speed(row) <= maxSpeed
            for column = 1:nColumns
                % CFAR functions leave untested thresholds as NaN.
                if ~isnan(Threshold(row, column))
                    TestedCells = TestedCells + 1;
                    if DetectionMap(row, column) == 1
                        FalseAlarms = FalseAlarms + 1;
                    end
                end
            end
        end
    end

    if TestedCells == 0
        error('No cells were tested. Check the CFAR settings.');
    end
   %% 5. Performance check

   
    % no targets, so every detection is a false alarm.
    NumberOfFalseAlarms = FalseAlarms;
    NumberOfCUTsTested = TestedCells;
    
    % Calculate measured PFA and absolute percentage error.
    PFA_Simulation = NumberOfFalseAlarms / NumberOfCUTsTested;
    PFA_error = abs((PFA - PFA_Simulation) / PFA) * 100;
    
    % Keep the output variable used by Test_CFAR.
    MeasuredPFA = PFA_Simulation;

    expectedFalseAlarms = NumberOfCUTsTested * PFA;
    
    fprintf('\n%s-CFAR performance check\n', Method);
    fprintf('Reference window (N):         %d\n', RefWindow);
    fprintf('Desired PFA:                  %.4g\n', PFA);
    fprintf('Number of CUTs tested:        %d\n', NumberOfCUTsTested);
     fprintf('Expected false alarms:        %.1f\n', expectedFalseAlarms);
    fprintf('Number of false alarms:      %d\n', NumberOfFalseAlarms);
    fprintf('Simulated PFA:                %.4g\n', PFA_Simulation);
    fprintf('PFA error:                    %.2f %%\n', PFA_error);
    
    % Check against a chosen 10% error tolerance.
    if PFA_error < 10
        fprintf('Error check: PASS (PFA error < 10%%).\n');
    else
        fprintf('Error check: Outside the chosen 10%% tolerance.\n');
    end
    
    % Approximate statistical check.
    % This binomial formula assumes independent detection decisions.
    
    stdFalseAlarms = sqrt(NumberOfCUTsTested * PFA * (1 - PFA));
    
    lowerLimit = expectedFalseAlarms - 3 * stdFalseAlarms;
    upperLimit = expectedFalseAlarms + 3 * stdFalseAlarms;
    
    % A false-alarm count cannot be negative.
    if lowerLimit < 0
        lowerLimit = 0;
    end
    
   
    fprintf('Approximate 3-sigma range:     %.1f to %.1f\n', lowerLimit, upperLimit);
    
    if NumberOfFalseAlarms >= lowerLimit && NumberOfFalseAlarms <= upperLimit
    
        fprintf('Statistical check: Within the approximate 3-sigma range.\n');
    else
        fprintf('Statistical check: Outside the approximate 3-sigma range.\n');
    end

    %% 6. Plot noise power with detections marked by red crosses
    figure;
    imagesc(1:nColumns, speed, 10*log10(Power + eps));
    axis xy;
    colorbar;
    hold on;
    [detectionRows, detectionColumns] = find(DetectionMap);
    plot(detectionColumns, speed(detectionRows), 'rx');
    xlabel('Column number');
    ylabel('Speed (m/s)');
    title([Method '-CFAR: noise power (dB) and false alarms']);
end
