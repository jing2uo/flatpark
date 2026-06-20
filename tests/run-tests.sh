#!/usr/bin/env bash
# Run every tests/test_*.sh; report pass/fail; exit non-zero on any failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
for t in "$ROOT"/tests/test_*.sh; do
    name="$(basename "$t")"
    if bash "$t"; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
done
exit "$fail"
