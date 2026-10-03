# Golf Swing Radar Processing

MATLAB processing pipeline for the EEE4022S golf swing project by Ebrahiem Slamang. The pipeline processes 24 GHz CW radar WAV recordings to compare CA-CFAR and OS-CFAR detections, group returns using DBSCAN, and produce reduced speed-time markers for further analysis.

The plotted speed is the radial component along the radar beam. The current pipeline produces detection markers; it does not fit curves or automatically identify the club head or swing phases.

## Files

| File | Purpose |
| --- | --- |
| `Golf_Club_Measurements.m` | Select recordings, set parameters, run processing, and display results. |
| `src/CA_CFAR.m` | Form thresholds from summed reference-cell powers. |
| `src/OS_CFAR.m` | Form thresholds from the kth smallest reference-cell power. |
| `src/ClusterDetections.m` | Group detections in speed-time space using DBSCAN. |
| `src/SelectClusterMarkers.m` | Reduce clustered detections to representative markers. |
| `config_local.m` | Local dataset configuration defining `dataRoot`. |
| `src/compute_spectrogram.m` | Existing helper called to calculate the spectrogram. |
| `src/PlotSpeedvsTime.m` | Existing helper called to plot the original radar return. |

The five documented MATLAB files and this README are an update to the existing repository, not a standalone replacement. Keep the existing spectrogram and plotting helpers. 

## Requirements and setup

- MATLAB with Statistics and Machine Learning Toolbox for `dbscan`.
- Existing project helpers on the MATLAB path. Any additional toolbox requirements depend on those helpers.
- Radar recordings in WAV format, arranged under a local dataset folder.

1. Place `Golf_Club_Measurements.m` and this README in the repository root. Place the four processing functions in `src`, using the filenames listed above without upload suffixes such as `(2)`.
2. Copy the repository's `config_local.example.m` to `config_local.m`, or create `config_local.m` containing:

   ```matlab
   dataRoot = 'C:\path\to\radar-recordings';
   ```

3. Check that your selected recording exists, for example `P002/session1/Driver_FullSwing1.wav` beneath `dataRoot`.
4. Edit `wavFile_CW_All` to select recordings. Uncomment additional entries to process several files.
5. Run `Golf_Club_Measurements` from MATLAB.


## Processing stages

1. **Load the recording:** use the first audio channel. This version processes the full recording; it contains no start/end trimming step.
2. **Calculate the spectrogram:** round `CPI*fs` up to a power-of-two frame length and construct a Hamming window. The actual frame duration is `framelen/fs` and can exceed the requested CPI. Overlap is passed to `compute_spectrogram`.
3. **Convert frequency to radial speed:** use `speed = f*lambda/2`, with `lambda = c/fc`.
4. **Prepare linear power:** calculate `abs(S).^2`, divide each frequency row by its median background power, then average over three time frames. Original power is retained for plotting and marker weighting.
5. **Apply both CFAR detectors:** compare each eligible speed bin with a local threshold calculated independently for each time column.
6. **Apply a power gate:** retain CFAR detections above the chosen dB level relative to the largest original power within the displayed speed region of that recording.
7. **Cluster detections:** run DBSCAN independently for CA-CFAR and OS-CFAR candidates.
8. **Reduce clusters:** sample occupied time columns, split detections into speed bands and smaller speed intervals, then calculate representative markers.

## CFAR behaviour

`PowerData` has speed bins in rows and time frames in columns. Both CFAR functions expect finite, nonnegative linear power, an ascending speed axis, and valid parameter values. `RefWindow` is the total reference-cell count; `GuardCells` is the guard count on each side. Use an even reference count when symmetric windows are required, `0 < PFA < 1`, and integer cell counts. For OS-CFAR, `1 <= Rank <= RefWindow`.

The cell under test (CUT) and its guard cells are excluded from the reference estimate. Asymmetric mode assigns `LowerRefCells` below the CUT and the remaining reference cells above it. Above `AsymmetricMaxSpeed`, the requested split is symmetric.

References stay inside the selected speed range. Near its limits, missing reference cells move to the opposite side. If the total reference count cannot fit, the CUT is skipped. Untested cells have `false` detections and `NaN` thresholds. There is no circular wrapping.

- **CA-CFAR:** multiply the sum of reference powers by `PFA^(-1/RefWindow)-1`.
- **OS-CFAR:** sort reference powers in each time column, select `Rank`, and multiply by a calibrated threshold factor. The factor is found with `fzero` using a log-form probability equation. The upper search bound doubles until the root is bracketed.

The threshold equations assume independent exponential noise powers. Whitening, temporal averaging, and overlapping frames mean the requested `PFA` should not be treated as a measured false-alarm rate for this complete pipeline.

## Current settings

These are the values in the supplied main script, not validated optimum settings.

