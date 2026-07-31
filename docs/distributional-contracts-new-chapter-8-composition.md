## 8. Distributional Contract Composition

The preceding sections define a distributional contract for a stochastic service considered as a single contractual unit. In practice, however, many stochastic applications are not a single service invocation. They are chains, graphs, or guarded architectures in which the output of one component becomes the input to another, and in which deterministic and stochastic components together determine the behaviour ultimately observed by the consumer.

A voice-command application may pass an audio sample through speech-to-text, translation, routing, command construction, and a user-interface API. A health-advice application may pass a generated candidate response through a safety boundary before it is shown to the user. A retrieval-augmented generation service may compose retrieval, ranking, prompt construction, model invocation, citation checking, and final formatting. In each case the behaviour of interest is not exhausted by any one component. The application-level claim is a claim about the composition.

This chapter introduces **distributional contract composition**: the construction of a new distributional contract from two or more component contracts, in such a way that the composed service can be exercised and evaluated as a contract in its own right while preserving the statistical evidence and diagnostic structure of its component stages.

The purpose of composition is not to manufacture an end-to-end probability from component pass rates. That operation is usually unjustified. The purpose is to make the composed stochastic mechanism itself an object of empirical investigation.

> Compose contracts to measure compositions, not to multiply component rates.

The statistical treatment of composition is deliberately not developed in full here. The present paper states the contractual meaning of composition, the operational obligations an implementation must satisfy, and the principal cautions that prevent misuse. The Statistical Companion [3] remains the canonical home for the formal statistics. Its current treatment of conditional containment in §1.4.5b is a special case of the compositional problem; the general treatment of distributional contract composition is reserved for the planned §1.4.5c.

### 8.1 A Service Contract as a Statistical Interface

A service contract is not merely a declarative description of expected behaviour. Once exercised, it carries statistical state: per-criterion outcomes, thresholds, confidence levels, verdicts, latency observations, covariate records, baseline identity, factor configuration, failure reasons, and population-claim metadata. It is therefore useful to regard a service contract as a **statistically characterised interface**.

At the type level, a service contract has the shape of an arrow from inputs to outputs:

$$C : I \rightsquigarrow O$$

where the hooked arrow indicates that the mapping is operational and possibly stochastic rather than a deterministic function. The contract receives an input of type $I$, invokes a service, produces an outcome over type $O$, and evaluates contractual criteria over that outcome. The contract is not only the invocation; it is the invocation together with the obligations and evidence by which the invocation is judged.

Two contracts are type-compatible for sequential composition when the output type of the first can be supplied as the input type of the second:

$$C_1 : A \rightsquigarrow B, \qquad C_2 : B \rightsquigarrow C.$$

Their sequential composition has the operational shape:

$$C_2 \circ C_1 : A \rightsquigarrow C.$$

For a chain of $k$ stages,

$$C_i : I_i \rightsquigarrow I_{i+1}, \qquad i = 1,\ldots,k,$$

the composite contract is:

$$C = C_k \circ \cdots \circ C_2 \circ C_1 : I_1 \rightsquigarrow I_{k+1}.$$

This notation states only the operational shape. It does not state that the statistical evidence carried by the components can be arithmetically combined into a valid end-to-end claim. Type compatibility permits execution; it does not by itself justify reuse of evidence.

### 8.2 The Motivation for First-Class Composition

Without first-class composition, a developer evaluating a stochastic pipeline is left with two poor alternatives.

The first is to hand-write the pipeline as ordinary orchestration and test only the final output. That gives an end-to-end result, but loses the internal statistical anatomy of the run: which stage failed, which criteria were violated, what denominator each stage saw, which covariates were in force, which baseline was implicated, and whether an upstream component shifted the input distribution seen by a downstream one.

The second is to test each component separately and then reason informally from the component reports. That preserves some local evidence, but invites an invalid inference: if each stage has a reported pass rate, the temptation is to combine those rates as though they were independent probabilities over a common population. For stochastic pipelines this is rarely justified. A downstream component is not exercised on the same population in the composed service as it was in its standalone experiment; it is exercised on the distribution of values emitted by the upstream component.

First-class composition exists to avoid both failures. It constructs a composite contract that can be sampled end to end, while preserving the stage-local evidence needed for diagnosis. The composite service becomes empirically addressable as a single contractual object, and the component contracts remain visible as trace-bearing substructures inside it.

The resulting question is no longer:

> What can be calculated from the reported component rates?

but rather:

