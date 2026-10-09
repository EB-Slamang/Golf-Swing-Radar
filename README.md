# Golf Swing Radar Processing

MATLAB processing pipeline for the EEE4022S golf swing project by Ebrahiem Slamang. The pipeline processes 24 GHz continuous-wave (CW) radar WAV recordings, compares CA-CFAR and OS-CFAR detections, groups returns using DBSCAN, and estimates swing events and timing metrics from OS-CFAR clusters.

Speeds are radial components along the radar beam, rather than total three-dimensional club-head speeds. Swing events are algorithmic candidates requiring reference/video validation; retained clusters are not automatically identified as club-head returns.

## Repository files

The main script, configuration files and README belong in the `Pipeline` root. Processing and plotting functions belong in `src`.

| Path | Purpose |
| --- | --- |
| `Golf_Club_Measurements.m` | Select recordings, configure processing, run the pipeline and collect results. |
| `config_local_example.m` | Example local dataset configuration. |
| `config_local.m` | Machine-specific configuration defining `dataRoot`. |
| `.gitignore` | Git exclusions; check that local configuration and generated files are excluded as intended. |
| `README.md` | Setup, processing, parameter and output documentation. |
| `src/compute_spectrogram.m` | Calculate spectrogram values and frequency/time axes. |
| `src/CA_CFAR.m` | Calculate CA-CFAR thresholds and detections. |
| `src/OS_CFAR.m` | Calculate OS-CFAR thresholds and detections. |
| `src/ClusterDetections.m` | Group candidate detections using DBSCAN. |
| `src/DetectSwingEvents.m` | Construct a speed envelope and estimate backswing start, top, peak speed and timing. |
| `src/PlotSwingEvents.m` | Plot swing-event results and diagnostic traces. |
| `src/PlotSpectrogram.m` | Spectrogram plotting helper; call is currently commented out in the supplied main script. |
| `src/PlotSpeedvsTime.m` | Speed–time plotting helper; call is currently commented out in the supplied main script. |
| `src/Test_CFAR.m` | Separate CFAR test script; not called by the main pipeline. |

The supplied folder listing also contains MATLAB `.asv` autosave files and `debug.log`. These are not required to run the pipeline.

## Requirements and setup

- MATLAB with Statistics and Machine Learning Toolbox for `dbscan`.
- The project helpers above, available on the MATLAB path.
- Radar WAV recordings stored beneath a local dataset folder. Additional toolbox requirements depend on the implementations of the project helpers.

1. Open the `Pipeline` folder in MATLAB.
2. If `config_local.m` does not already exist, copy `config_local_example.m` to `config_local.m`. Set the dataset root, for example:

   ```matlab
   dataRoot = 'C:\path\to\radar-recordings';
   ```

   The actual example filename is `config_local_example.m`. The supplied main script's missing-configuration error still refers to the older name `config_local.example.m`.

3. Edit `wavFile_CW_All` in `Golf_Club_Measurements.m`. Entries are relative to `dataRoot`, for example:

   ```matlab
   wavFile_CW_All = {
       fullfile('P001', 'session2', 'Driver_FullSwing1_3m_SoundBlaster.wav')
   };
   ```

4. Confirm that the selected WAV files exist. In the supplied current main script, **all recording entries are commented out**. Enable at least one entry; otherwise the processing loop runs zero times and no recording results are produced.

5. Run:

   ```matlab
   Golf_Club_Measurements
   ```

The main script derives `projectRoot` from its own location, adds `src` to the path and loads `config_local.m`. It clears the workspace and closes existing figures at startup. Every uncommented recording entry is processed.

## Processing stages

1. **Load audio:** read the WAV file and use its first channel. The supplied script processes the complete recording without a trimming step.
2. **Form the spectrogram:** round `CPI*fs` up to a power-of-two frame length and apply a Hamming window. Actual window duration is `framelen/fs`; time-hop spacing depends on the spectrogram helper and overlap.
3. **Convert Doppler frequency to radial speed:** use `speed = f*lambda/2`, where `lambda = c/fc`.
4. **Prepare power:** calculate `abs(S).^2`, normalise each frequency row by its median background power, and apply a three-frame temporal mean. Retain original power for display and the detection power gate.
5. **Apply CA-CFAR and OS-CFAR:** calculate local thresholds independently for each time column.
6. **Apply the original-power gate:** retain CFAR detections above the configured dB level relative to the largest original power in the displayed speed region.
7. **Cluster candidates:** use DBSCAN for the selected detector, then cluster CA and OS candidates independently in the comparison loop.
8. **Compare detector candidates:** display two spectrogram panels with power-gated CA/OS detections in magenta. These crosses show candidates before DBSCAN filtering, rather than only retained cluster cells.
9. **Detect swing events:** use the full OS-CFAR cluster map to construct an envelope and estimate peak, top and backswing start.
10. **Collect and display results:** retain swing metrics and diagnostic traces for each recording; display comparison and swing-event figures.

