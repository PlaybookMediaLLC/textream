# render — overlay frame pacing (PLAN #4)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T23:21:09-05:00.

| Words | Font | Mode | Hitch ms/s | Worst frame (ms) | CPU % | Refresh (Hz) |
|---|---|---|---|---|---|---|
| 1000 | sans | pinned | 9.35 | 34.67 | 14.71 | 74.97 |
| 1000 | sans | floating | 11.96 | 33.46 | 13.43 | 74.97 |
| 1000 | sans | fullscreen | 7.85 | 26.68 | 12.14 | 74.97 |
| 1000 | dyslexia | pinned | 0 | 13.34 | 11.44 | 74.97 |
| 1000 | dyslexia | floating | 7.84 | 26.68 | 9.66 | 74.97 |
| 1000 | dyslexia | fullscreen | 7.22 | 29.32 | 10.29 | 74.97 |
| 10000 | sans | pinned | 4.01 | 28.62 | 13.49 | 74.97 |
| 10000 | sans | floating | 4.22 | 29.32 | 12.08 | 74.97 |
| 10000 | sans | fullscreen | 0 | 13.34 | 7.24 | 74.97 |
| 10000 | dyslexia | pinned | 0 | 13.34 | 11.02 | 74.97 |
| 10000 | dyslexia | floating | 6.26 | 26.68 | 12.00 | 74.97 |
| 10000 | dyslexia | fullscreen | 0 | 13.34 | 7.23 | 74.97 |
| 50000 | sans | pinned | 32.84 | 503 | 13.89 | 74.97 |
| 50000 | sans | floating | 44.39 | 698 | 13.28 | 74.97 |
| 50000 | sans | fullscreen | 45.87 | 706 | 14.89 | 74.97 |
| 50000 | dyslexia | pinned | 25.84 | 381 | 11.13 | 74.97 |
| 50000 | dyslexia | floating | 40.25 | 705 | 8.07 | 74.97 |
| 50000 | dyslexia | fullscreen | 0 | 13.34 | 6.82 | 74.97 |

