# broadcast — browser-mode WebSocket clients (PLAN #7)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T23:30:10-05:00.

| Words | Clients | App CPU % | KB/s per client | Highlight → client p50 / p95 (ms) |
|---|---|---|---|---|
| 1000 | 1 | 6.51 | 89.55 | 4.19 / 9.03 |
| 1000 | 5 | 6.33 | 90.16 | 3.44 / 8.73 |
| 1000 | 20 | 7.99 | 90.30 | 4.43 / 9.66 |
| 10000 | 1 | 8.78 | 865 | 19.05 / 20.51 |
| 10000 | 5 | 9.29 | 849 | 19.27 / 23.18 |
| 10000 | 20 | 9.53 | 860 | 20.50 / 22.44 |
| 50000 | 1 | 18.53 | 4198 | 94.31 / 96.64 |
| 50000 | 5 | 18.56 | 4171 | 97.60 / 98.98 |
| 50000 | 20 | 19.83 | 4196 | 98.74 / 105 |

Browser mode (no auth token) with the highlight advancing at 150 wpm. Clients run in this process, not the app, so the app's CPU is the server's cost alone. Delay: app sets a new highlight → a client receives the first state containing it (the 100 ms broadcast timer bounds it at ≈100 ms plus encode and send).

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| broadcast.10k.1clients.cpuPercent | 8.78 | 0 | % | 1 |
| broadcast.10k.1clients.delayP95Ms | 20.51 | 0 | ms | 1 |
| broadcast.10k.1clients.kbPerSecPerClient | 865 | 0 | KB/s | 1 |
| broadcast.10k.20clients.cpuPercent | 9.53 | 0 | % | 1 |
| broadcast.10k.20clients.delayP95Ms | 22.44 | 0 | ms | 1 |
| broadcast.10k.20clients.kbPerSecPerClient | 860 | 0 | KB/s | 1 |
| broadcast.10k.5clients.cpuPercent | 9.29 | 0 | % | 1 |
| broadcast.10k.5clients.delayP95Ms | 23.18 | 0 | ms | 1 |
| broadcast.10k.5clients.kbPerSecPerClient | 849 | 0 | KB/s | 1 |
| broadcast.1k.1clients.cpuPercent | 6.51 | 0 | % | 1 |
| broadcast.1k.1clients.delayP95Ms | 9.03 | 0 | ms | 1 |
| broadcast.1k.1clients.kbPerSecPerClient | 89.55 | 0 | KB/s | 1 |
| broadcast.1k.20clients.cpuPercent | 7.99 | 0 | % | 1 |
| broadcast.1k.20clients.delayP95Ms | 9.66 | 0 | ms | 1 |
| broadcast.1k.20clients.kbPerSecPerClient | 90.30 | 0 | KB/s | 1 |
| broadcast.1k.5clients.cpuPercent | 6.33 | 0 | % | 1 |
| broadcast.1k.5clients.delayP95Ms | 8.73 | 0 | ms | 1 |
| broadcast.1k.5clients.kbPerSecPerClient | 90.16 | 0 | KB/s | 1 |
| broadcast.50k.1clients.cpuPercent | 18.53 | 0 | % | 1 |
| broadcast.50k.1clients.delayP95Ms | 96.64 | 0 | ms | 1 |
| broadcast.50k.1clients.kbPerSecPerClient | 4198 | 0 | KB/s | 1 |
| broadcast.50k.20clients.cpuPercent | 19.83 | 0 | % | 1 |
| broadcast.50k.20clients.delayP95Ms | 105 | 0 | ms | 1 |
| broadcast.50k.20clients.kbPerSecPerClient | 4196 | 0 | KB/s | 1 |
| broadcast.50k.5clients.cpuPercent | 18.56 | 0 | % | 1 |
| broadcast.50k.5clients.delayP95Ms | 98.98 | 0 | ms | 1 |
| broadcast.50k.5clients.kbPerSecPerClient | 4171 | 0 | KB/s | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
