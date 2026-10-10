"""Compose the README's hero image — an engineering sheet for the marketplace.

Not shipped code. Writes docs/hero.svg, then rasterises it to docs/hero.png
with a headless Chromium (the README shows the PNG: GitHub's `<img>` view of an
SVG loads no fonts, so the PNG is what keeps the faces). Needs the Inter and
DejaVu Sans Mono fonts installed for the PNG to match, and Pillow to crop.

The sheet deliberately carries no version, skill count or rubric size: a PNG
cannot follow the repo, so anything that changes on a release stays off it.

Usage, from the repository root:

    python3 tools/hero.py                    # write docs/hero.svg and docs/hero.png
    CHROMIUM=/path/to/chrome python3 tools/hero.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
OUT_SVG = ROOT / "docs" / "hero.svg"
OUT_PNG = ROOT / "docs" / "hero.png"

#: The GitHub social-preview size, which the README shows scaled to its column.
W, H = 1280, 640

GROUND = "#16181d"
GRID = "#22252c"
LINE = "#3a3f4a"
INK = "#e9e4da"
DIM = "#8a8f99"
ACCENT = "#e07a45"  # warm, Claude-adjacent orange
GREEN = "#7fbf7f"
RED = "#e06c6c"
SANS = "Inter, 'DejaVu Sans', sans-serif"
DISPLAY = "'Inter Display', Inter, sans-serif"
MONO = "'DejaVu Sans Mono', monospace"


PIPELINE = [
    ("explore-idea", "idea.md"),
    ("specify", "specification.md"),
    ("design", "design.md"),
    ("execution", "RED → GREEN → RECORD"),
    ("review", "findings, fixed"),
    ("ship", "PR · tag · changelog"),
]


def text(
    x: float,
    y: float,
    s: str,
    *,
    size: int,
    fill: str = INK,
    family: str = SANS,
    weight: int = 400,
    anchor: str = "start",
    spacing: float = 0,
) -> str:
    return (
        f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
        f'letter-spacing="{spacing}" xml:space="preserve">{escape(s)}</text>'
    )


def sheet() -> list[str]:
    """Grid, border with zone marks, registration marks — the drawspec family."""
    out = [f'<rect width="{W}" height="{H}" fill="{GROUND}"/>']
    for x in range(0, W, 20):
        out.append(
            f'<line x1="{x}" y1="0" x2="{x}" y2="{H}" stroke="{GRID}" '
            f'stroke-width="{1 if x % 100 == 0 else 0.4}"/>'
        )
    for y in range(0, H, 20):
        out.append(
            f'<line x1="0" y1="{y}" x2="{W}" y2="{y}" stroke="{GRID}" '
            f'stroke-width="{1 if y % 100 == 0 else 0.4}"/>'
        )
    out.append(
        f'<rect x="16" y="16" width="{W - 32}" height="{H - 32}" fill="none" '
        f'stroke="{LINE}" stroke-width="1"/>'
    )
    out.append(
        f'<rect x="30" y="30" width="{W - 60}" height="{H - 60}" fill="none" '
        f'stroke="{DIM}" stroke-width="1.5"/>'
    )
    zw = (W - 60) / 8
    for i in range(8):
        x = 30 + zw * i
        if i:
            out += [
                f'<line x1="{x}" y1="16" x2="{x}" y2="30" stroke="{LINE}"/>',
                f'<line x1="{x}" y1="{H - 30}" x2="{x}" y2="{H - 16}" stroke="{LINE}"/>',
            ]
        for y in (27, H - 19):
            out.append(
                text(x + zw / 2, y, str(8 - i), size=9, fill=DIM, family=MONO, anchor="middle")
            )
    zh = (H - 60) / 4
    for i in range(4):
        y = 30 + zh * i
        if i:
            out += [
                f'<line x1="16" y1="{y}" x2="30" y2="{y}" stroke="{LINE}"/>',
                f'<line x1="{W - 30}" y1="{y}" x2="{W - 16}" y2="{y}" stroke="{LINE}"/>',
            ]
        for x in (23, W - 23):
            out.append(
                text(x, y + zh / 2 + 3, "ABCD"[i], size=9, fill=DIM, family=MONO, anchor="middle")
            )
    for cx, cy in ((48, 48), (48, H - 48)):
        out += [
            f'<circle cx="{cx}" cy="{cy}" r="7" fill="none" stroke="{ACCENT}"/>',
            f'<line x1="{cx - 11}" y1="{cy}" x2="{cx + 11}" y2="{cy}" stroke="{ACCENT}"/>',
            f'<line x1="{cx}" y1="{cy - 11}" x2="{cx}" y2="{cy + 11}" stroke="{ACCENT}"/>',
        ]
    return out


LOGO_SIZE = 88  # the tile's height, standing on the wordmark's baseline
LOGO_GAP = 20


def logo() -> str:
    """The approved logo (docs/logo.svg), nested so the hero stays generated from it."""
    src = (ROOT / "docs" / "logo.svg").read_text().strip()
    inner = src[src.index(">") + 1 : src.rindex("</svg>")]
    return (
        f'<svg x="64" y="{160 - LOGO_SIZE}" width="{LOGO_SIZE}" height="{LOGO_SIZE}" '
        f'viewBox="0 0 64 64">{inner}</svg>'
    )


def wordmark() -> list[str]:
    return [
        logo(),
        f'<text x="{64 + LOGO_SIZE + LOGO_GAP}" y="160" font-family="{DISPLAY}" '
        f'font-size="104" font-weight="800" letter-spacing="-3"><tspan fill="{INK}">claude</tspan>'
        f'<tspan fill="{ACCENT}">-arsenal</tspan></text>',
        text(68, 210, "Make the agent work like an engineer.", size=27, fill="#b9c0cc"),
        text(
            68,
            244,
            "Specs before code · failing tests first · gates with numbers",
            size=17,
            fill=DIM,
        ),
    ]


def terminal() -> list[str]:
    x, y, w, h = 64, 284, 520, 236
    lines = [
        ("$ ", "/plugin marketplace add github:nuncaeslupus/claude-arsenal", INK),
        ("$ ", "/plugin install core@claude-arsenal", INK),
        ("$ ", "/init", INK),
        ("", "", INK),
        ("$ ", "/gate-check T-014", INK),
        ("  ", "RED    pytest -k cache_hit   fails: expected", RED),
        ("  ", "GREEN  pytest -k cache_hit   1 passed", GREEN),
        ("  ", "RECORD p95 41 ms ≤ 50 ms     committed", ACCENT),
    ]
    out = [
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="#0f1114" stroke="{LINE}"/>',
        f'<line x1="{x}" y1="{y + 26}" x2="{x + w}" y2="{y + 26}" stroke="{LINE}"/>',
    ]
    for i, c in enumerate((RED, "#e0b44f", GREEN)):
        out.append(
            f'<circle cx="{x + 16 + i * 16}" cy="{y + 13}" r="4.5" fill="{c}" opacity="0.8"/>'
        )
    out.append(
        text(
            x + w / 2, y + 17, "claude — your repo", size=11, fill=DIM, family=MONO, anchor="middle"
        )
    )
    for i, (prompt, body, color) in enumerate(lines):
        ty = y + 54 + i * 22
        out.append(
            f'<text x="{x + 16}" y="{ty}" font-family="{MONO}" font-size="13" '
            f'xml:space="preserve">'
            f'<tspan fill="{ACCENT}">{escape(prompt)}</tspan>'
            f'<tspan fill="{color}">{escape(body)}</tspan></text>'
        )
    return out


def rack() -> list[str]:
    """The three plugins as cartridges in a rack."""
    x, y = 612, 284  # rack column, left of the gate callout
    items = [
        ("core", "spec-driven skills · task queue"),
        ("skill-workshop", "rubric · validator · edit hook"),
        ("repo-audit", "explain · audit a repo"),
    ]
    out = [text(x, y - 10, "PLUGINS", size=10, fill=ACCENT, family=MONO, spacing=2)]
    for i, (name, sub) in enumerate(items):
        cy = y + i * 80
        out += [
            f'<rect x="{x}" y="{cy}" width="212" height="68" rx="4" fill="#1d2027" '
            f'stroke="{LINE}"/>',
            f'<rect x="{x}" y="{cy}" width="5" height="68" rx="2" fill="{ACCENT}"/>',
            text(x + 20, cy + 30, name, size=18, weight=600),
            text(x + 20, cy + 52, sub, size=12, fill=DIM),
        ]
    return out


def pipeline() -> list[str]:
    x, y, w, bh, gap = 900, 62, 300, 52, 26
    out = [
        text(x, y - 12 + 2, "SPEC-DRIVEN PIPELINE", size=10, fill=ACCENT, family=MONO, spacing=2)
    ]
    for i, (name, doc) in enumerate(PIPELINE):
        by = y + 8 + i * (bh + gap)
        gate = name == "execution"
        out += [
            f'<rect x="{x}" y="{by}" width="{w}" height="{bh}" rx="{bh / 2 if i in (0, 5) else 4}" '
            f'fill="{"#2a1f19" if gate else "#1d2027"}" '
            f'stroke="{ACCENT if gate else "#5a606c"}" stroke-width="{1.6 if gate else 1}"/>',
            text(x + 22, by + 32, name, size=17, weight=600, family=MONO),
            text(
                x + w - 18,
                by + 32,
                doc,
                size=12,
                fill=ACCENT if gate else DIM,
                anchor="end",
                family=MONO,
            ),
        ]
        if i < len(PIPELINE) - 1:
            ay = by + bh
            out += [
                f'<line x1="{x + w / 2}" y1="{ay}" x2="{x + w / 2}" y2="{ay + gap - 6}" '
                f'stroke="{DIM}" stroke-width="1.4"/>',
                f'<path d="M{x + w / 2 - 5},{ay + gap - 8} L{x + w / 2},{ay + gap - 1} '
                f'L{x + w / 2 + 5},{ay + gap - 8}" fill="none" stroke="{DIM}" '
                f'stroke-width="1.4"/>',
            ]
    # The gate callout: the acceptance gate is a fenced block a script runs.
    gy = y + 8 + 3 * (bh + gap) + bh / 2
    out += [
        f'<path d="M{x},{gy} L{x - 52},{gy}" stroke="{ACCENT}" stroke-dasharray="4 3"/>',
        f'<circle cx="{x}" cy="{gy}" r="3" fill="{ACCENT}"/>',
        text(x - 26, gy - 7, "gate", size=11, fill=ACCENT, family=MONO, anchor="middle"),
    ]
    return out


def title_block() -> list[str]:
    x, y, w, h = 612, 528, 586, 64
    cells = [
        (0, 200, "PROJECT", "claude-arsenal"),
        (200, 240, "SHEET", "Claude Code marketplace"),
        (440, 146, "LICENSE", "MIT"),
    ]
    out = [
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{GROUND}" stroke="{DIM}" '
        f'stroke-width="1.2"/>'
    ]
    for cx, _cw, label, value in cells:
        if cx:
            out.append(f'<line x1="{x + cx}" y1="{y}" x2="{x + cx}" y2="{y + h}" stroke="{DIM}"/>')
        out.append(text(x + cx + 10, y + 18, label, size=9, fill=DIM, family=MONO, spacing=1.5))
        big = label == "PROJECT"
        out.append(
            text(
                x + cx + 10,
                y + 46,
                value,
                size=19 if big else 12,
                weight=700 if big else 400,
                family=MONO,
                fill=INK,
            )
        )
    return out


def svg() -> str:
    parts = sheet() + wordmark() + terminal() + rack() + pipeline() + title_block()
    body = "\n  ".join(parts)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">\n  {body}\n</svg>\n'
    )


def chromium() -> str:
    for c in (
        os.environ.get("CHROMIUM"),
        "/opt/pw-browsers/chromium",
        shutil.which("chromium"),
        shutil.which("google-chrome"),
    ):
        if c and Path(c).exists():
            return c
    sys.exit("hero: no Chromium found; set CHROMIUM=/path/to/chrome")


def main() -> None:
    OUT_SVG.write_text(svg())
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "hero.html"
        page.write_text(f'<html><body style="margin:0">{svg()}</body></html>')
        subprocess.run(
            [
                chromium(),
                "--headless=new",
                "--no-sandbox",
                "--force-device-scale-factor=2",
                "--hide-scrollbars",
                f"--window-size={W},{H + 200}",
                f"--screenshot={OUT_PNG}",
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
    # Headless Chromium's viewport is shorter than its window; shoot tall, crop.
    from PIL import Image

    with Image.open(OUT_PNG) as shot:
        shot.crop((0, 0, W * 2, H * 2)).save(OUT_PNG, optimize=True)
    print(f"wrote {OUT_SVG.relative_to(ROOT)} and {OUT_PNG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
