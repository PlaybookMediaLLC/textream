#!/usr/bin/env python3
"""Isolated local verification console server for non-UI / backend / Swift / CI PRs.

Serves a live HTML verification summary displaying:
- Exact repository branch and commit SHA (`PR_EVIDENCE_COMMIT`, `PR_EVIDENCE_BRANCH`)
- Observed automated test suite outcomes passed via `PR_EVIDENCE_TEST_RESULTS`
- Deterministic HTTP 200 on `/` and HTTP 404 on unknown routes
"""

from __future__ import annotations

import html
import http.server
import json
import os
from pathlib import Path
import socketserver
import tempfile


class _ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def _render_html(commit_sha: str, branch: str, test_suites: list[dict]) -> str:
    passed_count = sum(1 for s in test_suites if s.get("status") == "passed")
    skipped_count = sum(1 for s in test_suites if s.get("status") == "skipped")
    failed_count = sum(1 for s in test_suites if s.get("status") == "failed")

    rows = []
    for idx, suite in enumerate(test_suites, start=1):
        status = str(suite.get("status", "unknown")).upper()
        badge_cls = "ok" if status == "PASSED" else ("warn" if status == "SKIPPED" else "err")
        rows.append(
            f"""
            <tr data-suite-row="{idx}">
              <td><code>{html.escape(str(suite.get('command', '')))}</code></td>
              <td><span class="badge {badge_cls}">{html.escape(status)}</span></td>
              <td class="detail">{html.escape(str(suite.get('detail', '')))}</td>
            </tr>
            """
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Dante for Creators — Live Verification Console</title>
  <style>
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; padding: 40px 56px;
      background: #0b0e14; color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }}
    header {{ display: flex; justify-content: space-between; align-items: baseline; border-bottom: 1px solid #1e293b; padding-bottom: 20px; }}
    h1 {{ margin: 0; font-size: 32px; letter-spacing: -0.02em; }}
    .meta {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: #94a3b8; font-size: 14px; }}
    .cards {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; margin: 26px 0; }}
    .card {{ background: #131924; border: 1px solid #1f2937; border-radius: 12px; padding: 20px; }}
    .card .label {{ font-size: 13px; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.06em; }}
    .card .val {{ font-size: 34px; font-weight: 700; margin-top: 8px; }}
    .ok {{ color: #22c55e; }} .warn {{ color: #f59e0b; }} .err {{ color: #ef4444; }}
    table {{ width: 100%; border-collapse: collapse; background: #131924; border-radius: 12px; overflow: hidden; border: 1px solid #1f2937; }}
    th, td {{ padding: 14px 16px; text-align: left; border-bottom: 1px solid #1f2937; font-size: 14px; }}
    th {{ color: #94a3b8; font-weight: 600; background: #0f141e; }}
    code {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; color: #e2e8f0; }}
    .badge {{ display: inline-block; padding: 3px 10px; border-radius: 999px; font-weight: 700; font-size: 12px; border: 1px solid currentColor; }}
    .detail {{ color: #cbd5e1; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.5px; }}
  </style>
</head>
<body>
  <header>
    <h1 id="console-title">Dante for Creators · Engineering Verification Console</h1>
    <div class="meta" id="commit-meta">Branch: {html.escape(branch)} · Commit: {html.escape(commit_sha[:12])}</div>
  </header>
  <section class="cards" id="summary-cards">
    <div class="card"><div class="label">Suites Passed</div><div class="val ok">{passed_count}</div></div>
    <div class="card"><div class="label">Host-Skipped (CI Verified)</div><div class="val warn">{skipped_count}</div></div>
    <div class="card"><div class="label">Suites Failed</div><div class="val err">{failed_count}</div></div>
  </section>
  <table id="suite-table">
    <thead><tr><th>Verification Command</th><th>Status</th><th>Observed Output</th></tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table>
</body>
</html>
"""


def _write_url_atomic(url_file: Path, url: str) -> None:
    url_file.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(url_file.parent), prefix=".url-", suffix=".tmp")
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(url)
        os.replace(tmp_path, url_file)
    except Exception:
        tmp_path.unlink(missing_ok=True)
        raise


def main() -> int:
    commit_sha = os.environ.get("PR_EVIDENCE_COMMIT", "unknown")
    branch = os.environ.get("PR_EVIDENCE_BRANCH", "unknown")
    suites = json.loads(os.environ.get("PR_EVIDENCE_TEST_RESULTS", "[]"))
    page_bytes = _render_html(commit_sha, branch, suites).encode("utf-8")

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path in ("/", "/index.html"):
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(page_bytes)))
                self.end_headers()
                self.wfile.write(page_bytes)
            else:
                self.send_response(404)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.end_headers()
                self.wfile.write(b"404 Not Found")

        def log_message(self, format: str, *args) -> None:  # noqa: A002
            return

    server = _ThreadingServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    url_file = os.environ.get("PR_EVIDENCE_URL_FILE")
    if url_file:
        _write_url_atomic(Path(url_file), f"http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
