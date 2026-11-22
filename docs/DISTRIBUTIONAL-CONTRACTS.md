---
title: "Distributional Contracts for Stochastic Systems"
author: "Version 0.9.2 · last updated 2026-11-22 · Copyright © 2026, Michael Franz Mannion BSc (Hons) MBA"
---

## 1. Document History

This is a working document: a formal declaration of what the mavai family of frameworks is for and how its statistical claims are constructed, expected to evolve as the methodology matures.

| # | Date | Milestone |
|---|------|-----------|
| 1 | **2026-01** | **First issue.** Functional stochasticity only: a Bernoulli model over a quality predicate $Q$, aggregated binomially, with Wilson-based thresholds. |
| 2 | **2026-03** | **Temporal dimension added.** Latency as empirical percentiles. |
| 3 | **2026-04** | **Stricter latency treatment.** The tripartite contract (correctness / availability / latency-given-success) and an exact order-statistic bound. *Service* replaces *system* for the artefact under evaluation. |
| 4 | **2026-05** | **Criterion decomposition.** The functional dimension becomes a conjunction of criteria, each its own Bernoulli stream, with a tuple-valued composite verdict; rate-bounded and categorical clause forms; every trial counts toward its criterion's denominator. |
| 5 | **2026-07** | **Behavioural populations** (§4.8). |
| 6 | **2026-11** | **Exact decision rules and composition.** Fisher's exact test for degradation, the exact binomial test for compliance (Wilson describes only); aligned with Statistical Companion 1.7.x; new chapter on composed and guarded services; the contract verdict given a chapter of its own; sample sizing left to the Statistical Companion. Prose tightened and repetition removed. |

Milestone 4 supersedes the exclusion of no-testable-value outcomes, and milestone 6 the use of Wilson as a decision rule; the Bernoulli/binomial foundation of milestone 1 stands.

## 2. Abstract

In stochastic systems, correctness cannot in general be characterised solely by the outcome of a single execution, since individual executions may legitimately vary even when the system is behaving acceptably overall.

This paper extends Bertrand Meyer's Design by Contract [1][2] by lifting postconditions from Boolean predicates over individual executions to statistical assertions over repeated executions. We introduce the notion of a distributional contract, under which the quality of a stochastic service is characterised along two orthogonal dimensions: functional stochasticity — whether the service produces acceptable results with sufficient probability — and temporal stochasticity — whether it responds within acceptable time bounds with sufficient probability. These dimensions require distinct statistical treatments but together address the two most fundamental quality concerns for a stochastic service.

Within the functional dimension, the single notion of an acceptable result is itself refined into a conjunction of separately-checkable *criteria*, each assessed as its own statistical stream rather than folded into one aggregate rate. The obligations a contract carries are further partitioned by form into *rate-bounded* clauses, whose tolerable failure rate is bounded statistically, and *categorical* clauses, which admit no rate and are evaluated by observation — the rate-bounded threshold being, on a separate axis, either normative or empirical in origin. Finally, services composed into chains and guarded architectures are treated as distributional contracts in their own right, measured end to end rather than inferred from their components.

Since the quantities of interest are not directly observable, they are estimated empirically from repeated executions and assessed using conservative statistical bounds. This yields an operational basis for making statistically grounded assertions, at a defined confidence level, that a stochastic service satisfies its contractual obligations. The model is implemented by the mavai family of probabilistic testing frameworks — punit for Java and feotest for Rust — which turn its elements into constructs a developer declares and a test runtime enforces (§10).

The statistical foundations on which these methods rest — the exact decision rules (the one-sided Fisher exact test for degradation from a baseline, the exact binomial test for compliance with a requirement), the feasibility constraint, the per-criterion model, and non-parametric latency inference — are developed and justified in full in the Statistical Companion [3], the canonical methodology document of the mavai family. The present paper builds on that work: it supplies the contractual framing and describes each method to the depth needed to convey the model, deferring the formal statistical justification to the companion.

## 3. Two Dimensions of Stochasticity

In deterministic software, correctness is defined pointwise: for any input satisfying the precondition, the postcondition must hold for the resulting output. A stochastic service breaks this model: one execution can fail its postcondition while the service, judged over many executions, is doing what it should.

The idea of assessing stochastic systems through repeated execution and statistical inference has precedent in the tradition of statistical model checking, where Younes and Simmons [4] showed that time-bounded probabilistic properties can be assessed by hypothesis testing over sampled executions, trading absolute certainty for bounded decision error, and Legay, Delahaye, and Bensalem [5] surveyed this approach as a scalable alternative to numerical model checking. We extend this line of reasoning from formal stochastic models to operational software services, and from temporal-logic property satisfaction to a contractual framing: the notion of a contract is lifted from individual executions to distributions over executions.

The contract idea has been lifted before. Benveniste et al. [6] generalised it from Meyer's routine-level preconditions, postconditions, and invariants to a meta-theory of contract-based *system* design, in which a component's guarantees hold relative to explicit assumptions about its environment and contracts support refinement and composition. The present work makes a complementary move along the same axis, but in a statistical rather than a model-theoretic register: it lifts the contract from deterministic, compositional obligations to operational, black-box obligations over a stochastic service, where the environmental assumptions become the sampling and covariate conditions under which evidence is drawn, and satisfaction becomes a statistically qualified verdict over repeated executions rather than a pointwise or purely compositional one.

The uncertainty of a stochastic service has two dimensions, each with its own form of distributional contract.

**Functional stochasticity** is whether the service produces an acceptable result. Given identical input, it may produce correct output on some executions and incorrect output on others, so each execution's outcome is binary and random, modelled as a Bernoulli process (§4). The contract asserts that the service succeeds with at least a minimum acceptable probability.

**Temporal stochasticity** is how long the service takes to respond. A service that typically responds in 200 milliseconds may occasionally take several seconds; each execution yields a duration, and latency is a distribution rather than a fixed property. The contract asserts that a given percentile of that distribution falls below a bound — for example, that the 95th percentile does not exceed 500 milliseconds — and is assessed by non-parametric percentile inference (§6).

The dimensions are orthogonal *contractual concerns*, not independent random variables. A fast response can be incorrect and a slow one correct, so a contract that addresses only one leaves the other unexamined. Yet the two are often correlated — timeouts are correctness failures, refusal paths may be fast, slow successes can be traded into failures — so the methodology assumes no statistical independence between them: it evaluates each separately and composes their verdicts by logical conjunction (§8.1).

## 4. Functional Stochasticity

In deterministic Design by Contract, a postcondition is a Boolean predicate that must hold on *every* execution. The functional contract for a stochastic service lifts this requirement: the obligation is not that every execution satisfies a postcondition, but that it is satisfied with at least a minimum acceptable probability. A contract is rarely a single such proposition, however: it is a conjunction of separately-checkable expectations — that a response parses, that required fields are present, that it leaks no prohibited material — and this section keeps them apart as separate criteria. The decomposition refines the evidence within the functional dimension; it is not a third dimension of stochasticity, since every criterion uses the same binomial machinery.

### 4.1 Postconditions, Criteria, and Samplings

The functional dimension rests on three primitives, each with exactly one job.

A **postcondition** is a named predicate over the output of a single execution: it decides, for one response, whether one observable property holds. *Response parses as JSON*, *required fields are present*, *the answer is readable by a layperson*, *the advice does not suggest self-harm* — each is a postcondition. It carries no threshold and no statistical configuration of its own. This is exactly Meyer's postcondition, with one change: it is not expected to hold on every execution, but its satisfaction on each execution is observed and recorded.

A **criterion** is the unit of statistical evaluation. It hosts one or more postconditions and, on each execution, yields a single pass/fail outcome — the conjunction of its hosted postconditions' verdicts. A criterion declares the threshold it is judged against, its confidence level, and the mode under which it is evaluated. The contractual obligation is stated *per criterion*: where a contract with a single quality predicate $Q$ asserts $p = \mathbb{P}(Q=1) \ge p_{\min}$, a criterion $c$ asserts

$$p_c \;=\; \mathbb{P}(\text{criterion } c \text{ holds}) \;\ge\; p^*_c,$$

with its own minimum acceptable rate $p^*_c$ and its own confidence level. Two postconditions whose failures carry materially different consequences belong in two different criteria, never merged into one stream (§4.4, §4.5).

A **sampling** is the list of $N \ge 1$ inputs that an experiment or test posts to the service. The sampling is shared across every criterion the contract exercises in a single run: one list of inputs produces one response per input, and every criterion is evaluated against every response. The input distribution the sampling is drawn from is part of the contract's definition, not a parameter of the run: what a criterion such as *layperson-readable* demands depends on the inputs it is judged on. A baseline experiment and the tests judged against it draw independently from that one distribution. Evidence about a different distribution comes from a different contract; the contracts that evidence one service over several input populations form a **family of contracts** (Statistical Companion §1.4.7).

A verdict is first a claim about the sampling it ran over. Extending it to a wider population is a claim the contract declares: the sampling is a *finite corpus*, whose verdict speaks only to its own inputs; a *sample* from a stated population, such as the production input distribution; or an illustration that generalises to nothing. Curated safety-probe and red-team sets are usually finite corpora, and reading their rates as population rates is the commonest error of this kind (Statistical Companion §1.4.7, §8.4.6).

### 4.2 The Per-Criterion Bernoulli Model

Each criterion $c$ defines its own Bernoulli stream. On each execution $i$ of the sampling it produces an indicator $X_{i,c} \in \{0,1\}$, modelled exactly as the single-criterion trial:

$$X_{i,c} \sim \text{Bernoulli}(p_c), \qquad K_c = \sum_{i=1}^{n_c} X_{i,c} \sim \text{Binomial}(n_c, p_c), \qquad \hat{p}_c = K_c / n_c,$$

where $n_c$ is the number of executions in the run, the sampling size $N$. Since $p_c$ is not directly observable it is estimated from such a stream, and the methodology runs two of them. An **experiment** exercises the criterion over $n_{\text{exp}}$ trials and reports the baseline estimate $\hat{p}_{c,\text{exp}}$; this baseline is not itself the bar a later run must clear.

A subsequent **probabilistic test** exercises the same criterion over its own sampling — of size $n_{\text{test}}$, typically much smaller than $n_{\text{exp}}$ — and re-estimates the rate as $\hat{p}_{c,\text{test}}$. Against a baseline, the test is decided by the one-sided Fisher exact test, which compares the test's success count with the baseline's and reduces to an integer cutoff on the former: if the test's count reaches it, there is no evidence of degradation and the criterion passes (§5.2; Statistical Companion §3.4).

