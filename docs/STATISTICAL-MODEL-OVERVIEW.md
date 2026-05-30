# Probabilistic Testing: A Practical Summary of the mavai Statistical Model

This page is the front door to the mavai statistical model. It is intended for engineers, reviewers, product owners, and auditors who need to understand what the model is for, what kind of evidence it produces, and what it deliberately does not claim — without working through the full statistical companion.

The [statistical companion](#reference-materials) remains the canonical reference for formulae, derivations, and edge cases. This document summarises the conceptual frame around it.

## 1. Motivation: deterministic testing breaks at uncertainty's boundary

Traditional software testing assumes that the same input should produce the same output. For deterministic software, that assumption is usually sound: one failing test is meaningful evidence of a defect. But modern AI-backed services, especially LLM-based services, often do not behave that way. Their behaviour is distributional. The same prompt may produce a correct response most of the time, an invalid response occasionally, and a borderline response rarely.

In such systems, uncertainty is not a nuisance to be engineered away. It is an intrinsic property of the system under test. The distribution of outputs *is* the behaviour.

The practical consequence is that the question "did this invocation pass?" is no longer the right question. The better question is: *how often does this service satisfy its contract, under stated conditions, and with what evidential strength?*

## 2. Scope: what the model is for

The mavai model focuses on two quality dimensions:

- **Functional stochasticity** — whether the service produces an acceptable result. Correctness is modelled as repeated pass/fail observations.
- **Temporal stochasticity** — how long successful invocations take. Latency is modelled through empirical percentiles rather than averages.

A contract may exercise either dimension on its own or both together; when both are in scope, the overall verdict requires each to pass, and the model does not assume the two are statistically independent.

What the model is *not* for:

The model does not claim to prove that an AI system is safe, truthful, or correct in any absolute sense. It provides disciplined, repeatable evidence about observed behaviour under stated sampling conditions. It is a testing and evidence framework, not a philosophical theory of AI correctness.

## 3. The core model, in plain language

Each invocation of the service is treated as a [trial]{.gloss term="trial"}. For a given criterion — for example, "the response parses as JSON" or "the answer satisfies a rubric" — the trial either passes or fails. Repeating the invocation over a defined set of inputs produces a count: how many trials passed out of how many attempted. Under stated assumptions of approximate [independence]{.gloss term="independence"} and [stationarity]{.gloss term="stationarity"}, that count can be treated as [binomial]{.gloss term="binomial"} evidence about the service's success rate.

The model uses **[Wilson score bounds]{.gloss term="wilson-score-bound"}** rather than naive observed percentages. This distinction matters: an observed rate is not the same thing as a reliable lower bound. If a service passes 95 out of 100 trials, the model does not pretend the true success rate is exactly 95%. It asks what lower success rate is still compatible with the evidence at the configured [confidence level]{.gloss term="confidence-level"}. That lower bound — not the raw percentage — is what compliance and regression decisions are made against.

## 4. Compliance vs regression

The model distinguishes two testing questions that are often confused.

- A **compliance test** asks whether the service has shown enough evidence to satisfy an external requirement, such as an SLA, SLO, or policy threshold.
- A **regression test** asks whether current behaviour has degraded relative to a measured baseline.

Both use repeated observations and one-sided decision rules, but the interpretation of PASS and FAIL differs. A compliance PASS means evidence supports compliance at the configured level. A regression PASS means no degradation signal was observed at the configured cutoff; it does *not* prove equivalence to the baseline.

Keeping these two questions separate is the single most important discipline for avoiding overclaiming.

## 5. Criteria: why one "overall correctness" number is not enough

Real service contracts rarely contain one kind of failure. A malformed JSON response, a slightly unsuitable tone, a missing required field, and a safety violation are all "failures," but they are not failures of the same kind. Aggregating them into one pass rate can hide exactly the failure mode that matters most.

The mavai model therefore allows a contract to be decomposed into criteria, each with its own threshold, confidence level, input set, and verdict. The combined contract verdict is **structural**: all required criteria must pass. The model does not assume that criteria are statistically independent merely because they are reported separately.

## 6. Empirical vs categorical clauses

A natural objection to any rate-based model is: "surely some failures are unacceptable at any rate." The model takes this seriously and distinguishes two kinds of clause.

- An **empirical clause** says, in effect, "this behaviour must succeed at least this often." It is bounded by a rate.
- A **categorical clause** says, "this must not happen." It is not bounded by a rate at all.

The model does not pretend that setting a threshold to 99.999% converts a categorical obligation into a statistical one. Intolerable failures are handled architecturally — by guardrails, filters, schemas, refusal mechanisms — and those architectural controls can themselves be tested statistically.

> Tolerable failures are bounded statistically; intolerable failures are bounded architecturally; and the architecture itself is bounded statistically.

## 7. What the model offers that ordinary tests cannot

Four claims:

1. It turns flaky-looking behaviour into **measurable** behaviour.
2. It separates **observed rates** from **statistically supported claims**.
3. It records the **assumptions** under which a verdict is meaningful: factor configuration (e.g. model version, temperature), covariates (e.g. model version, deployment region, time of day), baseline age, sampling design, and population claim.
4. It produces **audit-friendly evidence**: counts, thresholds, confidence bounds, cutoffs, caveats, and provenance.

The model's transparent-statistics mode is designed for exactly this audience: auditors, stakeholders, educators, and regulators who need to see the reasoning behind a verdict, not just the verdict.

## 8. What the model does not offer

The model does not remove uncertainty. It measures it.

It does not guarantee that future behaviour will match past behaviour. It assumes, and then documents, the conditions under which repeated observations can be interpreted: approximate independence, stationarity, and a defined input population. Where those assumptions are doubtful, the model does not magically repair them; it surfaces the doubt as part of the evidence trail.

A reported confidence level is therefore not a claim that an individual verdict has a certain probability of being correct. It is a statement about the long-run behaviour of the decision procedure under the stated assumptions. The model is frequentist by default for exactly this reason: it is a discipline for producing defensible evidence, not a machine for producing certainty.

## Glossary

Short definitions of the key statistical terms used above. The full [glossary](https://r.mavai.org/glossary.pdf) lives alongside this overview; only the terms that appear in the body are repeated here.

- **Binomial** — the distribution of the count of passes in a fixed number of independent trials with the same success probability. The companion uses binomial reasoning to relate observed pass counts to the underlying success rate.
- **Confidence level** — the long-run frequency with which the procedure's interval would cover the true parameter if the experiment were repeated under the same conditions. A 95% confidence level is a property of the procedure, not a probability attached to any single verdict.
- **Frequentist** — the school of statistical inference in which probabilities describe the long-run behaviour of procedures over repeated sampling, not degrees of belief about individual events. The mavai model is frequentist by default; this is why a confidence level is a property of the procedure rather than a probability of the verdict.
- **Independence** — the assumption that the outcome of one trial does not influence the outcome of another. Required for binomial reasoning to apply; the model asks for *approximate* independence and records the assumption rather than assuming it away.
- **One-sided decision rule** — a test that asks whether the evidence exceeds (or fails to exceed) a single threshold in one direction only — for example, "is the lower bound on the success rate at least 0.9?" — rather than testing equality against a two-sided interval.
- **Percentile** — the value below which a stated fraction of observations fall. Latency is summarised by empirical percentiles (e.g. p95) rather than means, because the upper tail is what users and SLAs care about.
- **Population** — the set of inputs and conditions about which a verdict is meant to generalise. The model's claims are only as strong as the population definition recorded alongside them.
- **Stationarity** — the assumption that the underlying success rate does not drift over the period during which trials are collected. Like independence, this is assumed and documented, not proven.
- **Trial** — a single invocation of the service, evaluated against a criterion, yielding a pass or a fail. The basic unit of evidence in the functional model.
- **Wilson score bound** — a confidence bound on a binomial proportion that behaves well at extreme rates (near 0 or 1) and at small sample sizes, where the naive normal approximation fails. The model uses the Wilson *lower* bound for compliance decisions on success-rate criteria.

---

For the full derivations, formulae, and the rules each implementation must conform to, see the [statistical companion](#reference-materials). For the language-agnostic conformance fixtures derived from the companion, see [`../inst/cases/`](../inst/cases/).