> What does this composed stochastic mechanism do under this sampling, this factor configuration, these covariates, and this composition policy?

That is the central operational value of composition.

### 8.3 The Composite Contract

A composed contract is itself a distributional contract. It has an input type, an output type, a contract identity, a sampling, criteria, latency observations where applicable, covariates, factor records, baseline provenance, feasibility constraints, and a run-level verdict. It can therefore be subjected to the same experiment-to-test workflow as any other contract.

The composite contract may carry three classes of criteria.

First, it carries **stage-local criteria** inherited from the component contracts. These are the criteria by which each stage judges its own output: a transcript is non-empty, a translation is in English, a router selects a valid application area, a command constructor emits valid JSON. Stage-local criteria are essential for attribution. They explain how the composed run behaved internally, and they identify where failures entered or propagated.

Second, it carries **end-to-end composite criteria** declared by the composite contract itself. These are criteria over the final result of the composed service, judged relative to the original input. In a voice-command pipeline, for example, the final criterion may be that the resulting screen state corresponds to the user's intended command. This is not a property of any one stage. It is a property of the composition.

Third, it may carry **cross-stage criteria** that inspect relationships between intermediate artefacts. A router's chosen application area may need to be consistent with the command emitted by a handler; a translated transcript may need to preserve the intent needed by the router; a generated command may need to be traceable to the original input rather than to a hallucinated intermediate value. These criteria are not purely stage-local and not purely final-output criteria. They require access to the composition trace.

A minimal implementation may initially support only stage-local criteria and final-output composite criteria. Cross-stage criteria require a trace-aware criterion model and may be deferred. Their eventual place in the theory is nevertheless clear: they are contractual criteria over the composed execution, not post hoc debugging annotations.

### 8.4 Trace Preservation

Composition must be trace-preserving. Without trace preservation, the feature degenerates into ordinary service orchestration.

A naïve implementation might invoke the first component, extract its value, pass it to the second component, and return only the final result. That is operationally sufficient to run the pipeline, but contractually insufficient. It discards the very evidence that gives distributional composition its meaning.

A composed sample must preserve, at minimum:

- the original input;
-- the final outcome;
- the ordered stage identities;
- the input supplied to each reached stage;
- the outcome produced by each reached stage;
- each stage's postcondition and criterion results;
- each stage's duration and resource usage where measured;
- the total duration and resource usage of the composed invocation;
- the factor and covariate context under which the stages were invoked;
- the reason for any failure or non-reach.

The final consumer of the composite service may see only an `Outcome<O>`. The evaluation framework must retain the richer trace. The trace is the object from which stage-local summaries, reach denominators, failure provenance, latency allocation, and cross-stage criteria are computed.

This is the difference between invoking a pipeline and composing contracts. Invocation connects values. Contract composition preserves meaning.

### 8.5 Failure Propagation and Denominators

Sequential composition introduces a denominator distinction that does not arise for a single service contract.

Consider:

$$A \rightsquigarrow B \rightsquigarrow C.$$

If the first stage fails to produce a usable value, the second and third stages are not invoked. At the composite level, the sample normally counts as a failure: the composed service did not produce the final value required by its contract. At the stage level, however, only the first stage was reached. The downstream stages were not passed malformed values; they were not passed values at all.

Two denominators must therefore be kept separate.

The **composite denominator** is the number of attempted end-to-end samples. Every input in the composite sampling contributes to it unless the run is aborted by a true catastrophe of the testing machinery. If the composed service fails to produce a final testable value, that attempt is a failure of any composite criterion that required such a value.

A **stage-reach denominator** is the number of composite samples that reached a given stage. Stage-local in-pipeline statistics for stage $j$ are conditional on reach:

$$n^{\mathrm{reach}}_j = |\{i : \text{sample } i \text{ reached stage } j\}|.$$

The resulting rate is not the same object as the stage's standalone contract rate. It is a rate measured under the upstream-produced distribution and under the conditional event that the stage was reached. It must be labelled accordingly.

This distinction is not a minor reporting detail. If a router is invoked on only 700 of 1000 composite samples because an upstream translation stage failed on the other 300, then the router's in-pipeline denominator is 700, not 1000. The composite denominator remains 1000. Reporting the router's conditional rate without the reach denominator would exaggerate the evidential weight of the observation; reporting it as though it were the router's standalone baseline would conflate two populations.

The same discipline applies to latency. The composite latency distribution is the latency of the composed service under the composite contract's success condition. Stage-local latency summaries are conditional on the stage being reached and, where the existing latency model requires it, on the stage succeeding. These conditional populations must be named rather than hidden.

