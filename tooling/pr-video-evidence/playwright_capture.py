"""Playwright browser capture with engineering visual annotations and timeline sync.

Drives the real running web application or live verification console in Chromium,
injecting restrained engineering visual annotations derived from real DOM locator
coordinates:
- Visible cursor movement along smooth interpolated paths
- Click ripple indicators
- Element bounding boxes with animated highlight border
- Numbered callout badges with directional pointer arrow
- Optional subtle spotlight around the target element
- Restrained camera zoom toward the target element (in document coordinates, with
  post-zoom overlay re-measurement so boxes and spotlights align accurately)
- Preserved raw video (.webm) and Playwright trace (trace.zip) even on errors
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import shutil
import time
from typing import Any
from urllib.parse import urljoin


OVERLAY_BOOTSTRAP_JS = r"""
(() => {
  if (window.__prEvidenceOverlay) return;

  const style = document.createElement('style');
  style.id = 'pr-evidence-style';
  style.textContent = `
    #pr-ev-layer {
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 2147483640;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    #pr-ev-spotlight {
      position: fixed;
      inset: 0;
      background: rgba(6, 9, 16, 0.42);
      opacity: 0;
      transition: opacity 240ms ease;
      pointer-events: none;
    }
    #pr-ev-box {
      position: fixed;
      border: 3px solid #38bdf8;
      border-radius: 10px;
      background: rgba(56, 189, 248, 0.08);
      box-shadow: 0 0 0 2px rgba(9, 13, 22, 0.7), 0 0 24px rgba(56, 189, 248, 0.45);
      opacity: 0;
      transition: opacity 200ms ease, left 220ms ease, top 220ms ease, width 220ms ease, height 220ms ease;
    }
    #pr-ev-box.pulse {
      animation: pr-ev-pulse 1.8s ease-in-out infinite;
    }
    @keyframes pr-ev-pulse {
      0%, 100% { box-shadow: 0 0 0 2px rgba(9, 13, 22, 0.7), 0 0 18px rgba(56, 189, 248, 0.45); }
      50% { box-shadow: 0 0 0 4px rgba(56, 189, 248, 0.35), 0 0 28px rgba(56, 189, 248, 0.72); }
    }
    #pr-ev-callout {
      position: fixed;
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 8px 14px;
      border-radius: 10px;
      background: rgba(11, 15, 25, 0.94);
      border: 1.5px solid #38bdf8;
      color: #f8fafc;
      font-size: 16px;
      font-weight: 600;
      letter-spacing: -0.01em;
      box-shadow: 0 10px 28px rgba(0, 0, 0, 0.45);
      opacity: 0;
      transition: opacity 220ms ease, left 220ms ease, top 220ms ease;
      max-width: 560px;
    }
    #pr-ev-callout-num {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 26px;
      height: 26px;
      border-radius: 999px;
      background: #38bdf8;
      color: #090d16;
      font-size: 14px;
      font-weight: 800;
      flex: none;
    }
    #pr-ev-arrow {
      position: fixed;
      inset: 0;
      width: 100vw;
      height: 100vh;
      pointer-events: none;
      opacity: 0;
      transition: opacity 220ms ease;
    }
    #pr-ev-cursor {
      position: fixed;
      width: 28px;
      height: 28px;
      left: 60px;
      top: 60px;
      transform: translate(-3px, -3px);
      filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.6));
      z-index: 2147483647;
    }
    .pr-ev-ripple {
      position: fixed;
      width: 18px;
      height: 18px;
      border-radius: 999px;
      border: 3px solid #38bdf8;
      background: rgba(56, 189, 248, 0.25);
      transform: translate(-50%, -50%) scale(0.6);
      animation: pr-ev-ripple-anim 620ms cubic-bezier(0.16, 1, 0.3, 1) forwards;
      z-index: 2147483646;
    }
    @keyframes pr-ev-ripple-anim {
      0% { opacity: 0.95; transform: translate(-50%, -50%) scale(0.5); }
      100% { opacity: 0; transform: translate(-50%, -50%) scale(3.4); }
    }
    #pr-ev-hud {
      position: fixed;
      top: 16px;
      right: 18px;
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 6px 12px;
      border-radius: 8px;
      background: rgba(11, 15, 25, 0.86);
      border: 1px solid rgba(148, 163, 184, 0.32);
      color: #cbd5e1;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 13px;
      z-index: 2147483645;
    }
    #pr-ev-hud-dot {
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: #22c55e;
    }
  `;
  document.head.appendChild(style);

  const layer = document.createElement('div');
  layer.id = 'pr-ev-layer';
  layer.innerHTML = `
    <div id="pr-ev-spotlight"></div>
    <svg id="pr-ev-arrow" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <marker id="pr-ev-arrowhead" markerWidth="10" markerHeight="7" refX="8" refY="3.5" orient="auto">
          <polygon points="0 0, 10 3.5, 0 7" fill="#38bdf8" />
        </marker>
      </defs>
      <line id="pr-ev-arrow-line" x1="0" y1="0" x2="0" y2="0" stroke="#38bdf8" stroke-width="3" marker-end="url(#pr-ev-arrowhead)" />
    </svg>
    <div id="pr-ev-box"></div>
    <div id="pr-ev-callout"><span id="pr-ev-callout-num">1</span><span id="pr-ev-callout-text"></span></div>
    <div id="pr-ev-hud"><span id="pr-ev-hud-dot"></span><span id="pr-ev-hud-label">PR VERIFICATION</span></div>
    <svg id="pr-ev-cursor" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M4 3L23 13.5L14.5 15.8L11.8 24L4 3Z" fill="#ffffff" stroke="#090d16" stroke-width="2.2" stroke-linejoin="round"/>
    </svg>
  `;
  document.documentElement.appendChild(layer);

  const cursorEl = document.getElementById('pr-ev-cursor');
  const boxEl = document.getElementById('pr-ev-box');
  const calloutEl = document.getElementById('pr-ev-callout');
  const calloutNumEl = document.getElementById('pr-ev-callout-num');
  const calloutTextEl = document.getElementById('pr-ev-callout-text');
  const spotlightEl = document.getElementById('pr-ev-spotlight');
  const arrowSvg = document.getElementById('pr-ev-arrow');
  const arrowLine = document.getElementById('pr-ev-arrow-line');
  const hudLabel = document.getElementById('pr-ev-hud-label');

  let curX = 96;
  let curY = 96;

  window.__prEvidenceOverlay = {
    setHud(text) {
      if (hudLabel) hudLabel.textContent = text;
    },
    moveCursor(x, y) {
      curX = x;
      curY = y;
      if (cursorEl) {
        cursorEl.style.left = `${x}px`;
        cursorEl.style.top = `${y}px`;
      }
    },
    getCursor() {
      return { x: curX, y: curY };
    },
    clickRipple(x, y) {
      const r = document.createElement('div');
      r.className = 'pr-ev-ripple';
      r.style.left = `${x}px`;
      r.style.top = `${y}px`;
      layer.appendChild(r);
      setTimeout(() => r.remove(), 700);
    },
    highlightRect(rect, label, calloutIndex, spotlight) {
      const pad = 8;
      const left = Math.max(4, rect.left - pad);
      const top = Math.max(4, rect.top - pad);
      const width = Math.max(24, rect.width + pad * 2);
      const height = Math.max(24, rect.height + pad * 2);

      boxEl.style.left = `${left}px`;
      boxEl.style.top = `${top}px`;
      boxEl.style.width = `${width}px`;
      boxEl.style.height = `${height}px`;
      boxEl.style.opacity = '1';
      boxEl.classList.add('pulse');

      if (spotlight) {
        const right = left + width;
        const bottom = top + height;
        spotlightEl.style.clipPath = `polygon(
          0% 0%, 0% 100%, ${left}px 100%, ${left}px ${top}px,
          ${right}px ${top}px, ${right}px ${bottom}px, ${left}px ${bottom}px,
          ${left}px 100%, 100% 100%, 100% 0%
        )`;
        spotlightEl.style.opacity = '1';
      } else {
        spotlightEl.style.opacity = '0';
      }

      if (label) {
        calloutNumEl.textContent = String(calloutIndex || 1);
        calloutTextEl.textContent = label;
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const preferAbove = top > 96;
        const cTop = preferAbove ? Math.max(60, top - 62) : Math.min(vh - 190, top + height + 18);
        const cLeft = Math.min(Math.max(24, left), Math.max(24, vw - 580));
        calloutEl.style.left = `${cLeft}px`;
        calloutEl.style.top = `${cTop}px`;
        calloutEl.style.opacity = '1';

        const fromX = cLeft + 48;
        const fromY = preferAbove ? cTop + 42 : cTop;
        const toX = Math.min(Math.max(left + 20, fromX), left + width - 20);
        const toY = preferAbove ? top - 3 : top + height + 3;
        arrowLine.setAttribute('x1', String(fromX));
        arrowLine.setAttribute('y1', String(fromY));
        arrowLine.setAttribute('x2', String(toX));
        arrowLine.setAttribute('y2', String(toY));
        arrowSvg.style.opacity = '0.9';
      } else {
        calloutEl.style.opacity = '0';
        arrowSvg.style.opacity = '0';
      }
    },
    clearHighlight() {
      boxEl.style.opacity = '0';
      boxEl.classList.remove('pulse');
      calloutEl.style.opacity = '0';
      arrowSvg.style.opacity = '0';
      spotlightEl.style.opacity = '0';
    },
    setZoom(scale, viewportOriginX, viewportOriginY, immediate) {
      const clamped = Math.max(1.0, Math.min(1.28, scale || 1.0));
      document.body.style.transition = immediate
        ? 'none'
        : 'transform 420ms cubic-bezier(0.22, 1, 0.36, 1)';
      if (clamped <= 1.001) {
        document.body.style.transformOrigin = '50% 50%';
        document.body.style.transform = 'scale(1)';
      } else {
        // Convert viewport coordinates to document coordinates for accurate scrolled zoom
        const docX = viewportOriginX + window.scrollX;
        const docY = viewportOriginY + window.scrollY;
        document.body.style.transformOrigin = `${docX}px ${docY}px`;
        document.body.style.transform = `scale(${clamped})`;
      }
    },
  };
})();
"""


@dataclass(frozen=True)
class BeatRecord:
    """Observed timing, assertions, and metadata for one recorded beat."""

    index: int
    acceptance_criterion: str
    route: str
    start_seconds: float
    end_seconds: float
    narration: str
    expected_result: str
    assertion_description: str
    passed: bool
    observed_detail: str
    annotation_label: str


@dataclass(frozen=True)
class CaptureResult:
    """Artifacts and observed results from a Playwright capture session."""

    raw_video_path: Path
    trace_path: Path
    beats: list[BeatRecord]
    console_errors: list[str]
    page_errors: list[str]
    total_duration_seconds: float


def build_route_url(base_url: str, route: str) -> str:
    """Join ``base_url`` and ``route`` cleanly regardless of leading/trailing slashes."""
    clean_base = base_url.rstrip("/") + "/"
    clean_route = route.lstrip("/")
    return urljoin(clean_base, clean_route)


def _ensure_overlay(page: Any, hud_text: str) -> None:
    page.evaluate(OVERLAY_BOOTSTRAP_JS)
    page.evaluate("(t) => window.__prEvidenceOverlay.setHud(t)", hud_text)


def _move_cursor_smooth(page: Any, target_x: float, target_y: float, steps: int = 14) -> None:
    cur = page.evaluate("() => window.__prEvidenceOverlay.getCursor()")
    start_x = float(cur.get("x", 96.0))
    start_y = float(cur.get("y", 96.0))
    for step in range(1, steps + 1):
        t = step / float(steps)
        eased = t * t * (3.0 - 2.0 * t)
        nx = start_x + (target_x - start_x) * eased
        ny = start_y + (target_y - start_y) * eased
        page.mouse.move(nx, ny)
        page.evaluate("([x, y]) => window.__prEvidenceOverlay.moveCursor(x, y)", [nx, ny])
        page.wait_for_timeout(14)


def _measure_box(page: Any, selector: str) -> dict[str, float] | None:
    box = page.locator(selector).first.bounding_box()
    if not box:
        return None
    return {
        "left": float(box["x"]),
        "top": float(box["y"]),
        "width": float(box["width"]),
        "height": float(box["height"]),
    }


def _run_assertion(page: Any, assertion: dict[str, Any], last_status: int | None) -> tuple[bool, str]:
    kind = assertion.get("type", "visible")
    try:
        if kind == "visible":
            selector = assertion["selector"]
            visible = page.locator(selector).first.is_visible()
            return visible, f"selector '{selector}' visible={visible}"

        if kind == "text_contains":
            selector = assertion.get("selector", "body")
            expected = str(assertion["expected"])
            text = page.locator(selector).first.inner_text(timeout=5000)
            ok = expected.lower() in text.lower()
            return ok, f"selector '{selector}' contains '{expected}': {ok}"

        if kind == "url_contains":
            expected = str(assertion["expected"])
            ok = expected in page.url
            return ok, f"url '{page.url}' contains '{expected}': {ok}"

        if kind == "title_contains":
            expected = str(assertion["expected"])
            title = page.title()
            ok = expected.lower() in title.lower()
            return ok, f"title '{title}' contains '{expected}': {ok}"

        if kind == "http_status":
            expected = int(assertion["expected"])
            ok = last_status == expected
            return ok, f"HTTP status observed={last_status}, expected={expected}"
    except Exception as exc:
        return False, f"assertion '{kind}' error: {exc}"

    raise ValueError(f"Unsupported assertion type: {kind}")


def capture_storyboard_with_playwright(
    base_url: str,
    beats: list[dict[str, Any]],
    narration_durations: list[float],
    output_dir: Path,
    commit_short: str,
    viewport_width: int = 1920,
    viewport_height: int = 1080,
) -> CaptureResult:
    """Execute storyboard beats in real Chromium, recording raw video + trace."""
    from playwright.sync_api import sync_playwright

    output_dir.mkdir(parents=True, exist_ok=True)
    raw_video_dir = output_dir / "pw_video"
    raw_video_dir.mkdir(parents=True, exist_ok=True)
    trace_path = output_dir / "trace.zip"

    console_errors: list[str] = []
    page_errors: list[str] = []
    beat_records: list[BeatRecord] = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={"width": viewport_width, "height": viewport_height},
            record_video_dir=str(raw_video_dir),
            record_video_size={"width": viewport_width, "height": viewport_height},
            color_scheme="dark",
        )
        context.tracing.start(screenshots=True, snapshots=True, sources=False)
        page = context.new_page()
        page.on(
            "console",
            lambda msg: console_errors.append(msg.text) if msg.type == "error" else None,
        )
        page.on("pageerror", lambda err: page_errors.append(str(err)))

        recording_started = time.monotonic()
        last_status: int | None = None
        video_obj = None
        try:
            for idx, beat in enumerate(beats):
                route = str(beat.get("route", "/"))
                action = str(beat.get("action", "inspect"))
                target = beat.get("target")
                annotation = beat.get("annotation") or {}
                label = str(annotation.get("label") or beat.get("acceptance_criterion") or f"Step {idx + 1}")
                spotlight = bool(annotation.get("spotlight", False))
                zoom = float(annotation.get("zoom", 1.0))
                hud_text = f"DANTE PR VERIFICATION · {commit_short} · {route}"

                # Navigate before marking Beat 0 start so narration aligns with loaded content
                if action == "goto" or idx == 0 or beat.get("navigate", False):
                    full_url = build_route_url(base_url, route)
                    resp = page.goto(full_url, wait_until="networkidle")
                    last_status = resp.status if resp is not None else None
                    _ensure_overlay(page, hud_text)
                else:
                    _ensure_overlay(page, hud_text)

                beat_start = round(time.monotonic() - recording_started, 3)

                # Reset previous zoom immediately so coordinates are never measured mid-transition
                page.evaluate("() => { window.__prEvidenceOverlay.clearHighlight(); window.__prEvidenceOverlay.setZoom(1.0, 0, 0, true); }")
                page.wait_for_timeout(40)

                # Perform scroll BEFORE measuring target, highlighting, or zooming
                if action == "scroll":
                    scroll_y = int(beat.get("scroll_y", 420))
                    page.evaluate("(y) => window.scrollTo({ top: y, behavior: 'smooth' })", scroll_y)
                    page.wait_for_timeout(420)

                if target:
                    locator = page.locator(str(target)).first
                    if action != "scroll":
                        locator.scroll_into_view_if_needed()
                        page.wait_for_timeout(120)
                    rect = _measure_box(page, str(target))
                    if rect:
                        cx = rect["left"] + rect["width"] / 2.0
                        cy = rect["top"] + rect["height"] / 2.0
                        _move_cursor_smooth(page, cx, cy, steps=12)

                        if action == "click":
                            page.evaluate(
                                "([r, l, n, s]) => window.__prEvidenceOverlay.highlightRect(r, l, n, s)",
                                [rect, label, idx + 1, spotlight],
                            )
                            page.wait_for_timeout(180)
                            page.evaluate("([x, y]) => window.__prEvidenceOverlay.clickRipple(x, y)", [cx, cy])
                            if beat.get("expect_navigation", False):
                                with page.expect_navigation(wait_until="networkidle") as nav_info:
                                    locator.click()
                                nav_resp = nav_info.value
                                last_status = nav_resp.status if nav_resp is not None else last_status
                                new_route = page.url.replace(base_url.rstrip("/"), "") or "/"
                                _ensure_overlay(page, f"DANTE PR VERIFICATION · {commit_short} · {new_route}")
                                post_target = beat.get("post_action_target")
                                if post_target:
                                    post_rect = _measure_box(page, str(post_target))
                                    if post_rect:
                                        pcx = post_rect["left"] + post_rect["width"] / 2.0
                                        pcy = post_rect["top"] + post_rect["height"] / 2.0
                                        _move_cursor_smooth(page, pcx, pcy, steps=10)
                                        page.evaluate(
                                            "([r, l, n, s]) => window.__prEvidenceOverlay.highlightRect(r, l, n, s)",
                                            [post_rect, label, idx + 1, spotlight],
                                        )
                            else:
                                locator.click()
                                page.wait_for_timeout(180)
                        else:
                            # Apply restrained zoom first, wait for transform to settle, then re-measure
                            # post-zoom bounding box so highlight & spotlight wrap the zoomed element cleanly
                            if zoom > 1.01:
                                page.evaluate(
                                    "([z, ox, oy]) => window.__prEvidenceOverlay.setZoom(z, ox, oy, false)",
                                    [zoom, cx, cy],
                                )
                                page.wait_for_timeout(480)
                                zoomed_rect = _measure_box(page, str(target)) or rect
                                zcx = zoomed_rect["left"] + zoomed_rect["width"] / 2.0
                                zcy = zoomed_rect["top"] + zoomed_rect["height"] / 2.0
                                page.evaluate("([x, y]) => window.__prEvidenceOverlay.moveCursor(x, y)", [zcx, zcy])
                                page.evaluate(
                                    "([r, l, n, s]) => window.__prEvidenceOverlay.highlightRect(r, l, n, s)",
                                    [zoomed_rect, label, idx + 1, spotlight],
                                )
                            else:
                                page.evaluate(
                                    "([r, l, n, s]) => window.__prEvidenceOverlay.highlightRect(r, l, n, s)",
                                    [rect, label, idx + 1, spotlight],
                                )

                # Evaluate beat assertion against observed live state
                assertion = beat.get("assertion")
                if assertion:
                    passed, detail = _run_assertion(page, assertion, last_status)
                    assertion_desc = str(assertion.get("description") or detail)
                else:
                    passed, detail = True, "visual observation recorded"
                    assertion_desc = "Observed state"

                # Hold frame so beat duration matches the synthesized spoken narration cleanly
                spoken_sec = narration_durations[idx] if idx < len(narration_durations) else 3.5
                elapsed_in_beat = time.monotonic() - recording_started - beat_start
                remaining_sec = max(0.35, (spoken_sec + 0.45) - elapsed_in_beat)
                page.wait_for_timeout(int(remaining_sec * 1000))

                beat_end = round(time.monotonic() - recording_started, 3)
                beat_records.append(
                    BeatRecord(
                        index=idx,
                        acceptance_criterion=str(beat.get("acceptance_criterion", f"Criterion {idx + 1}")),
                        route=route,
                        start_seconds=beat_start,
                        end_seconds=beat_end,
                        narration=str(beat.get("narration", "")),
                        expected_result=str(beat.get("expected_result", "")),
                        assertion_description=assertion_desc,
                        passed=passed,
                        observed_detail=detail,
                        annotation_label=label,
                    )
                )

            page.evaluate("() => window.__prEvidenceOverlay.setZoom(1.0, 0, 0, false)")
            page.wait_for_timeout(250)
            total_duration = round(time.monotonic() - recording_started, 3)
            video_obj = page.video
        finally:
            try:
                context.tracing.stop(path=str(trace_path))
            except Exception:
                pass
            try:
                context.close()
            finally:
                browser.close()

        raw_video_path = output_dir / "raw_capture.webm"
        try:
            if video_obj is not None:
                recorded_path = Path(video_obj.path())
                shutil.copyfile(recorded_path, raw_video_path)
        finally:
            shutil.rmtree(raw_video_dir, ignore_errors=True)

    timeline_path = output_dir / "annotations.json"
    timeline_path.write_text(
        json.dumps([b.__dict__ for b in beat_records], indent=2) + "\n",
        encoding="utf-8",
    )

    return CaptureResult(
        raw_video_path=raw_video_path,
        trace_path=trace_path,
        beats=beat_records,
        console_errors=console_errors,
        page_errors=page_errors,
        total_duration_seconds=total_duration,
    )
