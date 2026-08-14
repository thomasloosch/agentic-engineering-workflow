#!/usr/bin/env bash
#
# json-extract.sh — zero-dependency extraction of a top-level-ish JSON string
# value, for the Claude Code lifecycle hooks.
#
# WHY THIS EXISTS
#
# The four blocking/warning hooks parsed their stdin payload with `jq`. `jq` is
# not present in this MINGW runtime, and every one of them ran under
# `set -euo pipefail`, so the very first extraction line exited 127 — before any
# of the hook's own logic. Claude Code treats exit 2 as "block" and every other
# non-zero as a non-blocking error, so those hooks were not merely broken: they
# FAILED OPEN. `git add -A` sailed through a guard that existed to stop it, and
# nothing reported a problem. Same class as #16's manifest defect
# (`fail-open-guard`), one layer out.
#
# Rather than add a `jq` dependency to a guard whose entire job is to work
# reliably on this machine, extraction is done here with shell builtins and sed —
# matching the ethos of hooks/git/pre-commit, which deliberately depends on
# nothing but git and coreutils.
#
# Sourced by four hooks. That is well past Rule 7's rule-of-three, and the
# SSOT argument applies regardless: the fail-closed semantics below are a
# security property, and four hand-copied versions of a security property drift.

# json_string_value <key> <payload>
#
# Echoes the string value of "<key>": "..." from <payload>, with JSON escapes
# resolved. Returns 0 on a successful extraction, 1 if the key is absent or the
# value could not be parsed.
#
# Deliberately NOT a general JSON parser. It handles the one shape these hooks
# receive — a flat-ish object whose relevant values are strings — and reports
# failure rather than guessing when the input does not match. Callers must treat
# a non-zero return as "I do not know what this payload says", never as "the
# field was empty" (see json_extract_or_fail_closed below).
json_string_value() {
  local key="$1" payload="$2" raw

  # Match "key" : "value", where value is any run of non-quote/non-backslash
  # characters and backslash-escaped pairs. The escape-pair alternative is what
  # stops the match ending early on an escaped quote inside the value.
  raw="$(printf '%s' "$payload" | sed -n \
    "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\(\([^\"\\\\]\|\\\\.\)*\)\".*/\1/p")"

  # No match at all: sed printed nothing.
  if [ -z "$raw" ]; then
    # Distinguish "key absent" from "key present with an empty value". Only the
    # latter is a successful extraction of an empty string.
    if printf '%s' "$payload" | grep -q "\"${key}\"[[:space:]]*:[[:space:]]*\"\""; then
      printf '%s' ""
      return 0
    fi
    return 1
  fi

  # Resolve the escapes we can legitimately see in a shell command string.
  # Order matters: \\ last, or it would corrupt the sequences unescaped before it.
  raw="${raw//\\\"/\"}"
  raw="${raw//\\n/$'\n'}"
  raw="${raw//\\t/$'\t'}"
  raw="${raw//\\r/$'\r'}"
  raw="${raw//\\\\/\\}"

  printf '%s' "$raw"
  return 0
}

# json_extract_or_fail_closed <key> <payload> <danger-pattern> <hook-name>
#
# The safety wrapper the blocking hooks use. Extracts <key>; on success echoes
# the value and returns 0. On extraction FAILURE it does not shrug and continue —
# it checks whether the raw payload contains <danger-pattern> anywhere, and if so
# returns 2, telling the caller to block on the grounds that it cannot prove the
# command is safe.
#
# This is the #16 lesson applied directly: when a guard cannot determine the
# truth, the safe answer is to refuse, not to wave the command through. An
# unparseable payload carrying something that looks like `git add -A` is exactly
# the case where failing open is worst.
json_extract_or_fail_closed() {
  local key="$1" payload="$2" danger="$3" value

  if value="$(json_string_value "$key" "$payload")"; then
    printf '%s' "$value"
    return 0
  fi

  if printf '%s' "$payload" | grep -qE "$danger"; then
    return 2   # cannot parse, and it looks dangerous -> caller must block
  fi

  return 1     # cannot parse, nothing alarming in it -> caller may allow
}
