"""The sibling scripts must not drift apart.

Spec § 5.2 asks for consistency across six scripts as a *contract* rather than
a convention, on the grounds that divergent flag sets are the most likely way
for this toolkit to become annoying. A convention is a thing people mean; a
contract is a thing a test fails on.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"

# Every command that selects entries out of a capture. `run_har.py` joins this
# list when it is built, which is the point of the shared module.
SELECTORS = ("query_har.py", "create_har.py", "compare_har.py")
ALL_COMMANDS = (
    "analyze_har.py",
    "query_har.py",
    "validate_har.py",
    "create_repro.py",
    "create_har.py",
    "compare_har.py",
)


def _flags(script: str) -> set[str]:
    """Every long option a script's parser accepts, taken from the parser itself."""
    spec = importlib.util.spec_from_file_location(f"_parity_{script}", SCRIPTS / script)
    module = importlib.util.module_from_spec(spec)
    sys.modules[f"_parity_{script}"] = module
    spec.loader.exec_module(module)

    captured: dict[str, argparse.ArgumentParser] = {}
    real_parse = argparse.ArgumentParser.parse_args

    def capture(self, *args, **kwargs):
        captured["parser"] = self
        raise SystemExit(0)

    argparse.ArgumentParser.parse_args = capture  # type: ignore[method-assign]
    try:
        with pytest.raises(SystemExit):
            module.main([])
    finally:
        argparse.ArgumentParser.parse_args = real_parse  # type: ignore[method-assign]

    parser = captured["parser"]
    return {
        option
        for action in parser._actions
        for option in action.option_strings
        if option.startswith("--")
    }


SELECTION_FLAGS = {
    "--url", "--host", "--method", "--status", "--mime", "--type",
    "--min-size", "--max-size", "--slower-than", "--has-header", "--param",
    "--page", "--since", "--until",
    "--from-cache", "--no-cache", "--unknown-cache", "--invert",
}


@pytest.mark.parametrize("script", SELECTORS)
def test_sibling_scripts_expose_identical_selection_flags(script):
    """The gate: `shared_flag_parity_failures == 0`."""
    flags = _flags(script)
    missing = sorted(SELECTION_FLAGS - flags)
    assert missing == [], f"{script} is missing shared selection flags: {missing}"


def test_every_command_takes_input_and_json():
    """The canonical names mean the same thing here as in every other arsenal script."""
    for script in ALL_COMMANDS:
        flags = _flags(script)
        assert "--input" in flags, f"{script} does not take --input"
        assert "--json" in flags, f"{script} cannot be chained with --json"


def test_output_bearing_commands_take_output_and_limit():
    for script in ("query_har.py", "analyze_har.py", "compare_har.py"):
        flags = _flags(script)
        assert "--limit" in flags, f"{script} has no --limit"
        assert "--output" in flags, f"{script} has no --output escape"


def test_compare_refuses_body_filters_rather_than_running_slowly(scratch):
    """A comparison selects on metadata so it stays flat in the captures' body bytes."""
    import io
    from contextlib import redirect_stderr

    module = sys.modules["_parity_compare_har.py"]
    err = io.StringIO()
    with redirect_stderr(err):
        code = module.main(
            [
                "--input", str(scratch / "compare_a.har"),
                "--against", str(scratch / "compare_b.har"),
                "--response-match", "anything",
            ]
        )
    assert code == 2
    assert "body filters are not supported" in err.getvalue()
