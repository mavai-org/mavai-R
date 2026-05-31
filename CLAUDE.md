# mavai-R

This is the R member of the mavai project family. It generates
language-agnostic reference datasets for statistical computations used across
all mavai probabilistic testing frameworks.

## Role

mavai-R is the **statistical oracle**. It uses R — the gold standard for
statistical computing — to produce canonical expected outputs. Framework
implementations (punit, feotest, baseltest, ...) verify conformance against
these outputs.

mavai-R does not implement a testing framework. It produces reference data.

## Structure

```
R/              # R source: one file per statistical computation family
inst/cases/     # Generated JSON: the reference datasets (committed)
tests/testthat/ # R tests validating the generators themselves
scripts/        # Regeneration script
schema/         # JSON schema for the case format
```

## Conventions

- All statistical computations use R's base `stats` functions (`qnorm`,
  `pnorm`, etc.) — not custom implementations. The whole point is to rely on
  R's vetted statistical library.
- JSON files in `inst/cases/` are committed. They are the deliverable.
  Consumers should not need R installed.
- Each JSON file declares its own `tolerance` for floating-point comparison.
- Test cases should include edge cases (p=0, p=1, small n, large n) and
  realistic cases (typical LLM service pass rates around 0.90-0.99).
- The package is designed to grow. Future additions include design of
  experiments (DoE) reference data.

## Regenerating

```
Rscript scripts/generate_all.R
```

## Downstream requirements

Whenever the test suite defined by this project is modified or extended,
create a requirements document for each of the following sibling projects:
**punit** and **feotest**. Place the requirements in the `plan/` folder that
both of these projects have. Name the document `REQ-R-xxx.md` where `xxx`
is reflective of the changes (e.g., `REQ-R-latency-percentile.md`).

## Fixture versioning

The `inst/cases/*.json` reference datasets are the public API of this repo.
Downstream frameworks (punit, feotest, ...) consume them by version via the
`v*` tag releases published by `.github/workflows/release.yml`. Any change
that alters fixture content or shape is therefore an observable API change
and MUST be accompanied by a version bump. Do not silently ship schema or
content changes under the current version number.

**When a version bump is required** — any of the following:

- A generator function in `R/*.R` changes in a way that alters any JSON
  output (input fields, expected output fields, tolerance, method string,
  or the numerical values themselves).
- `schema/cases.schema.json` changes in a way that affects existing suites.
- A new suite is added, or an existing suite gains / loses cases.

**How to bump**:

- Update `Version:` in `DESCRIPTION`.
- For **breaking** changes (fields removed or reshaped, method semantics
  altered, numerical output changed): bump the **minor** number while on
  0.x (e.g. 0.5.0 → 0.6.0); bump **major** on 1.x+.
- For **additive** changes (a new suite, a new case within an existing
  suite, documentation-only edits): bump the **patch** number
  (e.g. 0.5.0 → 0.5.1).
- Add a `CHANGELOG.md` entry naming what changed and whether it is
  breaking. Downstream maintainers read this to decide whether to update
  their snapshot.

**How to publish**:

- Regenerate fixtures with `Rscript scripts/generate_all.R` before
  committing.
- Commit `DESCRIPTION` bump, regenerated fixtures, and changelog entry
  together.
- Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`. The
  `release.yml` workflow fires on tag push and uploads a zipped bundle
  (`cases-vX.Y.Z.zip`) to a GitHub Release.
- **Verify the tag reached origin**: run `git ls-remote --tags origin`
  after pushing and confirm the new tag is listed. Local-only tags do
  not trigger the release workflow. Prior incident: `v0.4.0` was created
  locally but never pushed, so no release was ever published for that
  version while `DESCRIPTION` drifted. If you find a local tag that is
  not on origin and whose commit has been superseded by further work,
  delete it (`git tag -d vX.Y.Z`) rather than retroactively pushing.

**Downstream snapshot sync**: per-language frameworks hold committed
copies of `inst/cases/*.json` in their own test resources. A published
release does not automatically update those copies; the downstream
requirements document (see above) should name the new version so the
punit / feotest maintainers know which release to pull.

## Relationship to other projects

- **punit** and **feotest** consume `inst/cases/*.json` in their conformance
  tests.
- **javai-orchestrator** tracks mavai-R in the project registry and feature
  inventory.
- mavai-R is an independent git repository, included as a submodule in
  javai-orchestrator.