The highlight advances one word at a time at 150 wpm with no recognizer (`-bench-autoplay`), so only rendering is measured. A hitch is a display-refresh callback that arrived more than 1.5 frames after the previous one: the main thread was busy. CPU % is the whole app process. PLAN bars: hitches < 5 ms/s, CPU < 15% at 50k words. Sidecar is a manual check each release.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| render.10k.dyslexia.floating.cpuPercent | 12.00 | 0 | % | 1 |
| render.10k.dyslexia.floating.hitchMsPerS | 6.26 | 0 | ms/s | 1 |
| render.10k.dyslexia.floating.maxFrameMs | 26.68 | 0 | ms | 1 |
| render.10k.dyslexia.fullscreen.cpuPercent | 7.23 | 0 | % | 1 |
| render.10k.dyslexia.fullscreen.hitchMsPerS | 0 | 0 | ms/s | 1 |
| render.10k.dyslexia.fullscreen.maxFrameMs | 13.34 | 0 | ms | 1 |
| render.10k.dyslexia.pinned.cpuPercent | 11.02 | 0 | % | 1 |
| render.10k.dyslexia.pinned.hitchMsPerS | 0 | 0 | ms/s | 1 |
| render.10k.dyslexia.pinned.maxFrameMs | 13.34 | 0 | ms | 1 |
| render.10k.sans.floating.cpuPercent | 12.08 | 0 | % | 1 |
| render.10k.sans.floating.hitchMsPerS | 4.22 | 0 | ms/s | 1 |
| render.10k.sans.floating.maxFrameMs | 29.32 | 0 | ms | 1 |
| render.10k.sans.fullscreen.cpuPercent | 7.24 | 0 | % | 1 |
| render.10k.sans.fullscreen.hitchMsPerS | 0 | 0 | ms/s | 1 |
| render.10k.sans.fullscreen.maxFrameMs | 13.34 | 0 | ms | 1 |
| render.10k.sans.pinned.cpuPercent | 13.49 | 0 | % | 1 |
| render.10k.sans.pinned.hitchMsPerS | 4.01 | 0 | ms/s | 1 |
| render.10k.sans.pinned.maxFrameMs | 28.62 | 0 | ms | 1 |
| render.1k.dyslexia.floating.cpuPercent | 9.66 | 0 | % | 1 |
| render.1k.dyslexia.floating.hitchMsPerS | 7.84 | 0 | ms/s | 1 |
| render.1k.dyslexia.floating.maxFrameMs | 26.68 | 0 | ms | 1 |
| render.1k.dyslexia.fullscreen.cpuPercent | 10.29 | 0 | % | 1 |
| render.1k.dyslexia.fullscreen.hitchMsPerS | 7.22 | 0 | ms/s | 1 |
| render.1k.dyslexia.fullscreen.maxFrameMs | 29.32 | 0 | ms | 1 |
| render.1k.dyslexia.pinned.cpuPercent | 11.44 | 0 | % | 1 |
| render.1k.dyslexia.pinned.hitchMsPerS | 0 | 0 | ms/s | 1 |
| render.1k.dyslexia.pinned.maxFrameMs | 13.34 | 0 | ms | 1 |
| render.1k.sans.floating.cpuPercent | 13.43 | 0 | % | 1 |
| render.1k.sans.floating.hitchMsPerS | 11.96 | 0 | ms/s | 1 |
| render.1k.sans.floating.maxFrameMs | 33.46 | 0 | ms | 1 |
| render.1k.sans.fullscreen.cpuPercent | 12.14 | 0 | % | 1 |
| render.1k.sans.fullscreen.hitchMsPerS | 7.85 | 0 | ms/s | 1 |
| render.1k.sans.fullscreen.maxFrameMs | 26.68 | 0 | ms | 1 |
| render.1k.sans.pinned.cpuPercent | 14.71 | 0 | % | 1 |
| render.1k.sans.pinned.hitchMsPerS | 9.35 | 0 | ms/s | 1 |
| render.1k.sans.pinned.maxFrameMs | 34.67 | 0 | ms | 1 |
| render.50k.dyslexia.floating.cpuPercent | 8.07 | 0 | % | 1 |
| render.50k.dyslexia.floating.hitchMsPerS | 40.25 | 0 | ms/s | 1 |
| render.50k.dyslexia.floating.maxFrameMs | 705 | 0 | ms | 1 |
| render.50k.dyslexia.fullscreen.cpuPercent | 6.82 | 0 | % | 1 |
| render.50k.dyslexia.fullscreen.hitchMsPerS | 0 | 0 | ms/s | 1 |
| render.50k.dyslexia.fullscreen.maxFrameMs | 13.34 | 0 | ms | 1 |
| render.50k.dyslexia.pinned.cpuPercent | 11.13 | 0 | % | 1 |
| render.50k.dyslexia.pinned.hitchMsPerS | 25.84 | 0 | ms/s | 1 |
| render.50k.dyslexia.pinned.maxFrameMs | 381 | 0 | ms | 1 |
| render.50k.sans.floating.cpuPercent | 13.28 | 0 | % | 1 |
| render.50k.sans.floating.hitchMsPerS | 44.39 | 0 | ms/s | 1 |
| render.50k.sans.floating.maxFrameMs | 698 | 0 | ms | 1 |
| render.50k.sans.fullscreen.cpuPercent | 14.89 | 0 | % | 1 |
| render.50k.sans.fullscreen.hitchMsPerS | 45.87 | 0 | ms/s | 1 |
| render.50k.sans.fullscreen.maxFrameMs | 706 | 0 | ms | 1 |
| render.50k.sans.pinned.cpuPercent | 13.89 | 0 | % | 1 |
| render.50k.sans.pinned.hitchMsPerS | 32.84 | 0 | ms/s | 1 |
| render.50k.sans.pinned.maxFrameMs | 503 | 0 | ms | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
