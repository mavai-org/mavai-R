# Statistical Companion — Concise Correction Proposals

Source: `STATISTICAL-COMPANION(3).md` uploaded on 2026-05-16. Line numbers refer to that uploaded Markdown file.

| # | Priority | Source line(s) | Correction proposal |
|---:|:---:|---|---|
| 1 | P0 | 23, 534–538 | Replace “single-trial `K=1` instance” with “single-criterion `m=1` instance.” `K` is reserved for success count; `m` is the number of criteria. |
| 2 | P0 | 648–654 | Split “inferential criterion” verdict logic into **compliance** and **regression** cases. Wilson lower-bound clearance is the compliance rule; regression should be stated as the integer-cutoff rule `PASS iff K_c ≥ c_c`. |
| 3 | P0 | 1918–1941, 1952–1985 | Scope §5.1–§5.4 as **regression execution/power**, or split the section into separate regression and compliance subsections. Current wording is degradation/no-degradation specific and does not describe compliance Type-I/Type-II semantics. |
| 4 | P0 | 1057–1061, 1105–1107, 3018, 3794 | Remove the unlabelled composite Type-I envelope. Replace with labelled envelopes: false-degradation-signal `≤ 0.05` and false-compliance `≤ 0.001` in the worked example; update §10.2 and Appendix A accordingly. |
| 5 | P0 | 2989–2993 | Replace the latency summary formula’s “clamped … exact” wording. Use `k_raw = qbinom(1 - α, n_s, p_j) + 1`; if `k_raw > n_s`, no non-saturated distribution-free bound exists. Do not clamp for VERIFICATION; only display `t_(n_s)` as `saturated: true` in advisory/SMOKE output. |
| 6 | P1 | 390–399, 502–506, 1014–1018 | Reconcile the validation-set model. Replace “a MEASURE experiment evaluates … over a single validation set” with: general model is per-criterion validation sets; sharing a validation set is an optional execution/design choice when criteria intentionally target the same population. |
| 7 | P1 | 2339–2342, 3131–3134 | Correct regression p-values and tail labels. For lines 2339–2342, `P_{0.951}(K ≤ 87)` is about `0.0012`, not `0.026`; `0.026` is the achieved-size calculation for `K < 91`. For lines 3131–3134, the stated lower-tail value `≈ 0.017` is directionally wrong; `P_{p*=0.937}(K ≤ 953)` is about `0.987`, while `≈ 0.019` is upper-tail evidence. Prefer omitting p-values unless the procedure orientation is unambiguous. |
| 8 | P1 | 1042–1043, 3123, 3210–3211, 3233–3238 | Recalculate worked-example statistics. `WilsonLB(0.951; 1000, 0.05)` is about `0.9385`, not `0.937`. For `K=788, n=800, α=0.001`, the one-sided Wilson lower bound is about `0.9649`; the 99.9% two-sided Wilson interval is about `[0.9631, 0.9940]`. To clear `0.98` at observed `p̂≈0.985` requires roughly `7.5k` samples, not `≈2200`. |
| 9 | P1 | 3449–3453, 3621–3626 | Normalize nearest-rank terminology. If using one-based order-statistic rank, use p50 `rank=3`, p90 `rank=9`, p95 `rank=19`, p99 `rank=99`; if using zero-based index, use `2, 8, 18, 98`. Do not mix zero-based index with one-based rank in the same table. |
| 10 | P2 | 60–61, 24 | Reclassify Wilson wording. Line 24 correctly says Wilson is a score-test inversion rather than exact; lines 60–61 should not place Wilson score intervals under “Exact statistical results” without qualification. Move Wilson to operational approximations or state “exactly computed formula with approximate coverage.” |
| 11 | P2 | 812, 3377, 3788 | Add explicit applicability/scope accounting. Since structural non-applicability is not a denominator policy, reports should expose fields such as `scopePredicateId` / `applicabilityPredicate`, `n_applicable`, `n_out_of_scope`, and `validationSetScope`. |
| 12 | P2 | 1105–1107, 3794 | Replace “false-acceptance rate” / “Composite Type-I envelope” terminology with procedure-direction-specific language to avoid mixing false compliance with false degradation alarms. |

## Suggested edit order

1. Fix procedure semantics first: items 2–4 and 12.
2. Fix latency saturation wording: item 5.
3. Recalculate numerical examples: items 7–9.
4. Clean up model metadata and historical wording: items 1, 6, 10, and 11.
