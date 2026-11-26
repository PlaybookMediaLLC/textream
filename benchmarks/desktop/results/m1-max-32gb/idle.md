# idle — idle and open-but-paused cost (PLAN #5)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T23:33:10-05:00.

| Scenario | CPU % | Wakeups/s | Energy (mW) | Memory (MB) |
|---|---|---|---|---|
| A.menubar | 0.00507 | 0.2 | 0.00556 | 63.41 |
| B.mainWindow | 0.0112 | 0.253 | 0.00731 | 63.72 |
| C.paused.pinned | 0.856 | 34.40 | 1.15 | 70.74 |
| C.paused.floating | 0.874 | 31.23 | 0.582 | 70.36 |
| C.paused.fullscreen | 1.61 | 13.88 | 19.74 | 75.59 |
| D.servers | 0.00962 | 0.363 | 0.00459 | 61.77 |
| E.classic | 31.32 | 60.72 | 438 | 69.33 |
| F.tracking-ui | 18.19 | 66.45 | 178 | 73.84 |

Each scenario: 60-s settle, then 1 min measured from the app's own task_info samples (every 10 s, so the sampler adds ≈0.1 wakeups/s). Energy is the kernel's per-task estimate (Apple silicon only). PLAN bars: A < 0.1% CPU and < 2 wakeups/s; B < 0.5%, < 5/s; C < 1%, < 20/s; D adds < 1 wakeup/s over A. C has recognition paused, so it measures what the open overlay costs on its own.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| idle.A.menubar.cpuPercent | 0.00507 | 0 | % | 1 |
| idle.A.menubar.energyMW | 0.00556 | 0 | mW | 1 |
| idle.A.menubar.wakeupsPerSec | 0.2 | 0 | /s | 1 |
| idle.B.mainWindow.cpuPercent | 0.0112 | 0 | % | 1 |
| idle.B.mainWindow.energyMW | 0.00731 | 0 | mW | 1 |
| idle.B.mainWindow.wakeupsPerSec | 0.253 | 0 | /s | 1 |
| idle.C.paused.floating.cpuPercent | 0.874 | 0 | % | 1 |
| idle.C.paused.floating.energyMW | 0.582 | 0 | mW | 1 |
| idle.C.paused.floating.wakeupsPerSec | 31.23 | 0 | /s | 1 |
| idle.C.paused.fullscreen.cpuPercent | 1.61 | 0 | % | 1 |
| idle.C.paused.fullscreen.energyMW | 19.74 | 0 | mW | 1 |
| idle.C.paused.fullscreen.wakeupsPerSec | 13.88 | 0 | /s | 1 |
| idle.C.paused.pinned.cpuPercent | 0.856 | 0 | % | 1 |
| idle.C.paused.pinned.energyMW | 1.15 | 0 | mW | 1 |
| idle.C.paused.pinned.wakeupsPerSec | 34.40 | 0 | /s | 1 |
| idle.D.servers.cpuPercent | 0.00962 | 0 | % | 1 |
| idle.D.servers.energyMW | 0.00459 | 0 | mW | 1 |
| idle.D.servers.wakeupsPerSec | 0.363 | 0 | /s | 1 |
| idle.E.classic.cpuPercent | 31.32 | 0 | % | 1 |
| idle.E.classic.energyMW | 438 | 0 | mW | 1 |
| idle.E.classic.wakeupsPerSec | 60.72 | 0 | /s | 1 |
| idle.F.tracking-ui.cpuPercent | 18.19 | 0 | % | 1 |
| idle.F.tracking-ui.energyMW | 178 | 0 | mW | 1 |
| idle.F.tracking-ui.wakeupsPerSec | 66.45 | 0 | /s | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