| Parameter | Current value | Meaning |
| --- | --- | --- |
| `fc` | 24 GHz | Radar centre frequency. |
| `CPI` / `overlapFrac` | 0.01 s / 0.95 | Requested frame duration and overlap fraction. |
| `MinimumDetectionSpeed` / `maxSpeed` | 1.5 / 60 m/s | CFAR speed range. |
| `PFA` | `1e-4` | Nominal CFAR false-alarm probability. |
| `RefWindowCA` / `GuardCellsCA` | 36 / 24 | Total references / guards per side. |
| `RefWindowOS` / `GuardCellsOS` | 60 / 20 | Total references / guards per side. |
| `UseAsymmetricCFAR` / `AsymmetricMaxSpeed` | `true` / 60 m/s | Enable asymmetric references through this speed. |
| `LowerRefCells` | 6 | Computed as `ceil(0.1*RefWindowOS)` and passed to both detectors. |
| `Rank` | 18 | Computed as `ceil(0.3*RefWindowOS)`; kth smallest reference power. |
| `MinimumDetectionPowerDB` | -35 dB | Gate relative to the displayed region's peak original power. |
| `TimeRadius` / `SpeedRadius` | 0.002 s / 2 m/s | DBSCAN neighbourhood scaling. |
| `MinPoints` | 4 | Neighbourhood detections needed for a core point, including itself. |
| `ClusterGapBins` | 2 | Maximum missing speed bins allowed within one band. |
| `FrameStep` | 6 | Select every sixth occupied column per cluster, plus its last column. |
| `WithinClusterMode` | `'upper_band'` | Retain the highest band per cluster and selected column. |
| `MarkerSpeedWidth` | 4 m/s | Subdivide each retained band into intervals of this width. |
| `PowerWeightExponent` | 10 | Emphasise stronger cells when calculating the group centre. |
| `UpperEdgeWeight` | 0.3 | Blend the weighted centre towards the group's highest speed. |

`UseOSCFAR` selects the detector for the initial cluster view. Both detectors still run and are compared independently. The later OS overlay and marker-only figure always show OS results.

## Clusters and reduced markers

DBSCAN scales time by `TimeRadius` and speed by `SpeedRadius`, then uses a Euclidean radius of 1. This defines an elliptical neighbourhood in physical coordinates. `MinPoints` counts detected cells, not distinct time frames. Cluster labels are `0` for no input detection, `-1` for noise, and positive integers for clusters. Border points assigned to clusters are retained.

Marker reduction operates separately on each cluster:

- Sample its occupied columns and keep its last column.
- Split rows where the number of missing speed bins exceeds `ClusterGapBins`.
- Keep the highest band for `'upper_band'`, or every band for `'all_bands'`.
- Divide each retained band into `MarkerSpeedWidth` intervals starting at that band's lowest detected speed.
- Calculate a power-weighted centre within each interval and blend it with the interval's highest detected speed.

Weights are `(groupPower/max(groupPower)).^PowerWeightExponent`. All-zero groups use equal weights. A weight of 0 for `UpperEdgeWeight` gives the weighted centre; 1 gives the upper edge. Use positive radii and marker width, a positive integer `FrameStep`, and `UpperEdgeWeight` between 0 and 1.

Even `'upper_band'` can produce several markers per time column because the retained band is subdivided. Markers are accumulated by cluster, so the complete output is not necessarily time-sorted. Cluster IDs are local to each detector and recording, not matched identities between CA and OS results.

## Outputs

The script displays the selected detector's clusters, a CA/OS spectrogram comparison with reduced markers, an OS cluster overlay, an OS marker-only figure, and the original speed-time plot. Magenta candidate crosses can be toggled with `ShowPowerGatedCandidates`.

Marker tables remain in the MATLAB workspace:

| Variable | Contents |
| --- | --- |
| `AllMarkerResults{i,1}` | CA-CFAR marker table for recording `i`. |
| `AllMarkerResults{i,2}` | OS-CFAR marker table for recording `i`. |
| `MarkerResults` | Both marker tables for the current/final recording. |
| `ClusterMaps` | Both cluster maps for the current/final recording. |

Each marker table contains `Time_s`, `Speed_mps`, `ClusterID`, and `TimeColumn`. Times come from the spectrogram helper; `TimeColumn` indexes its time axis. The script does not automatically export tables or figures. For example, after processing:

```matlab
osMarkers = AllMarkerResults{1,2};
writetable(osMarkers, 'OS_markers_recording1.csv');
```

## Documentation update

This update adds short comments and corrects outdated descriptions of reference-window edges, the Hamming window, and the 2 ms DBSCAN radius. Executable lines and parameter values are unchanged. The files were checked for comment-only differences; MATLAB execution was not performed as part of this update.
