# Review of `STATISTICAL-COMPANION(6).md`

Source reviewed: `STATISTICAL-COMPANION(6).md`, version `1.3-draft`, last-updated field `2026-05-14`.

## Verdict

The latest update is a clear improvement. The earlier validation-set problem is now largely resolved: the document consistently treats **sampling** as the input list for one experiment, shared by the criteria in that experiment, while different input distributions require separate experiments. The major remaining issues are not with that model; they are with integration around baselines, regression reporting, and latency feasibility/calibration.

I would describe this draft as **close, but still requiring a short correction pass before release**. The two most material issues are: baseline indexing does not yet fully carry the new experiment/sampling structure, and the latency feasibility gate still uses the old non-degeneracy minimum where the new confidence-bound existence minimum should also bind.

## Items now resolved

- The model-term replacement from “validation set” to “sampling” is effectively complete. Remaining uses of “validation” are generic phrases such as “AI system validation”, “validation rejection”, and “illustration, not validation”, not stale references to the input-list primitive.
- The sampling primitive now explicitly handles repeated-prompt designs by allowing the same underlying input to appear in multiple sample entries, with cluster structure recorded and handled under §8.2.1. Lines 481–496.
- §1.4.7 now correctly states that criteria within an experiment share one sampling, while contracts needing evidence about different input distributions run separate experiments. Lines 894–943.
- The finite-corpus wording has been fixed: it no longer says Wilson intervals “collapse to a point”, and instead says no binomial confidence interval is reported for an exhaustive finite-corpus estimand. Lines 2755–2772.
- The transparent-statistics decision-rule prose now distinguishes compliance from regression: compliance uses Wilson lower-bound clearance; regression uses the integer cutoff. Lines 3009–3015.
- The latency formula summary no longer clamps saturated ranks as exact bounds. Lines 2961–2963.

## Correction proposals

### 1. Add sampling / experiment identity to baseline indexing

**Severity:** High  
**Lines:** 1097–1146, 1380–1385, 2471–2482, 2748–2752, 2818–2820, 3773

**Issue:** The new sampling model says a contract may run multiple experiments, each with its own sampling. But the baseline is still indexed only by factor record, covariate profile, expiration window, and structural reference. That does not fully identify the population estimated by each criterion once the contract has multiple experiments and samplings. §8.4.6 also refers to `populationClaim`, `weights`, and `strata` as design metadata of §8.2.1, but §8.2.1’s required metadata table does not actually list `populationClaim` or `weights`.

**Proposal:** Add the experiment/sampling graph to the baseline’s structural reference, or add it as a fifth baseline index. At minimum, each baseline entry should carry `experimentId`, `samplingId`, `samplingVersion`, `populationClaim`, `samplingMode`, `targetEstimand`, and any weighting/stratification metadata needed to compare baseline and test.

Suggested replacement for the baseline index list around lines 1119–1138:

```md
- the **experiment and sampling reference** — experiment identifier,
  sampling identifier/version, populationClaim, samplingMode,
  targetEstimand, and any declared weights/strata — fixes the input
  population each criterion estimates. A baseline entry indexed under
  one sampling or population-claim regime does not support a test entry
  indexed under another;
- the **structural reference** — the postcondition-and-criterion graph,
  including denominator policy and any availability/evaluability
  criterion reference — fixes the meaning of each criterion in the family.
```

Also update Appendix A line 3773 so the baseline is not described as conditioned only on the four older indices.

### 2. Resolve `p*` overloading in regression sections

**Severity:** High  
**Lines:** 1563, 1598–1618, 1639–1641, 1889, 2264, 3093, 3111–3112

**Issue:** The draft uses `p*` for both the real-valued Wilson lower-bound output and the displayed integer-rate companion `c/n`. §3.2 says `p* = c/n`, while §3.4 uses `p*` / `p*_Wilson` for the real-valued Wilson bound and then derives `c = ceil(n p*_Wilson)`. This is conceptually manageable, but it is too easy for implementors to read the wrong quantity as the binding threshold.

**Proposal:** Use distinct names throughout:

```md
p_{Wilson,c}  = real-valued Wilson lower-bound output
c_c           = integer pass cutoff, ceil(n_c · p_{Wilson,c})
p_{display,c} = c_c / n_c
```

Then reserve `p_req` for compliance requirements. In regression reports, call `p_{Wilson,c}` diagnostic/threshold-derivation context and `c_c` the binding decision artefact.

### 3. Add achieved size to the §10.3 regression example

