# micro — per-redraw layout and broadcast encode cost (PLAN #4, #7)

Host `m1-max-32gb`, commit `0ce0187`, 2026-11-26T06:00:52-05:00.

Per-redraw work in `WordFlowLayout.body` before visible lines are laid out (cache check, next-word scan, RTL check), and one broadcast tick's JSON encode. `layout.cold` is the first layout of a script (cache miss).

At 10 Hz, a broadcast's CPU share ≈ encode ms × 10 / 1000.

## All metrics (median of runs, MAD)

| Metric | Median | MAD | Unit | Runs |
|---|---|---|---|---|
| browser.encode.10k.bytes | 344 | 0 | bytes | 5 |
| browser.encode.10k.ms | 0.0125 | 4.2e-05 | ms | 5 |
| browser.encode.1k.bytes | 342 | 0 | bytes | 5 |
| browser.encode.1k.ms | 0.0125 | 4.1e-05 | ms | 5 |
| browser.encode.50k.bytes | 346 | 0 | bytes | 5 |
| browser.encode.50k.ms | 0.0126 | 4.2e-05 | ms | 5 |
| director.encode.10k.bytes | 302 | 0 | bytes | 5 |
| director.encode.10k.ms | 0.012 | 0.000125 | ms | 5 |
| director.encode.1k.bytes | 300 | 0 | bytes | 5 |
| director.encode.1k.ms | 0.0122 | 0.000125 | ms | 5 |
| director.encode.50k.bytes | 304 | 0 | bytes | 5 |
| director.encode.50k.ms | 0.0123 | 8.4e-05 | ms | 5 |
| layout.cold.10k.ms | 13.26 | 0.0351 | ms | 5 |
| layout.cold.1k.ms | 2.83 | 0.0433 | ms | 5 |
| layout.cold.50k.ms | 59.81 | 0.0903 | ms | 5 |
| layout.redraw.10k@10%.ms | 0.00975 | 8.3e-05 | ms | 5 |
| layout.redraw.10k@50%.ms | 0.00979 | 4.2e-05 | ms | 5 |
| layout.redraw.10k@90%.ms | 0.00983 | 1e-06 | ms | 5 |
| layout.redraw.1k@10%.ms | 0.00142 | 0 | ms | 5 |
| layout.redraw.1k@50%.ms | 0.00137 | 0 | ms | 5 |
| layout.redraw.1k@90%.ms | 0.00142 | 0 | ms | 5 |
| layout.redraw.50k@10%.ms | 0.0476 | 0.000333 | ms | 5 |
| layout.redraw.50k@50%.ms | 0.047 | 0.000666 | ms | 5 |
| layout.redraw.50k@90%.ms | 0.047 | 0.000708 | ms | 5 |

## Against baseline

| Metric | Baseline | Now | Change | Verdict |
|---|---|---|---|---|
| browser.encode.10k.bytes | 344 | 344 | +0.0% | ok |
| browser.encode.10k.ms | 0.0117 | 0.0125 | +7.1% | ok |
| browser.encode.1k.bytes | 342 | 342 | +0.0% | ok |
| browser.encode.1k.ms | 0.0118 | 0.0125 | +6.7% | ok |
| browser.encode.50k.bytes | 346 | 346 | +0.0% | ok |
| browser.encode.50k.ms | 0.0118 | 0.0126 | +6.3% | ok |
| director.encode.10k.bytes | 302 | 302 | +0.0% | ok |
| director.encode.10k.ms | 0.0114 | 0.012 | +5.9% | ok |
| director.encode.1k.bytes | 300 | 300 | +0.0% | ok |
| director.encode.1k.ms | 0.0114 | 0.0122 | +6.9% | ok |
| director.encode.50k.bytes | 304 | 304 | +0.0% | ok |
| director.encode.50k.ms | 0.0115 | 0.0123 | +6.9% | ok |
| layout.cold.10k.ms | 91.09 | 13.26 | -85.4% | ok |
| layout.cold.1k.ms | 9.48 | 2.83 | -70.1% | ok |
| layout.cold.50k.ms | 455 | 59.81 | -86.9% | ok |
| layout.redraw.10k@10%.ms | 0.00942 | 0.00975 | +3.5% | ok |
| layout.redraw.10k@50%.ms | 0.00946 | 0.00979 | +3.5% | ok |
| layout.redraw.10k@90%.ms | 0.00946 | 0.00983 | +4.0% | ok |
| layout.redraw.1k@10%.ms | 0.00129 | 0.00142 | +9.7% | ok |
| layout.redraw.1k@50%.ms | 0.00129 | 0.00137 | +6.4% | ok |
| layout.redraw.1k@90%.ms | 0.00129 | 0.00142 | +9.6% | ok |
| layout.redraw.50k@10%.ms | 0.0466 | 0.0476 | +2.1% | ok |
| layout.redraw.50k@50%.ms | 0.0462 | 0.047 | +1.7% | ok |
| layout.redraw.50k@90%.ms | 0.0463 | 0.047 | +1.5% | ok |