## CFAR behaviour


`PowerData` has speed bins in rows and time frames in columns. Both CFAR functions expect finite, nonnegative linear power, an ascending speed axis, and valid parameter values. `RefWindow` is the total reference-cell count; `GuardCells` is the guard count on each side. Use an even reference count when symmetric windows are required, `0 < PFA < 1`, and integer cell counts. For OS-CFAR, `1 <= Rank <= RefWindow`.

The cell under test (CUT) and its guard cells are excluded from the reference estimate. Asymmetric mode assigns `LowerRefCells` below the CUT and the remaining reference cells above it. Above `AsymmetricMaxSpeed`, the requested split is symmetric.

References stay inside the selected speed range. Near its limits, missing reference cells move to the opposite side. If the total reference count cannot fit, the CUT is skipped. Untested cells have `false` detections and `NaN` thresholds. There is no circular wrapping.

- **CA-CFAR:** multiply the sum of reference powers by `PFA^(-1/RefWindow)-1`.
- **OS-CFAR:** sort reference powers in each time column, select `Rank`, and multiply by a calibrated threshold factor. The factor is found with `fzero` using a log-form probability equation. The upper search bound doubles until the root is bracketed.

The threshold equations assume independent exponential noise powers. Whitening, temporal averaging, and overlapping frames mean the requested `PFA` should not be treated as a measured false-alarm rate for this complete pipeline.

## Processing settings

These values reflect the latest supplied main script. They are experimental settings, not validated optima; the executable script remains authoritative if settings are changed later.

| Parameter | Value | Meaning |
| --- | --- | --- |
| `fc` | 24 GHz | Radar centre frequency. |
| `CPI` / `overlapFrac` | 0.01 s / 0.95 | Requested window duration and overlap fraction. |
| `MinimumDetectionSpeed` / `maxSpeed` | 0 / 60 m/s | Selected CFAR/display speed range. |
| `PFA` | `1e-5` | Nominal CFAR false-alarm probability. |
| `RefWindowCA` / `GuardCellsCA` | 36 / 24 | Total references / guards per side. |
| `RefWindowOS` / `GuardCellsOS` | 42 / 20 | Total references / guards per side. |
| `UseAsymmetricCFAR` / `AsymmetricMaxSpeed` | `true` / 60 m/s | Asymmetric references enabled through this speed. |
| `LowerRefCellsCA` / `LowerRefCellsOS` | 4 / 5 | Separately calculated as `ceil(0.1*RefWindowCA)` and `ceil(0.1*RefWindowOS)`. |
| `Rank` | 13 | `ceil(0.3*RefWindowOS)`; kth smallest reference power. |
| `MinimumDetectionPowerDB` | -55 dB | Gate relative to the display region's maximum original power. |
| `TimeRadius` / `SpeedRadius` | 0.002 s / 2 m/s | DBSCAN neighbourhood scaling. |
| `MinPoints` | 5 | Minimum neighbourhood cell count for a core point. |
| `SpectrogramBounds` | `[-55 0]` dB | Plot colour limits. |
| `ShowPowerGatedCandidates` | `true` | Assigned but not checked in the current plotting loop; candidate crosses are always drawn. |

`UseOSCFAR` selects the initial detector output. Both detectors still run and are compared independently. Swing-event detection always uses the separately calculated OS-CFAR clusters, even if `UseOSCFAR` is `false`.

## DBSCAN clusters

DBSCAN scales time by `TimeRadius` and speed by `SpeedRadius`, then uses a Euclidean radius of 1. This defines an elliptical neighbourhood in physical coordinates. `MinPoints` counts detected cells, not distinct time frames. Cluster labels are `0` for no input detection, `-1` for noise, and positive integers for clusters. Border points assigned to clusters are retained.

`ClusterMaps{1}` contains the independently calculated CA map and `ClusterMaps{2}` the OS map for the current recording. Cluster IDs are local to each detector and recording, not matched CA/OS identities. Swing detection ignores zero/noise labels and uses positive OS labels. The current pipeline does not perform reduced-marker selection or call `SelectClusterMarkers`.

## Swing-event detection

```matlab
[metrics, trace] = DetectSwingEvents( ...
    osClusterMap, DisplaySpeed, t, SwingParameters);
```

The detector uses the full positive-labelled OS cluster map, rather than a reduced-marker table or power weights. It estimates one dominant swing from the recording:

