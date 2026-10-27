# Golf Swing Radar — self-contained MATLAB pipeline

This project processes recorded IPM-365 continuous-wave radar signals offline.
It generates spectrograms, detects and groups returns, extracts an upper
radial-speed envelope, and estimates a supported peak, backswing onset and top.
The bundled WAV recordings are inside `Datasets`, so no machine-specific
configuration file or external dataset path is needed.

## 1. Quick start

1. Download and **extract** the complete project. Do not run it inside a ZIP.
2. Keep `Golf_Club_Measurements.m`, `RecordingSelection.m`, `src` and `Datasets`
   together inside the `Pipeline` folder.
3. Open `Golf_Club_Measurements.m` in MATLAB and press **Run**. If MATLAB asks
   whether to change folder or add the folder to the path, choose **Change Folder**.
4. The supplied selection runs `P002/session1/Driver_FullSwing1.wav`. That WAV
   is included. It is an example recording, not a batch reproduction of the
   complete 127-recording evaluation.
5. Inspect the figures and the workspace tables `AllSwingMetrics` and `Comparison`.

You can move the whole `Pipeline` folder to another computer. The main script uses
its own location to construct `Pipeline/Datasets/<selected relative path>` and to
add `src` to MATLAB's function path. It does not depend on your current username.
The script starts with `clear` and `close all`, so save other workspace work first.

## 2. Requirements

- MATLAB with support for the functions used here, including `table`, `string`,
  `movmedian`, `movmean`, `xline` and `exportgraphics`. Use the project's recent
  MATLAB environment for the closest reproduction; older releases may differ.
- **Statistics and Machine Learning Toolbox** for `dbscan` in `ClusterDetections`.
- No additional toolbox is introduced by the comments or portable folder setup.
  The STFT, Hamming window, CFAR formulas and robust onset fit are implemented
  directly; the code does not call the toolbox `spectrogram` or `robustfit` functions.
- Disk space for the extracted recordings and any newly saved figures/results.

The synthetic CFAR test does not use DBSCAN and does not need the recorded dataset.
MATLAB was unavailable in the editing environment: syntax and package checks were
performed, but this documented release has not been executed there.

## 3. Folder layout

| File/folder | Purpose |
| --- | --- |
| `Golf_Club_Measurements.m` | Main script and final analysis settings |
| `RecordingSelection.m` | Relative paths of the WAV files to process |
| `Datasets/P001` … `Datasets/P004` | 233 bundled radar WAV recordings, including exploratory tests |
| `AvailableRecordings.csv` | Complete file index, with sample format and recording duration |
| `src/` | Processing, table and plotting functions |
| `Results/` | Four supplied pipeline/video comparison CSVs, retained unchanged |
| `Test_CFAR.m` | Canonical standalone synthetic/noise verification script |
| `Tests/Test_CFAR.m` | Compatibility launcher for the root verification script |
| `DOCUMENTATION_CHANGES.md` | Changes, checks and limits of this update |

All 233 bundled WAVs have 44.1 kHz sample rate, one channel and 16-bit PCM.
They include exploratory recordings as well as the retained evaluation cases;
233 files does **not** mean 233 evaluated full swings. The earlier evaluation
contains 127 paired rows in the four supplied Results CSVs.

## 4. Choose recordings

Edit only the cell array in `RecordingSelection.m`. A `%` at the beginning of
a filename line comments it out. Keep at least one existing path active.

For example, to process the default recording:

```matlab
wavFile_CW_All = {
    fullfile('P002', 'session1', 'Driver_FullSwing1.wav')
};
```

To process a batch, place multiple `fullfile(...)` entries inside the same braces.
The paths begin at `Datasets`, so do **not** add `Pipeline` or `Datasets` to each
entry. Use `AvailableRecordings.csv` for the exact folder and filename spelling.
The commented examples were matched to the bundled filenames, including their
case, so they also work on case-sensitive systems when uncommented.

The current selected recording and selection order are unchanged from the upload.
The main script does not automatically process every WAV or silently skip failures.
A missing file causes a descriptive error.

**Batch plotting:** four figures are created per recording by the three plotting
calls at the end of the main loop. For a large batch, comment out those calls if
you want metrics without hundreds of open figures. This does not disable the
preceding signal processing or table construction.

## 5. What the processing does

1. **Read WAV:** `audioread` supplies samples and the stored sampling rate. The
   first audio channel is retained. Samples are not converted to calibrated volts.
2. **Compute complex STFT:** extract complete Hamming-weighted frames, subtract
   each windowed frame's mean, calculate its FFT and centre the frequency axis.
   The helper returns complex spectra, not power or detected speeds.
