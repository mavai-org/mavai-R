# Changelog

All notable changes to the `mavai-R` fixture releases are documented here.
Versions follow the fixture-versioning rules declared in `CLAUDE.md`:
**minor** bumps on 0.x mark breaking changes to fixture content or shape;
**patch** bumps mark additive changes.

## [0.9.3] — 2026-07-27

**Format corpus: the value-comparison forms (additive).** The
`mavai-contract/1` schema admits the deterministic value-comparison
postcondition forms added by the 2026-07-27 spec amendment
(`DIR-FAM-FORMS-value-comparison`): the numeric comparison sextet
`eq`/`ne`/`lt`/`le`/`gt`/`ge` (decimal semantics, number or numeric-string
operands), `not-equals`, `equals-ci`, `is-null` (operand `true` only), and
the collective set forms `equals-set`/`contains-set`/`count-equals`, which
require an `in:` naming a declared view plus a `path:` (expressed
structurally via the entry's dependent schemas). The corpus gains two
`valid/` cases (the scalar family; the set family, each form exercised
including per-input use) and four `invalid/` cases with new categories,
all structural: `set-form-without-path`, `value-operand-malformed`,
`is-null-operand`, `set-operand-empty`. The manifest registers the
categories against the mandating spec section. This release is the
dependency floor for the baseltest and punit implementation directives
(`DIR-BAS-FORMS-value-comparison`, `DIR-PU-FORMS-value-comparison`).

## [0.9.2] — 2026-07-25

**Format corpus: the max-iterations cases isolated to their category
(additive-scale patch; corpus content changed, schema outcomes did not).**
baseltest's format-conformance adoption — the corpus's first consumer —
surfaced that the two `optimization-max-iterations-*` cases omitted the
`stepper-config:` their stepper's factory requires, so a loader refused
before reaching the category under test. Each case now carries a complete,
valid entry except for its one defect. First live exercise of the
corpus-defect triage the conformance loop exists for.

## [0.9.1] — 2026-07-25

**Declarative format schemas and conformance corpus hosted (additive,
non-statistical).** This repository takes on a second, distinct oracle duty:
beside the methodology pair (Statistical Companion ↔ `inst/cases/`), it now
hosts the format pair — JSON Schemas (draft 2020-12) for the family's
declarative authoring formats `mavai-contract/1` and `mavai-services/1`,
with a 74-file conformance corpus (`valid/` files that MUST load, `invalid/`
files that MUST be refused, one per refusal category) and a manifest
classifying every expectation binding vs informational and every refusal
structural vs semantic, under `inst/formats/`. Releases gain a third asset,
`formats-vX.Y.Z.zip`. **Publication channel only**: the prose format
specifications are canonical in the family's requirements catalog and are
not published; these artefacts are family engineering infrastructure the
implementing frameworks conform to, not a public standard. Nothing here is
computed in R; no statistical authority is claimed. Build step:
`scripts/validate_formats.R` (schema compilation, corpus-vs-manifest
validation, run by testthat and the release workflow); the testthat file
adds the two-way coverage check and refusal cases.

## [0.9.0] — 2026-07-17

**Interchange `failureDistribution` redesigned (breaking to the section's
shape; the `mavai-explore-1` / `mavai-optimize-1` version ids are deliberately
reused — no framework emitter has shipped against the published schemas, so
there are no external consumers to migrate).** The check-name-keyed mapping is
withdrawn: emitters that derived keys from input content produced mapping keys
past YAML's 1,024-character implicit-key limit, making faithfully emitted
artefacts unparseable. The section is now a *sequence* of entries
`{condition, count, inputIndex?, inputExcerpt?}` — `condition` is the
violating condition's bounded identity (≤ 256 characters, never embedding
input or response content), per-input attribution travels structurally in
`inputIndex`, and `inputExcerpt` is a bounded informational excerpt. Both
schemas and all worked examples are updated. Authority: the family catalog's
interchange key-discipline amendment of 2026-07-17.

