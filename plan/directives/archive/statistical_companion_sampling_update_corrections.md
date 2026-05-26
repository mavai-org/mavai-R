# Statistical Companion — correction proposals after sampling update

**Source reviewed:** `STATISTICAL-COMPANION(4).md`  
**Version shown in source:** `1.3-draft`  
**Source last-updated field:** `2026-05-14`  
**Line numbers:** Based on the uploaded Markdown file as present in this conversation.

## Review premise

The rejection of the earlier “per-criterion validation set” proposal is accepted. In the revised model, a **sampling** is the list of input values executed by one experiment; every criterion in that experiment evaluates the same responses over that same sampling. Different input distributions are represented by separate experiments with separate samplings. The remaining proposals below preserve that model and focus only on integration residues.

## Concise correction register

| ID | Severity                  |                Lines | Issue                                                                                                                                                                                                                                                                                                                                                                 | Proposed correction                                                                                                                                                                                                                                                                                                                                                                                                                   |
|---:|---------------------------|---------------------:|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  1 | Release blocker           | 2979–3008; 3069–3107 | §10.2 still defines the inferential statistical verdict as “whether the Wilson lower bound clears `p*_c`.” That is correct for compliance, but not for regression, where the binding rule is the integer cutoff `K_c >= c_c`. The C_well-formed example already states the regression decision rule, but the verdict prose then reverts to Wilson-clearance language. | Replace the §10.2 “Statistical verdict” bullet with procedure-specific wording: compliance PASS iff the one-sided Wilson lower bound exceeds `p_req`; regression PASS iff `K_c >= c_c`. In the C_well-formed example, change the verdict explanation to “PASS because `K_c = 953 >= c_c`; Wilson lower bound and displayed threshold are reported as threshold-reference/diagnostic context, not as the binding regression decision.” |
|  2 | Important consistency fix |            2981–2983 | §10.2’s contract-level header still says singular “Type-I Envelope” and “disclosed sum over inferential criteria.” The rest of the draft now uses direction-specific envelopes.                                                                                                                                                                                       | Rename the row to **Type-I envelopes** and describe it as “procedure-direction-specific disclosed envelopes: false-degradation-signal for regression criteria and false-compliance for compliance criteria, per §1.4.6.”                                                                                                                                                                                                              |
|  3 | Important consistency fix |            3755–3758 | Appendix A repeats the same Wilson-only framing: “for inferential criteria the Wilson lower bound’s relation to `p*_c`.” This is now too narrow.                                                                                                                                                                                                                      | Replace the per-criterion verdict row with: “PASS, FAIL, or INCONCLUSIVE on a criterion: for compliance criteria, the Wilson lower bound’s relation to `p_req`; for regression criteria, the observed success count’s relation to the integer cutoff `c_c`; for observational criteria, the zero-failure observation.”                                                                                                                |
|  4 | Clarification             |   481–492; 2459–2479 | §1.4.2 says each sample is presented once; §8.2.1 describes repeated-prompt designs with `r` repetitions of each prompt. These are compatible, but the bridge is implicit.                                                                                                                                                                                            | Add a sentence after the sampling definition or at the start of §8.2.1: “A sampling is the executed trial list. Repeated-prompt designs are represented as multiple sample entries sharing the same `promptId` or cluster identifier. Each sample entry is presented once, although the same underlying input may appear in more than one entry; that repetition is recorded as cluster structure and handled under §8.2.1.”          |
|  5 | Terminology cleanup       |                 2457 | Heading still says “Clustered Validation Designs,” despite the new “sampling” terminology.                                                                                                                                                                                                                                                                            | Rename heading to **8.2.1 Clustered Sampling Designs**. Generic uses of “validation” outside the sampling primitive, such as “AI system validation” or “illustration, not validation,” can remain.                                                                                                                                                                                                                                    |
|  6 | Cross-reference fix       |              901–902 | §1.4.7 says finite-corpus and superpopulation framings are in §8.1, but the relevant section is §8.4.6.                                                                                                                                                                                                                                                               | Replace “§8.1” with **§8.4.6**.                                                                                                                                                                                                                                                                                                                                                                                                       |
|  7 | Mathematical precision    |            2751–2767 | The finite-corpus section says Wilson intervals “collapse to a point” under exhaustive evaluation. The intent is right — no binomial sampling uncertainty for the evaluated corpus — but Wilson is not the operative inferential object for an exhaustive finite-corpus estimand.                                                                                     | Replace lines 2753–2758 with: “Under exhaustive finite-corpus evaluation, the corpus rate is known exactly for the evaluated corpus: `p_c = K_c / n_c`. No binomial confidence interval is reported for that finite-corpus estimand. If a claim is made beyond the corpus, that is a separate superpopulation claim and must be labelled as such.”                                                                                    |

## Suggested replacement text for §10.2

```markdown
The **inferential verdict's three strands** adapt to the declared procedure:

- **Statistical verdict** — the hypothesis-test conclusion under the declared procedure. For compliance criteria, PASS iff the one-sided Wilson lower bound exceeds the required threshold `p_req`. For regression criteria, PASS iff the observed success count satisfies the integer cutoff `K_c >= c_c`; the Wilson-derived threshold and displayed rate are threshold-reference and diagnostic context, not the binding regression decision.
- **Observed-rate status** — whether the point estimate `p̂_c` sits on the right side of the displayed threshold. Can disagree with the statistical verdict, especially near the boundary; the disagreement is the point of disclosing both.
- **Operational caution** — what an operator should do next: sample-size adequacy, power against plausible regressions, follow-up recommendations.
```

## Suggested replacement text for the C_well-formed verdict block

```text
VERDICT
  Statistical verdict:  PASS
                        Observed successes K_c = 953 meet the regression
                        integer cutoff c_c = [reported cutoff]. Therefore
                        no degradation signal is present at α = 0.05 under
                        the declared reference-control procedure.

  Diagnostic context:   Wilson lower bound p̂_{c,L}(0.05) ≈ 0.940 and
                        derived displayed threshold p*_c ≈ 0.9385 are
                        reported for auditability and threshold provenance;
                        they are not the binding regression decision rule.
```

## Overall assessment

The sampling revision is coherent and should be retained. The remaining corrections are mostly editorial-integration fixes, except for §10’s verdict/reporting language, which should be treated as release-blocking because it can cause readers to misidentify the binding decision rule for regression criteria.
