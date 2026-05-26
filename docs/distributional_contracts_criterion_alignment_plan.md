# Plan: Align `DISTRIBUTIONAL-CONTRACTS.md` with the Companion's Criterion Model

**Status**: Draft for review
**Date**: 2026-05-25
**Target document**: `docs/DISTRIBUTIONAL-CONTRACTS.md` (currently v0.3, → v0.4)
**Oracle document**: `docs/STATISTICAL-COMPANION.md` (v1.3.1)

---

## Why this work is needed

`DISTRIBUTIONAL-CONTRACTS.md` was written when the companion expressed no
notion of a $K > 1$ criterion in a service contract. It models the functional
dimension as **one** Bernoulli stream over a single quality predicate $Q$, and
explicitly treats $Q$ as "a conjunction of arbitrarily many conditions …
evaluated as a single composite assertion" (line 292).

The companion (v1.3.1) now does the opposite: the functional dimension is
partitioned into $m \ge 1$ **criteria**, each its own Bernoulli stream, and the
companion *proves* (§1.4.4) that collapsing them into one conjunction rate masks
rare-but-consequential per-criterion failures. The companion is the oracle: when
the paper and the companion disagree, the paper is what changes.

---

## The gap, point by point

| # | Paper (v0.3) says | Companion now says | Companion ref |
|---|---|---|---|
| 1 | One predicate $Q$, one $p$, one $p_{\min}$, one Wilson bound | Functional dimension partitions into $m \ge 1$ **criteria**, each its own Bernoulli stream $\{X_{i,c}\}$, own $p^*_c$, own $\alpha_c$, own feasibility gate, own verdict; single-$Q$ is the $m=1$ special case | §1.4.1–1.4.3 |
| 2 | $Q$ = conjunction of conditions as a single composite assertion | Aggregating criteria into a conjunction rate **provably masks** rare-but-consequential per-criterion failures (union-bound hiding result; per-criterion rates not identifiable from the aggregate) | §1.4.4 |
| 3 | No vocabulary below "$Q$" | Three primitives: **sampling / criterion / postcondition** — the old $Q$ is a *postcondition*; a *criterion* is the statistical stream hosting 1+ postconditions | §1.4.2 |
| 4 | "Catastrophic" = infra failures (OOM); $Q$ undefined, excluded from denominator; availability tracked orthogonally | **Every in-scope trial counts**; non-value (malformed/timeout/refusal) is an in-scope **FAIL with a reason**, not an exclusion; scope set by an applicability predicate; availability is just **another criterion**, no special denominator handling | §1.4.5a |
| 5 | No categorical/empirical distinction; "catastrophic" is purely operational | **Empirical vs categorical clauses**: categorical (self-harm, PII, illegal content) admit no rate threshold, are discharged **architecturally**, evidenced by derived empirical criteria. "Tolerable failures bounded statistically; intolerable bounded architecturally; architecture bounded statistically." | "Clause Types"; §1.4.5 |
| 6 | Verdict ∈ {PASS, FAIL} | Verdict ∈ {PASS, **FAIL, INCONCLUSIVE**}; **inferential vs observational** criteria (observational = `zeroFailures`, "NO FAILURE OBSERVED", rule-of-three annotation) | §1.4.5 |
| 7 | Flat boolean: $\text{PASS}_{\text{functional}} \wedge \text{PASS}_{\text{latency}}$ | **Structured composite tuple** over per-criterion verdicts (never collapsed); two procedure-specific **Type-I envelopes** (false-compliance, false-degradation-signal) via union bound over $\alpha_c$ | §1.4.6 |
| 8 | "Stipulated vs derived" thresholds | Sharpened to **compliance vs regression** paradigms — two distinct procedures, different decision semantics, integer cutoff $c$ as the binding artefact | "Two Testing Paradigms" |
| 9 | One experiment, one sampling implicit | A contract may run **multiple experiments, each with its own sampling**; criteria within an experiment share its sampling and inferential reach | §1.4.7 |

---

## Scope decisions (confirmed)