**Interchange validation build step.** `scripts/validate_interchange.R`
compiles each interchange schema under ajv (draft 2020-12) and validates
every worked example against its schema; `tests/testthat/test-interchange-schemas.R`
drives it and adds refusal cases, and the release workflow runs it before
packaging the `interchange-vX.Y.Z.zip` asset, so an invalid schema or a
drifted example can no longer ship. New Suggests: `jsonvalidate`, `yaml`.

## [0.8.6] — 2026-07-15

**Interchange schemas hosted (additive, non-statistical).** This repository
now additionally publishes the mavai family's experiment interchange
artefacts: JSON Schemas for `mavai-explore-1` (one document per explored
experiment configuration) and `mavai-optimize-1` (one document per optimize
run) in `schema/`, with conformant worked examples in `inst/interchange/`.
Releases gain a second asset, `interchange-vX.Y.Z.zip`, alongside the
statistical cases bundle. **Publication channel only**: the formats are
specified canonically in the family's requirements catalog, nothing here is
computed in R, and no statistical authority is claimed — see
`inst/interchange/README.md`. The statistical cases and their schema are
untouched.

**Verdict XML schemas hosted (additive, non-statistical).** The verdict
interchange XSDs (`verdict-1.0/1.1/1.2.xsd`) join `schema/` under the same
publication-only terms, replacing their previous split existence (a private
canonical copy and a punit-embedded copy that had drifted in comments —
reconciled to one text). All schemas are also served at the documentation
site under `/schema/`, and ship in the `interchange-vX.Y.Z.zip` release
asset.

## [0.8.5] — 2026-07-11

**New suite: `risk_driven_sizing.json` (additive).** Materialises
companion §5.4.1 (new in companion 1.4.0): self-consistent power for
baseline-derived thresholds, where the acceptance floor
`WilsonLower(p0, n, 1−α)` moves with the test's own sample size.
Thirteen cases in three groups, discriminated by the `approach` field:

- `required_n` — smallest n meeting a target power for a declared
  minimal acceptable rate, with the floor and achieved power at that n;
  includes the companion's two computed examples (0.87/0.84/0.95/0.80
  → 891; the 0.96/0.93 scenario walk-through → 405) and parameter
  sensitivity around them.
- `power_at` — floor and power at candidate sample sizes, including the
  walk-through's table rows and the case pinning that the §5.4
  closed-form seed (n = 826) underpowers the worked example.
- `detectable_rate` — the inversion (largest tolerable rate detectable
  at a fixed n, bisection to 1e-10), including round-trips at the
  required-n answers.

The suite is **not** in the family-mandatory tier: it binds a framework
when it adopts risk-driven sizing (baseltest first, per
`DIR-BAS-SIZING-risk-driven` in the orchestrator). Defined for
`minimum_acceptable_rate < baseline_rate` only — the generators refuse
the over-reach regime. New exported helpers `power_self_consistent()`,
`required_n_self_consistent()`, `detectable_rate_self_consistent()`.
No existing suite changed. Also carries the companion at 1.4.1 (§5.4.1
new section; §6 operational-approaches taxonomy reconciliation; Type
I/II plain-language definitions).

## [0.8.4] — 2026-07-10

**New suite: `regression_decision.json` (additive).** Publishes the
composed §3.4 decision rule for the regression (baseline-derived)
procedure as a first-class conformance target: end-to-end scenario
cases `(baseline_successes, baseline_trials, test_samples, confidence,
observed_successes) → (threshold_real, wilson_lower, cutoff_integer,
displayed_rate, achieved_size, verdict)`, with `PASS iff K ≥ c`,
`c = ⌈n_test · p*⌉`. Thirteen cases: the §3.4 worked example
(p̂ = 0.951, n_test = 100 → p* ≈ 0.902124, c = 91, achieved size
≈ 0.024986) with `K = c` / `K = c − 1` boundaries, small-n
discretisation cases where the real-valued bound and the integer
cutoff disagree materially, the perfect-baseline `k = n` edge
(§4.3.2 effective-rate guard), a compliance-procedure sibling group
(test-side Wilson lower bound vs a declared threshold, §3.2/§3.6),
and a conflation-detector pair — one observation shared across both
procedures with opposite verdicts (`K = c = 91` passes the regression
rule; the same count read compliance-style against the same derived
value fails), so a framework applying the compliance rule on the
regression path fails the suite even though every component
computation is arithmetically conformant. Tolerance 1e-10; `procedure` field
distinguishes the two rule families. New generator
`generate_regression_decision_cases()`.

