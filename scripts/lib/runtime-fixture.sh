#!/usr/bin/env bash
#
# runtime-fixture.sh — build test fixtures that reproduce the PRODUCTION runtime.
#
# WHY THIS EXISTS (issue #33, verification.md catch 5a)
#
# Every fixture in this repo was built with `mktemp -d`, which returns an MSYS path
# (`/tmp/...`) with LF line endings and permissive path semantics. Every real
# project lives on a UNC path (`//wsl.localhost/...`) with CRLF checkouts and a
# Windows git index. Those are different runtimes, and four defects have now been
# found that exist only in the second one:
#
#   - `mkdir -p` on an absolute UNC path fails — bootstrap could not touch any real
#     project while passing its entire suite
#   - `chmod` never reaches the git index over UNC — guards shipped inert, twice
#   - a `\n`-delimited search never matched a CRLF file — the catch-log generator
#     silently shipped the wrong content
#   - a shallow clone made a guard's diff fail into an empty "nothing changed"
#
# Each was invisible because the tests ran somewhere the hazard does not exist.
# Promoting a principle did not stop the next one; a fixture that matches
# production can.
#
# THE ONE RULE FOR THIS FILE: a fixture that silently degrades to /tmp is worse
# than no fixture, because every suite using it would report green while testing
# the same runtime it always did. So `runtime_mktemp_d` FAILS LOUDLY rather than
# falling back — see the note there. That is catch 2a applied to the test tier
# itself.
#
# Usage:
#   source scripts/lib/runtime-fixture.sh
#   d="$(runtime_mktemp_d)" || exit 1
#   trap 'runtime_fixture_cleanup "$d"' EXIT

# WHICH runtime is "production"? There are two, and that ambiguity broke CI on this
# file's first push.
#
# Development happens on Windows/MSYS over a UNC checkout, where the hazards live.
# CI runs on ubuntu-latest, where UNC paths do not exist and `mkdir -p` on an
# absolute path works perfectly. Assertions that encode the Windows hazards are
# therefore FALSE on Linux — not because the code regressed, but because that
# runtime cannot exhibit them.
#
# So the tier detects its environment and the UNC-specific assertions SKIP LOUDLY
# where the hazard cannot exist. Loudly, never silently: a silent skip would let CI
# report coverage it does not have, which is the fail-open this whole tier exists
# to prevent. The honest position is that these hazards are covered on the
# development machine and structurally uncoverable in Linux CI.
runtime_fixture_is_unc() {
  case "$(runtime_fixture_root)" in
    //*) return 0 ;;
    *)   return 1 ;;
  esac
}

# The production path shape. Derived from this repo's own location rather than
# hardcoded, so the helper follows the checkout instead of asserting a machine.
runtime_fixture_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"   # repo root
  # Fixtures live beside the repo, never inside it: a fixture under the repo would
  # be picked up by test discovery, linting, and the exec-bit assertion.
  printf '%s' "$(dirname "$here")"
}

# runtime_mktemp_d [prefix]
#
# Creates a throwaway directory under the production root and echoes its path.
#
# Deliberately does NOT fall back to `mktemp -d` when the root is unavailable. A
# fallback would hand back an MSYS path, every assertion would still pass, and the
# suite would silently stop testing the runtime it was written to test — a
# fail-open in the test tier. Returns non-zero instead, so the caller stops.
runtime_mktemp_d() {
  local prefix="${1:-runtime-fixture}"
  local root dir
  root="$(runtime_fixture_root)"

  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "runtime_mktemp_d: production root '$root' unavailable — refusing to fall back to /tmp." >&2
    echo "runtime_mktemp_d: a /tmp fixture would pass every assertion while testing the wrong runtime." >&2
    return 1
  fi

  dir="$root/.$prefix-$$-${RANDOM}"
  # Created relative, from inside the root: `mkdir -p` on an absolute UNC path is
  # exactly the hazard this fixture exists to reproduce, so it cannot be used here.
  ( cd "$root" || exit 1; mkdir -p "$(basename "$dir")" ) || {
    echo "runtime_mktemp_d: could not create fixture under '$root'." >&2
    return 1
  }

  [ -d "$dir" ] || { echo "runtime_mktemp_d: fixture '$dir' not present after creation." >&2; return 1; }
  printf '%s' "$dir"
}

# runtime_write_crlf <path> [line ...]
#
# Writes the given lines with CRLF endings. The catch-log generator shipped the
# wrong content for want of exactly this: its search assumed LF, the file was CRLF,
# and the mismatch failed silently and looked plausible.
runtime_write_crlf() {
  local path="$1"; shift
  : > "$path"
  local line
  for line in "$@"; do
    printf '%s\r\n' "$line" >> "$path"
  done
}

# runtime_fixture_cleanup <dir>
#
# Removes a fixture. Refuses anything that is not under the production root, so a
# bad variable cannot turn cleanup into a destructive `rm -rf` somewhere real.
runtime_fixture_cleanup() {
  local dir="$1" root
  [ -z "$dir" ] && return 0
  root="$(runtime_fixture_root)"
  case "$dir" in
    "$root"/.*) rm -rf "$dir" ;;
    *) echo "runtime_fixture_cleanup: refusing to remove '$dir' — not a fixture under '$root'." >&2; return 1 ;;
  esac
}