This constraint — that the service is an opaque executable whose properties must be inferred from observed behaviour rather than from an inspectable internal model — is shared with the black-box probabilistic verification tradition. Sen, Viswanathan, and Agha [7] consider statistical model checking of black-box probabilistic systems where properties are inferred from observed traces, and Aichernig and Tappler [8] extend this to stochastic systems with probabilistic behaviour. The present work inherits their black-box constraint but reframes the objective: rather than establishing reachability or property satisfaction within automata-based frameworks, the goal is to assess whether the service meets a contractual quality obligation.

A contract with a single criterion is simply the $m = 1$ case of this model, in which the per-criterion stream coincides with the single Bernoulli model. **From here on, the single-criterion notation $X_i$, $\hat{p}$, $p_{\min}$, $\alpha$ used elsewhere in this paper should be read as the per-criterion $X_{i,c}$, $\hat{p}_c$, $p^*_c$, $\alpha_c$ for any criterion $c$ a contract declares: the criterion's decision rule, the feasibility gate, and the verdict rule all apply unchanged to each stream.** In this way Design by Contract is generalised from pointwise correctness to distributional correctness, criterion by criterion. How the streams compose into one verdict, and the resulting false-alarm budget, are set out in §8.

The independence and stationarity assumptions apply *per criterion*: within a criterion, the per-execution indicators are treated as i.i.d. under the input distribution the sampling represents. Across criteria the methodology assumes no independence — an execution that returns malformed output may fail several criteria at once — and the consequence of that dependence for the composite verdict is disclosed rather than assumed away.

### 4.3 The Operational Outcome of a Trial

In operational settings the raw outcome of an execution is not a clean pass/fail. A criterion may find an acceptable value, a value that is present but unacceptable, or no testable value at all — the service timed out, returned malformed output, omitted required material or refused, or a transform step the criterion applies failed to convert the response.

An execution that yields no testable value is an *expected, in-band* outcome of a stochastic service, and it counts as a failure of the criterion. Excluding it from the denominator would let a service flatter its measured rate by failing to respond, hiding a structurally unhealthy service behind a healthy-looking pass rate.

A criterion is evaluated on every execution of the sampling, and on each it yields exactly one of two outcomes:

- **PASS** — the criterion produced a value to test and its postconditions hold.
- **FAIL** — anything else. A FAIL carries a diagnostic **reason** that does not change the arithmetic: *condition* — the postcondition was evaluated and did not hold; or *transform / no-value* — no value to test could be produced, so the postcondition was never reached.

Every execution therefore counts toward the criterion's denominator $n_c$, which is simply the sampling size $N$; the success count $K_c$ is the number that PASS, and $\hat{p}_c = K_c / n_c$. The one place a denominator legitimately narrows is the latency dimension, which is summarised over successful executions only (§6.2). The accounting of per-trial outcomes and their reasons is detailed in the Statistical Companion (§1.4.5a).

This accounting makes a quality criterion's rate **end-to-end**: because a non-response already fails any criterion that needed the response, unavailability is reflected with no special handling. A contract that wants availability as a *distinct, visible* metric simply declares it as its own criterion — for example a zero-failures or rate criterion over *the service returned usable output* — standing alongside the others rather than altering their denominators. Availability is therefore ordinary structural composition, not a denominator mechanism or a separate sub-contract.

One outcome lies outside this accounting: a **catastrophe** — a failure not of the *service* but of the *testing machinery itself*, such as an `OutOfMemoryError`, a `StackOverflowError`, or process termination, after which the run cannot continue. A catastrophe aborts the run and is investigated as a defect; it is not a sample and contributes to no denominator. A transform step that fails to convert a response is not a catastrophe: the harness is alive, and the criterion simply had no value to test.

### 4.4 Why a Single Aggregate Rate Is Inadequate

Consider aggregating the per-criterion indicators into a single conjunction rate — one stream, one $p$, one verdict. A union-bound argument shows what such an aggregate conceals. Let $\{C_1,\dots,C_m\}$ be the contract's criteria with per-trial indicators $X_{i,c}$, and define the conjunction indicator $X_i = \prod_{c=1}^{m} X_{i,c}$ with $p = \mathbb{P}(X_i = 1)$ — the rate at which every criterion holds simultaneously on a trial. By the union bound applied to the complementary events,

$$1 - p \;=\; \mathbb{P}\bigl(\exists\, c : X_{i,c} = 0\bigr) \;\le\; \sum_{c=1}^{m} (1 - p_c),$$

with equality if and only if the per-criterion failure events are disjoint. The aggregate failure rate is thus bounded above by the sum of per-criterion failure rates and, in typical cases, dominated by the largest of them.

The consequence is a masking effect. If one criterion $c^*$ fails far more rarely than the others — $1 - p_{c^*} \ll \max_{c \ne c^*}(1 - p_c)$ — then $1 - p$ is essentially insensitive to $1 - p_{c^*}$: a change in the rare criterion's failure rate of any magnitude smaller than the dominant criterion's sampling noise leaves the aggregate unmoved. The conjunction rate cannot detect movement in the rare criterion. The masking is purely a property of frequency — rare failures are absorbed by frequent ones regardless of what they *mean* — and that is precisely the hazard, because high-consequence failures (self-harm advice, a double-charge, an unsafe instruction) are in practice deliberately *rare*. Rarity is what makes them invisible to aggregation; gravity is what makes that invisibility intolerable.

Nor is the masking recoverable after the fact. Given only an observed conjunction rate $\hat{p}$, the per-criterion rates are not identified: any allocation of $1 - \hat{p}$ among the criteria that respects the union bound is consistent with the observation. Recovering them requires per-criterion attribution at trial-record time — the wide trial record the per-criterion model demands. An archive that did not preserve per-criterion outcomes per trial cannot be decomposed retrospectively.

Per-criterion partitioning is therefore the only faithful representation of a contract whose postconditions defend against failure modes of differing consequence. Where the postconditions are genuinely interchangeable — equivalent consequence, comparable frequency, the same inputs — a single aggregated stream remains adequate, and that is exactly the $m = 1$ case recovered unchanged. A contract may still report an aggregate $\hat{p}$ as a descriptive dashboard statistic, but it is not threshold-bearing: thresholds are not derived from it, and verdicts are not framed against it.

### 4.5 Criterion Design Rule

The criterion is the unit of statistical inference, and a criterion may host more than one postcondition, conjoining their per-trial verdicts into a single pass/fail stream. That conjunction can reintroduce the very masking the per-criterion partition exists to prevent, one level lower: a rare, high-consequence postcondition folded in beside a frequent, low-consequence one is again absorbed into the latter's failure rate. The partition is therefore disciplined by a design rule.

> Postconditions may be hosted in a single criterion only when their failures share the same consequence class, the same remediation path, and broadly comparable expected frequency. Postconditions that differ along any of these axes belong in separate criteria.

Even where postconditions are legitimately conjoined, the per-postcondition outcomes are retained in the wide trial record demanded above, so that a criterion-level failure can be attributed to the postcondition that caused it: the conjunction governs the verdict, not what is recorded.

### 4.6 Clause Forms: Rate-Bounded and Categorical

Two questions about a clause must be kept apart: *what kind of proposition does it state?* — its **form** — and, if it carries a threshold, *where did that threshold come from?* — its **origin**. The form is the subject of this section; the origin axis is developed in §5. The two axes are independent, and the word *empirical* names a value on the origin axis — it is not the name of a form.

A **rate-bounded clause** states a proposition of the shape *criterion $c$ shall hold at rate at least $p^*_c$, with confidence $1 - \alpha_c$*. It is discharged statistically, by the machinery this paper develops, and it is the form every criterion discussed so far has taken. Its threshold $p^*_c$ has one of two **origins**, and the two are genuinely different inferential acts:

- **normative** (equivalently *stipulated*): the threshold is *given* — by a contract, SLA, SLO, policy, or regulation — and the question is whether the service *meets* it. Nothing is estimated about where the threshold should sit; it is mandated.
- **empirical**: the threshold is *derived from a baseline experiment*, and the question is whether the service has *regressed* from the rate it previously achieved.

*Empirical* is not the name of the rate-bounded form, because a rate-bounded clause may equally carry a normative threshold that was never measured. The mavai frameworks (§10) keep the two as separate authoring constructs rather than two settings of one knob: a normative target is declared as *meeting* a required rate, and an empirical baseline as an *empirical* derivation. The compliance and regression paradigms of the threshold chapter are exactly these two origins seen from the decision side.

A **categorical clause** states an obligation that admits no rate threshold at all: *the service shall not emit self-harm advice*, *shall not leak personal data*, *shall not produce illegal content*. It is satisfied or violated in kind, not in rate. No sample budget redenominates it as a rate-bounded claim — observing zero failures in $n$ trials yields at best a rule-of-three upper bound of $\approx 3/n$ on the failure rate, which reaches zero only in the limit — and letting a rate-bounded threshold approach 1 does not promote it into a categorical one; it merely tightens a bound that can never reach certainty. The frameworks recognise the categorical clause in exactly one form: a **zero-failures** declaration, by which the developer states the expectation while explicitly abandoning any pretence of establishing a statistical lower bound. Such a clause is evaluated *observationally* — it reports whether any failure was seen, never an estimated rate (see the next section): a single observed violation falsifies it, and a run without one shows only that none was seen. The two forms are mutually exclusive: every clause is either rate-bounded or categorical, never both. A contract may comprise several criteria, and each criterion is free to state its clause in either form.

A separate question is how a prohibited outcome is kept from the consumer when the service itself cannot be tested for it: a language model cannot realistically be coaxed into producing harmful health advice often enough for its reliability in avoiding it to be established. The answer is architectural: a dedicated component interposed between the service and its consumer — a deterministic filter or a refusal classifier, for example — commonly called a **guardrail**. Unlike the service, the guardrail can be tested directly, because its input is the content itself. It is a separate component with its own contract, not a criterion of the service's contract, and whether one is needed has no bearing on where a categorical clause may be stated. The guarded service, the residual risk it leaves and the record of the commitment are treated as a composition in *Guarded Composition* (§9.9). The methodology, in one line:

> *Tolerable failures are bounded statistically; intolerable failures are prohibited categorically; and what cannot be tested in the service is tested in its guardrail.*

### 4.7 Inferential and Observational Criteria

Two levels of outcome must be kept distinct. On a **single sample**, a criterion's evaluation is **PASS** or **FAIL** (§4.3); there is no third per-sample outcome, and a sample with no testable value is a FAIL with its reason. Only the criterion's **run-level verdict**, aggregated over the whole sampling, admits a third value, **INCONCLUSIVE**: a non-determination by the procedure, never a statement about any one sample (Statistical Companion §1.4.5, §1.4.5a). A criterion reaches its run verdict in one of two modes.

