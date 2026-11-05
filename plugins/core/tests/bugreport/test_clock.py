"""Clock derivation and `timeline --since`: § 5.5."""

from __future__ import annotations

import datetime as dt
import re

import _brlib as br


def _tl(cli, path, *argv):
    return cli("query_bugreport", "timeline", "--input", str(path), *argv)


def test_alarm_dump_offset_converts_kernel_time_to_local(fx, built, tmp_path):
    rpt = br.open_report(built("modern"), output_dir=tmp_path)
    assert rpt.clock["source"] == "alarm" and rpt.clock["utc_offset_s"] == fx.UTC_OFFSET_S
    marker = next(e for e in rpt.events() if "lowmemorykiller" in e["text"])
    assert br.fmt_ts(marker["t"]) == fx.facts("modern")["kernel_marker_local"]


def test_suspend_anchor_keeps_kernel_time_right_after_sleep(fx, built, tmp_path):
    """dmesg seconds stop while suspended: shift them back by a sleep and add the
    kernel's `PM: suspend exit` wall-clock line, and the marker must not move."""
    sleep_s = 5 * 3600
    local = dt.datetime.fromisoformat(fx.facts("modern")["kernel_marker_local"])
    utc = local - dt.timedelta(seconds=fx.UTC_OFFSET_S)

    def shift(m: re.Match[str]) -> str:
        line = f"<6>[{float(m.group(1)) - sleep_s:12.6f}]{m.group(2)}"
        if "lowmemorykiller" not in line:
            return line
        anchor = f"<6>[{float(m.group(1)) - sleep_s:12.6f}] PM: suspend exit {utc:%F %T.%f}123 UTC"
        return f"{line}\n{anchor}"

    path = tmp_path / "slept.txt"
    path.write_text(
        re.sub(r"^<6>\[\s*(\d+\.\d+)\](.*)$", shift, built("modern").read_text(), flags=re.M)
    )
    rpt = br.open_report(path, output_dir=tmp_path)
    marker = next(e for e in rpt.events() if "lowmemorykiller" in e["text"])
    assert br.fmt_ts(marker["t"]) == fx.facts("modern")["kernel_marker_local"]


def test_since_matching_two_dates_exits_2_listing_both(built, cli):
    code, _, err = _tl(cli, built(scenarios=("multi-day",)), "--since", "13:30")
    assert code == 2
    assert "2026-11-02 13:30" in err and "2026-11-03 13:30" in err


def test_date_qualified_since_resolves_the_ambiguity(built, cli):
    code, doc, _ = _tl(
        cli, built(scenarios=("multi-day",)), "--since", "2026-11-02 13:30", "--window", "1h"
    )
    assert code == 0 and doc["since"].startswith("2026-11-02 13:30")


def test_december_logs_in_january_report_get_previous_year(fx, built, tmp_path):
    rpt = br.open_report(built(scenarios=("new-year",)), output_dir=tmp_path)
    first = rpt.coverage(("SYSTEM LOG",))[0]
    assert first.year == 2026 and first.month == 12
    assert br.fmt_ts(first) == fx.facts("modern", ("new-year",))["bounds"]["SYSTEM LOG"][0]


def test_no_offset_source_marks_rows_elapsed(built, cli):
    code, doc, err = _tl(cli, built(scenarios=("no-clock",)), "--since", "14:10", "--window", "1m")
    assert code == 0 and doc["clock"] == "none"
    kernel = [r for r in doc["rows"] if r["src"] == "KERNEL LOG"]
    assert kernel and all(r["t"] is None and r["clock"] == "elapsed" for r in kernel)
    assert "no local time" in err


def test_since_outside_span_exits_1(built, cli):
    for since in ("02:00", "2026-11-04 10:00"):
        code, _, err = _tl(cli, built(), "--since", since)
        assert code == 1 and "outside report span" in err and "2026-11-03 13:00" in err


def test_since_empty_window_exits_0(fx, built, cli):
    # the generator leaves [capture - 22m05s, capture - 17m05s) without log lines
    quiet = dt.datetime(2026, 11, 3, 14, 22, 5) - fx.QUIET[0]
    code, doc, _ = _tl(cli, built(), "--since", f"{quiet:%H:%M:%S}", "--window", "4m")
    assert code == 0 and doc["rows"] == [] and doc["truncated"] is False


def test_relative_since_counts_back_from_capture(built, cli):
    code, doc, _ = _tl(cli, built(), "--since", "-30m")
    assert code == 0 and doc["since"] == "2026-11-03 13:52:05.000"


def test_bad_since_and_window_exit_2(built, cli):
    assert _tl(cli, built(), "--since", "yesterday")[0] == 2
    assert _tl(cli, built(), "--since", "14:00", "--window", "5 minutes")[0] == 2


def test_dst_fold_notes_first_occurrence(cli, capsys):
    import query_bugreport as q

    q._fold_note(dt.datetime(2026, 10, 25, 2, 30), "Europe/Berlin")
    assert "DST fold" in capsys.readouterr().err
