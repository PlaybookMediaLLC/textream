# micro — per-redraw layout and broadcast encode cost (PLAN #4, #7)

Host `m1-max-32gb`, commit `b60167a`, 2026-11-26T02:32:30-05:00.

Per-redraw work in `WordFlowLayout.body` before visible lines are laid out (cache check, next-word scan, RTL check), and one broadcast tick's JSON encode. `layout.cold` is the first layout of a script (cache miss).

At 10 Hz, a broadcast's CPU share ≈ encode ms × 10 / 1000.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| browser.encode.10k.bytes | 344 | 0 | bytes | 5 |
| browser.encode.10k.ms | 0.0117 | 4.1e-05 | ms | 5 |
| browser.encode.1k.bytes | 342 | 0 | bytes | 5 |
| browser.encode.1k.ms | 0.0118 | 4.1e-05 | ms | 5 |
| browser.encode.50k.bytes | 346 | 0 | bytes | 5 |
| browser.encode.50k.ms | 0.0118 | 4.1e-05 | ms | 5 |
| director.encode.10k.bytes | 302 | 0 | bytes | 5 |
| director.encode.10k.ms | 0.0114 | 4.1e-05 | ms | 5 |
| director.encode.1k.bytes | 300 | 0 | bytes | 5 |
| director.encode.1k.ms | 0.0114 | 4.2e-05 | ms | 5 |
| director.encode.50k.bytes | 304 | 0 | bytes | 5 |
| director.encode.50k.ms | 0.0115 | 4.2e-05 | ms | 5 |
| layout.cold.10k.ms | 91.09 | 2.28 | ms | 5 |
| layout.cold.1k.ms | 9.48 | 0.13 | ms | 5 |
| layout.cold.50k.ms | 455 | 3.03 | ms | 5 |
| layout.redraw.10k@10%.ms | 0.00942 | 0.000208 | ms | 5 |
| layout.redraw.10k@50%.ms | 0.00946 | 0.000125 | ms | 5 |
| layout.redraw.10k@90%.ms | 0.00946 | 0.000125 | ms | 5 |
| layout.redraw.1k@10%.ms | 0.00129 | 0 | ms | 5 |
| layout.redraw.1k@50%.ms | 0.00129 | 0 | ms | 5 |
| layout.redraw.1k@90%.ms | 0.00129 | 0 | ms | 5 |
| layout.redraw.50k@10%.ms | 0.0466 | 0.000208 | ms | 5 |
| layout.redraw.50k@50%.ms | 0.0462 | 0.000375 | ms | 5 |
| layout.redraw.50k@90%.ms | 0.0463 | 0.00025 | ms | 5 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
