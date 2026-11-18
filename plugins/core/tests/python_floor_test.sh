#!/usr/bin/env bash
# python_floor_test.sh — the shipped scripts need Python >= 3.11 (tomllib).
#
# On an older python3 they used to die with an ImportError traceback, and
# claim_task.sh silently fell back to the default claim prefix, so two machines
# claimed under different refs. Both must now say what is wrong. An old python
# is simulated by making `import tomllib` fail through a python3 shim.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${HERE}/../skills/init/assets"
REAL_PY="$(command -v python3)"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "${tmp}/shim"
cat > "${tmp}/shim/python3" <<EOF2
#!/usr/bin/env bash
exec "${REAL_PY}" -c 'import runpy, sys; sys.modules["tomllib"] = None; f = sys.argv[1]; sys.argv = sys.argv[1:]; runpy.run_path(f, run_name="__main__")' "\$@"
EOF2
chmod +x "${tmp}/shim/python3"

for s in "${ASSETS}/scripts/arsenal_config.py" "${HERE}/../skills/init/scripts/init.py"; do
    out=$(PATH="${tmp}/shim:${PATH}" python3 "${s}" --help 2>&1) && fail "${s##*/} ran without tomllib"
    grep -q "needs Python >= 3.11" <<<"${out}" || fail "${s##*/} gave no clear message: ${out}"
    grep -q Traceback <<<"${out}" && fail "${s##*/} still dies with a traceback"
done

out=$(cd "${tmp}" && PATH="${tmp}/shim:${PATH}" bash "${ASSETS}/bin/claim_task.sh" t-x 2>&1); rc=$?
[[ ${rc} -eq 2 ]] || fail "claim_task.sh exit ${rc}, expected 2 on an unreadable claim-prefix: ${out}"
grep -q "cannot read claim-prefix" <<<"${out}" || fail "claim_task.sh did not say why: ${out}"

echo "PASS: an old python3 is named, not swallowed"
