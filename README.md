# mavai-R

Reference statistical computations for the [mavai](https://mavai.org) project
family, implemented in R.

## Purpose

This R package generates language-agnostic reference datasets — canonical
expected outputs for the statistical computations that underpin probabilistic
testing frameworks across the mavai family:

- **[punit](https://github.com/mavai-org/punit)** (Java)
- **[feotest](https://github.com/mavai-org/feotest)** (Rust)
- **[baseltest](https://github.com/mavai-org/baseltest)** (Python, planned)

Each framework implements the same statistical methods independently, in its own
language and idiom. This project provides the shared truth: if your
implementation produces results that match the R-generated reference data
(within stated tolerances), it conforms.

## Why R?

R is the lingua franca of statistics. By generating reference data with R's
well-vetted statistical functions (`qnorm`, `pnorm`, `prop.test`, etc.),
anyone — statistician, auditor, contributor — can verify the expected outputs
independently. No need to trust a Java or Rust implementation.

## What's covered

The reference data implements the decision rules of Statistical Companion
1.5.0 over two quality dimensions of the mavai methodology: **pass-rate
analysis** (binomial) and **latency analysis** (non-parametric, empirical
percentile based). For the full statistical treatment, see the
[Statistical Companion](docs/STATISTICAL-COMPANION.md). For the contract
model that these computations serve, see
[Distributional Contracts](docs/DISTRIBUTIONAL-CONTRACTS.md).

Four versioned decision rules decide every verdict, and each fixture file
names the rules it depends on (`decisionRules`) and the methodology version
it implements (`methodologyVersion`):

| Rule | Decides | Binding artefact |
|---|---|---|
| `regression/fisher` v1 | Empirical regression against a baseline (one-sided Fisher exact test) | integer cutoff c; PASS iff K_t >= c |
| `compliance/exact-binomial` v1 | Normative compliance with a given requirement (exact one-sided binomial test) | k_min; PASS iff K >= k_min |
| `latency/precedence` v1 | Latency regression (precedence rank of the baseline latencies) | rank, or `saturated` (INCONCLUSIVE) |
| `latency/compliance-exact-binomial` v1 | An explicit latency requirement (exact one-sided binomial test on the count of successful latencies within the threshold) | y_min; PASS iff Y >= y_min, or INCONCLUSIVE when too few latencies arrived |

Configurations refused before any sample runs carry `configuration_error`, the
list of every applicable code in the fixed order `TEST_LARGER_THAN_BASELINE`,
`COMPLIANCE_INFEASIBLE` (empty when the configuration is valid). A service
judged against both a requirement and its baseline carries two criteria over
the same postconditions, one compliance and one regression, composed like any
others. The methodology-1.4.1 fixtures remain available as
the `v0.10.13` release assets.

### Pass-rate conformance

| Suite | File | Covers |
|---|---|---|
| Wilson CI | `inst/cases/wilson_ci.json` | Two-sided Wilson score intervals (descriptive) |
| Wilson lower | `inst/cases/wilson_lower.json` | One-sided Wilson score lower bound (descriptive) |
| Threshold derivation | `inst/cases/threshold_derivation.json` | The regression cutoff c or the configuration error, and the implied alpha of a declared cutoff |
| Regression decision | `inst/cases/regression_decision.json` | Regression verdicts through the production path |
| Compliance decision | `inst/cases/compliance_decision.json` | Compliance verdicts, VERIFICATION refusals and SMOKE outcomes |
| Feasibility | `inst/cases/feasibility.json` | Whether a normative test of this size can PASS at all |
| Power analysis | `inst/cases/power_analysis.json` | Exact compliance sizing (margin, midway or declared alternative), regression design power and resolved-test power, and minimum detectable degradation |
| Risk-driven sizing | `inst/cases/risk_driven_sizing.json` | Exact sizing of the regression rule at a declared design alternative rate, with refusals |
| Verdict | `inst/cases/verdict.json` | Verdicts under both ruled rules, including joint configurations |

### Latency conformance

| Suite | File | Covers |
|---|---|---|
| Latency percentile | `inst/cases/latency_percentile.json` | Nearest-rank empirical percentiles and summary statistics |
| Latency threshold | `inst/cases/latency_threshold.json` | The precedence rank and threshold, or saturation |
| Latency percentile minimums | `inst/cases/latency_percentile_minimums.json` | Emission minimums, precedence existence on the actual count, and the pre-run planning check |
| Latency compliance decision | `inst/cases/latency_compliance_decision.json` | Explicit latency requirements: verdicts, refusals and INCONCLUSIVE outcomes, with the advisory percentile comparison |

The multi-criteria suites (`criterion_verdict_*`, `composite_verdict`,
`baseline_object`, `multi_criteria_scenario_consult_advice`) are
informational. `inst/cases/manifest.json` lists every suite, its binding and
informational fields and the family-mandatory roster. The calibration
certification surfaces behind the rules are produced by `scripts/certify.R`
and published as a separate release asset.

### Design of experiments (planned)

Future suites will cover DoE reference data as the mavai family expands into
experimental design capabilities.

## Usage

### Regenerate the reference data

```r
Rscript scripts/generate_all.R
```

This writes JSON files to `inst/cases/`. These files are committed to the
repository so that consumers can read them without needing R installed.

### Install as an R package

```r
devtools::install_github("mavai-org/mavai-R")
```

### Run the R tests

```r
devtools::test()
```

## JSON format

Each suite file contains:

```json
{
  "suite": "wilson_ci",
  "methodologyVersion": "1.5.0",
  "fixtureSchemaVersion": 2,
  "decisionRules": [],
  "description": "Wilson score confidence intervals (two-sided)",
  "method": "qnorm-based Wilson score interval",
  "tolerance": 1e-10,
  "cases": [
    {
      "name": "fair_coin_100_trials_95pct",
      "inputs": { "successes": 50, "trials": 100, "confidence": 0.95 },
      "expected": { "lower": 0.40383, "upper": 0.59617, "point": 0.50 }
    }
  ]
}
```

The `tolerance` field specifies the maximum acceptable absolute difference
between a framework's output and the reference value. Framework conformance
tests should use this tolerance for floating-point comparison.

## A second oracle duty: the declarative format schemas

Beside the statistical reference data, this repository hosts and versions the
machine-checkable materialisation of the mavai family's declarative authoring
formats — JSON Schemas for `mavai-contract/1` and `mavai-services/1` with a
conformance corpus and its manifest, under
[`inst/formats/`](inst/formats/README.md). The pairing is deliberate: the
Statistical Companion with `inst/cases/` owns *methodology* truth; the format
specifications with `inst/formats/` own *format* truth. Nothing in the
formats directory is computed in R and none of it carries statistical
authority — mavai-R is the family's language-neutral, release-tagged
distribution channel, and these artefacts are family engineering
infrastructure for the implementing frameworks, not a public standard (see
the directory README for the full positioning and the consumer obligation).

## Releases

Conformance case files are published as versioned GitHub Release artifacts.
Consuming projects download a pinned release rather than depending on this
repository directly.

Each release attaches three zip archives in a flat structure:

- `cases-vX.Y.Z.zip` — the statistical conformance cases from `inst/cases/`
  plus their schema.
- `interchange-vX.Y.Z.zip` — the experiment interchange schemas
  (`mavai-explore-1`, `mavai-optimize-1`, the verdict XSDs) with worked
  examples.
- `formats-vX.Y.Z.zip` — the declarative format schemas with the conformance
  corpus and manifest from `inst/formats/`.

### Download URL

```
https://github.com/mavai-org/mavai-R/releases/download/vX.Y.Z/cases-vX.Y.Z.zip
```

### Creating a release

1. Regenerate and verify locally:

   ```r
   Rscript scripts/generate_all.R
   devtools::test()
   ```

2. Commit any changes to `inst/cases/`.

3. Update the version in `DESCRIPTION`.

4. Tag and push:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

   The GitHub Actions workflow packages the committed case files and creates the
   release automatically.

### Versioning

Releases follow semantic versioning:

- **MAJOR**: breaking changes to JSON schema or case structure.
- **MINOR**: new suites or new cases added to existing suites.
- **PATCH**: corrections to expected values or tolerance adjustments.

## Consuming the reference data

Framework projects download a pinned release and assert conformance against the
JSON cases. For example:

- **punit** (Java): a Gradle task downloads and caches the release zip; JUnit
  tests read the JSON and assert each computation matches within tolerance.
- **feotest** (Rust): a build step downloads the zip; `#[test]` functions read
  the JSON via `serde_json` and assert conformance.

The JSON files are the contract. The R code is the oracle.

## Feedback

This project does not accept code contributions, but feedback is welcome —
especially from statisticians. If you spot a flaw in the methodology, a
questionable computation, or a missing edge case, please
[open an issue](https://github.com/mavai-org/mavai-R/issues).

## License

Apache-2.0