An **inferential criterion** estimates the rate $p_c$ of the population its sampling is declared to represent from the run's per-sample PASS/FAIL outcomes and tests it against a threshold. Its run verdict is PASS when the evidence clears the threshold at confidence $1 - \alpha_c$, FAIL when it does not, and INCONCLUSIVE when the run cannot support a determination — because there were no trials ($n_c = 0$), or because no count the run could have produced would pass the compliance test. A configuration that could never support a verdict is refused before the run instead, as a configuration error rather than a verdict (§7). Where the threshold is empirical in origin and no baseline matches the covariates in force, the test either proceeds against the nearest baseline with that divergence carried on its verdict, or declines to resolve, as the project's covariate policy decides (Statistical Companion §1.4.5, §1.5.3). This is the mode for the question *what is the true rate of behaviour $c$, and does it clear the demanded threshold?*

An **observational criterion** asks only whether any failure was seen in the run. It estimates no parameter and carries no threshold:

$$\text{verdict}(c) = \begin{cases} \text{PASS} & \text{if } K_c = n_c \text{ and } n_c > 0 \\ \text{FAIL} & \text{if } K_c < n_c \\ \text{INCONCLUSIVE} & \text{if } n_c = 0. \end{cases}$$

A passing observational verdict at $n_c = 1000$ says exactly: *no failure of $c$ was observed in 1000 trials*. It entails no bound on the true population rate. This is the honest expression of a zero-failures expectation: an inferential test against a threshold of $1.0$ cannot pass at any finite sample size, since at a required rate of 1 a run with no failures has probability 1 under the exact binomial test: it is never surprising, so no count is ever evidence of compliance. The frameworks therefore do not accept $1.0$ as an inferential threshold and does not silently convert an observational criterion into one. For transparent reporting only, a passing observational verdict may be annotated with the rule-of-three upper bound of $\approx 3/n_c$ under an explicitly stated i.i.d. Bernoulli model, and high-consequence criteria may report *NO FAILURE OBSERVED* in place of PASS — a label change that leaves the verdict semantics untouched.

This is the mode in which a categorical clause is evaluated, on whichever contract it is stated. Where a guardrail is used, its evidence is first its own rate-bounded contract (§9.9); a zero-failures verdict over an adversarial sampling complements it, reporting that no prohibited outcome got through in that run, and no more.

### 4.8 Behavioural Populations

A service may be held to more than one contract. Because a contract's input distribution is part of its definition (§4.1), each contract fixes its own population, and the contracts that evidence one service form a family of contracts.

One reason a service needs several contracts is that it realises more than one **behavioural population**: distinguishable classes of input for which it produces structurally different responses — a support agent that returns a refund confirmation for one class of request and a product answer for another, say. A postcondition written against one population's response shape is not false of the other's responses but inapplicable to them. Evaluating it there, and folding the result into the criterion's Bernoulli stream, would corrupt $\hat{p}_c$ with trials that carry no information about the postcondition's subject — a category error, not a failure observation. Each behavioural population therefore has its own contract, with its own sampling and criteria.

Membership of a population is a property of the *input*, determined before invocation: the populations partition the input space, and each population's sample size is a design choice fixed before any run. Classifying trials by *observed response* — membership knowable only after the service has answered — does not define a population in this sense: the per-class count would become a random quantity needing its own prevalence estimate and bound. Defining populations by input makes that machinery unnecessary, since every population's sample size is known before the run.

Each contract's verdict is the composite verdict of §8.1 over its own sampling. A view across a family is reporting, not a verdict, and the samplings are never pooled (Statistical Companion §1.4.7).

## 5. Thresholds and Their Decision Rules

A rate-bounded criterion's threshold $p^*_c$ has one of the two origins of §4.6. A normative threshold expresses what the service *ought* to achieve, independently of what it has been observed to achieve; no experiment is required, and the question is only whether the service meets it (§5.4).

Often no external threshold exists. The service's acceptable performance level is not known in advance and must be discovered empirically. This is the common case for systems whose behaviour is inherently stochastic, where the developer cannot stipulate a success rate from first principles but must instead observe what the service actually achieves under controlled conditions. Services built on Large Language Models are natural candidates for this mode: an LLM invoked with a fixed system prompt, model version, and temperature setting may be reasonably expected to exhibit a consistent level of stochasticity over time, making the baseline estimate a stable foundation for subsequent evaluation — provided the operational profile remains comparable.

### 5.1 The Baseline Experiment

To establish an empirical threshold, a baseline experiment is conducted: the service is executed $n_{\text{exp}}$ times under controlled conditions, and the success count $k$ is recorded together with $n_{\text{exp}}$, giving the observed success rate $\hat{p}_{\text{exp}} = k / n_{\text{exp}}$. Both counts are kept, not only the rate: the decision rule a later test applies needs them, since a baseline of 95 successes in 100 and one of 950 in 1000 have the same rate but very different evidential weight. This point estimate serves as the best available characterisation of the service's current behaviour. It is important to note, as Musa [9] established in the context of software reliability engineering, that any such empirical estimate is meaningful only relative to the distribution of inputs under which the service is exercised. A baseline measured under one operational profile may not generalise to another — an insight that motivates the covariate tracking of §10.5.

Because every criterion is exercised against the same shared sampling, a single baseline experiment records a success rate *per criterion*: the baseline is vectorised across the contract's criteria, $\{\hat{p}_{\text{exp},c}\}$, and a threshold $p^*_c$ is derived for each criterion independently by the construction below.

However, $\hat{p}_{\text{exp}}$ cannot be used directly as a threshold for subsequent evaluations. The point estimate is subject to sampling variability: a different run of the same experiment would yield a different value of $\hat{p}$. Setting $p_{\min} = \hat{p}_{\text{exp}}$ would amount to requiring the service to meet a standard that is an artefact of a particular sample, not a stable property of the service. In practice, this leads to frequent false alarms — tests that reject a service whose true success probability has not changed, simply because the test sample happened to fall below the experimental estimate.

### 5.2 Conservative Threshold Derivation

The solution is to derive, in place of a rate the test must clear, an integer cutoff on the test's success count that allows for the sampling variability of *both* runs. The methodology derives it with the one-sided Fisher exact test, from the baseline's success and trial counts, the **test** sample size $n_{\text{test}}$, and the error level $\alpha$. The criterion passes when the test's success count reaches the cutoff. For example, from a baseline of 951 successes in 1000 trials, a test of 100 trials at $\alpha = 0.05$ passes with at least 91 successes.

The cutoff answers the question *given this baseline and a test of this size, how few successes could an unchanged service produce by sampling variation alone?* Both samples enter it: the baseline is itself a finite sample, and a small baseline is an uncertain reference. If the service has not changed, the probability that the test falls below the cutoff — a false degradation signal — is at most $\alpha$, with the baseline and the test both treated as random draws. Only genuine degradation, not sampling noise in either run, should trigger a failure.

How far the cutoff sits below the baseline's rate depends on both sample sizes. A larger test or a larger baseline yields a cutoff closer to that rate; a smaller one yields a more forgiving cutoff, so that the noisier comparison does not trip a false alarm. A passing test means there is no evidence of degradation at this cutoff, not that equivalence to the baseline has been proved.

This paper names the rule; the Statistical Companion develops it: the test and its calibration in §3.4 (*Regression Cutoff*), the derivation of the cutoff at the moment a test resolves against its baseline in §1.5.4, and reference values in §3.5.

### 5.3 Choice of Decision Rule

The methodology uses an exact rule for each question. The Wilson score lower bound [10] is an approximation, accurate for describing a rate, but it does not keep false alarms within the stated level in every regime, so it describes results and carries no verdict.

- **Degradation** from a measured baseline is decided by the one-sided Fisher exact test [11], which compares the test's success count with the baseline's (§5.2; companion §3.4).
- **Compliance** with a given requirement is decided by the exact binomial test, whose interval form is the one-sided Clopper–Pearson bound [12] (§5.4; companion §3.6).

Both rest on the same Bernoulli and binomial model as before, and both reduce to an integer count the test's successes must reach. Neither depends on a normal approximation.

The Wilson score interval keeps one role: it is the interval reported beside a verdict to describe the observed rate. For that purpose it remains the better choice over the Wald normal approximation, which collapses to a zero-width interval at a 100% success rate and can place bounds outside $[0,1]$ near the extremes (Brown et al. [13]; Agresti and Coull [14]). No verdict depends on it. The Statistical Companion gives the descriptive interval in §2.3.1 and the decision rules in §3.4 and §3.6.

### 5.4 Compliance with a Stipulated Threshold

A **stipulated** (normative) threshold $p_{\text{req}}$ is given, and the test is decided by the exact binomial test: it passes when its success count reaches the smallest count that would be improbable, at error level $\alpha$, for a service whose rate is only $p_{\text{req}}$ — affirmative evidence that the service meets the requirement, with the probability of a false compliance claim at most $\alpha$ at every sample size. A service may be held to a stipulated and a derived threshold at once (§5.2), as two criteria over the same postconditions. The two procedures control different errors and carry different meanings (companion §3.2): a stipulated failure is evidence the service does not meet an external requirement, while a derived failure is evidence it has degraded from its measured baseline.

## 6. Temporal Stochasticity

This section develops the contract over the temporal dimension of §3: response time.

### 6.1 Why Latency Demands Distributional Reasoning

A single observed response time tells us almost nothing about a service's temporal behaviour. Service latency distributions are typically right-skewed, often multimodal, and frequently heavy-tailed. A service with a 200ms mean may have a 95th percentile of 350ms or of 2000ms — the mean alone cannot distinguish the two. What matters operationally is not the average case but the tail: the experience of the worst-served fraction of requests. This is why latency assertions are expressed not in terms of means but in terms of percentiles.

### 6.2 The Latency Population

Executions that failed the contract's correctness criteria, for either reason of §4.3, are excluded from the latency population. A fast failure (an immediate validation rejection at $t \approx 0$) and a slow failure (a timeout at $t = 30{,}000\text{ms}$) both reflect error paths, not the latency of successful operation. Including them would contaminate the distribution with durations that are artefacts of failure modes rather than measurements of service responsiveness.

The latency distribution is therefore conditional on success. Let $\mathcal{L} = \{ t_i : X_i = 1 \}$ be the set of durations from executions that satisfied the contract's correctness criteria, and let $n_s = |\mathcal{L}|$. The distributional contract over temporal stochasticity applies to this conditional distribution $T \mid X = 1$, not to the unconditional distribution over all attempts.

Conditioning on success is the correct modelling choice, but it creates a hazard that must be named explicitly. Because the latency assertion applies only to the successful subset, a service could in principle improve its observed percentiles by converting slow-successes into fast-failures — moving mass from the right tail of $T \mid X = 1$ into the failure column entirely. This is not a defect of the conditioning; it is why the correctness criteria and the latency assertion are evaluated **jointly, by logical conjunction** (§8.1), each correctness criterion enforced at its own threshold. An operator writing a latency assertion should make the accompanying correctness threshold tight enough to catch such a trade: a latency improvement bought with a correctness regression is not an improvement of the contract.

