# broadcast — browser-mode WebSocket clients (PLAN #7)

Host `m1-max-32gb`, commit `8cee918`, 2026-11-26T04:18:33-05:00.

| Words | Clients | App CPU % | KB/s per client | Highlight → client p50 / p95 (ms) |
|---|---|---|---|---|
| 1000 | 1 | 15.12 | 1.72 | 10.20 / 19.56 |
| 1000 | 5 | 15.67 | 1.47 | 9.19 / 22.89 |
| 1000 | 20 | 15.98 | 1.48 | 9.46 / 21.76 |
| 10000 | 1 | 14.79 | 5.76 | 15.29 / 22.98 |
| 10000 | 5 | 15.81 | 5.99 | 16.11 / 24.04 |
| 10000 | 20 | 15.28 | 5.79 | 16.02 / 24.52 |
| 50000 | 1 | 15.65 | 27.86 | 76.59 / 79.65 |
| 50000 | 5 | 16.00 | 26.70 | 77.03 / 79.75 |
| 50000 | 20 | 15.80 | 26.84 | 78.18 / 81.61 |

Browser mode (no auth token) with the highlight advancing at 150 wpm. Clients run in this process, not the app, so the app's CPU is the server's cost alone. Delay: app sets a new highlight → a client receives the first state containing it (the 100 ms broadcast timer bounds it at ≈100 ms plus encode and send).

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| broadcast.10k.1clients.cpuPercent | 14.79 | 0.336 | % | 3 |
| broadcast.10k.1clients.delayP95Ms | 22.98 | 0.755 | ms | 3 |
| broadcast.10k.1clients.kbPerSecPerClient | 5.76 | 0.0175 | KB/s | 3 |
| broadcast.10k.20clients.cpuPercent | 15.28 | 0.27 | % | 3 |
| broadcast.10k.20clients.delayP95Ms | 24.52 | 0.896 | ms | 3 |
| broadcast.10k.20clients.kbPerSecPerClient | 5.79 | 0.0319 | KB/s | 3 |
| broadcast.10k.5clients.cpuPercent | 15.81 | 0.737 | % | 3 |
| broadcast.10k.5clients.delayP95Ms | 24.04 | 0.409 | ms | 3 |
| broadcast.10k.5clients.kbPerSecPerClient | 5.99 | 0.0928 | KB/s | 3 |
| broadcast.1k.1clients.cpuPercent | 15.12 | 0.0698 | % | 3 |
| broadcast.1k.1clients.delayP95Ms | 19.56 | 0.286 | ms | 3 |
| broadcast.1k.1clients.kbPerSecPerClient | 1.72 | 0.19 | KB/s | 3 |
| broadcast.1k.20clients.cpuPercent | 15.98 | 0.809 | % | 3 |
| broadcast.1k.20clients.delayP95Ms | 21.76 | 1.31 | ms | 3 |
| broadcast.1k.20clients.kbPerSecPerClient | 1.48 | 0.0633 | KB/s | 3 |
| broadcast.1k.5clients.cpuPercent | 15.67 | 0.447 | % | 3 |
| broadcast.1k.5clients.delayP95Ms | 22.89 | 0.339 | ms | 3 |
| broadcast.1k.5clients.kbPerSecPerClient | 1.47 | 0.238 | KB/s | 3 |
| broadcast.50k.1clients.cpuPercent | 15.65 | 0.13 | % | 3 |
| broadcast.50k.1clients.delayP95Ms | 79.65 | 0.909 | ms | 3 |
| broadcast.50k.1clients.kbPerSecPerClient | 27.86 | 0.375 | KB/s | 3 |
| broadcast.50k.20clients.cpuPercent | 15.80 | 0.519 | % | 3 |
| broadcast.50k.20clients.delayP95Ms | 81.61 | 0.0362 | ms | 3 |
| broadcast.50k.20clients.kbPerSecPerClient | 26.84 | 0.414 | KB/s | 3 |
| broadcast.50k.5clients.cpuPercent | 16.00 | 0.182 | % | 3 |
| broadcast.50k.5clients.delayP95Ms | 79.75 | 0.401 | ms | 3 |
| broadcast.50k.5clients.kbPerSecPerClient | 26.70 | 0.324 | KB/s | 3 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
