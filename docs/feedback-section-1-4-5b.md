# Re-evaluated feedback on §1.4.5b

**Document reviewed:** `STATISTICAL-COMPANION(7).md`  
**Section reviewed:** `§1.4.5b Conditional containment model for architectural discharge`  
**Related sections considered:** clause forms, observational criteria, guardrail scenarios, population-claim discipline, and multi-criterion contract treatment.

---

## Overall assessment

Keep §1.4.5b. It adds the missing probabilistic formalisation for what the surrounding sections had been doing architecturally: a categorical prohibition is not converted into a finite-sample “zero failures proved” claim; it is discharged by an architectural boundary, and the measurable residue is the conditional probability that prohibited content survives that boundary.

This fits the document’s existing position that categorical clauses admit no rate threshold, cannot be discharged by the rate-bounded apparatus, and are answered architecturally.

The core model is sound:

$$
p_{\mathrm{residual}}
=
p_{\mathrm{harm}}
\cdot
p_{\mathrm{miss}\mid\mathrm{harm}}.
$$

That formula is not an independence assumption. It is the multiplication rule applied to the event “harm is generated and the guardrail misses it.”

The section also correctly states that the guardrail experiment bounds the containment term, not the upstream prevalence term.

The earlier feedback should be revised in one important respect: the document already contains the bridge I previously suggested between observational zero-failures evidence and inferential guardrail-sensitivity evidence. §1.4.5b explicitly says the observational criterion remains deterministic, and that a population-level statement may be supported by pairing it with an inferential sensitivity criterion over the same harmful challenge sampling.

The remaining feedback is therefore narrower: claim calibration, vocabulary consistency, population-claim discipline, and sampling design.

---

## Main issues to address

### 1. Clarify “contract cannot carry” vs “contract cannot discharge through the generator alone”

The opening of §1.4.5b says the prohibition is “not a clause the service’s own contract can carry.” That is stronger than the surrounding model supports.

Earlier, the document defines the service contract as the conjunction of expectations, and the categorical-clause section explicitly treats categorical obligations as clauses carried by the contract but discharged architecturally.

The issue is not that the contract cannot carry the clause. The issue is that a stochastic generator cannot empirically validate a “never” obligation by finite sampling.

Suggested replacement:

```markdown
The categorical clause may appear in the application-level service contract, but it is not discharged by estimating the generator's own success rate. The stochastic generator can only be measured; it cannot empirically prove a "never" claim. The discharge therefore belongs to the composed application architecture: generator plus architectural boundary.
```

This preserves the intended distinction without disrupting the document’s vocabulary of service contracts, criteria, and clauses.

---

### 2. Add joint confidence accounting when both terms are estimated

The section correctly says that an end-to-end claim requires a separate estimate or bound on \(p_{\mathrm{harm}}\). The worked example then says that if a sentinel stream established \(p_{\mathrm{harm}} = 0.001\), the residual harm probability would be bounded by:

$$
0.001 \times 0.000167.
$$

That is valid only if \(0.001\) is treated as a known value or an externally accepted deterministic bound. If it is estimated from data, the residual bound must account for uncertainty in both factors.

Suggested patch:

```markdown
Where both upstream prevalence and guardrail miss probability are estimated, the end-to-end bound must account for uncertainty in both terms. Let \(U_{\mathrm{harm}}(\alpha_H)\) be an upper confidence bound on the upstream probability that the generator emits prohibited content, estimated from a compatible pre-guardrail production, sentinel, or representative sampling. Let \(U_{\mathrm{miss}}(\alpha_M)\) be an upper confidence bound on the guardrail's conditional miss probability over the harmful-output population to which the claim is extended. Then

\[
p_{\mathrm{residual}}
\leq
U_{\mathrm{harm}}(\alpha_H)
\cdot
U_{\mathrm{miss}}(\alpha_M).
\]

Absent a stronger justified dependence model, the joint coverage is at least \(1 - \alpha_H - \alpha_M\) by the union bound. If \(p_{\mathrm{harm}}\) is inserted as a point estimate rather than an upper confidence bound, the resulting product is a scenario calculation or plug-in estimate, not a confidence-bound claim.
```

This also aligns with the document’s existing preference for dependence-robust union-bound accounting over unjustified independence assumptions.

---

### 3. State that \(p_{\mathrm{harm}}\) must be measured pre-guardrail

The table says \(p_{\mathrm{harm}}\) may be evidenced by production monitoring, sentinel streams, representative production sampling, or not estimated. That is fine, but only if the measurement observes the generator’s candidate output before the guardrail suppresses or transforms it.

Post-guardrail monitoring estimates \(p_{\mathrm{residual}}\), not \(p_{\mathrm{harm}}\).

Suggested insertion:

```markdown
A production estimate of \(p_{\mathrm{harm}}\) must observe the generator's pre-guardrail candidate output, or an equivalent shadow/sentinel stream. Post-guardrail production monitoring estimates residual exposure, not upstream harmful-output prevalence.
```

This is operationally important because many production safety monitors only see what reached the user.

---

### 4. Separate the two safety samplings more explicitly