**Severity:** High  
**Lines:** 3095–3118, with checklist support at 3351–3352

**Issue:** The conformance checklist says achieved size must be reported alongside every integer cutoff. The §10.3 regression block reports a lower-tail probability at the observed count under `p = p*_c`, but it does not report the achieved false-degradation-alarm size at the cutoff under the stated reference model.

For the example as written, `p_baseline = 0.951`, `n = 1000`, `p*_Wilson ≈ 0.9385`, and `c_c = 939`. The achieved size is approximately:

```text
P_{p = 0.951}(K < 939) ≈ 0.0371
```

The displayed value `P_{p = p*_c}(K_c ≤ 953) ≈ 0.98` is not the achieved size at the cutoff. It may be retained as a diagnostic threshold-boundary tail probability, but it should not be the only tail probability shown in the regression block.

**Proposal:** Replace lines 3101–3106 with something like:

```md
Achieved size at integer cutoff:
  method:            exact-binomial-lower-tail
  reference:         p_ref = 0.951
  cutoff:            c_c = 939
  tail:              P_{p = 0.951}(K < 939)
  value:             ≈ 0.0371
  interpretation:    false-degradation-alarm probability under the
                     empirical reference at the configured cutoff.
```

Optionally add, separately and explicitly labelled:

```md
Diagnostic observed-count tail:
  tail:              P_{p = 0.951}(K ≤ 953)
  value:             ≈ 0.636
  interpretation:    observed count is not in the lower tail of the
                     reference distribution.
```

### 4. Fix the latency feasibility gate to enforce the confidence-bound existence minimum

**Severity:** High  
**Lines:** 3605–3627, 3631–3636, 3642–3648, 3681

**Issue:** §12.5.2.1 correctly says a non-saturated 95% p99 upper confidence bound needs 299 successful samples. But §12.5.3 still uses the older non-degeneracy minimum and gives a p99 example requiring only 100 successful samples. That contradicts the new existence gate.

**Proposal:** Define the VERIFICATION feasibility minimum as the maximum of the non-degeneracy minimum and the confidence-bound existence minimum:

```md
n_{s,min}^{verification}(p_j, α)
  = max(
      n_{s,min}^{nondegenerate}(p_j),
      ceil(log(α) / log(p_j))
    ).
```

Then update the p99 example at lines 3642–3648: at `α = 0.05`, p99 requires 299 successful samples for a non-saturated upper confidence bound, not merely 100.

Also change the table entry at line 3634. Under VERIFICATION, the failure mode should be “configuration error / INCONCLUSIVE”; “explicit saturation report” belongs only to SMOKE or advisory reporting.

### 5. Do not label saturated latency values as “Binomial bound”

**Severity:** Medium-high  
**Lines:** 3512–3521, 3549–3559

**Issue:** §12.4.2 now correctly says that if `k_raw > n_s`, no finite-sample distribution-free upper bound exists. But the bootstrap comparison table still labels the saturated `n_s = 200`, `p = 0.99`, `k = 200` row as a “Binomial bound”. Line 3559 acknowledges that the row is saturated, but the table heading still overclaims.

**Proposal:** Rename the column to distinguish valid bounds from advisory saturated values, or annotate the row directly:

```md
| lognormal | 200 | 0.99 | 448 | 589 | 589 (k_raw > n_s; advisory t_(n_s), saturated: true; not an exact bound) | 0 |
```

This keeps the illustrative comparison without undermining the new existence-gate rule.

### 6. Remove or qualify the latency “between α and 2α” claim

**Severity:** Medium-high  
**Lines:** 3535–3541

**Issue:** The note correctly distinguishes a confidence bound on the baseline quantile from a prediction interval for a future test percentile. However, the statement that false-positive rates are “between α and 2α” is too strong unless it is backed by a specific derivation and design assumptions. The actual breach probability depends on baseline size, test size, percentile rank, and rank convention; for small or comparable test samples it can be materially larger than `2α`.

**Proposal:** Replace the range claim with a qualitative statement:

```md
When baseline and test sample sizes are comparable, test-side sampling
variance can materially increase the no-degradation breach probability
above the nominal α. The increase is not controlled by the baseline
confidence-bound construction alone; it depends on the test sample size,
percentile level, and rank convention. Operators who require calibrated
false-degradation-alarm rates should use a predictive/two-sample
procedure or calibration fixtures, rather than reading the baseline
confidence bound as a predictive test threshold.
```

### 7. Correct the §10.3 layperson-readability Wilson interval

**Severity:** Medium  
**Lines:** 3187–3190