**New generated artefact: `manifest.json` (additive).** A conformance
coverage manifest generated alongside the suites (never
hand-maintained), `manifestVersion` 1: per-suite case rosters,
**binding vs informational** expected-field classification authored in
the generators, per-suite MD5 content hashes, and the oracle-declared
**family-mandatory tier** — `wilson_ci`, `wilson_lower`,
`threshold_derivation`, `verdict`, `latency_percentile`,
`latency_threshold`, `regression_decision`. Downstream frameworks
diff the set of `(suite, case, binding-field)` assertions they
actually make against (family-mandatory ∪ committed scope), making
field-selective assertion inside a nominally covered suite
machine-detectable. New generator `generate_manifest()`, invoked at
the end of `scripts/generate_all.R`.

**Binding-status clarification (no content change):**
`threshold_derivation.json`'s `cutoff_integer` and `achieved_size`
have been published since the suite's introduction but were consumed
by no framework — the blind spot that let a decision-rule deviation
ship. The manifest now classifies them **binding**; conformance tests
must assert them. Existing suites are otherwise unchanged.

Tracked by `DIR-DECISION-RULE-CONFORMANCE-family` in the orchestrator;
the manifest is Stage 1 of `DIR-CONFORMANCE-COVERAGE-MANIFEST-family`,
riding this release per the owner decision of 2026-07-10.

## [0.8.3] — 2026-07-09

**New suite: `latency_percentile_minimums.json` (additive).** Publishes
the family standard for empirical-latency-percentile minimum sample
sizes, closing a three-way implementation drift (companion §12.5.2 says
the p50 emission minimum is 5; punit's emission gate and the
orchestrator catalog said 1; feotest already said 5). Two case groups,
distinguished by the `approach` field:

- `emission_non_degeneracy` — the §12.5.2 minimums (5/10/20/100 for
  p50/p90/p95/p99) governing whether a percentile may be emitted in
  experiment artefacts and verdicts at all.
- `bound_existence` — the §12.5.2.1 minimums
  (`n_s ≥ ⌈log α / log p⌉`, Wilks) for a non-saturated
  distribution-free upper bound at confidence 0.95 and 0.99.
  Judgement-time minimums for latency-criterion evaluation, not
  emission rules.

All values are integers; suite `tolerance: 0` (exact equality). New
exported helper `latency_bound_existence_min_samples()`; the emission
values come from the existing `latency_min_samples()`. No existing
suite changed. Tracked by `DIR-PERCENTILE-MINIMUMS-family` in the
orchestrator.

## [0.8.2] — 2026-05-30

**First release from `mavai-org/mavai-R` — the javai → mavai rebrand
(metadata only).** This is the first tagged cut under the new brand. The
published docs (Statistical Companion, Glossary, Distributional
Contracts, Model Overview, README, PDF footer), the schema `$id`
(`github.com/mavai-org/mavai-R/...`), and the R package name
(`javair` → `mavair`) now carry the mavai brand. **No fixture content,
shape, expected values, tolerances, or schema *structure* changed** —
only the schema's `$id` identifier string and surrounding documentation.
Conformance behaviour is unaffected; downstream frameworks need not
re-pin for the rebrand. (Old `javai-org/javai-R` release URLs continue to
301-redirect here.)

**Documentation-only string cleanup on `baseline_object.json`.**