3. **Convert frequency to speed:** use the assumed 24 GHz carrier and the
   monostatic magnitude relation `speed = frequency * wavelength / 2`. Keep the
   selected nonnegative-speed interval for analysis. The single real channel does
   not independently distinguish approach from recession.
4. **Condition power:** square spectral magnitudes, divide each frequency row by
   its median across the recording, and average three frames along time. This
   linear-power array is the CFAR input. A persistent target can influence its
   own median, so normalisation is not guaranteed to preserve every return.
5. **Apply the selected CFAR:** `UseOSCFAR = true` selects OS; `false` selects CA.
   The switch controls the full detection → clustering → event path.
6. **Apply the original-power gate:** require candidates also to exceed -50 dB
   relative to the maximum original power within the retained band of that recording.
7. **Cluster:** DBSCAN groups time-speed detections using separately scaled axes.
   All positive cluster labels are retained; clusters are not assigned object IDs.
8. **Extract envelope:** take the highest retained speed per frame. `NaN` means
   no retained return. This “raw” envelope has already passed detection/clustering.
9. **Condition envelope:** linearly fill eligible internal gaps, flag interpolated
   samples, and smooth each finite section separately. Unfilled gaps stay missing.
10. **Choose peak:** examine raw candidates from highest to lowest. Require other
    raw observations nearby in both time and speed. Use the accepted raw amplitude
    and a nearby, raw-supported smoothed maximum for the phase endpoint.
11. **Choose top:** locate the last sustained slow region before the peak. Compare
    a supported raw-only valley with eligible raw missing intervals. A sufficiently
    long eligible gap overrides the valley and supplies its midpoint.
12. **Choose onset:** work backwards from the latest qualifying motion run, linking
    earlier runs within the allowed separation. Fit only the earliest selected
    run's initial motion; accepted zero-speed extrapolation can precede detection.
13. **Calculate metrics:** require `start < top < selected smoothed peak`. Invalid
    event ordering or missing events leaves duration/tempo values missing.

These are radial-speed and peak-based timing estimates. Dataset swings were
ball-free; no impact time is extracted. Dense competing returns, preliminary
motion and weak transition returns can still produce ambiguous events.

## 6. Current settings

The uploaded numerical settings are preserved. The following values belong to
this package, rather than older report drafts or earlier code versions.

| Setting | Value | Meaning |
| --- | --- | --- |
| `fc` | 24e9 Hz | Assumed carrier for frequency-to-speed conversion |
| `CPI` | 0.01 s requested | Rounded to a power-of-two measured frame |
| `overlapFrac` | 0.95 requested | Shared samples between successive frames |
| `maxSpeed` | **55 m/s** | Upper CFAR/display band limit |
| `PFA` | 1e-5 | Nominal false-alarm probability per tested cell |
| CA / OS references | 42 / 42 total | Background cells, both sides combined |
| CA / OS guards | 20 / 20 per side | Excluded neighbouring cells |
| Lower/upper allocation | 5 / 37 | Away from boundaries, below the asymmetry transition |
| `AsymmetricMaxSpeed` | 60 m/s | All of the current 0–55 m/s band uses asymmetric allocation |
| OS rank | 13th smallest | `ceil(0.3*42)` |
| Original-power gate | -50 dB | Relative to the recording maximum in the retained band |
| DBSCAN time / speed scale | 0.002 s / 2 m/s | Unit-radius ellipse in scaled coordinates |
| `MinPoints` | 5 | Nearby detected cells including the tested cell |
| Maximum interpolation gap | 0.4 s | Missing-frame count times actual hop |
| Interpolation endpoint difference | 4 m/s | Immediate measured endpoints must be close in speed |
| Main median / mean | 51 / 10 frames | Applied separately to finite envelope sections |
| Peak support neighbourhood | ±40 ms and ±4 m/s | Both conditions must hold for a supporting raw frame |
| Minimum other peak support | ceil(20 ms / hop) | 34 other frames at the current settings |
| Low-speed threshold / run duration | 5 m/s / 100 ms | Region searched before the selected peak |
| Top search look-back | 1.5 s | Before selected smoothed peak time |
| Top raw-only median | 30 ms, 10% minimum raw coverage | Centre must itself be measured |
| Required near-minimum valley duration | 50 ms | Sustained measured support |
| Gap override | >35 ms | Separation between immediate measured bounding observations |
| Onset search look-back / minimum run | 1 s / 30 ms | Before the selected low-region start |
| Maximum linked-run separation | 0.6 s | Link earlier qualifying runs backwards |
| Onset fitting window / bins | 100 ms / 5 ms | Initial raw/accepted-interpolated speeds |
| Maximum unsupported fit separation | 10 ms | Stops the fit interval at a larger unsupported gap |
| Minimum fit span / rise | 25 ms / 0.30 m/s | Applied with the positive-slope requirement |
| Minimum fit R² | 0.60 | Line agreement, not event-time accuracy |
| Maximum backward extrapolation | **200 ms** | Farther zero intercepts are rejected |