**Issue:** The example reports `99.9% Wilson CI: [0.971, 0.993]` and then reports one-sided Wilson lower bound `≈ 0.9649`. These values are not internally consistent. For `K = 788`, `n = 800`, `p̂ = 0.985`:

- the one-sided lower Wilson bound at `α = 0.001` is approximately `0.9649`;
- using the same `z_{1-α}` symmetrically gives approximately `[0.9649, 0.9937]`;
- a true two-sided 99.9% Wilson interval is approximately `[0.9631, 0.9940]`.

**Proposal:** Either omit the two-sided CI from this block and report only the binding one-sided lower bound, or correct and label the interval explicitly. Recommended wording:

```md
One-sided Wilson lower bound at α_c = 0.001: p̂_{c,L} ≈ 0.9649
```

### 8. Clarify the P4 / MEASURE wording

**Severity:** Medium  
**Lines:** 387–415, 438–441, 949–954

**Issue:** Lines 438–441 say `P4` is “routed out of MEASURE altogether”, but the worked example later says the contract runs three MEASURE experiments, including one for the architectural discharge of the categorical `P4` clause. The intended distinction appears to be: `P4` is not discharged as an end-to-end empirical clause in the primary MEASURE experiment, but the guardrail’s derived empirical false-negative criterion may be evaluated in a separate MEASURE experiment over an adversarial sampling.

**Proposal:** Replace “`P4` is routed out of MEASURE altogether” with:

```md
P4 is routed out of the primary end-to-end MEASURE experiment for
contractual discharge. Its categorical obligation is discharged by the
architectural commitment; the guardrail’s derived empirical criteria
may be evaluated in separate MEASURE experiments over adversarial
samplings.
```

### 9. Add `populationClaim` and weighting metadata to §8.2.1’s required metadata table

**Severity:** Medium  
**Lines:** 2471–2482, 2748–2752, 2818–2820

**Issue:** §8.4.6 says `populationClaim`, `samplingMode`, `weights`, and `strata` are design metadata of §8.2.1. The §8.2.1 table currently includes `samplingMode` and `targetEstimand`, but not `populationClaim` or `weights`; it has `stratumId`, but not a full `strata` / weighting declaration.

**Proposal:** Extend the §8.2.1 table with rows for:

```md
| `populationClaim` | finite-corpus, superpopulation, or no-generalisation; fixes the claim regime of the verdict. |
| `weights`         | Prompt, stratum, production, or severity weights, where the target estimand is weighted. |
| `strata`          | Declared strata and their intended population weights, where stratified sampling is used. |
```

This makes the hard-invalidator language in §8.4.6 operationally auditable.

### 10. Minor wording cleanups to protect the sampling model

**Severity:** Low  
**Lines:** 466–476, 894–900, 3763

**Issue:** A few phrases could be read as drifting back toward per-criterion samplings or treating observational verdicts as inferential claims.

**Proposals:**

- Line 475: replace “the sampling the criterion is exercised against” with “the experiment/sampling in which the criterion is exercised.”
- Lines 896–900: replace “A criterion’s inferential claim is, primarily…” with “A criterion’s verdict or evidence is, primarily…” because the sentence includes observational PASS verdicts.
- Line 3763: replace the stale cross-reference `§8.1` with `§8.4.6`.

### 11. Update document metadata if this is intended as a new issue

**Severity:** Low  
**Lines:** 3–4, 14–24

**Issue:** The document still says `Last updated: 2026-05-14`. If the sampling revision and the new reporting/latency repairs are intended to be traceable as another issue, the document history should record the new revision date and a milestone entry.

**Proposal:** Add a short milestone such as:

```md
| 8 | 2026-05-16 | Sampling terminology and integration pass. Replaced the validation-set primitive with experiment-level sampling; clarified shared sampling within experiments and separate experiments for separate input distributions; repaired transparent-statistics regression wording and latency saturation reporting. |
```

## Release priority

I would handle the corrections in this order:

1. Baseline indexing / experiment-sampling identity.
2. Latency feasibility gate and saturated-bound table wording.
3. §10.3 regression achieved-size reporting.
4. `p*` naming cleanup.
5. Numeric correction to the layperson-readability Wilson interval.
6. P4 / MEASURE wording clarification.
7. Metadata-table and cross-reference cleanup.

After those changes, the document should be statistically coherent enough to serve as the working conformance reference. The core sampling model is now defensible; the remaining work is mostly making sure the surrounding baseline, reporting, and latency sections honour it consistently.