Organisations that require an unconditional response-time guarantee — that is, a bound on latency marginalised over *all* attempts, including those that fail — should express this as a joint constraint on the correctness criteria and the latency assertion, rather than attempt to redefine the latency population itself. The conditional distribution $T \mid X = 1$ is the only population for which non-parametric percentile inference over successful-response latency is meaningful.

### 6.3 Empirical Percentile Estimation

The contract is assessed using non-parametric empirical percentiles computed directly from the observed order statistics, so that no assumption need be made about the shape of the underlying latency distribution.

Let $t_{(1)} \leq t_{(2)} \leq \cdots \leq t_{(n_s)}$ be the order statistics of the successful latencies. For a percentile level $p \in (0, 1]$, the empirical percentile is:

$$Q(p) = t_{(\lceil p \cdot n_s \rceil)}$$

This is the nearest-rank method: the $p$-th percentile is the smallest observed value such that at least a proportion $p$ of observations fall at or below it.

Strictly speaking, the order-statistic arguments of §6.5 assume a continuous latency distribution, under which ties occur with probability zero. Wall-clock latencies reported at millisecond resolution induce ties, and the constructions remain valid — the bounds become marginally *more* conservative under ties, not less — at the cost of a small loss of tightness. Practitioners who require tight bounds should report latencies at microsecond resolution.

### 6.4 The Latency Assertion

A contract's latency assertion specifies a set of percentile constraints:

$$\mathcal{C} = \{ (p_j, \tau_j) : j = 1, \ldots, m \}$$

where $p_j$ is a percentile level (e.g., 0.50, 0.90, 0.95, 0.99) and $\tau_j$ is the maximum acceptable value at that percentile. For each constraint, the assertion states, informally:

$$\text{PASS}_j \iff Q(p_j) \leq \tau_j$$

The latency assertion is satisfied if and only if all constraints are met:

$$\text{PASS}_{\text{latency}} = \bigwedge_{j=1}^{m} \text{PASS}_j$$

As with functional stochasticity, the threshold $\tau_j$ may be stipulated externally — by an SLA specifying, say, that the 95th percentile latency must not exceed 500ms — or derived empirically from a baseline experiment. A breach means what it means on the functional side (§5.4): non-compliance against a stipulated threshold, degradation against a derived one. A test does not pass merely because its observed percentile is at or below $\tau_j$. The observed percentile varies from run to run, so a service whose true percentile sits exactly at $\tau_j$ would pass that comparison more often than not. Instead, against a stipulated threshold the test counts the successful latencies at or below $\tau_j$ and passes only if that count is large enough to show, by the exact binomial test (§5.4), that at least a fraction $p_j$ of all latencies fall within $\tau_j$ (companion §12.3.4). Against a derived threshold it applies the precedence rule of §6.5.

### 6.5 Threshold Derivation for Latency

When $\tau_j$ is derived from a baseline, the observed percentile $Q_{\text{baseline}}(p_j)$ is, like $\hat{p}_{\text{exp}}$ in the functional case, a point estimate subject to sampling variability, and using it directly as a threshold would again invite false alarms. As on the functional side, the threshold must allow for the variability of both the baseline and the test.

The methodology derives it with a precedence rule, a classical two-sample comparison through order statistics (Nelson [15]; Balakrishnan and Ng [16]), resting on the distribution-free behaviour of order statistics (Conover [17]; Hollander and Wolfe [18]). The threshold is one of the baseline's own observed latencies, the $k$-th smallest, with $k$ the smallest rank for which an unchanged service — baseline and test latencies drawn from one distribution — would see the test's percentile exceed it with probability at most $\alpha$. The test passes when its observed percentile is at most that latency. The rule is exact for continuous latency distributions and conservative under ties, assumes nothing about the distribution's shape, and yields an observed value in milliseconds, with no rounding, normal approximation or density estimate. When no rank achieves $\alpha$ — the baseline is too small for a test of this size at this percentile — the result is INCONCLUSIVE, never a silently misleading threshold. The Statistical Companion develops the rule in §12.4.2.

A further consequence of the empirical approach is that small sample sizes trivially exclude higher percentiles from meaningful evaluation. The $p$-th percentile requires at least $\lceil 1 / (1 - p) \rceil$ observations before it is distinct from the sample maximum: for $p = 0.95$ this is 20, for $p = 0.99$ it is 100. When $n_s$ falls below such a threshold, the corresponding percentile constraint cannot be assessed at all. And even at the boundary — $n_s = 100$ for $p = 0.99$, for instance — the percentile estimate rests on a single observation separating it from the maximum, which is hardly a basis for a meaningful contractual judgement. In practice, reliable percentile estimation requires $n_s$ to be substantially larger than the theoretical minimum, so that the estimate is determined by a region of the distribution rather than by an isolated order statistic. The frameworks enforce these minimums, with an engineering minimum of 5 for the median, as a non-degeneracy gate. The gate is necessary but not sufficient: a baseline-derived threshold also needs the precedence rank above to exist for the test that will run, and where it does not, the verdict is INCONCLUSIVE (Statistical Companion §12.5.2, §12.5.3).

## 7. Sample Size and Feasibility

Sample size, threshold and error level are bound together: fixing any two determines the third, so a contract cannot be at once stringent, highly confident and cheap to verify. The software reliability literature makes the same point for conventional software — testing methods are to be judged by the reliability they deliver in operation [19], and success on carefully chosen examples does not by itself justify confidence in future behaviour [20] — and it bears harder still on stochastic services, where no single execution is decisive. How an experiment or test is sized — from its cost, from the risk it must control, or from a threshold dictated from outside — what power a design attains, and the minimum sample size below which a stipulated threshold cannot be met even by a flawless run are set out in the Statistical Companion (§5, §6). Sizing plans a test; it never decides one. Three consequences bear on how contracts are structured.

**The constraint is per criterion.** Each criterion $c$ binds its own triple $(n_c, p^*_c, \alpha_c)$. A contract's criteria are all evaluated on every sample of a run, so an experiment or test against the contract has a single size $N$, set by the **limiting criterion**: the one whose triple demands the largest $N$. A low-baseline or tightly thresholded criterion can therefore dominate the cost of every run against the contract, which per-criterion sizing surfaces where an aggregate would hide it. A criterion that needs evidence about a different input distribution does not inflate this $N$: it belongs to a different contract with its own sampling (§4.1), and a family of $E$ contracts has total sample budget $\sum_e N_e$, its limiting criterion identified contract by contract.

**A test declares its intent.** A VERIFICATION test sets out to demonstrate its requirement. A SMOKE test is declared too small to demonstrate anything — a quick check in a pre-commit hook or a nightly canary, say — and FAILs only on evidence that the service falls short of its requirement, so its PASS means only that no such evidence was found (Statistical Companion §5.7).

**A design that cannot support its verdict is refused before it runs.** A VERIFICATION test against a stipulated threshold that even a flawless run could not pass, and a regression test planned larger than the baseline it consumes, are configuration errors (`COMPLIANCE_INFEASIBLE`, `TEST_LARGER_THAN_BASELINE`), not verdicts (Statistical Companion §5.7.1, §3.4).

## 8. The Contract Verdict

A contract is decided by many rules: one for each functional criterion and one for each latency constraint. This chapter sets out how their verdicts combine into the contract's verdict, what Type-I error that verdict carries, and when its failure fails the test.

### 8.1 The Structured Verdict

The contract's verdict combines its per-criterion functional verdicts with its latency verdict. Crucially, this is *not* a single flattened boolean: a flat PASS/FAIL surface would obscure exactly the per-criterion outcomes the criterion decomposition exists to expose. The contract verdict is a **structured tuple** over the per-criterion verdicts $V_c \in \{\text{PASS}, \text{FAIL}, \text{INCONCLUSIVE}\}$, with the structural composite

$$
V_{\text{contract}} = \begin{cases}
\text{PASS}         & \text{if } \forall\, c : V_c = \text{PASS} \\
\text{FAIL}         & \text{if } \exists\, c : V_c = \text{FAIL} \\
\text{INCONCLUSIVE} & \text{otherwise,}
\end{cases}
$$

and the per-criterion verdicts retained in full on the composite so that a consumer reads the conclusion and its supporting evidence in one place. The latency constraints form a second composite of the same shape, and the test's verdict composes the two dimensions by the same rule: a service is acceptable only if every functional criterion passes *and* the latency constraints hold (Statistical Companion §12.3.2).

A payment API that succeeds 99.5% of the time but takes 30 seconds for 1% of requests therefore fails its contract just as surely as one that returns incorrect results — and, under the decomposition, a contract in which a rare safety criterion has regressed fails even when an aggregate rate would still look healthy.

### 8.2 Type-I Envelopes

Because a contract aggregates many per-criterion tests, its false-alarm budget is itself an aggregate — and it has two directions, because the two procedures guard against different errors. The methodology discloses two **Type-I envelopes**: a *false-compliance* envelope over the compliance criteria, bounding the probability of declaring some requirement met that is not, and a *false-degradation-signal* envelope over the regression criteria, bounding the probability of signalling degradation where none occurred. By the union bound each is at most the sum of its criteria's $\alpha_c$, under arbitrary dependence among them; the bound rests on each criterion's own rule keeping its error within its $\alpha_c$, which the exact rules of §5 guarantee. Latency decisions enter the same two envelopes according to their threshold's origin. Observational criteria enter neither, since they carry no $\alpha$, and neither does a criterion decided under SMOKE intent, whose $\alpha$ bounds a false FAIL and whose PASS claims no compliance (§7).

The envelopes are reported on the composite verdict as disclosed properties, not driven to a target by shrinking the per-criterion $\alpha_c$: a safety criterion held at $\alpha = 0.001$ keeps that level because the consequence of a false claim of safety demands it, and uniformly dividing the $\alpha_c$ would sap exactly the power such a criterion most needs. The Statistical Companion gives the envelopes their precise form in §1.4.6.

### 8.3 Enforcement

Every assertion a contract declares is **enforced** by default — functional criteria and latency constraints alike, whatever the origin of their thresholds — so that its failure fails the test. One set of assertions holds in every environment; what differs between environments is the evidence an assertion is judged against, such as the baseline a test consumes. A run-time switch, never a per-test setting, can make the functional dimension, the latency dimension or both *advisory*: an advisory dimension is still decided by its rules and reported beside the verdict, but it cannot fail the test (Statistical Companion §12.6).

## 9. Distributional Contract Composition

The preceding sections define a distributional contract for a stochastic service considered as a single contractual unit. In practice, however, many stochastic applications are not a single service invocation. They are chains, graphs, or guarded architectures in which the output of one component becomes the input to another, and in which deterministic and stochastic components together determine the behaviour ultimately observed by the consumer.