There is still a conceptual tension between §1.4.8 and §1.4.5b.

§1.4.8 defines \(V_{\text{probe}}\) as adversarial **inputs** designed to elicit self-harm advice, and the observational no-self-harm criterion runs against that probe set.

§1.4.5b’s worked example defines \(V_{\mathrm{harm}}\) as harmful **candidate outputs** presented to the guardrail.

These estimate different quantities.

For adversarial prompt inputs:

$$
V_{\text{probe-input}}
\quad\Rightarrow\quad
P(\text{harm reaches user} \mid \text{adversarial prompt}).
$$

For harmful candidate outputs presented directly to the guardrail:

$$
V_{\text{harm-candidate}}
\quad\Rightarrow\quad
P(\text{guardrail misses} \mid \text{harmful candidate presented}).
$$

Both are useful, but they should not share the same conceptual label.

Suggested terminology:

```markdown
- \(V_{\mathrm{redteam\text{-}input}}\): adversarial prompts submitted to the generator-plus-guardrail application, used for end-to-end diagnostic probing.
- \(V_{\mathrm{harm\text{-}candidate}}\): harmful candidate outputs submitted directly to the guardrail, used to estimate conditional guardrail sensitivity.
```

That distinction makes the conditional-containment model much harder to misread.

---

### 5. Make `populationClaim` binding before using Wilson in the worked example

The worked example applies a Wilson lower bound to 99,990 / 100,000 harmful candidates. The numerical result is correct under a superpopulation interpretation:

$$
L_s(0.05) \approx 0.999833,
$$

so:

$$
U_{\mathrm{miss}}(0.05) \approx 1.67 \times 10^{-4}.
$$

But the text should explicitly say whether \(V_{\mathrm{harm}}\) is:

1. a finite corpus evaluated exhaustively;
2. a sample from a challenge distribution; or
3. exploratory no-generalisation evidence.

This matters because the document elsewhere states that an exhaustive finite-corpus evaluation has no sampling uncertainty for the corpus rate, and Wilson/binomial confidence intervals do not apply to that finite-corpus estimand.

A Wilson bound is appropriate only if the harmful candidates are treated as a sample from a named superpopulation, or if a partial finite-corpus sampling approximation is being disclosed.

Suggested insertion before the Wilson calculation:

```markdown
The following Wilson calculation assumes \(V_{\mathrm{harm}}\) is declared as a superpopulation sampling from the named harmful-candidate distribution. If instead \(V_{\mathrm{harm}}\) is an exhaustively evaluated finite corpus, the corpus sensitivity is known exactly as \(99{,}990 / 100{,}000\), and the Wilson interval is not a confidence interval for that finite-corpus estimand. Any extension beyond the corpus requires a separate superpopulation claim.
```

This would make §1.4.5b consistent with the document’s own population-claim discipline.

---

### 6. Do not force guardrail criteria to have empirical-origin thresholds

The Clause Forms section currently says the guardrail component’s false-negative and false-positive performance re-enters the contract as rate-bounded clauses with empirical-origin thresholds.

That is too narrow. A guardrail sensitivity threshold may be normative: imposed by safety policy, regulator, SLO, medical-risk control, customer contract, or release gate.

It may also be empirical if the purpose is regression monitoring against a prior guardrail baseline.

Suggested replacement:

```markdown
The component's performance re-enters the contract as one or more ordinary rate-bounded criteria, typically covering false-negative and false-positive behaviour over appropriate challenge samplings. Their threshold origin may be normative, where a safety policy mandates a minimum containment level, or empirical, where the criterion is used for regression against a measured baseline.
```

This keeps the document’s threshold-origin axis clean: “rate-bounded” is the clause form; “normative” or “empirical” is the threshold origin.

---

### 7. Bring stratification and target estimands into the guardrail section

A harmful challenge set of 100,000 candidates will almost certainly not be homogeneous. It may contain self-harm, medical misinformation, jailbreaks, PII leakage, illegal-content requests, severity bands, languages, prompt styles, and template families.

A pooled sensitivity estimate can hide weak containment in a rare but critical stratum.

The document already has machinery for this: `targetEstimand`, `weights`, `strata`, and `populationClaim` are used to fix what population the per-criterion rate estimates, and clustered or stratified estimators are required where plain binomial aggregation is not warranted.

Suggested addition:

```markdown
For harmful challenge samplings, the verdict must declare the target estimand: call-weighted, prompt-weighted, stratum-weighted, severity-weighted, or no-generalisation. Where the harmful-candidate set is stratified by failure mode or severity, the report should either provide per-stratum sensitivity bounds or state the weighting scheme by which the pooled sensitivity is interpreted. A pooled bound must not be read as a guarantee for every harm stratum unless the per-stratum evidence supports that reading.
```

For safety work, this is not just statistical neatness. It prevents a guardrail from looking excellent overall while failing a small high-severity class.

---

### 8. Add the clustering caveat to the 100,000-candidate example

The worked example treats \(n_H = 100{,}000\) harmful candidates as if they were independent Bernoulli trials. That may be reasonable, but it should be declared.

