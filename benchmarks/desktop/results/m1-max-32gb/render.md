# render — overlay frame pacing (PLAN #4)

Host `m1-max-32gb`, commit `8cee918`, 2026-11-26T03:47:42-05:00.

| Words | Font | Mode | Hitch ms/s | Worst frame (ms) | CPU % | Refresh (Hz) |
|---|---|---|---|---|---|---|
| 1000 | sans | pinned | 44.70 | 131 | 16.57 | 74.97 |
| 1000 | sans | floating | 47.97 | 197 | 15.56 | 74.97 |
| 1000 | sans | fullscreen | 31.57 | 79.96 | 16.42 | 74.97 |
| 1000 | dyslexia | pinned | 37.80 | 107 | 18.56 | 74.97 |
| 1000 | dyslexia | floating | 39.42 | 193 | 16.56 | 74.97 |
| 1000 | dyslexia | fullscreen | 28.07 | 139 | 16.63 | 74.97 |
| 10000 | sans | pinned | 42.69 | 157 | 16.89 | 74.97 |
| 10000 | sans | floating | 46.40 | 186 | 16.54 | 74.97 |
| 10000 | sans | fullscreen | 49.32 | 337 | 17.41 | 74.97 |
| 10000 | dyslexia | pinned | 43.71 | 183 | 17.96 | 74.97 |
| 10000 | dyslexia | floating | 37.70 | 158 | 15.86 | 74.97 |
| 10000 | dyslexia | fullscreen | 32.33 | 105 | 17.36 | 74.97 |
| 50000 | sans | pinned | 91.34 | 505 | 15.30 | 74.97 |
| 50000 | sans | floating | 61.08 | 792 | 17.56 | 74.97 |
| 50000 | sans | fullscreen | 70.04 | 678 | 17.26 | 74.97 |
| 50000 | dyslexia | pinned | 81.83 | 787 | 18.74 | 74.97 |
| 50000 | dyslexia | floating | 83.08 | 686 | 17.36 | 74.97 |
| 50000 | dyslexia | fullscreen | 73.00 | 782 | 18.42 | 74.97 |