A voice-command application may pass an audio sample through speech-to-text, translation, routing, command construction, and a user-interface API. A health-advice application may pass a generated candidate response through a safety boundary before it is shown to the user. A retrieval-augmented generation service may compose retrieval, ranking, prompt construction, model invocation, citation checking, and final formatting. In each case the behaviour of interest is not exhausted by any one component. The application-level claim is a claim about the composition.

This chapter introduces **distributional contract composition**: the construction of a new distributional contract from two or more component contracts, in such a way that the composed service can be exercised and evaluated as a contract in its own right while preserving the statistical evidence and diagnostic structure of its component stages.

The purpose of composition is not to manufacture an end-to-end probability from component pass rates. That operation is usually unjustified. The purpose is to make the composed stochastic mechanism itself an object of empirical investigation.

> Compose contracts to measure compositions, not to multiply component rates.

The chapter states the contractual meaning of composition, what any composition must preserve, and the principal cautions that prevent misuse. It introduces no new statistics: a composed contract is evaluated with the models the Statistical Companion [3] already defines, and where this chapter names a statistical quantity it cites the companion for its treatment. The guarded architecture of §9.9 — a generator followed by a safety boundary — is the composition used when a service cannot be tested for an outcome it must never produce, and the companion's model of its residual risk (§1.4.5b) is the statistical side of that arrangement.

### 9.1 A Service Contract as a Statistical Interface

A service contract is not merely a declarative description of expected behaviour. Once exercised, it carries statistical state: per-criterion outcomes, thresholds and their error levels, verdicts, latency observations, the covariate profile, the baseline it was judged against, its factor record, failure reasons, and the population claim it makes. It is therefore useful to regard a service contract as a **statistically characterised interface**.

At the type level, a service contract has the shape of an arrow from inputs to outputs:

$$C : I \rightsquigarrow O$$

where the wavy arrow indicates that the mapping is operational and possibly stochastic rather than a deterministic function. The contract receives an input of type $I$, invokes a service, produces an outcome over type $O$ — a value, or a failure carrying its reason — and evaluates contractual criteria over that outcome. The contract is not only the invocation; it is the invocation together with the obligations and evidence by which the invocation is judged.

Two contracts are type-compatible for sequential composition when the output type of the first can be supplied as the input type of the second:

$$C_1 : A \rightsquigarrow B, \qquad C_2 : B \rightsquigarrow C.$$

Their sequential composition has the operational shape:

$$C_2 \circ C_1 : A \rightsquigarrow C.$$

For a chain of $k$ stages,

$$C_i : I_i \rightsquigarrow I_{i+1}, \qquad i = 1,\ldots,k,$$

the composite contract is:

$$C = C_k \circ \cdots \circ C_2 \circ C_1 : I_1 \rightsquigarrow I_{k+1}.$$

This notation states only the operational shape. It does not state that the statistical evidence carried by the components can be arithmetically combined into a valid end-to-end claim. Type compatibility permits execution; it does not by itself justify reuse of evidence.

### 9.2 The Motivation for First-Class Composition

Without first-class composition, a developer evaluating a stochastic pipeline is left with two poor alternatives.

The first is to hand-write the pipeline as ordinary orchestration and test only the final output. That gives an end-to-end result, but loses the internal statistical anatomy of the run: which stage failed, which criteria were violated, how many samples each stage saw, which covariates were in force, which baseline was implicated, and whether an upstream component shifted the input distribution seen by a downstream one.

The second is to test each component separately and then reason informally from the component reports. That preserves some local evidence, but invites an invalid inference: if each stage has a reported pass rate, the temptation is to combine those rates as though they were independent probabilities over a common population. For stochastic pipelines this is rarely justified. A downstream component is not exercised on the same population in the composed service as it was in its standalone experiment; it is exercised on the distribution of values emitted by the upstream component.

First-class composition exists to avoid both failures. It constructs a composite contract that can be sampled end to end, while preserving the stage-local evidence needed for diagnosis. The composite service becomes empirically addressable as a single contractual object, and the component contracts remain visible as trace-bearing substructures inside it.

The resulting question is no longer:

> What can be calculated from the reported component rates?

but rather:

> What does this composed stochastic mechanism do under this sampling, this factor configuration, these covariates, and this composition policy?

That is the central operational value of composition.

### 9.3 The Composite Contract

A composed contract is itself a distributional contract. It has an input type, an output type, a contract identity, a sampling, criteria, latency observations where applicable, covariates, a factor record, baseline provenance, feasibility constraints, and a run-level verdict. It can therefore be subjected to the same experiment-to-test workflow as any other contract.

The composite contract may carry three classes of criteria.

First, **end-to-end composite criteria** declared by the composite contract itself. These are criteria over the final result of the composed service, judged relative to the original input. In a voice-command pipeline, for example, the final criterion may be that the resulting screen state corresponds to the user's intended command. This is not a property of any one stage. It is a property of the composition.

Second, **cross-stage criteria** that inspect relationships between intermediate artefacts. A router's chosen application area may need to be consistent with the command emitted by a handler; a translated transcript may need to preserve the intent needed by the router; a generated command may need to be traceable to the original input rather than to a hallucinated intermediate value. These criteria are not purely stage-local and not purely final-output criteria. They require access to the composition trace.

Both classes are the composite contract's own criteria. Each is evaluated on every sample of the composite sampling — a sample that never produced the intermediate artefact a criterion needs is a FAIL of that criterion with its reason, exactly as in §4.3 — and each is decided like any criterion of any contract: by the Fisher test against a baseline or the exact binomial test against a requirement, under the test's declared intent, enforced by default, entering the envelope of its direction (§5, §8.2; Statistical Companion §1.4.6, §3.4, §3.6).

Third, **stage-local criteria** inherited from the component contracts: the criteria by which each stage judges its own output — a transcript is non-empty, a translation is in English, a router selects a valid application area, a command constructor emits valid JSON. Inside the composite they are essential for attribution: they explain how the composed run behaved internally, and they identify where failures entered or propagated. But they are diagnostics, not verdicts of the composite: a stage is evaluated only on the samples that reached it, and §9.5 explains why that count cannot carry an inferential claim. Each component contract keeps its own verdicts where it is evaluated standalone, over its own sampling.

A composition that declares only end-to-end criteria is complete; cross-stage criteria need a trace-aware criterion model and may come later. Their place in the theory is nevertheless clear: they are contractual criteria over the composed execution, not post hoc debugging annotations.

### 9.4 Trace Preservation

Composition must be trace-preserving. Without trace preservation, the feature degenerates into ordinary service orchestration.

A naïve implementation might invoke the first component, extract its value, pass it to the second component, and return only the final result. That is operationally sufficient to run the pipeline, but contractually insufficient. It discards the very evidence that gives distributional composition its meaning.

A composed sample must preserve, at minimum:

- the original input;
- the final outcome;
- the ordered stage identities;
- the input supplied to each reached stage;
- the outcome produced by each reached stage;
- each stage's postcondition and criterion results;
- each stage's duration and resource usage where measured;
- the total duration and resource usage of the composed invocation;
- the factor and covariate context under which the stages were invoked;
- the reason for any failure or non-reach.

The final consumer of the composite service may see only its outcome. The evaluation must retain the richer trace. The trace is the object from which stage-local summaries, reach counts, failure provenance, latency allocation, and cross-stage criteria are computed.

This is the difference between invoking a pipeline and composing contracts. Invocation connects values. Contract composition preserves meaning.

### 9.5 Failure Propagation and Denominators

Sequential composition introduces a denominator distinction that does not arise for a single service contract.

Consider:

$$A \rightsquigarrow B \rightsquigarrow C.$$

If the first stage fails to produce a usable value, the second and third stages are not invoked. At the composite level the sample counts as a failure: the composed service did not produce the final value required by its contract. At the stage level, however, only the first stage was reached. The downstream stages were not passed malformed values; they were not passed values at all.

Two denominators must therefore be kept separate.

The **composite denominator** is the number of attempted end-to-end samples — the size of the composite sampling. Every input contributes to it, and one that never produced a final testable value is a FAIL of every composite criterion that needed it: the accounting of §4.3, applied to the composition (Statistical Companion §1.4.5a).

A **stage-reach denominator** is the number of composite samples that reached a given stage:

$$n^{\mathrm{reach}}_j = |\{i : \text{sample } i \text{ reached stage } j\}|.$$

The two are different kinds of number. The composite denominator is fixed by design before the run. The stage-reach denominator is not: whether a sample reaches stage $j$ depends on what the upstream stages produced, so $n^{\mathrm{reach}}_j$ is itself a random outcome of the run. This is exactly the post-hoc, response-determined classification that §4.8 places outside the definitions this paper relies on, because the count then needs its own estimate and bound. A stage's in-pipeline rate over its reach denominator is therefore reported as a labelled **descriptive diagnostic**: it carries no verdict, enters no Type-I envelope, and is not the same object as the stage's standalone contract rate, being measured under the upstream-produced distribution and under the condition that the stage was reached.

This distinction is not a minor reporting detail. If a router is invoked on only 700 of 1000 composite samples because an upstream translation stage failed on the other 300, then the router's in-pipeline count is 700, not 1000, and the composite denominator remains 1000. Reporting the router's rate without its reach count would exaggerate the evidential weight of the observation; reporting it as though it were the router's standalone baseline would conflate two populations.

The same discipline applies to latency. The composite latency distribution is the latency of the composed service conditional on composite success — every composite criterion passing — exactly as §6.2 conditions a single contract's latency on success (Statistical Companion §12.2.1). Stage-local latency summaries are conditional on the stage being reached and succeeding, and are diagnostics in the same sense. These conditional populations must be named rather than hidden.

### 9.6 Type Compatibility and Distributional Compatibility

Composition has two compatibility layers.

The first is **type compatibility**. The output type of one stage must be acceptable as the input type of the next. In a language with parametric types this can be checked mechanically. If the first contract produces `EnglishTranscript` and the second consumes `EnglishTranscript`, the composition can be constructed at the type level.

The second is **distributional compatibility**. A downstream contract's evidence is meaningful only over the input population on which that evidence was drawn, or over a population to which the operator is willing to extend the claim. A type match does not establish that relationship.

For example:

```text
Translator output type: EnglishTranscript
Router input type:      EnglishTranscript
```

This composition may type-check. But if the router's baseline was established on clean, human-written English transcripts, while the composed service supplies machine-translated transcripts containing translation artefacts, the router's standalone evidence is not automatically portable. The downstream type is the same; the downstream input distribution is not.

The rule is therefore:

> Type compatibility permits execution; distributional compatibility permits reuse of evidence.