### 8.6 Type Compatibility and Distributional Compatibility

Composition has two compatibility layers.

The first is **type compatibility**. The output type of one stage must be acceptable as the input type of the next. In a language with parametric types this can be checked mechanically. If the first contract produces `EnglishTranscript` and the second consumes `EnglishTranscript`, the composition can be constructed at the type level.

The second is **distributional compatibility**. A downstream contract's evidence is meaningful only over the input population on which that evidence was drawn, or over a population to which the operator is willing to extend the claim. A type match does not establish that relationship.

For example:

```text
Translator output type: EnglishTranscript
Router input type:    EnglishTranscript
```

This composition may type-check. But if the router's baseline was established on clean, human-written English transcripts, while the composed service supplies machine-translated transcripts containing translation artefacts, the router's standalone evidence is not automatically portable. The downstream type is the same; the downstream input distribution is not.

The rule is therefore:

> Type compatibility permits execution; distributional compatibility permits reuse of evidence.

When distributional compatibility is undeclared, doubtful, or false, the composed service must be measured on its own terms. The downstream component's standalone contract may still be useful as a diagnostic reference, but it does not by itself establish the downstream stage's in-pipeline behaviour, and it certainly does not establish the composite contract.

This is the compositional form of the population-claim discipline developed elsewhere in the methodology. Evidence is always evidence over a declared sampling regime, covariate profile, and operational context. Composition changes those conditions because upstream components generate the values downstream components see.

### 8.7 Empirical Composite Evidence

The authoritative evidence for a composed contract is obtained by running the composed contract end to end over a declared sampling and evaluating the composite criteria directly.

Let $S_C$ be the event that the composite contract satisfies its end-to-end functional criteria on a sample. The empirical composite experiment observes the stream:

$$X_{i,C} = \mathbf{1}\{S_C \text{ holds on sample } i\},$$

together with the trace-local streams for each reached stage. The composite contract's rate-bounded criteria, observational criteria, and latency constraints are then assessed under the same general principles already developed for an individual contract, applied to the composite service as the service under test.

The component traces do not disappear. They answer different questions:

- which stages were reached;
-- which stage-local criteria failed;
- whether failures were introduced upstream or downstream;
- whether a downstream stage behaved differently under upstream-produced inputs;
- how latency and resource usage were distributed across the pipeline;
- whether a baseline became stale because a child contract, adapter, factor, or covariate changed.

These are not substitutes for the composite verdict. They are the evidence by which the composite verdict is explained.

This distinction should be reflected in reporting. A composition report should present the end-to-end composite verdict first, then stage-local and trace-derived diagnostics. The report may include descriptive stage rates, conditional reach rates, and latency decompositions, but it must not present those summaries as though they were an independently derived proof of the end-to-end result.

### 8.8 Derived Quantities and Their Limits

There are cases in which a derived compositional calculation is meaningful. The conditional containment model for architectural discharge is one such case. If an upstream generator may produce a prohibited candidate and a downstream guardrail may miss it, then the residual event is structurally an event of survival through a boundary. That model is compositional: the application-level safety claim concerns the generator-boundary-consumer architecture, not the generator alone and not the guardrail alone.

But this special case should not be mistaken for a general licence to multiply pass rates.

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

The framework should therefore treat derived quantities as secondary labelled artefacts. A report may distinguish, for example:

```text
empirical-end-to-end
chain-rule-conditional
union-bound
independence-assumed
diagnostic-only
```

The label is part of the claim. A derived quantity must state the basis on which it was produced, the population to which it applies, and the assumptions under which it is valid. It must not be displayed as equivalent to an empirical measurement of the composed service.

The general statistical rules for such derived quantities are beyond the scope of this chapter. They belong in the Statistical Companion. Until that treatment is complete, the safe default is simple:

> Measure the composition empirically. Treat derived composition as explicit, assumption-bearing commentary.

### 8.9 Composition Graph Identity and Baseline Provenance

A baseline for a single service contract is already a structured artefact. It is tied to the contract identity, structural reference, factor record, covariate profile, sampling regime, threshold derivation, and expiry conditions. A composite baseline must carry at least the same discipline, and in practice more.

The identity of a composed contract is not merely the identity of its final output type. It is the identity of a graph: the ordered or otherwise structured arrangement of stages, adapters, criteria, factor configurations, covariate declarations, and composition policies by which the final output is produced.

