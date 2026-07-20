# Code-review checklist — AI failure modes

Additions to the standard review pass, tuned to the ways AI-generated code fails
differently from human-written code. Apply these when reviewing any diff (the
`/code-review` skill, or a manual review). They complement — do not replace — the
12 [engineering standards](../standards/engineering-standards.md); secrets are
already caught mechanically by the pre-commit guard and CI gitleaks.

The three modes below share a root cause: AI code is *fluent* — it reads as
correct and passes the happy path — so review must probe the things fluency
hides.

## 1. Hallucinated dependencies

A model invents a plausible-sounding package, import, method, or option that does
not exist (slopsquatting) — or exists but is the wrong, typosquatted name.

- **Detection heuristic:** for every third-party `import`/`require` added, confirm
  the package is declared in the manifest/lockfile **and** is a real, correctly
  spelled published package; for every method/option/flag called on a library,
  confirm it exists in that library's actual API — don't trust that it compiles.

## 2. Inadequate error handling

AI code optimizes for the happy path and quietly drops the failure path — empty
catches, bare `except`, unchecked return codes, errors logged-and-swallowed.

- **Detection heuristic:** at each system boundary (file I/O, network, DB,
  external/API calls, subprocess), find the failure branch and confirm it exists,
  propagates or handles the error, and does not silently swallow it — production
  paths fail closed, dev paths fail loud (standard #4).

## 3. Plausible-but-wrong logic

Code that looks right, reads cleanly, and passes basic/happy-path tests but is
wrong on the cases the tests don't cover — off-by-one, boundary conditions, empty
input, inverted condition, wrong operator, misread spec.

- **Detection heuristic:** trace one concrete non-happy-path input by hand
  (empty collection, boundary value, zero/negative, the spec's edge case) through
  the logic and confirm the output — passing happy-path tests is not evidence of
  correctness. Verify the code against the *intent*, not against itself.
