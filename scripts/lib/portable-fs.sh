#!/usr/bin/env bash
#
# portable-fs.sh — filesystem helpers that survive this repo's actual runtime.
#
# WHY THIS EXISTS
#
# Every project here lives on a UNC path (`//wsl.localhost/ubuntu/home/...`), and
# MSYS `mkdir -p` cannot be given one:
#
#   $ mkdir -p //wsl.localhost/ubuntu/home/thomas/projects/jobs-radar/.claude
#   mkdir: cannot create directory '//wsl.localhost': Read-only file system
#
# It walks up the path and tries to create the share root, and it does this even
# when the target directory ALREADY EXISTS — so it is not a "create missing parents"
# problem, it is unusable on absolute UNC paths altogether.
#
# This went unnoticed because every test fixture uses `mktemp -d`, which returns an
# MSYS path (`/tmp/...`) where `mkdir -p` is fine. So the whole bootstrap passed its
# entire suite while being broken for every real target. A test that only ever
# exercises a synthetic path verifies a path production never takes —
# verification.md catch 5, at the level of the fixture rather than the invocation.
#
# The fix is to `cd` into a known-existing root and create RELATIVE paths from
# there, which MSYS handles correctly.

# ensure_dir <root> <relative-path>
#
# Creates <root>/<relative-path>, UNC-safe. <root> must already exist. A
# <relative-path> of "." or "" is a no-op success.
#
# Guards the cd explicitly rather than relying on `set -e`: a bare `cd` failure does
# not reliably abort, and a silently-failed cd would create the directory tree in
# whatever directory the script happened to be in (verification.md catch 6).
ensure_dir() {
  local root="$1" rel="$2"
  [ -z "$rel" ] && return 0
  [ "$rel" = "." ] && return 0
  ( cd "$root" || exit 1; mkdir -p "$rel" ) || return 1
  return 0
}