1. **Raw envelope:** retain the highest clustered speed at each time frame. No retained detection gives `NaN`, not zero. Positive cluster identities are combined rather than tracked separately.
2. **Bounded interpolation:** fill internal raw gaps only if measured endpoints exist, missing-frame duration is within the time limit and endpoint speeds differ by no more than the speed limit. Immediate endpoints are used; the routine does not skip an outlier endpoint to find a later replacement.
3. **Main smoothing:** apply a median filter followed by a moving average to each finite section separately. Unfilled gaps remain missing.
4. **Peak selection:** locate the global smoothed peak at a measured frame. Measure raw peak amplitude within a local window around that timestamp.
5. **Low-speed region:** select the last sustained low-speed region within the pre-peak search window. Short unfilled gaps can connect its logical mask when both smoothed endpoints are low, without supplying estimated speeds.
6. **Top candidates:** calculate a simple smoothed minimum, a sustained-rise candidate, a robust measured valley and eligible raw-gap midpoints. The robust valley uses a separate raw-data median and measured-coverage checks; interpolation does not supply measured support.
7. **Hybrid selection:** retain the robust valley unless an eligible gap overrides it. With no robust valley, use the largest eligible gap midpoint if available.
8. **Backswing start:** search backwards from the start of the low-speed region, find sustained motion runs and select/link them according to the start mode.
9. **Timing:** calculate durations only when `backswing start < selected top < smoothed peak`. Otherwise retain `NaN` durations and an explanatory status.

### Top-selection rules

The supplied main script sets `TopMethod = 'hybrid'`. `'minimum'` is a compatibility alias for the same hybrid behaviour. The simple minimum is a diagnostic candidate, not the selected hybrid valley.

| Mode / condition | Selected top |
| --- | --- |
| Hybrid: robust valley exists; no eligible gap exceeds 35 ms | Robust measured valley. |
| Hybrid: largest eligible gap bracket exceeds 35 ms | Largest gap midpoint. |
| Hybrid: no robust valley; an eligible gap exists | Largest gap midpoint, even when shorter than 35 ms. |
| Hybrid: no robust valley or eligible gap | No top candidate (`NaN`). |
| `'rise'` | First qualifying sustained-rise candidate; no hybrid fallback. |

Eligible raw gaps must be internal, have at least the configured missing duration, lie wholly within the selected region and have raw endpoint speeds at or below the top threshold. Equal longest gaps favour the later gap.

The override uses the separation of the two bounding measured timestamps. On a uniform grid, this is `missingFrameCount*dt + dt`; the missing-frame duration alone is one hop shorter. The midpoint may fall between frames. It is an inferred timestamp, not a measured zero speed or proof of physical turnaround.

The robust valley is a continuous supported near-minimum interval. Valid intervals are ranked by lowest median robust speed, then longest duration. Its selected timestamp is a central measured frame; disconnected minima are not averaged together.

### Swing parameters

| Parameter | Value | Role |
| --- | --- | --- |
| `MotionThreshold_mps` | 0.1 | Minimum smoothed speed counted as backswing motion. |
| `MinimumMotionDuration_s` | 0.03 | Minimum continuous motion duration. |
| `BackswingSearchWindow_s` | 1 | Search duration before the low-region start. |
| `BackswingStartMode` | `'linked'` | Link qualifying motion runs backwards from the latest run. |
| `MaximumMotionGap_s` | 0.3 | Maximum run-end to run-start separation for linking. |
| `TopThreshold_mps` | 4 | Low-speed region and candidate threshold. |
| `MinimumTopDuration_s` | 0.1 | Minimum low-region duration, including accepted mask gaps. |
| `TopSearchWindow_s` | 1.5 | Low-region search before the smoothed peak. |
| `TopMethod` | `'hybrid'` | Effective top-selection mode. |
| `MaxInterpolationGap_s` | 0.5 | Maximum missing duration for interpolation: **500 ms**. |
| `MaxInterpolationSpeedGap_mps` | 4 | Maximum difference between immediate raw endpoint speeds. |
| `MaxTopGap_s` | 0.1 | Maximum unfilled gap for low-region mask connection. |
| `MedianFilterFrames` | 51 with the supplied script `dt` | Main median window derived from `medianWindow_s = 0.030`. |
| `MovingAverageFrames` | 10 | Main moving-average frame count. |
| `PeakSearchHalfWidth_s` | 0.04 | Raw peak-amplitude search within ±40 ms. |
| `TopMedianWindow_s` | 0.030 | Separate raw-data robust-median window. |
| `TopMinimumMeasuredFraction` | 0.10 | Minimum raw coverage within the robust window; centre must also be measured. |
| `TopSpeedTolerance_mps` | Half the median speed-bin spacing | Function default; not explicitly assigned by the main script. |
| `MinimumValleyDuration_s` | 0.05 | Minimum contiguous supported near-minimum interval. |
| `MinimumGapReport_s` | 0.001 | Minimum raw missing duration for eligible-gap reporting. |
| `GapOverrideDuration_s` | 0.035 | Strict bracket-separation override threshold. |
| `RiseWindow_s` | 0.06 | Forward interval for sustained-rise testing. |
| `MinimumRise_mps` | 1.2 | Minimum net smoothed-speed gain over that interval. |
| `MinimumRisingFraction` | 0.60 | Minimum fraction of positive checkpoint changes. |
| `RiseDropTolerance_mps` | 0.15 | Maximum permitted checkpoint speed decrease. |
| `MinimumMeasuredFraction` | 0.30 | Minimum raw-frame fraction for the rise candidate only. |

