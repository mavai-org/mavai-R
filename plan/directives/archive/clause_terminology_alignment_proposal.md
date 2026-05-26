# Clause-Terminology Alignment Proposal

**Status:** Proposal only — no edits to the companion, glossary, ontology,
catalog, or any framework are made under this document.
**Source directive:** `DIR-CLAUSE-TERMINOLOGY-javai-R` (orchestrator).
**Target documents:** `docs/STATISTICAL-COMPANION.md` (v1.3.1),
`docs/GLOSSARY.md`.
**Reconciled against:** `docs/DISTRIBUTIONAL-CONTRACTS.md` v0.4
(§"Clause Forms: Rate-Bounded and Categorical", §"Inferential and
Observational Criteria").

---

## 0. The defect in one paragraph

The companion uses **empirical** for two unrelated things: (a) the *name of
a clause form* — "empirical clause", "empirical class", "empirical-class
machinery" — and (b) one *value on the threshold-origin axis* — a threshold
"empirically derived" from a baseline, as opposed to "normative" in origin.
These are orthogonal axes. A rate-bounded clause can carry a **normative**
(SLA-mandated) threshold that was never measured, yet the companion's name
for that clause is *empirical* — so the clause-form name actively
contradicts the origin it most often carries. The distributional-contracts
paper (v0.4) already fixed this by naming the form **rate-bounded** and
reserving **empirical** for the origin only. This proposal brings the
companion and glossary up to the paper.

A second, downstream instance of the same overload: the companion calls the
zero-failures evidence criterion that supports an architectural commitment a
"**derived-empirical** criterion". That criterion is **observational** — it
estimates no rate and carries no threshold — so naming it "empirical"
re-imports the very confusion the rename removes. The paper calls it an
**observational** criterion. This proposal recommends the companion follow.

---

## 1. Inventory of affected text in the companion

Occurrences fall into four buckets. Line numbers are against
`STATISTICAL-COMPANION.md` at the revision investigated (v1.3.1); treat them
as locators, not as guarantees against drift.

### 1a. Form-naming uses of "empirical" — **must change** (the core defect)

| Line(s) | Text | Sense |
|---|---|---|
| 117 | Section title `## Clause Types: Empirical and Categorical` | form name |
| 128 | "An **empirical clause** states a rate-bounded proposition" | form name (defining sentence) |
| 150–152 | "**Empirical** and categorical clauses are not two points…"; "does not promote an **empirical clause**" | form name |
| 157–158 | "discharged by the **empirical-clause apparatus**" | form name |
| 166, 169 | "derived **empirical clauses**"; "ordinary **empirical clauses**" | form name |
| 181 | "The **empirical/categorical** distinction is foundational" | form name |
| 184 | "all operate *within the **empirical class***" | form name |
| 193 | "Within the **empirical class** of contract clauses" | form name |
| 352–356 | "rate-bounded **empirical** criteria"; "**empirical-class** machinery"; "categorical rather than **empirical**" | form name |
| 368–369 | "the **empirical and categorical clause classes**"; cross-ref to section title | form name |
| 375, 381, 384, 389 | "Within the **empirical class**"; "the **empirical/categorical** boundary"; "limit-case of an **empirical clause**" | form name |
| 391, 396 | "**empirical-class** criteria"; "**empirical-class** peers" | form name |
| 432, 436 | "Within the **empirical class**"; "the **empirical/categorical** boundary" | form name |
| 445–450 | "$P_1$ … **empirical**, low-consequence" (and $P_2$, $P_3$) | form name (classifying a criterion) |

### 1b. "Derived empirical criterion" — **should change** (the second overload)

These name an **observational** criterion as "empirical", re-introducing the
overload. The directive (item 1) flags exactly this. Reword to *observational
zero-failures criterion* (providing evidence for the architectural
commitment).

| Line(s) | Text |
|---|---|
| 455 | "the guardrail's false-negative rate is evaluated as a **derived empirical criterion** over an adversarial sampling" |
| 469 | "the guardrail's **derived empirical criteria** may themselves be…" |
| 739–745 | §1.4.5 epistemic-status use #1, titled "*Derived-empirical.*" — "evaluates a **derived empirical criterion** on an architectural component" |
| 760–762 | "no **derived-empirical** criterion paired with it" |
| 1046–1049 | "$C_{\text{no-self-harm}}$ … is the *__derived-empirical__* observational criterion" |

**Note on a genuine subtlety.** A guardrail also carries its *own* contract,
which is a real **rate-bounded clause with an empirical-origin threshold**
("the guardrail's false-negative rate ≥ 0.99 at high confidence"). Calling
*that* "empirical" (origin sense) is correct. The defect at 455/739/1046 is
that the companion conflates the guardrail's rate-bounded own-contract with
the **observational** zero-failures criterion that the methodology actually
scores as evidence (the one the rule-of-three annotation applies to, the one
with no threshold). The reword must preserve the distinction, not erase it:
the *evidence* criterion is observational; the guardrail's *own contract* may
separately be a rate-bounded, empirical-origin clause.

### 1c. Origin-sense uses of "empirical" — **keep unchanged**

These are already correct under the proposed vocabulary and must be left
alone:

| Line(s) | Text |
|---|---|
| 132–133, 169–170 | "empirically derived (a measured baseline)"; "may be normative or empirical in origin" |
| 1578 | "the Wilson-derived **empirical regression rule**" (origin/paradigm sense) |
| Glossary "Empirical Baseline", "Empirical Percentile", "Threshold Origin", "Normative Threshold" | origin / unrelated senses |

### 1d. Zero-failures / observational prose — **already correct, keep**

Lines 408–409, 419–425, 711, 730, 974, 994, 999, 3780 use "zero-failures",
"`zeroFailures`", and "observational" in the kept vocabulary. No change.

### 1e. Document-history ledger — **append, do not rewrite**

Milestone 6 (line 21) records "clauses are typed as **empirical**
(rate-bounded …) or **categorical**". The document history is an immutable
ledger; rather than edit milestone 6, add a milestone 7 row recording the
terminology refinement (form = rate-bounded; *empirical* confined to origin).

---

## 2. Proposed vocabulary (reconciled with paper + implementation)

| Axis | Value | Authoring construct (confirmed in source) | Decision |
|---|---|---|---|
| **Form** | rate-bounded | `Criteria.meeting()` / `Criteria.empirical()` (Java); `Criteria::meeting()` / `Criteria::empirical()` (Rust) | Adopt **rate-bounded clause** as the form-class name (paper's term). |
| **Form** | categorical | `ContractualDecl.zeroFailures()` (Java); `NormativeCriteria/EmpiricalCriteria::zero_failures()` (Rust) | Adopt **categorical clause**, with **zero-failures** as its single recognised form. |
| **Origin** (of a rate-bounded threshold) | normative *(a.k.a. stipulated)* | `meeting()` | Standardise on **normative** as the primary term; introduce **stipulated** as an explicit synonym on first use and in the glossary. |
| **Origin** | empirical | `empirical()` | Keep **empirical** — but only here. |

**Construct names — confirmed against source** (read-only, this
investigation), validating the directive's table:

| Concept | Java (punit) | Rust (feotest) |
|---|---|---|
| normative/stipulated rate threshold | `Criteria.meeting()` → `ContractualDecl` (`api/criterion/Criteria.java:165`) | `Criteria::meeting()` → `NormativeCriteria` (`src/criteria/mod.rs:53`) |
| empirically-derived rate threshold | `Criteria.empirical()` → `EmpiricalDecl` (`api/criterion/Criteria.java:181`) | `Criteria::empirical()` → `EmpiricalCriteria` (`src/criteria/mod.rs:59`) |
| zero-failures (categorical) | `ContractualDecl.zeroFailures()` (`api/criterion/ContractualDecl.java:54`) | `*::zero_failures()` (`src/criteria/builder.rs:61,88`) |

The construct names map cleanly onto the proposed vocabulary: `meeting()` =
normative origin, `empirical()` = empirical origin, `zeroFailures()` =
categorical form. The directive's guesses were all correct.

**Minor cross-implementation note (out of scope, flag only):** in Java,
`zeroFailures()` lives only on the contractual/`meeting` path —
`EmpiricalDecl` deliberately omits it ("zero-failures is intrinsically
contractual"). In Rust, `zero_failures()` is offered on *both* the normative
and empirical builders. The categorical form is conceptually origin-free, so
neither is wrong, but the surfaces differ. This is an API-shape observation
for a possible future framework directive, **not** part of the terminology
change.

**Normative vs stipulated.** Recommendation: **carry both, lead with
"normative".** The paper writes "**normative** (equivalently *stipulated*)".
"Normative" is the load-bearing term (it is what the glossary "Normative
Threshold" entry and the `ThresholdOrigin` enum already use); "stipulated"
reads more naturally in some sentences ("a stipulated 99.5%"). Standardising
on one and banning the other would cost more churn than it saves. Define them
as synonyms once, then use "normative" as the default.

**Mapping to compliance/regression.** The companion already states (line 138
of the paper; §3 of the companion) that compliance and regression "are
exactly these two origins seen from the decision side": **compliance ↔
normative origin**, **regression ↔ empirical origin**. The proposal should
**state this mapping once** at the point the origin axis is introduced and
**not duplicate** the compliance/regression treatment — those sections (§3,
§3.4) stay as-is; only their framing sentence gains a one-line pointer that
"compliance" and "regression" are the decision-side names for the normative
and empirical origins respectively.

---

## 3. Located change proposals — companion

Section by section. "Cosmetic" = pure find-and-replace of a form-name;
"load-bearing" = a defined term, cross-reference, or sentence whose logic
must be re-read.

### 3.1 Section title (line 117) — **load-bearing**

- **Before:** `## Clause Types: Empirical and Categorical`
- **After:** `## Clause Forms: Rate-Bounded and Categorical`

Mirrors the paper's section title exactly. **Blast radius:** this title is
cross-referenced by name in at least six places (lines 369, 423–424,
736–737, 1046–1047, and the glossary). Every "*Clause Types: Empirical and
Categorical*" cross-reference string must be updated in lockstep to
"*Clause Forms: Rate-Bounded and Categorical*". Also rename "Types" → "Forms"
to match the paper's "form" vocabulary; "type" collides with the verbed
"clauses are *typed* as…" usage and is better retired here.

### 3.2 Defining paragraphs (lines 119–158) — **load-bearing**

Replace the opening two-axis framing with the paper's §"Clause Forms"
framing. Concretely:

- **Before (128):** "An **empirical clause** states a rate-bounded
  proposition: …"
- **After:** "A **rate-bounded clause** states a proposition of the shape
  *criterion $c$ shall hold at rate at least $p^*_c$, with confidence
  $1-\alpha_c$*. Its threshold $p^*_c$ has one of two **origins** —
  **normative** (a.k.a. *stipulated*) or **empirical** — developed under §3;
  the word *empirical* names that origin and is **not** the name of this
  form."

- **Before (150–158):** "**Empirical** and categorical clauses are not two
  points on a strictness spectrum… cannot be discharged by the
  **empirical-clause apparatus**…"
- **After:** "**Rate-bounded** and categorical clauses are not two points on
  a strictness spectrum… cannot be discharged by the **rate-bounded
  apparatus**…" (mechanical substitution, but verify each sentence still
  parses).

Recommend lifting the paper's §"Clause Forms" prose nearly verbatim here,
since the paper is now the upstream authority and the two should not drift.

### 3.3 Architectural-discharge paragraph (lines 160–172) — **load-bearing**

- **Before (165–169):** "its performance re-enters the contract as one or
  more **derived empirical clauses** … The derived clauses are ordinary
  **empirical clauses**…"
- **After:** "its performance re-enters the contract as one or more
  **rate-bounded clauses with empirical-origin thresholds** … These are
  ordinary **rate-bounded clauses**; their thresholds are empirical in
  origin." — This is the place where the origin sense is *correct*; make the
  origin explicit rather than leaning on the old form-name.

Keep separate the guardrail's own rate-bounded contract (correct to call
empirical-origin) from the observational evidence criterion (§3.6 below).

### 3.4 Foundational-distinction paragraph (lines 181–187) — **cosmetic+**

- "The **empirical/categorical** distinction" → "The **rate-bounded/categorical**
  distinction".
- "operate *within the empirical class*" → "operate *within the rate-bounded
  class*".

### 3.5 Compliance/Regression bridge (lines 191–203) — **load-bearing, light**

- "Within the **empirical class** of contract clauses" → "Within the
  **rate-bounded class** of contract clauses".
- Add a single framing sentence at the head of §3 (or retain where the origin
  axis is introduced): "Compliance and regression are the decision-side names
  for the two threshold **origins**: compliance tests a **normative**
  threshold, regression tests an **empirical** one." Do **not** restate the
  procedures.

### 3.6 §1.4 development — three-axis example (lines 340–469) — **mixed**

- Lines 351–356: "rate-bounded **empirical** criteria" → "rate-bounded
  criteria"; "**empirical-class** machinery" → "rate-bounded machinery";
  "Self-harm is **categorical** rather than **empirical**" → "Self-harm is
  **categorical** rather than **rate-bounded**".
- Lines 368–369, 375, 381, 384, 389, 391, 396, 432, 436: substitute
  "empirical class/boundary" → "rate-bounded class/boundary", "empirical-class
  peers" → "rate-bounded peers", "limit-case of an **empirical clause**" →
  "limit-case of a **rate-bounded clause**".
- Lines 445–450 ($P_1$–$P_3$): "**empirical**, low-consequence" →
  "**rate-bounded**, low-consequence" (etc.).
- Lines 455, 469 ($P_4$ / guardrail): see §3.7.

### 3.7 §1.4.5 observational mode + epistemic status (lines 711–765) — **load-bearing**

This is the "derived-empirical" overload (bucket 1b).

- **Before (455):** "the guardrail's false-negative rate is evaluated as a
  **derived empirical criterion** over an adversarial sampling"
- **After:** "the guardrail's false-negative behaviour over an adversarial
  sampling is reported as an **observational zero-failures criterion**, read
  as evidence for the architectural commitment" — matching the paper's
  line ("Observational criteria are the methodology's vehicle for the
  zero-failures evidence that supports an architectural commitment").

- **Before (739, the §1.4.5 use #1 heading "*Derived-empirical.*"):** "The
  verdict evaluates a **derived empirical criterion** on an architectural
  component…"
- **After:** retitle the use to "*Architectural-commitment evidence.*" and
  reword to "The verdict evaluates an **observational zero-failures
  criterion** on an architectural component — typically a guardrail's
  false-negative behaviour over an adversarial sampling." Keep the
  rule-of-three annotation (it is *because* the criterion is observational
  that rule-of-three applies — which is itself the proof the old name was
  wrong).

- Lines 760–762, 1046–1049: "**derived-empirical** criterion" →
  "**observational zero-failures** criterion".

### 3.8 §7 / §10 report vocabulary (lines 1040–1059) — **load-bearing**

Update the report-reader prose at 1046–1049 as in §3.7. Confirm no report
*field name* or XSD element carries "empirical" as a form label — the
verdict XML uses `ThresholdOrigin`/procedure direction, not a clause-form
string (see §5 blast radius). If a report column is literally headed
"empirical clause", rename to "rate-bounded clause"; otherwise prose-only.

### 3.9 Document history (line 21) — **append milestone 7**

Add a new row: "**Terminology refinement.** Clause *form* renamed
rate-bounded (was 'empirical'); *empirical* confined to the threshold-origin
axis; the zero-failures evidence criterion named observational, not
derived-empirical. No change to the statistics or the model." Leave
milestone 6 as the historical record.

---

## 4. Located change proposals — glossary

### 4.1 Rename / replace "Empirical Clause" → **"Rate-Bounded Clause"**

- **Remove** the "Empirical Clause" row (line 26).
- **Add** "Rate-Bounded Clause": "A service-contract clause stating a
  rate-bounded proposition: the criterion's true pass rate $p_c$ must clear a
  threshold $p^*_c$ at confidence $1-\alpha_c$. Discharged statistically by
  the Wilson construction and integer-pass-cutoff machinery (§3, §3.4). Its
  threshold's **origin** — normative or empirical — is a separate axis (see
  *Threshold Origin*, *Form vs Origin*). Not promotable to a categorical
  clause by letting $p^*_c\to1$. See Statistical Companion §"Clause Forms"."
- Optionally retain an "Empirical Clause" stub as a **deprecated
  cross-reference**: "*Empirical clause* — former name for *Rate-Bounded
  Clause*; the word *empirical* is now reserved for the threshold origin.
  See *Rate-Bounded Clause*." (Recommended, since published posts and older
  per-framework docs may still use it.)

### 4.2 Amend "Categorical Clause" (line 10)

- Replace "not promotable from an **empirical clause** by letting $p^*_c\to1$.
  The **empirical-class machinery** does not apply." with "not promotable from
  a **rate-bounded clause** by letting $p^*_c\to1$. The rate-bounded machinery
  does not apply. Recognised in exactly one form, **zero-failures**, evaluated
  observationally." Update the §1.4 cross-ref to §"Clause Forms".

### 4.3 Amend "Service Contract" (line 72)

- "Clauses are typed as **empirical** (rate-bounded, statistically evaluated)
  or **categorical**…" → "Clauses take one of two **forms**: **rate-bounded**
  (statistically evaluated) or **categorical** (discharged architecturally)."

### 4.4 Amend "Observational Mode" (line 54)

- "typically the **derived empirical criterion** paired with a categorical
  clause discharged architecturally" → "typically the **observational
  zero-failures criterion** that provides evidence for a categorical clause
  discharged architecturally".

### 4.5 New entries

- **Zero-Failures Clause** (or "…Form"): "The single form in which a
  categorical clause is recognised: the developer declares the expectation
  while explicitly abandoning any statistical lower bound. Evaluated
  observationally (PASS if no failure observed, FAIL on any, INCONCLUSIVE only
  if no trials). Authored as `zeroFailures()` (punit) / `zero_failures()`
  (feotest)."
- **Stipulated Threshold**: cross-reference to **Normative Threshold**
  ("synonym; *normative* is the primary term").
- **Form vs Origin**: "Two orthogonal axes describing a clause. **Form** —
  rate-bounded vs categorical — is *what kind of proposition* the clause
  states. **Origin** — normative vs empirical — is *where a rate-bounded
  threshold came from*. The word *empirical* names a value on the origin axis
  only; it is not a form."
- **Per-Sample Outcome vs Run-Level Verdict**: "A criterion's outcome on a
  **single sample** is two-valued — PASS or FAIL (a FAIL carrying a
  condition or transform/no-value reason). Only the **run-level verdict**,
  aggregated over the whole sampling, is three-valued and may be
  **INCONCLUSIVE** — when the run cannot support a determination (sample below
  the feasibility minimum, or an empirical-origin threshold with no baseline
  rate for the covariates in force). INCONCLUSIVE is a statement about the
  run, never about any one sample."

### 4.6 Leave unchanged

"Empirical Baseline", "Empirical Percentile", "Normative Threshold",
"Threshold Origin", "Inferential Mode", "Compliance/Conformance Testing" —
all use vocabulary that is correct under the proposal.

---

## 5. Blast-radius and risk assessment

### 5.1 Fixtures, schema, method/keyword strings — **NOT affected** (confirmed)

Verified by scanning `inst/cases/*.json` and `schema/cases.schema.json`:

- No fixture contains "empirical clause", "empirical class", "empirical-class",
  or "derived empirical" in the renamed form-naming sense.
- The four fixtures that match `empirical|categorical|clause|zero.failure` use
  only **kept** vocabulary:
  - `latency_percentile.json` — "Empirical *percentile*" (an unrelated term).
  - `multi_criteria_scenario_consult_advice.json` — "EMPIRICAL *origin*"
    (origin sense, kept).
  - `criterion_verdict_observational.json` — `zero_failures` case names (kept).
  - `baseline_object.json` — "observational criterion" (kept).
- No `"method"` string, schema enum, or keyword carries a clause-form label;
  origins are carried by procedure direction (REGRESSION/COMPLIANCE) and
  `EMPIRICAL`/`SLO`-origin tags, all of which the proposal **keeps**.

**Conclusion:** this is a prose-only terminology change. The
fixture-versioning discipline in `javai-R/CLAUDE.md` is **not** triggered.
No `DESCRIPTION` bump, no `cases-vX.Y.Z` release, no `REQ-R-*.md` downstream
requirement. This matches the directive's expectation and the acceptance
criterion.

### 5.2 Downstream consistency

| Surface | Impact | Action |
|---|---|---|
| `DISTRIBUTIONAL-CONTRACTS.md` (paper) | already aligned (v0.4) | none — it is the upstream authority |
| punit / feotest **source** | construct names (`meeting`/`empirical`/`zeroFailures`) are origin/form constructs, not the overloaded form-name; the requirement-code isolation rule already keeps planning vocabulary out of source | none expected; a later doc-only directive may align per-project **user guides** if they say "empirical clause" |
| punit / feotest **docs** | may use "empirical clause"; check after companion lands | follow-on per-framework doc directive (sequenced last) |
| orchestrator `inventory/catalog/` | catalog entries reference companion section numbers and may use "empirical clause" | follow-on directive; the §"Clause Forms" title change breaks any `§"Clause Types…"` cross-reference |
| family `DOMAIN-ONTOLOGY.md` | **Ambiguous Terms** section is the designated home for exactly this overload | **Recommend**: record *empirical* (form vs origin) in Ambiguous Terms, and add *rate-bounded clause* / *categorical clause* / *zero-failures* as concepts. Editing the ontology is out of scope here; the proposal flags it for the sequenced directive. |
| verdict XML / XSD | uses `ThresholdOrigin` + procedure direction, not a clause-form string | none expected; confirm during companion edit |

### 5.3 Risks

- **Cross-reference breakage.** The biggest concrete risk is the section-title
  rename (§3.1): every "*Clause Types: Empirical and Categorical*" string
  across the companion, glossary, catalog, and per-framework docs must move to
  "*Clause Forms: Rate-Bounded and Categorical*" together, or links rot. This
  is mechanical but easy to miss.
- **Origin/form re-confusion during edit.** The same word stays in the
  vocabulary (origin sense), so a careless find-and-replace of "empirical" →
  "rate-bounded" would wrongly rewrite the origin uses (§1c). Edits must be
  bucket-aware, not global.
- **Guardrail criterion subtlety (§3.3/§3.7).** Conflating the guardrail's own
  rate-bounded empirical-origin contract with the observational evidence
  criterion is the current defect; the reword must keep them distinct, not
  collapse both into "observational".

---

## 6. Recommendation: **GO**

Adopt the rename. Rationale:

1. **The defect is real and load-bearing, not cosmetic.** The current
   form-name *contradicts* the origin it most often carries (a normative SLA
   threshold housed in a clause named "empirical"). The paper already judged
   this worth fixing and fixed it; leaving the companion — the **oracle** —
   behind inverts the family's source-of-truth ordering (companion wins; here
   the paper is ahead and the companion must catch up).
2. **The churn is bounded and prose-only.** No fixtures, no schema, no version
   bump, no code. The cost is editing two documents plus sequenced
   cross-reference fixes — entirely within the methodology-prose layer.
3. **The vocabulary maps cleanly onto shipped constructs** (`meeting()` /
   `empirical()` / `zeroFailures()`), so there is no risk of the docs naming
   something the frameworks cannot express.

The alternative — keep "empirical clause" and add a disambiguating note — is
**not recommended**: it preserves a name that is actively misleading
(empirical-named clauses that are normative in origin), forces every reader
to hold a footnote in mind, and leaves the oracle permanently out of step
with its own paper. A disambiguating note is the right tool for an
*unavoidable* overload; here the overload is avoidable, and the paper has
already shown the way.

**One concession to caution:** retain "empirical clause" as a *deprecated
cross-reference* stub in the glossary (§4.1) for one revision, so external
readers and older per-framework docs land softly.

---

## 7. Recommended sequencing

If accepted, spawn follow-on edit directives in this order, each its own
commit/PR, each referencing this investigation:

1. **Companion** (`STATISTICAL-COMPANION.md`) — the oracle; lands first.
   Includes the §"Clause Forms" title rename and all bucket-1a/1b edits.
2. **Glossary** (`GLOSSARY.md`) — new/renamed entries (§4).
3. **Family ontology** (`DOMAIN-ONTOLOGY.md`) Ambiguous Terms + concepts, and
   orchestrator **catalog** cross-reference fixes — in one orchestrator commit
   (ontology and inventory move in lockstep per orchestrator CLAUDE.md).
4. **Per-framework docs** (punit / feotest user guides) — only if they use the
   old form-name; lowest priority, no source changes.

No per-language framework source work and no fixture work is authorised by
this investigation or by step 4 (docs only).

---

## Appendix: acceptance-criteria self-check

- [x] Proposal document exists in `javai-R` capturing items 1–6, with located
  before/after text for companion and glossary.
- [x] Internally consistent with `DISTRIBUTIONAL-CONTRACTS.md` v0.4 and with
  the confirmed implementation constructs (`meeting`/`empirical`/`zeroFailures`).
- [x] Blast-radius section explicitly states fixtures/schema are **not**
  affected; versioning discipline **not** triggered.
- [x] No change made to companion, glossary, ontology, catalog, or any
  framework (this is a new proposal file only).