At 44.1 kHz, the selected frame has **512 measured samples**, an actual duration
of **11.610 ms**, a **26-sample hop** and **0.58957 ms updates**. Actual overlap is
94.922%; frequency-grid spacing is 86.133 Hz and speed-grid spacing is 0.53833 m/s.
There is no zero-padding because FFT length equals measured frame length.
The update interval is not independent time resolution.

The main 30 ms moving median uses the original fixed `dt = 5.8957e-4` conversion
to 51 frames. Other event-time rules use the returned time axis. This conversion
has not been changed during documentation. The raw-only top median uses actual hop.

Some event-helper defaults differ from main-script values: 5 ms minimum valley
and 300 ms maximum extrapolation are fallbacks only. The main script explicitly
supplies **50 ms** and **200 ms**, which take precedence. Change main settings
first when investigating the actual processing configuration.

## 7. Outputs and definitions

| Workspace output | Contents |
| --- | --- |
| `AllSwingMetrics` | One full metrics/diagnostics row per selected file, including status |
| `AllSwingTraces{k}` | Matching envelopes, interpolation and region masks, fit/candidate evidence, parameters |
| `Comparison` | Compact pipeline results plus new empty video-reference columns |

The comparison table keeps these existing column names:

| Column | Definition |
| --- | --- |
| `Recording` | Path relative to `Datasets` |
| `Pipeline_BackswingDuration_s` | Selected top minus final onset |
| `Pipeline_DownswingDuration_s` | Selected smoothed-peak time minus top; not impact-based |
| `Pipeline_RawPeakRadialSpeed_mps` | Selected supported raw-peak amplitude |
| `Pipeline_SmoothedPeakRadialSpeed_mps` | Smoothed value at the selected peak timestamp |
| `Pipeline_TempoRatio` | Backswing duration divided by top-to-peak duration |
| `Video_BackswingDuration_s` | Empty manual-reference placeholder, in seconds |
| `Video_DownswingDuration_s` | Empty manual-reference top-to-speed-peak duration |
| `Video_PeakRadialSpeed_mps` | Legacy name for a manually entered video speed; does not prove matching projection |
| `Video_TempoRatio` | Empty manual-reference ratio placeholder |
| `Reference_Notes` | Optional notes on reference quality or annotations |

Status is retained in `AllSwingMetrics`, **not** automatically in `Comparison`.
`NaN` means unavailable or not entered; it does not mean zero duration/speed/error.
Raw and smoothed peaks can occur at different times. Since raw selection is
support-based and smoothing uses neighbouring values, do not assume the selected
smoothed value must always be below the selected raw value.

The supplied `Results` CSVs already contain reference measurements. Running the
pipeline does not read or overwrite them. A new `Comparison` table starts with
missing video values, even if an old CSV has annotations.

## 8. Save results and figures

CSV writing remains commented out at the bottom of the main script. To save a
NEW timestamped comparison file, uncomment that block. It writes under `Results`.
Keep existing reference-filled CSVs unchanged when rerunning pipeline settings.

You can also save the diagnostic workspace outputs after a run:

```matlab
save(fullfile(projectRoot, 'Results', 'My_Analysis_Run.mat'), ...
    'AllSwingMetrics', 'AllSwingTraces', 'Comparison', 'SwingParameters', ...
    'fc', 'CPI', 'overlapFrac', 'PFA', 'UseOSCFAR', 'wavFile_CW_All');
```

This filename is an example and will overwrite an existing file with that name.
Use a distinct name per analysis, and retain the exact code version and file list.
Save `AllSwingTraces` if you need to inspect inferred gaps or onset fits later.

`PlotSwingEvents` optionally returns two figure handles:

```matlab
[figSpectrogram, figEnvelope] = PlotSwingEvents(t, DisplaySpeed, ...
    DisplayPowerDB, SpectrogramBounds, metrics, trace, wavFile_CW);
exportgraphics(figEnvelope, 'Swing_Envelope.pdf', 'ContentType', 'vector');
savefig(figEnvelope, 'Swing_Envelope.fig');
```