Most run durations are calculated as frame count times actual hop spacing. The main median frame count is calculated earlier from the manually assigned script `dt = 5.8957e-04` s. `DetectSwingEvents` derives actual hop spacing from `t`, but does not recalculate that supplied frame count. Its separate robust-median frame count does use actual spacing.

`MaxTopGap_s` applies to unfilled gaps only. Already interpolated gaps participate in low-region classification through their smoothed speeds. The interpolation and low-region limits therefore control different operations.

## Outputs and interpretation

For each enabled recording, the main script displays the CA/OS spectrogram comparison with magenta power-gated candidate detections and calls `PlotSwingEvents`. The standalone cluster display and `PlotSpectrogram`/`PlotSpeedvsTime` calls are commented out. `ShowPowerGatedCandidates` currently does not toggle the comparison overlays because there is no corresponding `if` condition.

| Workspace variable | Contents |
| --- | --- |
| `ClusterMaps` | Independently clustered CA/OS maps for the current or final recording. |
| `DetectionClustered` / `ClusterMap` | Selected detector's retained cells / labels for the current or final recording. |
| `CandidatesCA` / `CandidatesOS` | Power-gated detections before DBSCAN for the current or final recording. |
| `AllSwingMetrics` | One metrics row per selected recording, with its relative recording path. |
| `AllSwingTraces{i}` | Raw, filled, smoothed and robust envelopes, masks, candidate comparison and effective parameters. |
| `metrics` / `trace` | Swing outputs for the current or final recording. |

| Swing metric | Interpretation |
| --- | --- |
| `PeakSpeedTime_s` | Smoothed-peak timestamp at a measured frame; timing endpoint used below. |
| `PeakRadialSpeed_mps` / `RawPeakTime_s` | Highest raw speed and its timestamp within the local peak window. |
| `BackswingStartTime_s` | Start of the selected/linked sustained motion run. |
| `TopOfBackswingTime_s` | Selected robust-valley, gap-midpoint or rise timestamp. |
| `BackswingDuration_s` | Selected top minus backswing start. |
| `DownswingDuration_s` | Smoothed peak minus selected top: a **top-to-peak proxy**, not independently measured impact timing. |
| `TempoRatio` | Backswing duration divided by top-to-peak duration. |
| `TopSource` / `TopSelectionReason` | Selected candidate type and selection explanation. |
| `TopIsGapEstimate` | Whether the selected top is an inferred gap midpoint. |
| `TopUsesMissingData` | Whether the selected low-speed region contains raw missing data; can be true for a measured top. |
| `BackswingTouchesSearchStart` | Whether the selected run starts at the first frame of the backswing search; inspect for possible truncation. |
| `Status` | Outcome or reason events/durations could not be completed. |

Additional candidate timestamps and gap diagnostics remain in `AllSwingMetrics` and `trace.TopComparison`. Missing events/durations remain `NaN`; inspect `Status` rather than treating every row as a complete detection.

The global envelope peak can be affected by another movement or a retained high-speed artefact. Missing returns near low speed can have causes other than turnaround. Validate event timestamps against video or another reference before interpreting physical swing phases.

### Optional export

The script retains results in the workspace; export lines are commented out by default. After processing, for example:

```matlab
writetable(AllSwingMetrics, fullfile(projectRoot, 'SwingMetrics.csv'));
save(fullfile(projectRoot, 'SwingDetectionResults.mat'), ...
    'AllSwingMetrics', 'AllSwingTraces', 'SwingParameters');
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Missing configuration error | Create `config_local.m` from `config_local_example.m` and define `dataRoot`. |
| Empty results and no processing figures | Uncomment at least one entry in `wavFile_CW_All`. |
| Dataset/recording not found | Check `dataRoot` and each relative entry in `wavFile_CW_All`. |
| `dbscan` unavailable | Check Statistics and Machine Learning Toolbox availability. |
| No envelope or low-speed region | Inspect retained clusters and the raw/smoothed traces; check speed/power gates and region thresholds. |
| Top repeatedly inferred from a gap | Inspect raw dropouts, endpoint speeds and bracket durations in `trace.TopComparison`. |
| Incomplete durations | Inspect `Status`, candidate timestamps, backswing support and event order. |