When distributional compatibility is undeclared, doubtful, or false, the composed service must be measured on its own terms. The downstream component's standalone contract may still be useful as a diagnostic reference, but it does not by itself establish the downstream stage's in-pipeline behaviour, and it certainly does not establish the composite contract.

This is the compositional form of the population-claim discipline introduced in §4.1: a verdict is first a claim about the sampling it ran over, and extending it is a declared claim (Statistical Companion §1.4.7, §8.4.6). Composition changes the conditions of that claim, because upstream components generate the values downstream components see — just as a baseline measured under one covariate profile is no reference for a test run under another (Statistical Companion §1.5.3).

### 9.7 Empirical Composite Evidence

The authoritative evidence for a composed contract is obtained by running the composed contract end to end over a declared sampling and evaluating the composite criteria directly.

Let $S_C$ be the event that the composite contract satisfies its end-to-end functional criteria on a sample. The empirical composite experiment observes the stream:

$$X_{i,C} = \mathbf{1}\{S_C \text{ holds on sample } i\},$$

together with the trace-local streams for each reached stage. The composite contract is the service under test: its rate-bounded criteria are decided by the companion's rules, its observational criteria by the zero-failures rule, its latency constraints by the latency rules, and its verdict is the structured composite of §8.1, with its envelopes disclosed (§8.2) — all unchanged from a single contract.

The component traces do not disappear. They answer different questions:

- which stages were reached;
- which stage-local criteria failed;
- whether failures were introduced upstream or downstream;
- whether a downstream stage behaved differently under upstream-produced inputs;
- how latency and resource usage were distributed across the pipeline;
- whether a baseline became stale because a child contract, adapter, factor, or covariate changed.

These are not substitutes for the composite verdict. They are the evidence by which the composite verdict is explained.

This distinction should be reflected in reporting. A composition report presents the end-to-end composite verdict first, then stage-local and trace-derived diagnostics. The report may include descriptive stage rates, reach counts, and latency decompositions, but it must not present those summaries as though they were an independently derived proof of the end-to-end result.

### 9.8 Derived Quantities and Their Limits

There are cases in which a derived compositional calculation is meaningful. The guarded architecture of §9.9 is the principal one: the residual event — a prohibited candidate emitted upstream and missed by the boundary — is structurally an event of survival through a boundary, and the companion models it. But that special case should not be mistaken for a general licence to multiply pass rates.

For a sequential chain with stage-success events $S_1,\ldots,S_k$, the end-to-end success event is usually:

$$S_1 \cap S_2 \cap \cdots \cap S_k.$$

The chain rule gives:

$$P(S_1 \cap \cdots \cap S_k) = P(S_1)P(S_2 \mid S_1) \cdots P(S_k \mid S_1,\ldots,S_{k-1}).$$

The standalone product

$$P(S_1)P(S_2)\cdots P(S_k)$$

is a different expression. It requires assumptions — independence, compatible populations, stable conditional behaviour, and appropriately aligned event definitions — that are rarely established in stochastic service pipelines. In many LLM-based architectures, the downstream input distribution is generated precisely by the upstream component, so independence is the wrong default assumption.

Even conservative bounds require care. A union-bound style statement over failure events,

$$P(S_1 \cap \cdots \cap S_k) \geq 1 - \sum_{j=1}^{k} P(\neg S_j),$$

is meaningful only when the events are defined over a compatible common population and the failure probabilities being bounded are the relevant ones for that population. The bound may be conservative, but conservatism does not repair a population mismatch.

Derived quantities are therefore secondary, labelled artefacts. A report may distinguish, for example:

```text
empirical-end-to-end
chain-rule-conditional
union-bound
independence-assumed
diagnostic-only
```

The label is part of the claim. A derived quantity must state the basis on which it was produced, the population to which it applies, and the assumptions under which it is valid. It must not be displayed as equivalent to an empirical measurement of the composed service, and the methodology attaches no verdict to it: outside the guarded case, the Statistical Companion defines no general model for derived compositional claims, and none is needed for the composite contract to be evaluated. The default is simple:

> Measure the composition empirically. Treat derived composition as explicit, assumption-bearing commentary.

### 9.9 Guarded Composition

When a service cannot realistically be coaxed into producing the content a categorical clause prohibits — *the service shall not emit self-harm advice* — the guardrail of §4.6 is interposed between the service and its consumer. That arrangement is a composition. The generator's candidate output is the guardrail's input, and what reaches the consumer is the output of the pair. The guardrail is a component with its own distributional contract, and the guarded service is a composite contract in the sense of this chapter.

The application-level claim concerns the generator-boundary-consumer architecture, not the generator alone and not the guardrail alone. Its statistical side is the companion's: the probability that prohibited content reaches the consumer is the product of the generator's harm rate and the guardrail's conditional miss rate, each evidenced separately — the miss rate by an experiment over a harmful-candidate sampling, the harm rate by production monitoring or a sentinel stream, if at all — and a claim about the product needs an upper bound on each factor at a stated joint confidence (Statistical Companion §1.4.5b). The guardrail's detection is an affirmative safety claim and is therefore decided exactly, by the exact binomial test and its Clopper–Pearson bound (Statistical Companion §2.3.3, *Clause Forms*). None of this makes the residual zero; it makes it bounded.

What the statistics cannot say is what the commitment *is*. That is contractual, and it belongs here. An **architectural commitment** is the documented statement that a named component guards against the outcome a categorical clause prohibits, and it records:

- **the clause** — the categorical obligation the component guards, in the contract's own words;
- **the threat model** — the ways the prohibited outcome is expected to arise, including the inputs that provoke it;
- **the component and its placement** — which guardrail, where it sits between generator and consumer, and what it inspects;
- **the bypass analysis** — whether any path lets output reach the consumer without passing the component;
- **the detection evidence** — the guardrail's own rate-bounded contract over its harmful-candidate sampling, with its verdict and bound;
- **the false-positive cost** — what wrongly blocking acceptable output costs the consumer, and the rate-bounded clause that guards it: a floor taken from an operational commitment, or a threshold derived from the guardrail's baseline;
- **the coverage ledger** — which threats of the threat model the adversarial sampling actually exercises, and which it does not;
- **the residual risk** — the bound on the product above, with its basis, or the statement that the generator's harm rate is not estimated and the residual therefore unbounded.

The coverage ledger matters because an adversarial sampling is almost always a finite corpus (§4.1): a guardrail that catches every probe in a set exercising one style of attack has shown nothing about the styles the set omits, and the ledger makes that omission visible instead of leaving it to be assumed away. The record is documentary: it states the commitment for the developer, the reviewer and the auditor, and no framework need consume it as a structured artefact.

**Two error rates, one constrained.** A guardrail can miss harmful content and can wrongly block acceptable content, and moving its operating threshold trades one error for the other. The methodology resolves the trade as the Neyman–Pearson principle does [24, 25]: the graver error is constrained at a declared level, and the other is kept as small as that constraint allows. For a guardrail that protects users from harmful content the miss is the graver error, so sensitivity carries a normative threshold derived from the tolerable residual harm, decided by the compliance test. Specificity is not given a matching requirement by the same reasoning, because the harm analysis supplies none. It is measured, and it is guarded so that a guardrail that blocks everything cannot pass: by a normative floor taken from an operational commitment, such as an SLO, until a baseline exists, and thereafter by an empirical threshold derived from that baseline, decided by the regression test (§5). The architectural commitment states which error is constrained and why; where a wrongful block is the graver harm, as in front of an emergency-information service, the roles invert. Requiring the specificity clause does not weaken the sensitivity clause (Statistical Companion §1.4.5b).

### 9.10 Composition Graph Identity and Baseline Provenance

A baseline for a single service contract is already a structured artefact. It is tied to the contract identity, structural reference, factor record, covariate profile, sampling, and expiry conditions (Statistical Companion §1.5.3, §8.4.2). A composite baseline must carry at least the same discipline, and in practice more.

The identity of a composed contract is not merely the identity of its final output type. It is the identity of a graph: the ordered or otherwise structured arrangement of stages, adapters, criteria, factor configurations, covariate declarations, and composition policies by which the final output is produced. A judge or a guardrail invoked by the composition is a declared service in its own right, and its configuration — model, prompt, thresholds — enters the composition's identity like any stage's.

A composite baseline should therefore record, at minimum:

- the composite contract id;
- the composition graph identity or hash;
- the ordered stage ids or graph topology;
- each child contract id;
- each child structural reference;
- each child factor record;
- the covariates declared and resolved for each stage;
- any adapter functions between stages;
- the composition policy, including failure propagation;
- the final-output criteria;
- any trace-aware or cross-stage criteria;
- the latency policy for the composite and for stage-local summaries.

If any of these change materially, the composite baseline should not silently remain valid. A changed child contract, prompt, model, adapter, covariate resolver, routing policy, or final criterion may preserve the same external type while changing the stochastic mechanism under evaluation. Such a change is a baseline-provenance event, to be surfaced rather than absorbed.

This is especially important because a composite can appear stable at the boundary while changing internally. The input type and output type may remain unchanged, and even the final output may appear superficially similar, while a stage replacement shifts the distribution of intermediate values or changes which failures are masked, repaired, or propagated. Composition graph identity is the safeguard against treating such a change as the same empirical object.

### 9.11 An Illustrative API

What composition means in practice is easiest to see in the shape an API for it might take. The sketch below is an illustration of the idea, not a specification: no mavai framework implements it, and the family's frameworks compose today in host code that invokes declared services. A Java rendering might read:

```java
ServiceContract<VoiceFactors, AudioBlob, ScreenState> pipeline =
    Contracts.chain("voice-ui-command")
        .first("stt", sttContract)
        .then("translate", translatorContract)
        .then("route", routerContract)
        .then("handle", handlerContract)
        .then("execute", uiApiContract)
        .criteria(finalCriteria)
        .build();
```

The point of the sketch is that `pipeline` is itself a `ServiceContract`: it can be baselined, tested, monitored, and reported as the service under evaluation. Its stage contracts remain visible through the composition trace, but the composite has its own criteria, its own denominator, its own population claim, and its own baseline provenance.

The statistics at the interfaces of such an API would look like this:

- **At the composite's boundary:** the composite verdict — the structured tuple over the composite's own criteria, each decided by its rule (§5.3) at its error level, with the two envelopes disclosed and the composite sampling's size as every criterion's denominator.
- **At each stage boundary inside it:** the stage's reach count $n^{\mathrm{reach}}_j$, its stage-local outcomes over that count labelled as descriptive diagnostics, and the reasons for any failure or non-reach.
- **For latency:** the composite's percentiles over the samples on which the composite succeeded, decided by the latency rules; stage durations as diagnostics.
- **For a guarded composition:** the guardrail's detection verdict and its false-positive clause from its own contract, and the residual risk as a labelled derived quantity with its basis, per §9.9.