Statistical Companion §1.5 was revised (companion doc 1.3.4 → 1.3.5):
the §1.5.5 *accumulation* construct was withdrawn and the long-term-
monitoring framing of baseline indexing removed, while baseline
indexing itself was retained and stated precisely (the index is the
service-contract identity plus the resolved covariate values; the
factor record is provenance). None of this was ever implemented as
fixture data, expected values, schema, or generator logic — only as
descriptive strings. This patch re-words the `baseline_object`
suite/case `description` and `method` strings to match. No inputs,
expected outputs, tolerances, numerical values, case set, or schema
change; conformance behaviour is unaffected. Downstream frameworks
need not re-pin.

## [0.8.1] — 2026-05-19

**Saturation discipline on `latency_threshold_bootstrap.json`.**

Per Statistical Companion §12.4.2 — a one-rung patch on the bootstrap
conformance fixture so downstream frameworks can honour the
saturation discipline against the published reference data.

### Changed

- **`inst/cases/latency_threshold_bootstrap.json`** — every case's
  `expected` block gains two new fields per **Statistical Companion
  §12.4.2** (saturation discipline): `k_raw` (the unclamped binomial-
  derived rank `qbinom(1 - alpha, n, p) + 1`) and `saturated` (TRUE
  iff `k_raw > n`). When `saturated` is TRUE the published `rank` and
  `threshold` are advisory at the saturation ceiling (`rank = n`,
  `threshold = t_{(n)}`) and MUST NOT be presented as exact bounds
  on Q(p); the suite description now states this explicitly.
  Consumers must branch on `saturated` before treating `threshold`
  as inferential. Of the four published cases, `lognormal_n200_p99`
  is saturated (`k_raw = 201` against `n = 200`); the other three
  are not (`k_raw == rank`). Per
  `DIR-LATENCY-SATURATION-FIXTURE-javai-R.md`. Downstream:
  `LatencyThresholdDeriver` in `punit` already exposes the saturation
  flag on its `Threshold` record (punit#192); the punit conformance
  test will be extended to assert against the new fields under a
  follow-on punit directive. `feotest` follows under its own
  directive.

### Added

- New helper `latency_threshold_binomial_rank(n, p, confidence)` in
  `R/latency.R` returning `{k_raw, saturated}`. `latency_threshold_derive()`
  is unchanged — the saturation-discipline fields stay localised to
  the bootstrap suite's generator.

---

## [0.8.0] — 2026-05-14

**Multi-criteria model fixtures. Lands five new formula-value suites
and an in-place extension of `threshold_derivation.json` per the
criterion-decomposition model of Statistical Companion v1.3
(§§1.4–1.5, §10).**

This release is the formula-value half of the conformance contract
named in §10.6: arithmetic agreement between downstream framework
computations and the javai-R oracle. The calibration-fixture half
(achieved Type-I rates, achieved power, achieved family-wise rates
under stated dependence regimes) is named in §10.6 as future work and
will land in a subsequent release.

Per `DIR-MULTI-CRITERIA-FIXTURES-javai-R.md` in the orchestrator.

### Added

- **`inst/cases/criterion_verdict_observational.json`** — per-criterion
  verdict cases for observational criteria (§1.4.5), with the §1.4.5a
  two-policy denominator enum. The effective denominator `n_c` is the
  policy-derived field; cases include a policy-difference pair where
  the same raw counts yield PASS under `CONDITIONAL_ON_EVALUABLE` and
  FAIL under `MARGINAL_COUNT_UNEVALUABLE_AS_FAIL`.
- **`inst/cases/criterion_verdict_inferential.json`** — per-criterion
  verdict cases for inferential criteria, partitioned by procedure
  (REGRESSION decides on the integer cutoff `K_c >= c` per SC-RU-02;
  COMPLIANCE decides on the Wilson lower bound exceeding `p_req`).
  Three-strand verdict (`statistical`, `observed_rate_status`,
  `operational_caution_category`) plus p-value method/tail metadata.
- **`inst/cases/composite_verdict.json`** — composite-verdict
  aggregation per §1.4.6 and SC-RU-05: composite PASS / FAIL /
  INCONCLUSIVE plus the procedure-split envelopes
  (`false_compliance_envelope` over compliance criteria,
  `false_degradation_signal_envelope` over regression criteria).
  Observational criteria contribute to neither envelope.
- **`inst/cases/baseline_object.json`** — canonical baseline objects
  at named points in the index space (factor record, covariate
  profile, expiration window, structural reference) under the locked
  §1.4.5a two-policy enum, with `availability_criterion_ref` for the
  structural-composition pattern. Schema-only fixtures: each case
  carries an empty `expected` block.
- **`inst/cases/multi_criteria_scenario_consult_advice.json`** — the
  end-to-end fixture mirroring §10.3. Four cases: the locked §10.3
  composite-FAIL contract, the passing counterfactual, the paired-
  evaluability / content structural-composition pattern with non-1.0
  `r_obs`, and the cross-policy structural-mismatch refusal. Every
  case carries the §10.6 `conformance_status` metadata block with
  `formula_value_fixtures: passed`, `calibration_fixtures:
  not-published`, `calibration_claim_permitted: false`.

### Changed

- **`inst/cases/threshold_derivation.json`** — every
  `sample_size_first` case gains three new `expected` fields per
  **SC-RU-02**: `wilson_lower_real` (the real-valued Wilson lower
  bound), `cutoff_integer` (the binding decision artefact
  `ceiling(n_test × wilson_lower_real)`), and `achieved_size` (the
  lower-tail false-degradation probability `P_{p_0}(K < c)` under the
  effective baseline rate). The historical `threshold` field is
  preserved as a synonym for `wilson_lower_real`. A new
  `ssf_sc_ru_02_worked_example` case anchors the §3.4 worked-example
  numerics (`p̂ = 0.951`, `n_test = 100`, `α = 0.05` → real-valued
  ≈ 0.902124, cutoff = 91, achieved size ≈ 0.024986).
- **`schema/cases.schema.json`** — relaxed top-level `inputs` /
  `expected` value constraints to accept arbitrary JSON (numbers,
  booleans, strings, nulls, arrays, objects) so the per-criterion and
  scenario fixtures' nested shapes validate. Existing flat-shape
  fixtures continue to validate unchanged. New top-level case fields
  added: `description` (optional), `procedure` (optional, enum).
  `$defs` introduces the two-value denominator policy enum for
  generators that need to validate the enum explicitly.

### Downstream

- `punit` and `feotest` need extending to consume the new suites; see
  `DIR-MULTI-CRITERIA-FIXTURES-punit.md` and
  `DIR-MULTI-CRITERIA-FIXTURES-feotest.md` (forthcoming).

---

## [0.7.0] — Unreleased

**Breaking — `latency_threshold_bootstrap` fixture role change and
shape change.**

`inst/cases/latency_threshold_bootstrap.json` is upgraded from an
*informational* comparison report (R-internal) to a *conformance*
contract for the exact binomial order-statistic upper bound. Both
`punit` and `feotest` will now consume this suite to verify their
implementations agree exactly with `javai-R`'s on the same lognormal
baselines. The bootstrap-vs-binomial comparison content is preserved
alongside as informational fields.

### Changed

- **`inst/cases/latency_threshold_bootstrap.json` shape.** Each case
  now publishes the (ascending-sorted) baseline sample in
  `inputs.baseline_latencies`, alongside `p` and `confidence`. The
  `expected` section gains four conformance fields:
    - `rank` (was `binomial_rank`),
    - `threshold` (was `binomial_bound`),
    - `baseline_percentile` (the raw sample quantile `Q(p)`),
    - `n` (the baseline sample count).
  The fields `bootstrap_upper`, `point_estimate`, and `diff` are
  preserved as informational comparison content and are no longer
  conformance targets. The suite-level `description` documents the
  new role; `method` is rewritten to lead with the binomial
  construction.

- **`scripts/bootstrap_compare.R`.** The generator logic moved into
  `generate_latency_threshold_bootstrap_cases()` in `R/latency.R`.
  The script is now a thin wrapper that produces the markdown
  comparison table for §12.4.4 of the Statistical Companion; JSON
  emission is driven by `scripts/generate_all.R`.

- **`R/latency.R`.** Added the bootstrap-comparison generator plus a
  reusable `bootstrap_upper()` helper. The bootstrap RNG seed is
  fixed (default `seed = 1`) so the informational fields stay stable
  across regenerations.

### Conformance properties

The new conformance fields are integer-valued or are specific
elements of the integer-valued `baseline_latencies` array, so the
suite carries `tolerance: 0` (exact equality), matching the sister
suite `latency_threshold.json`. Per-field precision contract:

| Field                 | Conformance check    |
|-----------------------|----------------------|
| `rank`                | exact integer match  |
| `threshold`           | exact match (equals `baseline_latencies[rank - 1]`) |
| `baseline_percentile` | exact match (`t_{([p·n])}`) |
| `n`                   | exact integer match  |
| `bootstrap_upper`     | informational only   |
| `point_estimate`      | informational only   |
| `diff`                | informational only   |

### Downstream impact

The four existing cases (`lognormal_n200_p95`, `lognormal_n200_p99`,
`lognormal_n935_p95`, `lognormal_n935_p99`) keep their names and
keep the same underlying lognormal draws (the `set.seed(42)` calls
are unchanged), so consumers picking up the upgraded fixture see
the same numerical `binomial_bound` / `binomial_rank` values they
would have read out of the prior shape — only the field names and
the addition of `baseline_latencies` differ.

Downstream maintainers should:

- Pull the upgraded `latency_threshold_bootstrap.json` into their
  test resources (or rely on the conformance-data download
  mechanism).
- Extend their conformance test (`LatencyConformanceTest` in
  `punit`; equivalent in `feotest`) to consume the new shape.

See `REQ-R-bootstrap-fixture-upgrade.md` in each downstream
project's `plan/` folder for per-framework guidance.

### Documentation (shipped alongside the fixture upgrade)

- `docs/STATISTICAL-COMPANION.md` — §1.3 restructured to add a new
  §1.3.1 *Why the Working Approximation is Defensible*, articulating
  the conditions under which the Bernoulli i.i.d. assumption is
  reasonable for LLM testing: a pinned-snapshot model identifier
  (versus a floating alias), fixed system prompt and sampling
  configuration, no conversation state carried between calls, a stable
  input-sampling process, and a single experimental run of bounded
  wall-clock duration. The new sub-section quotes Anthropic's
  documented commitment that every Claude model ID is a pinned snapshot
  and cites Chen, Zaharia & Zou (2023) as the empirical counterweight
  showing that floating aliases do drift across snapshots over months.
  Existing §1.3 material moves unchanged into §1.3.2 (formal
  assumptions and operational threats) and §1.3.3 (developer
  responsibility for trial independence — previously an unnumbered
  sub-section, now numbered to match the §8.3.x convention used
  elsewhere in the document). Bibliography gains entries 17 (Anthropic,
  2026) and 18 (Chen, Zaharia & Zou, 2023).

## [0.6.0] — 2026-05-08

**Breaking — threshold-derivation fixture content and signature change.**

The `threshold_sample_size_first` and `threshold_first_implied_confidence`
generators were not matching the statistical companion: they ignored
their `test_samples` parameter and computed `wilson_lower(k_baseline,
n_baseline, conf)` regardless. The companion's §3.4 / §4.3.2 / §6.3
construction is the one-sided Wilson lower bound at the *test* sample
size, with a two-step compression for the perfect-baseline case. This
release replaces the generators with the companion-correct construction
and regenerates the affected fixture.

Downstream conformance suites (punit, feotest) MUST be updated before
consuming this release. A requirements document describing the migration
exists at `plan/REQ-R-threshold-derivation-test-sample-size.md` in each
consumer repository.

### Changed

- `inst/cases/threshold_derivation.json` — **expected values change for
  every case, and the threshold-first input shape adds a required
  `test_samples` field**. `sample_size_first` thresholds are now derived
  by Wilson lower bound at the test sample size: general case (§3.4)
  uses the baseline point estimate as the formula's centre; perfect-
  baseline case (§4.3.2) compresses the baseline through its own Wilson
  lower bound first, then applies the same Wilson construction at the
  test sample size. New cases sweep `test_samples` to make the new
  sensitivity verifiable from the fixture alone (`ssf_950_of_1000_test50`,
  `ssf_950_of_1000_test200`, `ssf_perfect_baseline_n1000_test100`).
  Threshold-first cases acquire a `test_samples` input.
- `R/threshold.R` — `threshold_sample_size_first(...)` and
  `threshold_first_implied_confidence(...)` rewritten to follow the
  companion. `threshold_first_implied_confidence` gains `test_samples`
  in its signature; the binary search runs against the corrected
  forward construction.
- `R/wilson.R` — adds `wilson_lower_from_rate(p_hat, n, confidence)`
  for the continuous-rate Wilson lower bound that the threshold
  construction needs (the discrete `wilson_lower(k, n, conf)` is now a
  thin wrapper).

### Why

The previous generator effectively published `wilson_lower(baseline)`
under the name "threshold". A test passes (per §5.1) when the
*observed* test rate clears the threshold, and the threshold's role is
to bound the test-side false-positive rate at the configured α. That
calls for a Wilson construction parametrised by `n_test`, not
`n_baseline` — exactly what §3.4 / §3.5 already specified and what the
generators had drifted from. Smaller test samples lower the threshold
(§3.5), which the new fixture demonstrates.

## [0.5.0] — 2026-04-16

**Breaking — latency fixture schema and method change.**

Downstream conformance suites (punit, feotest) MUST be updated before
consuming this release. A requirements document describing the migration
exists at `plan/REQ-R-latency-threshold-binomial.md` in each consumer
repository.

### Changed

- `inst/cases/latency_threshold.json` — **inputs reshaped and method
  replaced**. The `s / sqrt(n_s)` standard-error approximation used to
  derive an upper bound on a baseline percentile has been superseded by
  an exact non-parametric construction: the binomial order-statistic
  upper confidence bound. Input fields changed from
  `{baseline_percentile, baseline_sd, baseline_n, confidence}` to
  `{baseline_latencies, p, confidence}`; expected output fields changed
  from `{raw_upper, threshold}` to `{rank, threshold, baseline_percentile, n}`.
  Tolerance is now zero (the expected threshold is always an exact order
  statistic of the integer-ms baseline).
- `inst/cases/latency_percentile.json` — summary cases drop the sample
  standard deviation (`sd`) field. `mean` and `max` remain. The latency
  distribution is not well-characterised by its second moment, and the
  new threshold construction does not use `s`.

### Added

- `inst/cases/latency_threshold_bootstrap.json` — informational
  reference data comparing the binomial order-statistic bound against a
  10,000-replicate percentile bootstrap on representative lognormal
  baselines. Not part of the conformance contract; provided so
  consumers can verify the §12.4.4 table in `STATISTICAL-COMPANION.md`
  without an R installation.
- `scripts/bootstrap_compare.R` — the script that generates the
  bootstrap comparison fixture.

### Notes

- A local `v0.4.0` tag existed on the commit that bumped `DESCRIPTION`
  to 0.4.0 but was never pushed to `origin`, so no 0.4.0 release was
  ever published. The 0.4.0 version number is skipped to avoid
  confusion with that un-released state. Downstream consumers
  upgrading should read this as 0.3.0 → 0.5.0 directly.

## [0.3.0] — 2026-03-28

Reference data upgraded to full-precision numerical output.

## [0.2.0] — 2026-03-28

JSON Schema for conformance case files added under `schema/`.

## [0.1.0] — 2026-03-28

Initial public release.