- **Depth = middle.** The criterion model, the hiding result, and the structured
  composite verdict get full treatment in the paper — they *are* the paper's
  thesis. The §1.4.5a denominator policy, the feasibility-gate arithmetic, and
  the Type-I envelope bounds are **stated and cited** to the companion, not
  re-derived.
- **Categorical clauses = introduce, defer discharge.** The empirical/categorical
  distinction and the "intolerable failures are bounded architecturally"
  principle land in the paper; discharge mechanics (derived empirical criteria,
  adversarial samplings) are gestured at and deferred, mirroring the companion's
  own forward reference to a forthcoming architectural-commitments chapter.

The paper remains the more *abstract* of the two documents by design — a formal
declaration of what the family is for and how its claims are constructed — and
this revision keeps that character.

---

## Edit plan, section by section

1. **Document History** — add Milestone 4 (2026-05): criterion decomposition +
   empirical/categorical clauses. State that it strictly extends the
   Bernoulli/Wilson foundation ($m=1$ recovers v0.3 unchanged), and **honestly
   flag the one supersession**: the catastrophic-exclusion outcome model is
   replaced, not extended.

2. **Abstract** — note the functional dimension partitions into
   separately-contractual criteria, and the empirical/categorical clause split.

3. **"Two Dimensions of Stochasticity"** — add: criteria refine evidence *within*
   the functional dimension; they do not add dimensions (mirrors companion
   line 62).

4. **"Functional Stochasticity"** — reframe single $Q$ → per-criterion stream
   $p_c \ge p^*_c$; introduce the three primitives (sampling / criterion /
   postcondition).

5. **"Operational Outcome Model"** *(heaviest reconciliation)* — replace
   pass/fail/catastrophic-excluded with the in-scope-trial denominator +
   FAIL-with-reason rule; separate genuine catastrophe (a *defect* that aborts
   the run) from a transform/no-value FAIL; recast availability as its own
   criterion. Cite companion §1.4.5a for the exact rule.

6. **"Q as a Bernoulli Trial"** → **"Criteria as Bernoulli streams"**, plus a new
   subsection carrying the **hiding result** (full treatment) as the
   justification for partitioning.

7. **New section: Clause Types (empirical vs categorical)** — the distinction and
   the "bounded architecturally" principle; discharge mechanics deferred.

8. **New section: Inferential vs Observational Criteria** — three-valued verdict
   (PASS/FAIL/INCONCLUSIVE), observational `zeroFailures`, rule-of-three
   annotation.

9. **"Deriving Thresholds from Baselines"** — $p_{\min} \to p^*_c$; baseline
   vectorised across criteria; body otherwise survives.

10. **"The Composite Verdict"** — full treatment of the structured tuple over
    per-criterion verdicts; Type-I envelopes stated and cited; latency
    conjunction kept as one component.

11. **"Sample Size and Feasibility"** — per-criterion feasibility gates over a
    shared sampling; the limiting criterion; multiple experiments/samplings per
    contract.

12. **"Expressing a Distributional Contract"** — fix line 292 (the now-rejected
    single-composite-assertion claim) to the criterion model.

13. **Conclusion + open questions** — update to reflect the new structure; note
    the availability-as-criterion change closes one current open question.

14. **Consistency pass** — terminology against `GLOSSARY.md` (trial/sample
    synonyms; sampling/criterion/postcondition); bump `Version: 0.4` and
    `Last updated`.

---

## One reconciliation needing care (step 5)

The companion folds *non-value* outcomes (timeout, refusal, malformed output)
into in-scope **FAILs with a reason**, but reserves genuine catastrophe (a thrown
*defect*) for **aborting the run** — whereas v0.3 lumped all "catastrophic"
outcomes together and **excluded** them from the denominator. The rewrite will
draw that line explicitly, consistent with the orchestrator's `Outcome`
convention (expected failures travel as data and count as FAILs; defects throw
and abort).

---

## Out of scope for this revision

- Full architectural-discharge mechanics (deferred, per the categorical-clause
  decision above and the companion's own forward reference).
- Latency-side changes beyond keeping the latency conjunction as one component of
  the structured composite verdict (the latency treatment is otherwise
  current).
- Any change to the companion itself — the companion is the oracle and is already
  at v1.3.1.