Whatever form an implementation takes, a composition must preserve the properties this chapter depends on. Stage identifiers are stable and unique. Adjacent stage types are compatible. Child contract identities and their factor records are present and stable. Covariate names do not collide silently. The composition graph identity can be produced and recorded. The failure propagation policy is explicit. The composite's own criteria are declared, even where stage-local criteria are inherited. And each reached stage is evaluated through the same machinery as a standalone evaluation — postconditions, criteria, timing, covariate capture — rather than bypassed because it runs inside a larger contract.

### 9.12 What Composition Is Not

Several exclusions are essential.

First, distributional contract composition is not a claim of automatic probabilistic composability. The existence of component contracts does not imply that their pass rates can be multiplied, averaged, unioned, or otherwise combined into a valid composite rate. Any such operation requires stated assumptions and belongs to a labelled derived analysis, not to the default semantics of composition.

Second, composition is not a substitute for end-to-end evaluation. The composed service induces its own distribution over executions. Where the application-level claim concerns the final behaviour seen by the consumer, the composed service must be sampled and assessed directly.

Third, composition does not make downstream standalone baselines portable. A downstream component measured on one input population may behave differently when fed values produced by an upstream stochastic component. Type compatibility is not distributional compatibility.

Fourth, composition does not collapse criteria. The argument against aggregate rates (§4.4) applies with greater force in a composed service, where failures may be introduced, transformed, masked, or repaired across stages. Stage-local, cross-stage, and final-output criteria remain separately attributable.

Fifth, composition is not ordinary orchestration. Orchestration connects components so that values flow. Contract composition connects contracts so that evidence remains interpretable.

Finally, composition is not a rare-event certification device. A guarded architecture may reduce risk, and the companion's containment model (§1.4.5b) structures that claim, but no finite ordinary sample proves the absence of catastrophic behaviour. High-consequence obligations remain governed by the categorical clause of §4.6 and the guarded composition of §9.9, within the limits of finite empirical evidence.

### 9.13 Summary

Distributional contract composition extends the central move of this paper from individual stochastic services to connected stochastic architectures. A service contract is a statistically characterised interface. When such interfaces are connected, the resulting composition must not be treated as an unstructured implementation detail, nor as an invitation to calculate end-to-end quality from standalone component summaries.

A composite contract is a new empirical object. It has its own population claim, denominator, criteria, latency behaviour, baseline identity, and verdict, all evaluated with the machinery a single contract uses. The component contracts remain present as trace-preserving substructures, supplying attribution and diagnostic evidence. A guarded composition polices a service that cannot be tested for an outcome it must never produce, and its architectural commitment is recorded as a contractual statement whose statistics the companion supplies.

The guiding rule is therefore:

> Operational composition is first-class; empirical composition is authoritative; derived composition is secondary, labelled, and assumption-bearing.

## 10. The mavai Project Family: Implementations of the Distributional Contract

This section describes the mavai project family, which implements the model as practical tooling for developers working with stochastic systems.

The mavai project was created in response to a conspicuous gap in the testing landscape. The shortcomings of existing approaches to testing stochastic systems have been recognised in the literature. Christensen et al. [21] observe that "in practice, testers resort to running probabilistic programs an arbitrary number of times; hoping to trigger existing bugs, but without any guarantees," and propose ProbTest, a black-box unit testing method that uses the coupon collector's problem to determine sample sizes for bug detection in probabilistic programs. Their work confirms the need for statistically principled approaches and demonstrates that the problem admits tractable solutions, though their focus is on bug-finding rather than on contractual quality assurance over deployed services.

The advent of Large Language Models brought stochastic behaviour from the margins of software engineering — where it had been treated as accidental and undesirable — to the centre. Services built on LLMs are inherently non-deterministic: the same input genuinely produces different outputs, and the distribution of those outputs *is* the service's behaviour. Yet the available testing tools offered no principled way to express, measure, or enforce quality expectations over such services. The mavai project family addresses this gap.

The methodology is implemented as language-native frameworks, each idiomatic to its ecosystem:

| Framework                                       | Language | Integration             | Repository                   |
|-------------------------------------------------|----------|-------------------------|------------------------------|
| [punit](https://github.com/mavai-org/punit)     | Java     | JUnit 5 extension       | The reference implementation |
| [feotest](https://github.com/mavai-org/feotest) | Rust     | Cargo test integration  | Idiomatic Rust, not a port   |
| baseltest                                       | Python   | pytest plugin (planned) | —                            |

Each framework is a direct operational realisation of the distributional contract, its features corresponding to the elements of the model.

### 10.1 Expressing a Distributional Contract

Each framework gives the developer the means to express a distributional contract as a declarative specification. The functional dimension is defined through one or more **criteria**, each hosting one or more postconditions — syntactic validity, presence of required fields, schema adherence, semantic correctness, absence of disallowed content. Postconditions are grouped into criteria by the design rule of §4.5, each criterion its own statistical stream with its own threshold and confidence level. The developer may additionally declare latency thresholds — percentile-level bounds to which the service must adhere — expressing the temporal dimension of the contract.

All frameworks evaluate both dimensions by the methods of this paper. Every verdict names the rule that produced it by the versioned identifier the Statistical Companion assigns — `regression/fisher` for the Fisher test, `compliance/exact-binomial` for the exact binomial test, `latency/precedence` for the latency precedence rule, and so on — so that a reader can trace each verdict to its rule. The Wilson interval is reported beside the verdict only as a description of the observed rate. The frameworks report the structured composite verdict of §8.1, with its disclosed Type-I envelopes (§8.2), and follow its enforcement semantics (§8.3).

The move to a distributional contract also reframes what it means for a postcondition to fail. In Meyer's original formulation, a violated postcondition is evidence of a defect in the supplier: the routine failed to honour its obligation, and the appropriate response is to locate and fix the bug. Under a distributional contract this interpretation is no longer available at the level of an individual execution. A single execution on which a postcondition is not satisfied does not, by itself, establish a defect — it is indistinguishable from a sample outcome drawn from the variability the contract explicitly admits.

The notion of contract failure is therefore lifted along with the postcondition: a failure is no longer the falsification of a postcondition on one execution, but the failure of a criterion, over a principled number of executions, to deliver the desired outcome with sufficient probability. Accordingly, the frameworks treat an individual failing execution as data, not as an alarm, and reserve the contract-failure verdict for the statistical assessment of the population as a whole.

### 10.2 Stipulated and Empirical Thresholds

Both threshold sources are supported across all implementations. A developer may declare a stipulated threshold directly — from an SLA, regulatory requirement, or organisational policy — or may conduct a baseline measurement experiment against which later tests are judged by the Fisher test. The baseline result is recorded as a persistent specification artefact, capturing the success count and sample size together with the conditions under which the baseline was established; the cutoff a test must reach is derived from it when the test runs, since it depends on the test's own size.

### 10.3 The Feasibility Gate

All implementations check the design before any sample runs and refuse the configurations of §7 (`COMPLIANCE_INFEASIBLE`, `TEST_LARGER_THAN_BASELINE`), honouring the test's declared intent. A refusal is a configuration error — distinct from a system failure and from any verdict — and it applies whether a dimension is enforced or advisory.

### 10.4 Early Termination

In some cases, the final verdict can be determined before all planned samples have been executed. Every decision rule reduces to a count of successes the test must reach. If enough failures have been observed that this count can no longer be reached even if all remaining samples pass, continued execution is pointless. Conversely, once the count has been reached, the verdict is determined regardless of the remaining outcomes. The frameworks detect both conditions and terminate early.

Each additional execution beyond the point at which the verdict is fixed consumes resources with real-world cost: LLM token spend billed per call, CPU and memory on the host running the test, network bandwidth to the service under test, energy and the carbon footprint it implies, and — in rate-limited environments — quota that may be needed elsewhere. These costs scale linearly with the number of samples and can be substantial: a single probabilistic test of a large language model may consume tens of thousands of tokens, and a test suite running in continuous integration may execute thousands of such tests per day.

Continuing to sample once the verdict is mathematically determined is therefore an active waste of non-renewable budget. The frameworks treat early termination as a first-class obligation rather than an optional optimisation, on the pragmatic grounds that a methodology which ignores the operational cost of its own evaluations is unlikely to be adopted, and less likely still to be sustained.

### 10.5 Operational Safeguards

The Bernoulli model assumes independence between executions and stationarity of the success probability across the sampling window. These assumptions are not given by the operational environment; they must be actively maintained. The frameworks provide several mechanisms toward this end. A warmup facility allows initial observations to be discarded, mitigating cold-start non-stationarity caused by caches, connection pools, or runtime compilation.

Part of that maintenance is the developer's. Provider features that make trials share state — cached system prompts, conversation context carried between calls, batched requests, fixed seeds — undermine independence, and should be disabled during experiments or at least documented. Where trials remain dependent, as when the same inputs are repeated, they carry less evidence than their count suggests: more independent inputs help, and more repetitions of the same ones do not (Statistical Companion §1.3.3, §8.2).

A particular threat to stationarity arises from exogenous covariates: factors external to the service under test that influence the success probability without being part of the input. In any population sampling exercise — and Bernoulli trial sampling is no exception — the validity of comparisons between samples depends on the conditions under which those samples were drawn. If the baseline was established under one set of conditions and the evaluation is conducted under another, the two samples are drawn from different populations, and the comparison is statistically meaningless regardless of the sample sizes involved.

Deployment region, time of day, model version, infrastructure configuration, and upstream service behaviour are all examples of exogenous covariates that can shift the success probability between a baseline and a subsequent evaluation. The frameworks address this by associating covariate declarations with baselines, making contextual factors explicit and auditable, and issuing warnings when conditions at evaluation time differ from those recorded in the baseline.

Baseline expiration tracking alerts operators when a specification may no longer represent current service behaviour. These mechanisms do not guarantee that the Bernoulli assumptions hold — that is impossible in practice — but they make violations visible rather than allowing them to silently undermine inference.

The covariate problem points to a deeper reality: for many stochastic services, behaviour is environmentally dependent in ways that cannot be fully captured at baseline time. A service that meets its distributional contract in a test environment may violate it in production, not because the service itself has changed but because the operating conditions have. It is therefore insufficient, in many cases, to rely on one-time evaluations conducted in controlled settings. What is needed is a mechanism for probing the service's behaviour in situ — in the environment where it actually operates, under the conditions it actually encounters. Sentinel capabilities within the mavai family address this requirement, providing lightweight runtime agents that evaluate the distributional contract continuously against the live deployment, detecting degradation as it occurs rather than after the fact. Continuous evaluation repeats the test, and the per-run error level $\alpha$ bounds one run, not a horizon of them: over $H$ runs against one baseline the probability of at least one false alarm is bounded only by $H\alpha$, so a monitor states the horizon over which it controls false alarms, and choosing that control is part of designing it (Statistical Companion §8.5).

### 10.6 The Experiment-to-Test Workflow

The frameworks operationalise the experiment-then-test workflow of §4.2 and §5: an experiment produces a specification, and later tests, with fewer samples, are judged against it. The use case — the reusable unit that invokes the service and evaluates the result — is shared between experiments and tests, ensuring that the contract's criteria are applied consistently.

### 10.7 Conformance Across Implementations

Because the distributional contract is a statistical model, not a language-specific construct, all mavai framework implementations must produce identical statistical results for the same inputs. The [mavai-R](https://github.com/mavai-org/mavai-R) project provides the verification mechanism: it generates canonical reference datasets using R — the gold standard for statistical computing — against which each framework validates its statistics engine. This ensures that a distributional contract evaluated by punit in Java produces the same verdict as one evaluated by feotest in Rust, within stated floating-point tolerances. Agreement of results is necessary but not sufficient: with each release mavai-R also publishes a calibration certification, showing that its reference implementation achieves the error rates the regression, compliance and latency rules claim.

## 11. Conclusion

Meyer's Design by Contract gave software engineering a powerful organising principle: the obligations between caller and callee, expressed as preconditions, postconditions, and invariants, and enforced deterministically at runtime. For over three decades it has stood as a beacon for those who care about software correctness. Still, the systems it addressed were, by and large, deterministic: a postcondition either held or it did not, and a single counterexample was definitive evidence of a defect.

Yet stochastic systems have always existed — network services subject to variable latency, randomised algorithms, probabilistic data structures, simulations — and they lie outside the deterministic scope Design by Contract was built for. A deterministic postcondition cannot express "succeeds at least 95% of the time" or "responds within 500ms at the 99th percentile". These are inherently distributional claims, and no amount of Boolean logic over individual executions can capture them. Design by Contract never set out to address this — its concern was deterministic correctness — and that boundary could be overlooked as long as stochastic behaviour remained marginal. The rise of Large Language Models has made it impossible to ignore: when non-determinism is not a defect but the defining characteristic of the technology, the absence of a principled contractual framework for stochastic systems becomes an acute gap.

This gap can only be addressed by a probabilistic approach. When a service's behaviour is inherently variable, a single execution cannot characterise its quality, a single failure cannot condemn it, and a single success cannot vindicate it. The postcondition must be lifted from a Boolean predicate over an individual execution to a statistical assertion over a population of executions.

This paper has proposed such a lifting, drawing on established traditions — statistical model checking [4][5][22], black-box probabilistic verification [7][8], and software reliability engineering [9][19][20] — while recasting their insights in a contractual form suited to day-to-day software engineering practice. The distributional contract preserves the contractual structure of Design by Contract — the notion that a service has obligations to its consumers that can be formally stated and objectively assessed — while replacing pointwise evaluation with statistical inference.

The contract is expressed along two orthogonal dimensions: functional stochasticity, assessed via a Bernoulli model and exact decision rules, and temporal stochasticity, assessed via empirical percentile analysis. Within the functional dimension the contract decomposes further into separately-contractual criteria, each its own stream, because a single aggregate rate provably masks movement in the rare-but-consequential criteria a contract most needs to watch; the per-criterion verdicts compose into a structured composite carrying two disclosed Type-I envelopes, one for each direction of error.

A contract's obligations also divide by form: rate-bounded clauses, bounded statistically by the machinery above, and categorical clauses, which admit no rate and are evaluated by an observational zero-failures criterion, falsified by a single violation and never demonstrated by a clean run. A rate-bounded clause's threshold is, on a separate axis, either normative in origin — stipulated by an SLA, SLO, policy, or regulation — or empirical, derived conservatively from a measured baseline. Every criterion is subject to the constraint that binds sample size, threshold and confidence in any honest statistical claim.

Services composed into chains and guarded architectures are distributional contracts in their own right. The composed service is measured end to end, with its own criteria, denominator and verdict; its stages keep their evidence as diagnostics; and component rates are not multiplied into an end-to-end claim. Where a service cannot be tested for an outcome it must never produce, a guardrail is tested in its place.

The model is deliberately conservative in its statistical choices. Each verdict is decided by an exact rule chosen for its question — the Fisher test for degradation, the exact binomial test for compliance — because only an exact rule keeps the probability of a false verdict within the stated level at every sample size; an approximation, however well-behaved, cannot promise that. The rules are conservative by construction: where they err, they err towards fewer false alarms and fewer false claims of compliance, at a modest cost in sensitivity that was judged a smaller risk than false precision. The Wilson interval remains, to describe what was observed, but it decides nothing.

The mavai project family demonstrates that the distributional contract is not merely a theoretical construct but a practical tool. The frameworks translate each element of the model — the postcondition, the criterion, the threshold, the decision rule, the feasibility gate, the baseline specification — into declarative constructs that a developer can express and a runtime can enforce, across multiple language ecosystems. Sentinel capabilities extend the model beyond one-time evaluation to continuous in-situ monitoring, with false alarms controlled over a stated horizon of runs rather than per run, acknowledging that stochastic services are environmentally dependent and that a contract verified under controlled conditions may not hold in production.

Several questions remain open. The treatment of exogenous covariates in this paper is operational rather than formal: covariates are declared and tracked, but there is no statistical framework for adjusting inference when covariate drift is detected.

The architectural commitment of §9.9 is a documentary record; whether it should become a structured artefact that frameworks consume is left open until a consumer needs one. Derived compositional claims beyond the guarded case have no general model, and the chapter on composition treats them as labelled commentary. And the independence assumption, while supported by operational safeguards, is ultimately unverifiable from the data alone.

These are not deficiencies to be apologised for; they are honest boundaries of what a practical framework can achieve. The distributional contract does not claim to resolve the fundamental difficulty of reasoning about stochastic systems. It claims only to provide a disciplined, statistically grounded basis for doing so — one that makes its assumptions explicit, its limitations visible, and its verdicts defensible.

## 12. References

[1] Meyer, B. "Applying 'Design by Contract'." *IEEE Computer*, vol. 25, no. 10, October 1992, pp. 40–51.

[2] Meyer, B. *Object-Oriented Software Construction*, 2nd ed. Prentice Hall, 1997.

[3] Mannion, M. F. "Statistical Companion Document: Formal Statistical Foundations for the Mavai® Methodology." Version 1.7.2. The mavai project family, 2026. Available at https://github.com/mavai-org/mavai-R/blob/main/docs/STATISTICAL-COMPANION.md.

[4] Younes, H. L. S. and Simmons, R. G. "Statistical probabilistic model checking with a focus on time-bounded properties." *Information and Computation*, vol. 204, no. 9, 2006, pp. 1368–1409.

[5] Legay, A., Delahaye, B., and Bensalem, S. "Statistical model checking: an overview." In: *Runtime Verification*, LNCS 6418, Springer, 2010, pp. 122–135.

[6] Benveniste, A., Caillaud, B., Nickovic, D., Passerone, R., Raclet, J.-B., Reinkemeier, P., Sangiovanni-Vincentelli, A., Damm, W., Henzinger, T. A., and Larsen, K. G. "Contracts for System Design." *Foundations and Trends in Electronic Design Automation*, vol. 12, no. 2–3, 2018, pp. 124–400. DOI: 10.1561/1000000053.

[7] Sen, K., Viswanathan, M., and Agha, G. "Statistical model checking of black-box probabilistic systems." In: *Computer Aided Verification*, LNCS 3114, Springer, 2004, pp. 202–215.

[8] Aichernig, B. K. and Tappler, M. "Probabilistic black-box reachability checking." In: *Runtime Verification*, LNCS 10548, Springer, 2017, pp. 50–67.

[9] Musa, J. D. "Operational profiles in software-reliability engineering." *IEEE Software*, vol. 10, no. 2, 1993, pp. 14–32.

[10] Wilson, E. B. "Probable inference, the law of succession, and statistical inference." *Journal of the American Statistical Association*, vol. 22, no. 158, 1927, pp. 209–212.

[11] Fisher, R. A. "The logic of inductive inference." *Journal of the Royal Statistical Society*, vol. 98, no. 1, 1935, pp. 39–82.

[12] Clopper, C. J. and Pearson, E. S. "The use of confidence or fiducial limits illustrated in the case of the binomial." *Biometrika*, vol. 26, no. 4, 1934, pp. 404–413.

[13] Brown, L. D., Cai, T. T., and DasGupta, A. "Interval estimation for a binomial proportion." *Statistical Science*, vol. 16, no. 2, 2001, pp. 101–133.

[14] Agresti, A. and Coull, B. A. "Approximate is better than 'exact' for interval estimation of binomial proportions." *The American Statistician*, vol. 52, no. 2, 1998, pp. 119–126.

[15] Nelson, L. S. "Tables for a precedence life test." *Technometrics*, vol. 5, no. 4, 1963, pp. 491–499.

[16] Balakrishnan, N. and Ng, H. K. T. *Precedence-Type Tests and Applications*. Wiley, 2006.

[17] Conover, W. J. *Practical Nonparametric Statistics*, 3rd ed. Wiley, 1999.

[18] Hollander, M. and Wolfe, D. A. *Nonparametric Statistical Methods*, 2nd ed. Wiley, 1999.

[19] Frankl, P. G., Hamlet, D., Littlewood, B., and Strigini, L. "Evaluating testing methods by delivered reliability." *IEEE Transactions on Software Engineering*, vol. 24, no. 8, 1998, pp. 586–601.

[20] Hamlet, D. and Taylor, R. "Partition testing does not inspire confidence." *IEEE Transactions on Software Engineering*, vol. 16, no. 12, 1990, pp. 1402–1411.

[21] Christensen, K., Varshosaz, M., and Pardo, R. "ProbTest: Unit Testing for Probabilistic Programs." In: Bianculli, D. and Gómez-Martínez, E. (Eds.), *Software Engineering and Formal Methods (SEFM 2025)*, LNCS 16192, pp. 91–109. Springer Nature Switzerland, 2026. (The chapter carries a 2025 date in some indexes while the proceedings volume is dated 2026; the volume year is used here.)

[22] Agha, G. and Palmskog, K. "A survey of statistical model checking." *ACM Transactions on Modeling and Computer Simulation*, vol. 28, no. 1, 2018, pp. 1–39.

[23] The mavai project family: probabilistic testing frameworks. Source code and documentation available at https://mavai.org and https://github.com/mavai-org.

[24] Neyman, J. and Pearson, E. S. "On the problem of the most efficient tests of statistical hypotheses." *Philosophical Transactions of the Royal Society of London, Series A*, vol. 231, 1933, pp. 289–337.

[25] Lehmann, E. L. and Romano, J. P. *Testing Statistical Hypotheses*, 4th ed. Springer, 2022.