If the 100,000 candidates are generated from a smaller number of prompt templates, model outputs, paraphrase families, or synthetic augmentations, the effective evidence may be far below 100,000.

The document already says that material cluster structure invalidates plain binomial calibration for VERIFICATION unless an approved clustered, stratified, hierarchical, or design-based estimator is used, or the claim is demoted.

Suggested addition:

```markdown
The Wilson calculation assumes the harmful challenge trials are treated as independent Bernoulli observations under the declared target estimand. Where the challenge set contains repeated templates, paraphrase families, batch effects, or other material clustering, the guardrail-sensitivity criterion must either use an estimator appropriate to that design or demote the claim according to the population-claim rules of §8.4.6.
```

---

### 9. Generalise carefully to multiple guardrails

The current section models one guardrail. That is fine, but real architectures often have several boundaries: prompt classifier, retrieval filter, output classifier, schema gate, deterministic deny-list, human escalation, and policy router.

Add a short caution:

```markdown
For multiple architectural boundaries, the containment term is

\[
P(\text{all relevant boundaries miss} \mid \mathrm{harm}).
\]

Individual miss probabilities must not be multiplied unless a justified conditional-independence model has been declared. Without such a model, the chain rule form is

\[
P(M_1 \cap M_2 \cap \cdots \cap M_r \mid H)
=
P(M_1 \mid H)
P(M_2 \mid H, M_1)
\cdots
P(M_r \mid H, M_1,\ldots,M_{r-1}).
\]
```

This is consistent with the document’s broader refusal to infer probabilistic independence from logical composition.

---

### 10. Symmetrise the false-positive treatment

The false-positive paragraph is directionally right: a guardrail that blocks everything has perfect sensitivity and no utility, so specificity or false-positive behaviour must be measured separately.

It would be stronger if it mirrored the sensitivity section formally:

```markdown
For a non-harmful challenge sampling of size \(n_N\), let \(K_A\) be the number of non-harmful candidates allowed by the guardrail. Define

\[
\hat{t} = \frac{K_A}{n_N}
\]

as the observed specificity. An inferential specificity criterion may report the one-sided Wilson lower bound \(L_t(\alpha)\), yielding the upper confidence bound on the false-positive probability

\[
U_{\mathrm{fp}}(\alpha) = 1 - L_t(\alpha).
\]

Safety-class contracts should report the sensitivity/miss bound and the specificity/false-positive bound as separate criteria, over separately named harmful and non-harmful challenge samplings.
```

This makes over-refusal evidence as inspectable as under-blocking evidence.

---

## Minor editorial fixes

- Replace “second service” with “architectural boundary” or “guardrail component.” The Clause Forms section deliberately includes guardrails, deterministic filters, hard schema constraints, and refusal classifiers; not all of these are naturally described as services.
- Fix the double space in “must name  the challenge distribution.”
- In the worked example, change “established \(p_{\mathrm{harm}} = 0.001\)” to either “established an upper bound \(U_{\mathrm{harm}} = 0.001\)” or “estimated \(\hat p_{\mathrm{harm}} = 0.001\).” The former licenses a bound; the latter licenses only a plug-in estimate.
- Consider renaming \(K_B\) to \(K_{\mathrm{block}}\). `B` is understandable, but a mnemonic subscript is clearer in a document already carrying many overloaded symbols.

---

## Suggested compact patch

```markdown
Where an end-to-end production claim is required, the containment
experiment alone is insufficient. Let \(U_{\mathrm{miss}}(\alpha_M)\)
be an upper confidence bound on the guardrail's conditional miss
probability over the declared harmful-candidate population. Let
\(U_{\mathrm{harm}}(\alpha_H)\) be an upper confidence bound on the
generator's upstream prohibited-content prevalence, measured from a
compatible pre-guardrail production, sentinel, or representative
sampling. Then

\[
p_{\mathrm{residual}}
\leq
U_{\mathrm{harm}}(\alpha_H)
\cdot
U_{\mathrm{miss}}(\alpha_M).
\]

Absent a stronger justified dependence model, this product has joint
coverage at least \(1-\alpha_H-\alpha_M\) by the union bound. If the
upstream term is supplied as a point estimate rather than an upper
confidence bound, the product is a scenario calculation, not a
confidence-bound claim.

The two samplings must also be named separately. A red-team input
sampling estimates end-to-end behaviour under adversarial prompts; a
harmful-candidate sampling estimates the conditional sensitivity of
the guardrail given prohibited content has reached the boundary. The
latter does not estimate upstream harmful-output prevalence, and the
former does not by itself isolate guardrail sensitivity.
```

---

## Bottom line

§1.4.5b is worth keeping. It correctly turns the architectural-discharge idea into a conditional containment model without pretending to prove “zero failures.”

The most important remaining fix is to tighten the end-to-end claim boundary:

- a guardrail experiment bounds \(p_{\mathrm{miss}\mid\mathrm{harm}}\), not \(p_{\mathrm{harm}}\);
- if both terms are estimated, both need confidence accounting;
- the population claims must be compatible;
- the sampling-design assumptions must be explicit.
