# Statistical models of the mavai methodology — an overview

*Statistical Companion 1.5.0 and 1.6.0 (mavai-R 0.11.x and 0.12.x): 1.6.0 keeps the four rules of 1.5.0 and changes only which verdicts bind. A summary for orientation; the companion is normative.*

## Introduction

A mavai test runs a service a number of times and turns what it observes into a verdict. Since Statistical Companion 1.5.0 every verdict is decided by one of four exact rules, each with a versioned identifier that appears in the fixtures and in every verdict record. Two answer *pass-rate* questions and two answer *latency* questions. Each of the two dimensions has a **regression** form (has the service got worse than its measured baseline?) and a **compliance** form (does the service meet a stated requirement?).

All four rules share the same shape. Before any sample runs, they fix an integer bar: a count of successes, or a baseline rank. The verdict compares an observed count with that bar. No rule relies on a normal approximation, and each keeps its false-alarm probability at or below the configured α.

The Wilson score interval, which decided verdicts up to 1.4.1, remains only as a descriptive interval around an observed rate. It decides nothing.

A test's overall verdict combines the pass-rate verdict and the latency verdict. It is PASS if both pass, FAIL if either fails, and INCONCLUSIVE otherwise. Since Statistical Companion 1.6.0 both dimensions count by default, whatever the source of their thresholds; a run-time switch can make the pass-rate dimension, the latency dimension or both advisory, in which case that dimension is still decided by its rule and reported, but it is left out of the overall verdict and cannot fail the test.

## 1. Regression of a pass rate — `regression/fisher`

**Question.** Has the success rate fallen below the baseline's?

**Model.** The baseline (K_b successes in n_b trials) and the test (K_t in n_t) are treated as two independent binomial samples from the same unchanged rate. The one-sided Fisher exact test judges the test against the baseline, conditioning on the pooled successes. Its cutoff *c* is the smallest test count whose hypergeometric lower tail exceeds α. The test PASSES when K_t ≥ c.

**Why this model.** It weighs the uncertainty of the baseline and of the test together. The earlier rule treated the baseline's rate as if it were known exactly, and its false-alarm rate could exceed α. With Fisher, the probability that an unchanged service is flagged, taken over both samples, never exceeds α, at any baseline size and any rate. It is conservative, which is its price. The cutoff also rises steadily with the baseline count: the old jump at a perfect baseline is gone.

**Example.** Baseline 951 of 1000, test of 100, α = 0.05: *c* = 91. At 90 passes, the probability that an unchanged service scores that low is 0.035, inside α, so 90 FAILS; 91 PASSES.

**Sizing.** Design power (before a baseline exists) and resolved power (against the observed baseline) are reported separately. A baseline too small to reach the required power is refused as BASELINE_TOO_SMALL. A test larger than its baseline is refused as TEST_LARGER_THAN_BASELINE.

## 2. Compliance of a pass rate — `compliance/exact-binomial`

**Question.** Does the service demonstrably meet a stated requirement p_req (a contract, an SLA or a policy)?

**Model.** The test's successes follow Binomial(n, p). The null hypothesis is that the service is *at or below* the requirement, so PASS is positive evidence of compliance. The bar is k_min, the smallest count that a service exactly at p_req reaches with probability no more than α. The test PASSES when K ≥ k_min.

Equivalently, the one-sided Clopper–Pearson lower bound on the rate reaches p_req. The Clopper–Pearson interval is the exact interval for a binomial proportion, found by inverting the binomial test.

**Why this model.** It is exact at every n, so a service falsely demonstrates compliance with probability at most α. A normative test therefore has no upper size limit.

**Example.** Requirement 0.90, 100 samples, α = 0.01: k_min = 97. A service at exactly 0.90 reaches 97 or more only 0.8% of the time, so observing 93 FAILS, even though 0.93 exceeds 0.90. The requirement is the claim; the count is the evidence the claim needs.

**Feasibility.** Even a perfect run can pass only if n ≥ ⌈log α / log p_req⌉. For 0.999 at α = 0.05 that is 2995 samples. A smaller verification design is refused as COMPLIANCE_INFEASIBLE.

## 3. Regression of latency — `latency/precedence`

**Question.** Has the service become slower at a given percentile than its baseline?

**Model.** The model is distribution-free: no shape is assumed for latencies. The rule takes the baseline's n_b latencies in order and the test's percentile (nearest rank, over the latencies of samples that passed every functional criterion). It computes, for each baseline rank *k*, the exact probability that an unchanged service's test percentile would exceed the *k*-th baseline latency. That probability is the precedence (breach) probability. The threshold is the smallest rank at which it is at most α, and the test PASSES when its percentile does not exceed that baseline value.

**Why this model.** The earlier order-statistic bound treated the baseline quantile as fixed. For a future test, its breach probability could reach 46%. Precedence accounts for the randomness of both samples and is exact for continuous latencies (conservative under ties).

**Example.** A p95 test of 100 against 1000 baseline latencies: the threshold is the baseline's 976th fastest latency, not its own p95 (the 950th). That margin is what keeps false alarms within α.

**Saturation.** If no rank reaches α, the constraint cannot be judged and the result is INCONCLUSIVE, marked *saturated*. This happens when the test contributes too few latencies against too small a baseline. For example, at p95 with 17 test latencies against 95 baseline latencies, even the baseline's slowest latency is exceeded with probability 0.15 by an unchanged service.

## 4. Compliance of latency — `latency/compliance-exact-binomial`

**Question.** Does a stated latency requirement hold, for example "p90 ≤ 600 ms"?

**Model.** The requirement is recast as a proportion: at least a fraction *p* of successful latencies lie within τ. The count Y of latencies at or below τ is then judged by the same exact binomial rule as in section 2, with p_req = p over the realised number of successful latencies. The test PASSES when Y ≥ y_min.

**Why this model.** Comparing the observed percentile with τ directly is a coin toss at the boundary: it passes about 62% of the time (p95, 100 latencies). The count rule gives the same α guarantee as pass-rate compliance. The raw percentile comparison is still reported, labelled advisory; it decides nothing.

**Example.** 93 successful latencies, requirement p90 ≤ 600 ms, α = 0.05: y_min = 89. With 80 of 93 within 600 ms the requirement FAILS. If too few latencies arrive for any count to pass, the result is INCONCLUSIVE.

## Summary

| Rule | Dimension | Question | Bar | Refusals and special cases |
|---|---|---|---|---|
| `regression/fisher` | pass rate | worse than baseline? | cutoff *c* | TEST_LARGER_THAN_BASELINE, BASELINE_TOO_SMALL |
| `compliance/exact-binomial` | pass rate | meets requirement? | k_min | COMPLIANCE_INFEASIBLE |
| `latency/precedence` | latency | slower than baseline? | baseline rank | INCONCLUSIVE when saturated |
| `latency/compliance-exact-binomial` | latency | meets latency requirement? | y_min | INCONCLUSIVE when too few latencies |
