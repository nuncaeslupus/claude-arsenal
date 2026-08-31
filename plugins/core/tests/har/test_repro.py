"""A generated reproduction must run the request the capture contains — nothing else.

This is the command whose output an operator pastes into their own shell, built
from a document that came off the network. A generated command that executes
something the capture did not contain is the worst bug available here, so the
tests parse the emitted text the way a shell would rather than grepping it.
"""

from __future__ import annotations

import shlex

import pytest


@pytest.fixture
def repro(scratch):
    import importlib.util
    import io
    import sys
    from contextlib import redirect_stderr, redirect_stdout
    from pathlib import Path

    scripts = Path(__file__).resolve().parent.parent.parent / "skills" / "har" / "scripts"
    spec = importlib.util.spec_from_file_location("_har_repro", scripts / "create_repro.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules["_har_repro"] = module
    spec.loader.exec_module(module)

    def run(fixture: str, *args: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = module.main(["--input", str(scratch / f"{fixture}.har"), *args])
        return code, out.getvalue(), err.getvalue()

    return run


def _argv(curl_text: str) -> list[str]:
    """Parse the generated command the way a shell would, so quoting is really tested."""
    command = "\n".join(
        line for line in curl_text.splitlines() if line and not line.startswith("#")
    )
    return shlex.split(command.replace("\\\n", " "))


def test_repro_curl_shell_metacharacters_stay_data(repro):
    """The gate: `adversarial_repro_shell_executions == 0`.

    The hostile fixture carries a header value of `'; rm -rf / #`. After
    parsing, it has to come back as one argument with that exact text — not as
    a command separator, and not truncated at the `#`.
    """
    code, out, _ = repro("hostile", "--id", "2", "--format", "curl")
    assert code == 0

    argv = _argv(out)
    assert argv[0] == "curl"
    header = next(
        argv[i + 1] for i, tok in enumerate(argv) if tok == "-H" and "x-note" in argv[i + 1]
    )
    assert header == "x-note: '; rm -rf / #", (
        f"the header value did not survive quoting: {header!r}"
    )
    assert ";" not in " ".join(t for t in argv if not t.startswith("x-note")), (
        "a shell operator escaped into the command"
    )


def test_repro_curl_body_starting_with_at_is_data_not_file(repro):
    """`--data @file` reads a local file. `--data-raw` does not, and is what is emitted."""
    code, out, _ = repro("hostile", "--id", "2", "--format", "curl")
    assert code == 0
    assert "--data-raw" in out
    assert " --data " not in out and " -d " not in out

    argv = _argv(out)
    body = argv[argv.index("--data-raw") + 1]
    assert body == "@/etc/passwd", "the body was not passed through verbatim"


def test_repro_quotes_every_argument_even_when_it_need_not(repro):
    """Uniform quoting removes the class rather than the instance.

    A bare `@/etc/passwd` is safe as emitted and becomes a file read the moment
    someone edits `--data-raw` into `--data`.
    """
    code, out, _ = repro("basic", "--id", "2", "--format", "curl")
    assert code == 0
    body_lines = [
        line.strip()
        for line in out.splitlines()
        if line.strip().startswith(("curl", "-H"))
    ]
    for line in body_lines:
        argument = line.split(" ", 1)[1] if line.startswith("curl") else line[3:]
        assert argument.startswith("'"), f"unquoted argument in the generated command: {line}"


def test_repro_python_uses_repr_not_concatenation(repro):
    """`repr()` is what makes a captured quote a quote instead of a syntax error."""
    code, out, _ = repro("hostile", "--id", "2", "--format", "python")
    assert code == 0
    assert '"\'; rm -rf / #"' in out, "the adversarial header was not repr()'d"
    compile(out, "<repro>", "exec")  # it has to be valid Python, not just plausible


def test_repro_redacts_by_default_and_says_so(repro):
    code, out, _ = repro("basic", "--id", "2", "--format", "curl")
    assert code == 0
    assert "live-token-aaaa" not in out
    assert "<redacted:" in out
    assert "--secrets" in out, "a redacted reproduction must say how to get a working one"


def test_secrets_restores_the_real_credential_and_the_userinfo(repro):
    """Reproducing a login needs the real Cookie and Authorization — that is the point."""
    code, out, _ = repro("basic", "--id", "2", "--format", "curl", "--secrets")
    assert code == 0
    assert "live-token-aaaa" in out
    assert "<redacted:" not in out

    code, hostile, _ = repro("hostile", "--id", "3", "--format", "curl", "--secrets")
    assert code == 0
    assert "hunter2" in hostile, "--secrets must restore userinfo where a reproduction needs it"

    code, safe, _ = repro("hostile", "--id", "3", "--format", "curl")
    assert code == 0
    assert "hunter2" not in safe


def test_repro_omits_headers_a_client_sets_for_itself(repro):
    """A stale `Content-Length` breaks the first edit anyone makes to a reproduction."""
    code, out, _ = repro("basic", "--id", "2", "--format", "curl")
    assert code == 0
    assert "content-length" not in out.lower()
    assert "host:" not in out.lower()


def test_an_out_of_range_id_is_a_usage_error(repro):
    code, _, err = repro("basic", "--id", "999", "--format", "curl")
    assert code == 2
    assert "no entry 999" in err
