#!/usr/bin/env bash
# SPDX-License-Identifier: MIT OR Apache-2.0
#
# End-to-end test of the generated install.sh: real downloads and installs of
# every tool it knows, then the failures it must report. install.sh itself is
# POSIX and runs with `sh`; this test is bash. Run by install-test.yml on
# macOS and Linux (and Alpine), and locally:
#
#   bin/tap site _site && bash test/installer.sh _site/install.sh
set -euo pipefail

script="${1:?usage: test/installer.sh path/to/install.sh}"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tools="$(sed -n 's/^# Tools: //p' "${script}" | tr ',' '\n' | awk '{print $1}')"
[[ -n "${tools}" ]] || fail "no tools listed in ${script}"
first="$(printf '%s\n' "${tools}" | head -n 1)"

musl=0
if ldd --version 2>&1 | grep -qi musl; then musl=1; fi

for tool in ${tools}
do
  printf '=== %s\n' "${tool}"
  if sh "${script}" --prefix "${work}/p" "${tool}" 2>"${work}/err"
  then
    continue
  fi
  # On musl a glibc-only build must be refused cleanly, nothing left behind.
  if [[ "${musl}" -eq 1 ]] && grep -q 'needs glibc' "${work}/err"
  then
    printf 'refused on musl as expected: %s\n' "${tool}"
    continue
  fi
  fail "install of ${tool}: $(cat "${work}/err")"
done
for binary in "${work}"/p/bin/*
do
  "${binary}" --version >/dev/null 2>&1 || "${binary}" version >/dev/null 2>&1 || fail "${binary} does not run"
  printf 'runs: %s\n' "${binary##*/}"
done

printf '=== a tampered SHA-256 is refused\n'
sed 's/^\(      sha256=\)[0-9a-f]/\10/' "${script}" >"${work}/tampered.sh"
if sh "${work}/tampered.sh" --prefix "${work}/q" "${first}" 2>"${work}/err"; then fail "tampered archive installed"; fi
grep -q 'SHA-256 mismatch' "${work}/err" || fail "unexpected error: $(cat "${work}/err")"

printf '=== --require-provenance without a logged-in gh is refused\n'
if env PATH=/usr/bin:/bin sh "${script}" --prefix "${work}/q" --require-provenance "${first}" 2>"${work}/err"
then
  fail "installed without provenance"
fi
grep -q 'provenance' "${work}/err" || fail "unexpected error: $(cat "${work}/err")"

printf '=== an unknown tool is refused\n'
if sh "${script}" nope 2>"${work}/err"; then fail "unknown tool accepted"; fi
grep -q 'no nope for' "${work}/err" || fail "unexpected error: $(cat "${work}/err")"

printf 'installer: all checks passed\n'
