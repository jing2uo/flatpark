#!/usr/bin/env bash
# Dependency-free assertion helpers. Each asserts or exits non-zero.
assert_eq()       { [ "$1" = "$2" ]            || { echo "FAIL assert_eq: got [$1] want [$2]"; exit 1; }; }
assert_file()     { [ -f "$1" ]                || { echo "FAIL assert_file: missing $1"; exit 1; }; }
assert_contains() { grep -qF -- "$2" "$1"      || { echo "FAIL assert_contains: $1 lacks [$2]"; exit 1; }; }
assert_ok()       { "$@"                        || { echo "FAIL assert_ok: $*"; exit 1; }; }
