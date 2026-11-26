# launch — launch and time-to-first-prompt (PLAN #8)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T23:03:28-05:00.

Launch is measured from process start (kernel start time) to the first display refresh of the main window. The app is exec'd directly, so LaunchServices time (Dock click, `open`) is not included.

- `ttfp.notRunning`: launched with a 2,000-word script → first overlay frame.
- `ttfp.running`: script read 2 s after launch → first overlay frame.
- `ttfp.firstHighlight.<engine>`: read → first frame with a highlighted word (file-fed audio; local includes model load).

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| launch.didFinishLaunching.ms | 288 | 11.19 | ms | 3 |
| launch.mainWindowFirstFrame.ms | 575 | 120 | ms | 3 |
| launch.step.browserServer.ms | 0.0169 | 0.000238 | ms | 3 |
| launch.step.directorServer.ms | 0.046 | 0.0031 | ms | 3 |
| launch.step.services.ms | 0.862 | 0.026 | ms | 3 |
| launch.step.updateCheck.ms | 1.55 | 0.111 | ms | 3 |
| ttfp.firstHighlight.local-whisper-tiny-Q8_0.ms | 1773 | 4.85 | ms | 3 |
| ttfp.notRunning.overlayFirstFrame.ms | 454 | 0.782 | ms | 3 |
| ttfp.running.overlayFirstFrame.ms | 112 | 1.13 | ms | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
