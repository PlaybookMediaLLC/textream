# idle — idle and open-but-paused cost (PLAN #5)

Host `m1-max-32gb`, commit `b60167a`, 2026-11-26T02:33:22-05:00.

| Scenario | CPU % | Wakeups/s | Energy (mW) | Memory (MB) |
|---|---|---|---|---|
| A.menubar | 0.0129 | 0.233 | 0.0066 | 60.42 |
| B.mainWindow | 0.0125 | 0.242 | 0.00682 | 56.81 |
| C.paused.pinned | 0.924 | 13.94 | 0.384 | 69.24 |
| C.paused.floating | 0.597 | 11.15 | 0.272 | 68.44 |
| C.paused.fullscreen | 0.604 | 12.20 | 0.304 | 71.17 |
| D.servers | 0.0102 | 0.357 | 0.00635 | 60.89 |
| E.classic | 34.38 | 15.77 | 43.90 | 61.28 |
| F.tracking-ui | 25.95 | 16.97 | 34.38 | 72.80 |

Each scenario: 60-s settle, then 2 min measured from the app's own task_info samples (every 10 s, so the sampler adds ≈0.1 wakeups/s). Energy is the kernel's per-task estimate (Apple silicon only). PLAN bars: A < 0.1% CPU and < 2 wakeups/s; B < 0.5%, < 5/s; C < 1%, < 20/s; D adds < 1 wakeup/s over A. C has recognition paused, so it measures what the open overlay costs on its own.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| idle.A.menubar.cpuPercent | 0.0129 | 0.000164 | % | 3 |
| idle.A.menubar.energyMW | 0.0066 | 0.000585 | mW | 3 |
| idle.A.menubar.wakeupsPerSec | 0.233 | 0.00833 | /s | 3 |
| idle.B.mainWindow.cpuPercent | 0.0125 | 2.76e-05 | % | 3 |
| idle.B.mainWindow.energyMW | 0.00682 | 3.26e-05 | mW | 3 |
| idle.B.mainWindow.wakeupsPerSec | 0.242 | 4.37e-07 | /s | 3 |
| idle.C.paused.floating.cpuPercent | 0.597 | 0.014 | % | 3 |
| idle.C.paused.floating.energyMW | 0.272 | 0.00115 | mW | 3 |
| idle.C.paused.floating.wakeupsPerSec | 11.15 | 0.0417 | /s | 3 |
| idle.C.paused.fullscreen.cpuPercent | 0.604 | 0.0687 | % | 3 |
| idle.C.paused.fullscreen.energyMW | 0.304 | 0.0121 | mW | 3 |
| idle.C.paused.fullscreen.wakeupsPerSec | 12.20 | 0.0838 | /s | 3 |
| idle.C.paused.pinned.cpuPercent | 0.924 | 0.00379 | % | 3 |
| idle.C.paused.pinned.energyMW | 0.384 | 0.00866 | mW | 3 |
| idle.C.paused.pinned.wakeupsPerSec | 13.94 | 0.354 | /s | 3 |
| idle.D.servers.cpuPercent | 0.0102 | 1.15e-05 | % | 3 |
| idle.D.servers.energyMW | 0.00635 | 0.000353 | mW | 3 |
| idle.D.servers.wakeupsPerSec | 0.357 | 0.00808 | /s | 3 |
| idle.E.classic.cpuPercent | 34.38 | 0.22 | % | 3 |
| idle.E.classic.energyMW | 43.90 | 0.228 | mW | 3 |
| idle.E.classic.wakeupsPerSec | 15.77 | 0.287 | /s | 3 |
| idle.F.tracking-ui.cpuPercent | 25.95 | 1.35 | % | 3 |
| idle.F.tracking-ui.energyMW | 34.38 | 3.09 | mW | 3 |
| idle.F.tracking-ui.wakeupsPerSec | 16.97 | 0.659 | /s | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