The highlight advances one word at a time at 150 wpm with no recognizer (`-bench-autoplay`), so only rendering is measured. A hitch is a display-refresh callback that arrived more than 1.5 frames after the previous one: the main thread was busy. CPU % is the whole app process. PLAN bars: hitches < 5 ms/s, CPU < 15% at 50k words. Sidecar is a manual check each release.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| render.10k.dyslexia.floating.cpuPercent | 15.86 | 0.174 | % | 3 |
| render.10k.dyslexia.floating.hitchMsPerS | 37.70 | 12.58 | ms/s | 3 |
| render.10k.dyslexia.floating.maxFrameMs | 158 | 83.77 | ms | 3 |
| render.10k.dyslexia.fullscreen.cpuPercent | 17.36 | 0.452 | % | 3 |
| render.10k.dyslexia.fullscreen.hitchMsPerS | 32.33 | 5.92 | ms/s | 3 |
| render.10k.dyslexia.fullscreen.maxFrameMs | 105 | 27.74 | ms | 3 |
| render.10k.dyslexia.pinned.cpuPercent | 17.96 | 0.49 | % | 3 |
| render.10k.dyslexia.pinned.hitchMsPerS | 43.71 | 0.146 | ms/s | 3 |
| render.10k.dyslexia.pinned.maxFrameMs | 183 | 1.96 | ms | 3 |
| render.10k.sans.floating.cpuPercent | 16.54 | 0.032 | % | 3 |
| render.10k.sans.floating.hitchMsPerS | 46.40 | 5.27 | ms/s | 3 |
| render.10k.sans.floating.maxFrameMs | 186 | 55.43 | ms | 3 |
| render.10k.sans.fullscreen.cpuPercent | 17.41 | 0.0437 | % | 3 |
| render.10k.sans.fullscreen.hitchMsPerS | 49.32 | 18.81 | ms/s | 3 |
| render.10k.sans.fullscreen.maxFrameMs | 337 | 267 | ms | 3 |
| render.10k.sans.pinned.cpuPercent | 16.89 | 0.626 | % | 3 |
| render.10k.sans.pinned.hitchMsPerS | 42.69 | 10.33 | ms/s | 3 |
| render.10k.sans.pinned.maxFrameMs | 157 | 102 | ms | 3 |
| render.1k.dyslexia.floating.cpuPercent | 16.56 | 0.0536 | % | 3 |
| render.1k.dyslexia.floating.hitchMsPerS | 39.42 | 4.90 | ms/s | 3 |
| render.1k.dyslexia.floating.maxFrameMs | 193 | 69.97 | ms | 3 |
| render.1k.dyslexia.fullscreen.cpuPercent | 16.63 | 0.476 | % | 3 |
| render.1k.dyslexia.fullscreen.hitchMsPerS | 28.07 | 6.47 | ms/s | 3 |
| render.1k.dyslexia.fullscreen.maxFrameMs | 139 | 74.82 | ms | 3 |
| render.1k.dyslexia.pinned.cpuPercent | 18.56 | 0.0174 | % | 3 |
| render.1k.dyslexia.pinned.hitchMsPerS | 37.80 | 3.33 | ms/s | 3 |
| render.1k.dyslexia.pinned.maxFrameMs | 107 | 9.88 | ms | 3 |
| render.1k.sans.floating.cpuPercent | 15.56 | 0.142 | % | 3 |
| render.1k.sans.floating.hitchMsPerS | 47.97 | 4.12 | ms/s | 3 |
| render.1k.sans.floating.maxFrameMs | 197 | 50.74 | ms | 3 |
| render.1k.sans.fullscreen.cpuPercent | 16.42 | 1.05 | % | 3 |
| render.1k.sans.fullscreen.hitchMsPerS | 31.57 | 5.15 | ms/s | 3 |
| render.1k.sans.fullscreen.maxFrameMs | 79.96 | 4.88 | ms | 3 |
| render.1k.sans.pinned.cpuPercent | 16.57 | 0.0264 | % | 3 |
| render.1k.sans.pinned.hitchMsPerS | 44.70 | 1.21 | ms/s | 3 |
| render.1k.sans.pinned.maxFrameMs | 131 | 11.93 | ms | 3 |
| render.50k.dyslexia.floating.cpuPercent | 17.36 | 0.127 | % | 3 |
| render.50k.dyslexia.floating.hitchMsPerS | 83.08 | 34.35 | ms/s | 3 |
| render.50k.dyslexia.floating.maxFrameMs | 686 | 96.39 | ms | 3 |
| render.50k.dyslexia.fullscreen.cpuPercent | 18.42 | 0.197 | % | 3 |
| render.50k.dyslexia.fullscreen.hitchMsPerS | 73.00 | 3.93 | ms/s | 3 |
| render.50k.dyslexia.fullscreen.maxFrameMs | 782 | 2.54 | ms | 3 |
| render.50k.dyslexia.pinned.cpuPercent | 18.74 | 0.0739 | % | 3 |
| render.50k.dyslexia.pinned.hitchMsPerS | 81.83 | 5.86 | ms/s | 3 |
| render.50k.dyslexia.pinned.maxFrameMs | 787 | 287 | ms | 3 |
| render.50k.sans.floating.cpuPercent | 17.56 | 0.455 | % | 3 |
| render.50k.sans.floating.hitchMsPerS | 61.08 | 9.63 | ms/s | 3 |
| render.50k.sans.floating.maxFrameMs | 792 | 5.84 | ms | 3 |
| render.50k.sans.fullscreen.cpuPercent | 17.26 | 0.183 | % | 3 |
| render.50k.sans.fullscreen.hitchMsPerS | 70.04 | 21.52 | ms/s | 3 |
| render.50k.sans.fullscreen.maxFrameMs | 678 | 123 | ms | 3 |
| render.50k.sans.pinned.cpuPercent | 15.30 | 1.16 | % | 3 |
| render.50k.sans.pinned.hitchMsPerS | 91.34 | 3.12 | ms/s | 3 |
| render.50k.sans.pinned.maxFrameMs | 505 | 8.77 | ms | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
