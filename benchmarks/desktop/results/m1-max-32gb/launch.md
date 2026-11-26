# launch — launch and time-to-first-prompt (PLAN #8)

Host `m1-max-32gb`, commit `b60167a`, 2026-11-26T02:32:38-05:00.

Launch is measured from process start (kernel start time) to the first display refresh of the main window. The app is exec'd directly, so LaunchServices time (Dock click, `open`) is not included.

- `ttfp.notRunning`: launched with a 2,000-word script → first overlay frame.
- `ttfp.running`: script read 2 s after launch → first overlay frame.
- `ttfp.firstHighlight.<engine>`: read → first frame with a highlighted word (file-fed audio; local includes model load).

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| launch.didFinishLaunching.ms | 281 | 6.91 | ms | 5 |
| launch.mainWindowFirstFrame.ms | 363 | 3.89 | ms | 5 |
| launch.step.browserServer.ms | 0.0191 | 0.00596 | ms | 5 |
| launch.step.directorServer.ms | 0.0441 | 0.00167 | ms | 5 |
| launch.step.services.ms | 0.857 | 0.0269 | ms | 5 |
| launch.step.updateCheck.ms | 1.47 | 0.0916 | ms | 5 |
| ttfp.firstHighlight.local-whisper-tiny-Q8_0.ms | 1811 | 16.40 | ms | 5 |
| ttfp.notRunning.overlayFirstFrame.ms | 481 | 8.01 | ms | 5 |
| ttfp.running.overlayFirstFrame.ms | 139 | 0.196 | ms | 5 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
