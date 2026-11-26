# micro — per-redraw layout and broadcast encode cost (PLAN #4, #7)

Host `m1-max-32gb`, commit `f9c6c94`, 2026-11-25T22:45:48-05:00.

Per-redraw work in `WordFlowLayout.body` before visible lines are laid out (cache check, next-word scan, RTL check), and one broadcast tick's JSON encode. `layout.cold` is the first layout of a script (cache miss).

At 10 Hz, a broadcast's CPU share ≈ encode ms × 10 / 1000.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| browser.encode.10k.bytes | 90357 | 0 | bytes | 1 |
| browser.encode.10k.ms | 2.64 | 0 | ms | 1 |
| browser.encode.1k.bytes | 9443 | 0 | bytes | 1 |
| browser.encode.1k.ms | 0.269 | 0 | ms | 1 |
| browser.encode.50k.bytes | 450047 | 0 | bytes | 1 |
| browser.encode.50k.ms | 13.00 | 0 | ms | 1 |
| director.encode.10k.bytes | 90315 | 0 | bytes | 1 |
| director.encode.10k.ms | 2.67 | 0 | ms | 1 |
| director.encode.1k.bytes | 9401 | 0 | bytes | 1 |
| director.encode.1k.ms | 0.277 | 0 | ms | 1 |
| director.encode.50k.bytes | 450005 | 0 | bytes | 1 |
| director.encode.50k.ms | 13.05 | 0 | ms | 1 |
| layout.cold.10k.ms | 89.41 | 0 | ms | 1 |
| layout.cold.1k.ms | 9.21 | 0 | ms | 1 |
| layout.cold.50k.ms | 441 | 0 | ms | 1 |
| layout.redraw.10k@10%.ms | 0.441 | 0 | ms | 1 |
| layout.redraw.10k@50%.ms | 2.17 | 0 | ms | 1 |
| layout.redraw.10k@90%.ms | 3.85 | 0 | ms | 1 |
| layout.redraw.1k@10%.ms | 0.044 | 0 | ms | 1 |
| layout.redraw.1k@50%.ms | 0.213 | 0 | ms | 1 |
| layout.redraw.1k@90%.ms | 0.376 | 0 | ms | 1 |
| layout.redraw.50k@10%.ms | 2.20 | 0 | ms | 1 |
| layout.redraw.50k@50%.ms | 10.78 | 0 | ms | 1 |
| layout.redraw.50k@90%.ms | 19.35 | 0 | ms | 1 |

No baseline yet for this host. Commit one with -update-baseline once the numbers look right.
