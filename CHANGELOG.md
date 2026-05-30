# Changelog

All notable changes to the `mavai-R` fixture releases are documented here.
Versions follow the fixture-versioning rules declared in `CLAUDE.md`:
**minor** bumps on 0.x mark breaking changes to fixture content or shape;
**patch** bumps mark additive changes.

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