Use MATLAB's figure controls to zoom or save the figures manually if preferred.
The event figures annotate timestamps, raw/smoothed peaks, durations and tempo.
The envelope view distinguishes measured points, accepted interpolation, selected
gaps, raw-peak support and accepted onset extrapolation. It does not recalculate events.

`PlotSpectrogram` retains its original unnormalised `20*log10(abs(S))` display.
`PlotSpeedvsTime` and the event spectrogram use recording-relative displays.
Identical colour limits do not make these different display scales equivalent.

## 9. Run CFAR verification separately

Open the root `Test_CFAR.m` and press Run. The `Tests/Test_CFAR.m` entry is only a
launcher for that same root script. It avoids maintaining two copies of settings.
The test clears the workspace, uses fixed seed 4022 and can open 16 figures.

- **Test 1:** 100,000 columns of independent exponential power, in batches of
  1,000, check the nominal threshold formulas. Every detection is a false alarm.
- **Test 2:** ten 3 s real Gaussian-noise records pass through the actual Hamming
  STFT and conditioning. This checks empirical false alarms after processing.
- **Test 3:** a flat track and three downward-opening speed parabolas are converted
  to real Doppler cosines, combined with shared noise, and processed. Peak speed
  is 45 m/s; endpoint drops are 0, 5, 15 and 40 m/s, over 0.6, 0.6, 0.6 and 0.2 s.
  All speeds stay positive. Signal amplitude and noise standard deviation are one.

`PFA` is detections divided by eligible tested noise cells. Exact-bin `PD` is the
fraction of scored active frames detected at the strongest noise-free target bin.
Nearby-bin PD separately accepts ±1 bin. False alarms in signal records are counted
only in target-free frames, excluding boundary overlaps. Other crossings during
the arc may be target-associated and are not automatically false alarms.

These tests exclude the original-power gate, clustering and swing-event extraction.
Overlapping decisions are correlated, and all arcs share noise. A 100% observed
hit fraction at one amplitude is not a general guarantee of perfect detection.

`SaveResults = true` and `SavePlots = true` create a new timestamped `CFAR_Check_*`
folder beside the root script. It contains PFA/PD CSV tables, settings/results in
`CFAR_Verification.mat`, detection overlays and threshold-diagnostic PNGs.
Set either flag to false before running if you do not want those saved outputs.

## 10. Function guide

| Function | Responsibility |
| --- | --- |
| `compute_spectrogram` | Complex, centred STFT and frequency/time axes |
| `CA_CFAR` | Mean-equivalent reference-sum threshold, edge allocation and crossings |
| `OS_CFAR` | Ascending-rank threshold with numerically solved PFA scale |
| `ClusterDetections` | DBSCAN grouping in scaled time-speed space |
| `DetectSwingEvents` | Envelope conditioning and supported peak/hybrid top/linked onset |
| `CreateComparisonTable` | Compact table construction; no file I/O |
| `PlotSwingEvents` | Two separate annotated figures from stored decisions |
| `PlotSpectrogram` | Signed-frequency display |
| `PlotSpeedvsTime` | Nonnegative radial-speed display |

Each function now has expanded help comments describing inputs, outputs, units
and important assumptions. Inspect the code or enter, for example:

```matlab
help DetectSwingEvents
help compute_spectrogram
```

Local helper comments in `DetectSwingEvents` explain run finding, candidate
support, gap duration conventions, robust fitting, R² and rejected-fit fallbacks.

## 11. Troubleshooting

| Message or symptom | What to check |
| --- | --- |
| Bundled Datasets folder missing | Extract the whole archive and keep its folder layout |
| Recording not found | Use the exact relative path/case from `AvailableRecordings.csv` |
| No selected recordings | Uncomment at least one existing `fullfile` entry |
| `dbscan` unavailable | Install/enable Statistics and Machine Learning Toolbox |
| Missing top/onset/durations | Inspect `Status`, gaps and event evidence; a numerical peak alone does not establish valid timing |
| New CSV has empty video values | Expected: `CreateComparisonTable` does not merge old references |
| Too many figures | Comment out plotting calls for batch-only metric extraction |
| Test seems slow | It intentionally processes many noise cells and saves high-resolution plots |
| Different outcome on an old or modified recording | Confirm exact settings, input file, first-channel selection and analysis version |

Keep the whole project together; no `config_local.m`, external `dataRoot` setting
or hard-coded user directory is required. The `.gitignore` intentionally allows
the bundled `Datasets` and reference Results CSVs to be included, while ignoring
new verification runs and common temporary outputs.