A composite baseline should therefore record, at minimum:

- the composite contract id;
-- the composition graph identity or hash;
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

If any of these change materially, the composite baseline should not silently remain valid. A changed child contract, prompt, model, adapter, covariate resolver, routing policy, or final criterion may preserve the same external type while changing the stochastic mechanism under evaluation. The framework should surface that change as a baseline-provenance event.

This is especially important because a composite can appear stable at the boundary while changing internally. The input type and output type may remain unchanged, and even the final output may appear superficially similar, while a stage replacement shifts the distribution of intermediate values or changes which failures are masked, repaired, or propagated. Composition graph identity is the safeguard against treating such a change as the same empirical object.

### 8.10 Implementation Commitments

An implementation of distributional contract composition is a framework-owned mechanism for constructing a contract from contracts. It is not a helper method for nesting service calls.

At build time, the implementation should establish at least the following:

- stage identifiers are stable and unique within the composition;
-- adjacent stage types are compatible;
- child contract identities are present and stable;
- covariate names do not conflict silently;
- factor records are either composed explicitly or fixed by the constructed instances;
- the composition graph identity can be generated and recorded;
- the failure propagation policy is explicit;
- final-output criteria are declared, even if stage-local criteria are inherited.

At runtime, the implementation should invoke each reached stage through the same contract-evaluation machinery used for standalone evaluation, or through an internal equivalent that preserves the same evidence. It should not bypass postcondition evaluation, criterion evaluation, timing, token accounting, covariate capture, pacing, or warmup policy merely because the stage is being invoked inside a larger contract.

A schematic Java shape is:

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

The resulting `pipeline` is not merely a convenience wrapper. It is itself a `ServiceContract`: it can be baselined, tested, monitored, and reported as the service under evaluation. Its stage contracts remain visible through the composition trace, but the composite contract has its own criteria, its own denominator, its own population claim, and its own baseline provenance.

The minimal useful implementation need not solve every problem in the first version. In particular, trace-aware cross-stage criteria, formal distributional-compatibility declarations, and derived compositional bounds may be introduced incrementally. The minimum feature is nevertheless non-trivial: typed composition, framework-owned invocation, trace preservation, composite criteria, reach denominators, stage-local summaries, and composite baseline identity.

### 8.11 What Composition Is Not

Several exclusions are essential.

First, distributional contract composition is not a claim of automatic probabilistic composability. The existence of component contracts does not imply that their pass rates can be multiplied, averaged, unioned, or otherwise combined into a valid composite rate. Any such operation requires stated assumptions and belongs to a labelled derived analysis, not to the default semantics of composition.

Second, composition is not a substitute for end-to-end evaluation. The composed service induces its own distribution over executions. Where the application-level claim concerns the final behaviour seen by the consumer, the composed service must normally be sampled and assessed directly.

Third, composition does not make downstream standalone baselines portable. A downstream component measured on one input population may behave differently when fed values produced by an upstream stochastic component. Type compatibility is not distributional compatibility.

Fourth, composition does not collapse criteria. The argument against aggregate rates applies with greater force in a composed service, where failures may be introduced, transformed, masked, or repaired across stages. Stage-local, cross-stage, and final-output criteria should remain separately attributable.

Fifth, composition is not ordinary orchestration. Orchestration connects components so that values flow. Contract composition connects contracts so that evidence remains interpretable.

Finally, composition is not a rare-event certification device. A composed architecture may reduce risk, and a conditional containment model may help structure that claim, but no finite ordinary sample proves the absence of catastrophic behaviour. High-consequence obligations remain governed by the distinction already introduced in this paper: tolerable failures are bounded statistically; intolerable failures are bounded architecturally; and the architecture itself is then tested within the limits of finite empirical evidence.

### 8.12 Summary

Distributional contract composition extends the central move of this paper from individual stochastic services to connected stochastic architectures. A service contract is a statistically characterised interface. When such interfaces are connected, the resulting composition must not be treated as an unstructured implementation detail, nor as an invitation to calculate end-to-end quality from standalone component summaries.

A composite contract is a new empirical object. It has its own population claim, denominator, criteria, latency behaviour, baseline identity, and verdict. The component contracts remain present as trace-preserving substructures, supplying attribution and diagnostic evidence. The framework's task is to preserve that structure so that the composed service can be measured on its own terms.

The guiding rule is therefore:

> Operational composition is first-class; empirical composition is authoritative; derived composition is secondary, labelled, and assumption-bearing.
