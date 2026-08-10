# Changelog

All notable changes to the `mavai-R` fixture releases are documented here.
Versions follow the fixture-versioning rules declared in `CLAUDE.md`:
**minor** bumps on 0.x mark breaking changes to fixture content or shape;
**patch** bumps mark additive changes.

## [0.10.12] — 2026-08-10

**A postcondition says who stated it, and a verdict record says what its
inputs are.** Two additive facts, carried in one turn of the loop so the
schemas move once.

*Postcondition provenance.* A standings row gains an optional
`provenance`: `criterion` for a postcondition the criterion states, asserted
of every input; `input` for one an input's own expected values state,
asserted only against that input. Both are postconditions — they differ in
who stated them, and their denominators differ accordingly, which is why a
consumer that lists them together shows one figure out of six beside
another out of twelve with nothing to explain it. Absence means
`criterion`, so every emission already in the field keeps its present
meaning and no consumer needs a migration. Added to
`mavai-explore-1` and `mavai-optimize-1`; `mavai-baseline-1` defers to the
exploration schema for the standings shape and needed no change.

*Verdict record inputs.* `schema/verdict-1.6.xsd` adds an optional
`<inputs>` element, one `<input>` per input with its structural index and a
bounded excerpt, and the same optional `@provenance` on a standings row.
Every other interchange format has carried an inputs block for some time; a
verdict record could not, so a verdict report named the document a failure
came from by its index and nothing else. Stated for every input, not only
the ones that failed. Both additions are optional: a 1.5-shaped record is a
valid 1.6 record.

Worked examples: `explore-typical.yaml` states both provenances, including
an input postcondition whose denominator is that input's samples alone, and
`verdict-1.6-typical.xml` states the inputs block and both provenances. The
pre-amendment examples are untouched and still validate — absence remains
the shape most records have.

A note on the word, since the verdict record now carries it twice: a
`<provenance>` element describes the run, the `@provenance` attribute
describes a postcondition. They sit at different positions and ask the same
question of different subjects — where did this stated thing come from —
which is why the family spells both the same way.

## [0.10.11] — 2026-08-10

**The baseline schema ships in the bundle.** `mavai-baseline-1` has been the
family's one baseline format since 0.9.0, and its worked examples have
travelled in every interchange asset since — but the schema itself never
did. The commit that introduced it says *publish*, and the packaging step
was missed, so a consumer following the release could obtain the format's
examples and not the format. It is in the bundle from this release; the
copies vendored downstream were taken from the repository rather than from
an asset, whatever their notes say.

The interchange validator now checks the bundle against the directory in
both directions — a schema present but unpackaged, a packaged name that does
not exist — so the next format cannot be published everywhere except in its
own release asset. It runs before packaging in the release workflow, so the
release fails rather than shipping short.

**An input can say what it is (additive).** A report could name an input
only where that input had failed. `inputExcerpt` rides on
`failureDistribution` entries, so a document that behaved had nowhere to
state what it was, and a reader met a table naming one row and leaving five
blank — asymmetry that reads as missing data rather than as a fact about
which inputs failed.

Every artefact may now state **`inputs`**: one entry per input the run drove,
each carrying the `inputIndex` that failure entries already use and an
`inputExcerpt` of the same shape and bound. Optional and additive in
`mavai-explore-1`, `mavai-optimize-1` and `mavai-baseline-1` — absent in
pre-amendment emissions, and a consumer reads absence as *not stated* and
renders the report it renders today.

Informational throughout. Nothing here is identity: that remains the inputs
fingerprint, which is why an emitter may state a document's name without
its path. Consumers correlate by `inputIndex`, never by matching excerpts.

The worked examples show both: the three `*-typical` documents state the
block, and the `*-minimal` ones do not.

## [0.10.10] — 2026-08-07

**A failed delivery says so (additive).** A trial that never received a
response and a trial that received one and failed it are different findings
that have, until now, been serialised identically: both a failed trial, both
a `failureDistribution` entry, the delivery cause travelling as free text in
the same `condition` field a declared contract condition uses. So a run in
which nothing was ever measured presented exactly like a run in which
everything was measured and found wanting — a 0.0 pass rate across four
configurations, diagnosable only by reading raw artefacts.

Every failure entry may now state **`kind`**: `delivery` or `evaluated`.
Optional and additive — absent in pre-amendment emissions, and a consumer
reads absence as *not stated*, never as "evaluated". The arithmetic is
untouched: a failed delivery remains one failed trial counted against every
criterion, and this states what kind of failure it was, not how much it
counts. There is deliberately **no second count** of delivery failures: a
consumer sums the delivery-kind entries, which is a trivial aggregate over
stated counts, where a separate field would be a second source of one truth
free to disagree with the first.

A delivery entry's `condition` carries its **cause**, from a closed
vocabulary the schemas enforce: `unreachable`, `client-deadline`,
`peer-timeout`, `server-error`, `unusable-response`. Free text is refused
there — a cause that is not groupable is not countable, and one that
interpolates an endpoint or a provider message is not an identity at all
(area rule 6). The two timeout senses are separate tokens on purpose:
`client-deadline` says *this framework stopped waiting*, which only a
framework holding its own deadline may claim, and `peer-timeout` says the
peer stated that it did. One `timeout` token would have blurred them the
moment client deadlines arrived, which they now have
(`DIR-FAM-TIMEOUT-client-deadline`).

`mavai-explore-1`, `mavai-optimize-1` and `mavai-baseline-1` all carry the
amendment — one entry shape across the family, since an amendment reaching
only the format a given report happens to read is how the last one went
unnoticed. In the baseline format `kind` sits beside the existing `reason`
and is orthogonal to it: `reason` is the Companion's §1.4.5a axis over
trials that *were* evaluated, and a delivery entry states none, having never
reached evaluation. Widening that enum instead would have put a transport
fact on a companion-owned axis.

`schema/verdict-1.5.xsd` adds the optional `@kind` on a failure-distribution
`<check>`; 1.4 stays published and a 1.4-shaped check is a valid 1.5 check.
The cause vocabulary is documented rather than typed there, because the
constraint is conditional on `@kind` and XSD 1.0 cannot state a
co-occurrence constraint — a simpleType nothing referenced would imply an
enforcement the schema does not perform.

Worked examples: `explore-nothing-delivered.yaml` (the incident's shape —
every sample undelivered, three causes, all standings skipped) and
`explore-mixed-delivery.yaml` (both kinds in one run, counts still summing
to `failures`), plus `verdict-1.5-typical.xml`. The pre-amendment examples
are unchanged and remain valid, which is the absent-kind case.

**The services format gains `deadline-ms` (additive).** `mavai-services/1`
admits the reader's own deadline on a `language-model` service — how long it
waits for one response before recording a failed delivery, in whole
milliseconds, bounding the whole exchange rather than the connection. It is
a distributional factor and therefore identity: a shorter deadline converts
slow-but-delivered responses into failed deliveries. The schema states no
upper bound; what the format requires is that a reader ship a *finite*
default and record it resolved, not that the number be small.

## [0.10.9] — 2026-08-05

**The author can name a configuration (additive).** A configuration's
identity is derived from its factor *values*, so grid points sharing a long
common prefix — three system prompts all opening "You are an information
extraction system" — are identical in their readable half by construction,
separated only by a digest. A reader comparing them learns nothing from the
name. `mavai-explore-1` therefore gains **`configurationName`**: the
author's name for what the configuration *is*, stated on the grid entry
rather than derived from its values.

Optional and stated only when authored. A consumer showing a configuration
to a reader shows this when present, and otherwise falls back to whatever it
derives from `configuration` — never to an empty name, which is why the
empty string is refused rather than treated as absence. Bounded at 256
characters like every other displayable value. It is prose: it carries no
uniqueness guarantee and never becomes identity, so two configurations may
state the same name and remain two configurations.

**`configuration` is no longer described as a display name.** It never was
one — it is emitter-derived identity, and calling it a display name left two
fields claiming the reader's eye once a name existed beside it. The
description now says what the field is; nothing about its type, its
`binding` class, or any emitted value changes.

Specified in the orchestrator catalog's `MAVAI-EXPLORE-FORMAT.md`
(amendment 2026-08-05, `DIR-FAM-PROVENANCE-factor-sources`). Additive: a
pre-amendment document validates unchanged, and no emitter is obliged to
adopt the field.

## [0.10.8] — 2026-08-03

**Zero-trial worked example corrected (additive).** The
`baseline-zero-trials` example stated `observedPassRate: 0.0` beside a
null `wilsonLowerBound`. A rate is not stateable at zero trials, and
asserting one from the same non-evidence that makes the bound null is the
confusion the null was introduced to prevent — so the field is now absent
in that document, value-or-absent as the latency percentiles already are.
Found by baseltest's emitter-conformance suite, whose writer omits it.

The schema is unchanged: `observedPassRate` was never in `required`, so
both spellings validate. Only the example was inconsistent with what a
conformant emitter produces, which is precisely what a worked example
must not be.

## [0.10.7] — 2026-08-03

**Baseline interchange schema published (additive).** The family's
baseline (measure) artefact gains its first machine-checkable form:
`schema/mavai-baseline-1.schema.json`, plus five worked examples in
`inst/interchange/` and validation wired into
`scripts/validate_interchange.R`. Until now this repository published
schemas for `mavai-explore-1`, `mavai-optimize-1` and the verdict XSD
set, but nothing for the one artefact that is *read back* — by a
resolver, to derive a regression threshold — so it was the only
interchange surface with no published contract.

`mavai-baseline-1` supersedes the three per-framework dialects
(`baseltest-baseline-2`, `punit-baseline-3`, `feotest-spec-1`) under
`DIR-FAM-BASELINE-interchange-standard`. Because it is read back rather
than only displayed, it carries identity that is *compared*: the tuple
`(serviceContractId, serviceName, covariateProfile, inputsIdentity)`, no
element of which keys a record alone. Per-criterion it states `trials`,
`successes`, `observedPassRate` and a one-sided `wilsonLowerBound` at the
record's `confidenceLevel` — a characterisation of the recorded evidence,
never an acceptance threshold — with `contentFingerprint` over the whole.

The examples pin what a schema cannot: the perfect baseline states
`0.9737` where a test at the same sample size would derive `0.9323`,
because the test side applies the §4.3.2 two-step and the measure side
does not; the zero-trials document states a **null** bound rather than
omitting it, so "no evidence" stays distinguishable from "field absent".
Supporting that required teaching `read_yaml_as_json` explicit nulls
(YAML null → R `NULL` → jsonlite `{}` had failed validation as an
object) — this is the first interchange format to state one.

No denominator policy appears anywhere in the schema: the Companion
withdrew the per-criterion policy in 2026-05 (§1.4.5a), so `trials` is
the full sampling and a trial that produced no testable value is a FAIL
distinguished by its *reason*. The generators in this repository still
carry the withdrawn construct; correcting them is its own change
(`DIR-FAM-DENOMINATOR-policy-withdrawal`), as is amending
`inst/cases/baseline_object.json` to carry the new fields.

Additive: no existing suite, schema or fixture value changes.

## [0.10.6] — 2026-07-31

**Base configuration stated in the explore schema (additive).** Entry
backfilled 2026-08-03; the version shipped without one. An explore
corpus is a base configuration plus configurations overriding some of
its factor values, but every emitted document carries its own
fully-resolved factor set, so the overlay structure is lost at
serialisation and consumers were left inferring which configuration the
sweep was built around — inference that provably cannot recover it,
since a cross-product design is balanced and every corner reads equally
well as the base. `mavai-explore-1` therefore gains **`baseConfiguration`**,
stated only on the base and only as `true`
(`DIR-FAM-BASE-configuration-marker`), with `explore-typical.yaml`
updated and schema tests extended.

## [0.10.5] — 2026-07-29

**Format corpus: named path anchors (additive).** Both format schemas
admit the top-level **`roots:`** block added by the 2026-07-29
named-path-anchors spec amendment (`DIR-FAM-ROOTS-named-path-anchors`):
named anchors for file-referencing positions — names matching
`[a-z][a-z0-9-]*`, values relative directory paths — referenced as
`@<name>/…` from file-sourced parts. The **`mavai-services/1`** schema
additionally gains the format's first file-referencing position:
`system-prompt:` accepts **`{file: <path>}`** (UTF-8 text; the resolved
string is the covariate exactly as if inline), in the baseline
configuration and in exploration deltas alike. Structural constraints
pinned schema-side: non-empty block, name pattern, non-empty relative
values (the POSIX absolute spelling refused by pattern; loaders refuse
every spelling), and the non-empty `file:` value. Everything the schema
deliberately accepts — `@` reference resolution, undeclared-reference
and dead-declaration refusals, directory existence, the
`MAVAI_ROOT_<NAME>` override (environment behaviour, outside the corpus)
— is loader obligation, manifest-carried. New structural categories
`roots-block-malformed`, `roots-name-shape`, `roots-value-malformed`,
`lm-system-prompt-file-malformed`; new semantic categories
`roots-reference-undeclared`, `roots-dead-declaration`,
`roots-directory-missing`, `services-roots-reference-undeclared`. Two
`valid/` cases exercise roots over text and media parts (contract) and
the prompt-file form with and without a root (services); one new corpus
asset (`system-prompt.txt`). This release is the dependency floor for
the framework implementations of the amendment (baseltest first).

## [0.10.4] — 2026-07-29

**Format corpus: the graded set claim (additive).** The
`mavai-contract/1` schema admits the composite **`set-of:`** form,
added by the 2026-07-29 graded-set spec amendment
(`DIR-BAS-FORMS-set-of`): required members, tolerated members with a
`min-present:` floor (a distinct-member count, or an explicit `N%`
resolved by floor exactly as `optional-slack:`), and `refuse-extras:`
defaulting true. **Membership semantics — a set is a set (owner
ruling)**: declared lists and the selection are judged as sets,
duplicates collapsing to one entry; an operand duplicate is a loader
warning (informational), never a refusal, pinned by the
`contract-set-of-duplicate-member.yaml` valid case. `optional:` is
structurally required on the composite operand — a `set-of:` without
it states `equals-set:`/`contains-set:` and is refused naming the
sharper form. New structural categories `set-of-without-optional`,
`set-of-min-present-malformed`; new semantic categories
`set-of-lists-overlap`, `set-of-min-present-bounds` (excess and
saturated floors, one file each). Two `valid/` cases exercise the full
spelling, the percentage floor, `refuse-extras: false`, the
pure-subset claim, and per-input use. This release is the dependency
floor for the baseltest implementation.

## [0.10.3] — 2026-07-29

**Release packaging fix (no content change).** The release workflow's
interchange bundle listed the verdict XSDs by hand (1.0–1.2) and
globbed only YAML worked examples, so the v0.10.1 and v0.10.2
`interchange-*.zip` assets silently omitted `verdict-1.3.xsd`,
`verdict-1.4.xsd`, and their typical XML records — the releases'
own headline deliverables. The workflow now globs every
`verdict-*.xsd` revision and both YAML and XML worked examples. No
schema, corpus, or fixture content changes; this release exists so a
complete interchange bundle is published under an immutable tag —
consumers of the standings schemas should pin ≥ 0.10.3.

## [0.10.2] — 2026-07-28

**Interchange schemas: structured standings rows (additive).** Realises
`DIR-FAM-STANDINGS-structured-rows` (owner feedback from the first
realistic extraction report); fixtures untouched. Standings rows may
state their structure beside the unchanged `check` identity — `path`
(the by-path grouping key, never derived from the name), `form`, a
bounded `expected` excerpt — plus `observed` obtained-value exemplars
(`{excerpt ≤256, count, held}`, failing first, emitter-capped, with an
`elided` remainder). `schema/verdict-1.4.xsd` adds the row attributes
and `<observed>` children (1.3 stays published; a 1.3-shaped row is a
valid 1.4 row); both JSON Schemas gain the additive row properties;
worked examples exercise the structure including a failing exemplar,
and `verdict-1.4-typical.xml` joins the validated set. Negative tests:
an exemplar without `held` and an over-bound excerpt are refused; a
restamped unstructured 1.4 record remains valid.

## [0.10.1] — 2026-07-28

**Interchange schemas: the postcondition standings (additive).** Realises
the interchange side of the 2026-07-28 standings-consumption rulings
(`DIR-R-STANDINGS-interchange-schemas`, following
`DIR-REP-STANDINGS-rendering`); the statistical fixtures are untouched.

- **`schema/verdict-1.3.xsd`** — a new verdict revision beside 1.2
  (namespace unchanged). The record gains an optional first-class
  `<postcondition-standings>` element: one `<criterion>` per criterion
  carrying standings, with an optional verbatim `optional-slack`
  attribute (`"2"` a count, `"20%"` a percentage; absent iff undeclared)
  and `<row>` children stating input index, bounded check identity, a
  **required** `optional` flag, the passed/failed/skipped counts, and the
  observed fraction. Descriptive by construction — the element offers no
  place for an interval, threshold, or per-check verdict. 1.3 emitters
  do not write the transitional `postcondition-standings:*` environment
  entries. The deferred decision-rule cutoff attribute does **not** ride
  this revision (owner ruling 2026-07-28: standings only).
- **`schema/mavai-explore-1.schema.json`** — the per-criterion
  `standings` block (binding when present, additive): optional verbatim
  `optionalSlack`, required `rows` with
  `inputIndex`/`check`/`optional`/`passed`/`failed`/`skipped`/`observedFraction`.
  Pre-amendment documents remain valid.
- **`schema/mavai-optimize-1.schema.json`** — the identical block on each
  iteration's per-criterion statistics, per the identical-statistics-shape
  rule (the definition is duplicated per file deliberately: frameworks
  vendor each schema as a self-contained file).
- **Worked examples** — `explore-typical.yaml` and `optimize-typical.yaml`
  gain standings blocks (including a marked-optional check and a declared
  slack); new `verdict-1.3-typical.xml` with a populated standings
  element. `scripts/validate_interchange.R` now also validates the
  verdict XML examples against their XSDs (via `xml2`, skipped with a
  notice where absent); negative tests cover a row missing `optional`, a
  bare-fraction slack, and element absence remaining valid.

## [0.10.0] — 2026-07-27

**Format corpus: the partial-credit and default-view amendments
(breaking).** Realises the two 2026-07-27 spec amendments
(`DIR-FAM-EXPECTED-partial-credit`, `DIR-FAM-FORMS-default-view`) in the
`mavai-contract/1` schema and corpus. Partial credit: postcondition
entries (global and per-input) admit `optional: true` (the literal
`true` only — `optional: false` is refused, mirroring `is-null:`'s
operand discipline), criteria admit `optional-slack:` (non-negative
integer count, or an explicit `N%` string resolved by floor; a bare
fraction is refused), and `optional:` on a `parses:` form is refused as
inert. New structural categories `optional-slack-malformed`,
`optional-operand`, `optional-on-parses`; one `valid/` case exercises
both slack spellings and the double opt-in. Default view: `path:` no
longer structurally requires `in:` — a path-bearing check omitting
`in:` resolves to the criterion's single `parses:` view, else the sole
declared transform, else a semantic load refusal (new category
`default-view-unresolvable`); a path-less check omitting `in:` judges
`raw` exactly as before. Two `valid/` cases exercise the two resolution
tiers. **Breaking:** the structural category `path-without-in` is
retired — its shape is now structurally admitted and its corpus file is
reworked as `default-view-no-views.yaml` under the semantic
`default-view-unresolvable` category — so consumers' binding-obligation
diffs change shape. The postcondition standings (the amendments' other
half) are output-artefact semantics and do not touch these authoring
schemas. This release is the dependency floor for the framework
implementations (baseltest first). Folds in the unreleased 0.9.6 below.

## [0.9.6] — 2026-07-27

**Format corpus: RFC 9535 path correction (fix).** The value-comparison
corpus files addressed hyphenated fields through member-name shorthand
(`$.instalment-fee`, `$.tax-rate`, `$.term-months`, `$.cancellation-date`)
— but RFC 9535's grammar does not admit `-` in shorthand names (name-char
is ALPHA / DIGIT / `_` / ≥U+0080), so a strictly conformant engine refuses
the corpus's own valid case. Surfaced by punit's CTS-validated path engine;
lenient third-party engines (e.g. Python's `jsonpath_rfc9535`) accept the
old spelling, which is how it went unnoticed. The paths in
`contract-value-comparison-scalar.yaml` and `is-null-operand.yaml` now use
bracket selectors (`$['instalment-fee']`); no schema, manifest category, or
expected-outcome change. Also refreshes the stale pre-amendment comment in
`path-on-non-string-form.yaml`.

## [0.9.5] — 2026-07-27

**Format corpus: the boolean comparison form (additive).** The
`mavai-contract/1` schema admits `is: <bool>` — boolean identity, added by
the 2026-07-27 boolean-comparison spec amendment
(`DIR-FAM-FORMS-boolean-comparison`): the subject must be JSON
`true`/`false` itself (never the strings `"true"`/`"false"` or the numbers
1/0), the operand is strictly a boolean, and the form is universal over a
multi-valued selection like the other scalar value forms. One `valid/`
corpus case exercises it (true/false, wildcard selection, per-input use);
one `invalid/` case pins the new structural category
`is-operand-not-boolean` (`is: "true"` refused). This release is the
dependency floor for the baseltest implementation.

## [0.9.4] — 2026-07-27

**Format corpus: the scalar value-comparison case isolated to one
criterion (corpus-defect patch; schema outcomes unchanged).** baseltest's
adoption of v0.9.3 — the corpus's first consumer for the value-comparison
forms — surfaced that `contract-value-comparison-scalar.yaml` declared two
criteria *and* a per-input `expected:` entry, which the specification's
single-criterion rule refuses (a semantic rule the schema deliberately
does not express, so `validate_formats.R` could not catch it). The case
now carries one criterion, with the raw-judging `not-equals` form beside
its `postconditions:` list. Second live exercise of the corpus-defect
triage discipline, after the v0.9.2 max-iterations isolation.

## [0.9.3] — 2026-07-27

**Format corpus: the value-comparison forms (additive).** The
`mavai-contract/1` schema admits the deterministic value-comparison
postcondition forms added by the 2026-07-27 spec amendment
(`DIR-FAM-FORMS-value-comparison`): the numeric comparison sextet
`eq`/`ne`/`lt`/`le`/`gt`/`ge` (decimal semantics, number or numeric-string
operands), `not-equals`, `equals-ci`, `is-null` (operand `true` only), and
the collective set forms `equals-set`/`contains-set`/`count-equals`, which
require an `in:` naming a declared view plus a `path:` (expressed
structurally via the entry's dependent schemas). The corpus gains two
`valid/` cases (the scalar family; the set family, each form exercised
including per-input use) and four `invalid/` cases with new categories,
all structural: `set-form-without-path`, `value-operand-malformed`,
`is-null-operand`, `set-operand-empty`. The manifest registers the
categories against the mandating spec section. This release is the
dependency floor for the baseltest and punit implementation directives
(`DIR-BAS-FORMS-value-comparison`, `DIR-PU-FORMS-value-comparison`).

## [0.9.2] — 2026-07-25

**Format corpus: the max-iterations cases isolated to their category
(additive-scale patch; corpus content changed, schema outcomes did not).**
baseltest's format-conformance adoption — the corpus's first consumer —
surfaced that the two `optimization-max-iterations-*` cases omitted the
`stepper-config:` their stepper's factory requires, so a loader refused
before reaching the category under test. Each case now carries a complete,
valid entry except for its one defect. First live exercise of the
corpus-defect triage the conformance loop exists for.

## [0.9.1] — 2026-07-25

**Declarative format schemas and conformance corpus hosted (additive,
non-statistical).** This repository takes on a second, distinct oracle duty:
beside the methodology pair (Statistical Companion ↔ `inst/cases/`), it now
hosts the format pair — JSON Schemas (draft 2020-12) for the family's
declarative authoring formats `mavai-contract/1` and `mavai-services/1`,
with a 74-file conformance corpus (`valid/` files that MUST load, `invalid/`
files that MUST be refused, one per refusal category) and a manifest
classifying every expectation binding vs informational and every refusal
structural vs semantic, under `inst/formats/`. Releases gain a third asset,
`formats-vX.Y.Z.zip`. **Publication channel only**: the prose format
specifications are canonical in the family's requirements catalog and are
not published; these artefacts are family engineering infrastructure the
implementing frameworks conform to, not a public standard. Nothing here is
computed in R; no statistical authority is claimed. Build step:
`scripts/validate_formats.R` (schema compilation, corpus-vs-manifest
validation, run by testthat and the release workflow); the testthat file
adds the two-way coverage check and refusal cases.

## [0.9.0] — 2026-07-17

**Interchange `failureDistribution` redesigned (breaking to the section's
shape; the `mavai-explore-1` / `mavai-optimize-1` version ids are deliberately
reused — no framework emitter has shipped against the published schemas, so
there are no external consumers to migrate).** The check-name-keyed mapping is
withdrawn: emitters that derived keys from input content produced mapping keys
past YAML's 1,024-character implicit-key limit, making faithfully emitted
artefacts unparseable. The section is now a *sequence* of entries
`{condition, count, inputIndex?, inputExcerpt?}` — `condition` is the
violating condition's bounded identity (≤ 256 characters, never embedding
input or response content), per-input attribution travels structurally in
`inputIndex`, and `inputExcerpt` is a bounded informational excerpt. Both
schemas and all worked examples are updated. Authority: the family catalog's
interchange key-discipline amendment of 2026-07-17.

**Interchange validation build step.** `scripts/validate_interchange.R`
compiles each interchange schema under ajv (draft 2020-12) and validates
every worked example against its schema; `tests/testthat/test-interchange-schemas.R`
drives it and adds refusal cases, and the release workflow runs it before
packaging the `interchange-vX.Y.Z.zip` asset, so an invalid schema or a
drifted example can no longer ship. New Suggests: `jsonvalidate`, `yaml`.

## [0.8.6] — 2026-07-15

**Interchange schemas hosted (additive, non-statistical).** This repository
now additionally publishes the mavai family's experiment interchange
artefacts: JSON Schemas for `mavai-explore-1` (one document per explored
experiment configuration) and `mavai-optimize-1` (one document per optimize
run) in `schema/`, with conformant worked examples in `inst/interchange/`.
Releases gain a second asset, `interchange-vX.Y.Z.zip`, alongside the
statistical cases bundle. **Publication channel only**: the formats are
specified canonically in the family's requirements catalog, nothing here is
computed in R, and no statistical authority is claimed — see
`inst/interchange/README.md`. The statistical cases and their schema are
untouched.

**Verdict XML schemas hosted (additive, non-statistical).** The verdict
interchange XSDs (`verdict-1.0/1.1/1.2.xsd`) join `schema/` under the same
publication-only terms, replacing their previous split existence (a private
canonical copy and a punit-embedded copy that had drifted in comments —
reconciled to one text). All schemas are also served at the documentation
site under `/schema/`, and ship in the `interchange-vX.Y.Z.zip` release
asset.

## [0.8.5] — 2026-07-11

**New suite: `risk_driven_sizing.json` (additive).** Materialises
companion §5.4.1 (new in companion 1.4.0): self-consistent power for
baseline-derived thresholds, where the acceptance floor
`WilsonLower(p0, n, 1−α)` moves with the test's own sample size.
Thirteen cases in three groups, discriminated by the `approach` field:

- `required_n` — smallest n meeting a target power for a declared
  minimal acceptable rate, with the floor and achieved power at that n;
  includes the companion's two computed examples (0.87/0.84/0.95/0.80
  → 891; the 0.96/0.93 scenario walk-through → 405) and parameter
  sensitivity around them.
- `power_at` — floor and power at candidate sample sizes, including the
  walk-through's table rows and the case pinning that the §5.4
  closed-form seed (n = 826) underpowers the worked example.
- `detectable_rate` — the inversion (largest tolerable rate detectable
  at a fixed n, bisection to 1e-10), including round-trips at the
  required-n answers.

The suite is **not** in the family-mandatory tier: it binds a framework
when it adopts risk-driven sizing (baseltest first, per
`DIR-BAS-SIZING-risk-driven` in the orchestrator). Defined for
`minimum_acceptable_rate < baseline_rate` only — the generators refuse
the over-reach regime. New exported helpers `power_self_consistent()`,
`required_n_self_consistent()`, `detectable_rate_self_consistent()`.
No existing suite changed. Also carries the companion at 1.4.1 (§5.4.1
new section; §6 operational-approaches taxonomy reconciliation; Type
I/II plain-language definitions).

## [0.8.4] — 2026-07-10

**New suite: `regression_decision.json` (additive).** Publishes the
composed §3.4 decision rule for the regression (baseline-derived)
procedure as a first-class conformance target: end-to-end scenario
cases `(baseline_successes, baseline_trials, test_samples, confidence,
observed_successes) → (threshold_real, wilson_lower, cutoff_integer,
displayed_rate, achieved_size, verdict)`, with `PASS iff K ≥ c`,
`c = ⌈n_test · p*⌉`. Thirteen cases: the §3.4 worked example
(p̂ = 0.951, n_test = 100 → p* ≈ 0.902124, c = 91, achieved size
≈ 0.024986) with `K = c` / `K = c − 1` boundaries, small-n
discretisation cases where the real-valued bound and the integer
cutoff disagree materially, the perfect-baseline `k = n` edge
(§4.3.2 effective-rate guard), a compliance-procedure sibling group
(test-side Wilson lower bound vs a declared threshold, §3.2/§3.6),
and a conflation-detector pair — one observation shared across both
procedures with opposite verdicts (`K = c = 91` passes the regression
rule; the same count read compliance-style against the same derived
value fails), so a framework applying the compliance rule on the
regression path fails the suite even though every component
computation is arithmetically conformant. Tolerance 1e-10; `procedure` field
distinguishes the two rule families. New generator
`generate_regression_decision_cases()`.

**New generated artefact: `manifest.json` (additive).** A conformance
coverage manifest generated alongside the suites (never
hand-maintained), `manifestVersion` 1: per-suite case rosters,
**binding vs informational** expected-field classification authored in
the generators, per-suite MD5 content hashes, and the oracle-declared
**family-mandatory tier** — `wilson_ci`, `wilson_lower`,
`threshold_derivation`, `verdict`, `latency_percentile`,
`latency_threshold`, `regression_decision`. Downstream frameworks
diff the set of `(suite, case, binding-field)` assertions they
actually make against (family-mandatory ∪ committed scope), making
field-selective assertion inside a nominally covered suite
machine-detectable. New generator `generate_manifest()`, invoked at
the end of `scripts/generate_all.R`.

**Binding-status clarification (no content change):**
`threshold_derivation.json`'s `cutoff_integer` and `achieved_size`
have been published since the suite's introduction but were consumed
by no framework — the blind spot that let a decision-rule deviation
ship. The manifest now classifies them **binding**; conformance tests
must assert them. Existing suites are otherwise unchanged.

Tracked by `DIR-DECISION-RULE-CONFORMANCE-family` in the orchestrator;
the manifest is Stage 1 of `DIR-CONFORMANCE-COVERAGE-MANIFEST-family`,
riding this release per the owner decision of 2026-07-10.

## [0.8.3] — 2026-07-09

**New suite: `latency_percentile_minimums.json` (additive).** Publishes
the family standard for empirical-latency-percentile minimum sample
sizes, closing a three-way implementation drift (companion §12.5.2 says
the p50 emission minimum is 5; punit's emission gate and the
orchestrator catalog said 1; feotest already said 5). Two case groups,
distinguished by the `approach` field:

- `emission_non_degeneracy` — the §12.5.2 minimums (5/10/20/100 for
  p50/p90/p95/p99) governing whether a percentile may be emitted in
  experiment artefacts and verdicts at all.
- `bound_existence` — the §12.5.2.1 minimums
  (`n_s ≥ ⌈log α / log p⌉`, Wilks) for a non-saturated
  distribution-free upper bound at confidence 0.95 and 0.99.
  Judgement-time minimums for latency-criterion evaluation, not
  emission rules.

All values are integers; suite `tolerance: 0` (exact equality). New
exported helper `latency_bound_existence_min_samples()`; the emission
values come from the existing `latency_min_samples()`. No existing
suite changed. Tracked by `DIR-PERCENTILE-MINIMUMS-family` in the
orchestrator.

## [0.8.2] — 2026-05-30

**First release from `mavai-org/mavai-R` — the javai → mavai rebrand
(metadata only).** This is the first tagged cut under the new brand. The
published docs (Statistical Companion, Glossary, Distributional
Contracts, Model Overview, README, PDF footer), the schema `$id`
(`github.com/mavai-org/mavai-R/...`), and the R package name
(`javair` → `mavair`) now carry the mavai brand. **No fixture content,
shape, expected values, tolerances, or schema *structure* changed** —
only the schema's `$id` identifier string and surrounding documentation.
Conformance behaviour is unaffected; downstream frameworks need not
re-pin for the rebrand. (Old `javai-org/javai-R` release URLs continue to
301-redirect here.)

**Documentation-only string cleanup on `baseline_object.json`.**

Statistical Companion §1.5 was revised (companion doc 1.3.4 → 1.3.5):
the §1.5.5 *accumulation* construct was withdrawn and the long-term-
monitoring framing of baseline indexing removed, while baseline
indexing itself was retained and stated precisely (the index is the
service-contract identity plus the resolved covariate values; the
factor record is provenance). None of this was ever implemented as
fixture data, expected values, schema, or generator logic — only as
descriptive strings. This patch re-words the `baseline_object`
suite/case `description` and `method` strings to match. No inputs,
expected outputs, tolerances, numerical values, case set, or schema
change; conformance behaviour is unaffected. Downstream frameworks
need not re-pin.

## [0.8.1] — 2026-05-19

**Saturation discipline on `latency_threshold_bootstrap.json`.**

Per Statistical Companion §12.4.2 — a one-rung patch on the bootstrap
conformance fixture so downstream frameworks can honour the
saturation discipline against the published reference data.

### Changed

- **`inst/cases/latency_threshold_bootstrap.json`** — every case's
  `expected` block gains two new fields per **Statistical Companion
  §12.4.2** (saturation discipline): `k_raw` (the unclamped binomial-
  derived rank `qbinom(1 - alpha, n, p) + 1`) and `saturated` (TRUE
  iff `k_raw > n`). When `saturated` is TRUE the published `rank` and
  `threshold` are advisory at the saturation ceiling (`rank = n`,
  `threshold = t_{(n)}`) and MUST NOT be presented as exact bounds
  on Q(p); the suite description now states this explicitly.
  Consumers must branch on `saturated` before treating `threshold`
  as inferential. Of the four published cases, `lognormal_n200_p99`
  is saturated (`k_raw = 201` against `n = 200`); the other three
  are not (`k_raw == rank`). Per
  `DIR-LATENCY-SATURATION-FIXTURE-javai-R.md`. Downstream:
  `LatencyThresholdDeriver` in `punit` already exposes the saturation
  flag on its `Threshold` record (punit#192); the punit conformance
  test will be extended to assert against the new fields under a
  follow-on punit directive. `feotest` follows under its own
  directive.

### Added

- New helper `latency_threshold_binomial_rank(n, p, confidence)` in
  `R/latency.R` returning `{k_raw, saturated}`. `latency_threshold_derive()`
  is unchanged — the saturation-discipline fields stay localised to
  the bootstrap suite's generator.

---

## [0.8.0] — 2026-05-14

**Multi-criteria model fixtures. Lands five new formula-value suites
and an in-place extension of `threshold_derivation.json` per the
criterion-decomposition model of Statistical Companion v1.3
(§§1.4–1.5, §10).**

This release is the formula-value half of the conformance contract
named in §10.6: arithmetic agreement between downstream framework
computations and the javai-R oracle. The calibration-fixture half
(achieved Type-I rates, achieved power, achieved family-wise rates
under stated dependence regimes) is named in §10.6 as future work and
will land in a subsequent release.

Per `DIR-MULTI-CRITERIA-FIXTURES-javai-R.md` in the orchestrator.

### Added

- **`inst/cases/criterion_verdict_observational.json`** — per-criterion
  verdict cases for observational criteria (§1.4.5), with the §1.4.5a
  two-policy denominator enum. The effective denominator `n_c` is the
  policy-derived field; cases include a policy-difference pair where
  the same raw counts yield PASS under `CONDITIONAL_ON_EVALUABLE` and
  FAIL under `MARGINAL_COUNT_UNEVALUABLE_AS_FAIL`.
- **`inst/cases/criterion_verdict_inferential.json`** — per-criterion
  verdict cases for inferential criteria, partitioned by procedure
  (REGRESSION decides on the integer cutoff `K_c >= c` per SC-RU-02;
  COMPLIANCE decides on the Wilson lower bound exceeding `p_req`).
  Three-strand verdict (`statistical`, `observed_rate_status`,
  `operational_caution_category`) plus p-value method/tail metadata.
- **`inst/cases/composite_verdict.json`** — composite-verdict
  aggregation per §1.4.6 and SC-RU-05: composite PASS / FAIL /
  INCONCLUSIVE plus the procedure-split envelopes
  (`false_compliance_envelope` over compliance criteria,
  `false_degradation_signal_envelope` over regression criteria).
  Observational criteria contribute to neither envelope.
- **`inst/cases/baseline_object.json`** — canonical baseline objects
  at named points in the index space (factor record, covariate
  profile, expiration window, structural reference) under the locked
  §1.4.5a two-policy enum, with `availability_criterion_ref` for the
  structural-composition pattern. Schema-only fixtures: each case
  carries an empty `expected` block.
- **`inst/cases/multi_criteria_scenario_consult_advice.json`** — the
  end-to-end fixture mirroring §10.3. Four cases: the locked §10.3
  composite-FAIL contract, the passing counterfactual, the paired-
  evaluability / content structural-composition pattern with non-1.0
  `r_obs`, and the cross-policy structural-mismatch refusal. Every
  case carries the §10.6 `conformance_status` metadata block with
  `formula_value_fixtures: passed`, `calibration_fixtures:
  not-published`, `calibration_claim_permitted: false`.

### Changed

- **`inst/cases/threshold_derivation.json`** — every
  `sample_size_first` case gains three new `expected` fields per
  **SC-RU-02**: `wilson_lower_real` (the real-valued Wilson lower
  bound), `cutoff_integer` (the binding decision artefact
  `ceiling(n_test × wilson_lower_real)`), and `achieved_size` (the
  lower-tail false-degradation probability `P_{p_0}(K < c)` under the
  effective baseline rate). The historical `threshold` field is
  preserved as a synonym for `wilson_lower_real`. A new
  `ssf_sc_ru_02_worked_example` case anchors the §3.4 worked-example
  numerics (`p̂ = 0.951`, `n_test = 100`, `α = 0.05` → real-valued
  ≈ 0.902124, cutoff = 91, achieved size ≈ 0.024986).
- **`schema/cases.schema.json`** — relaxed top-level `inputs` /
  `expected` value constraints to accept arbitrary JSON (numbers,
  booleans, strings, nulls, arrays, objects) so the per-criterion and
  scenario fixtures' nested shapes validate. Existing flat-shape
  fixtures continue to validate unchanged. New top-level case fields
  added: `description` (optional), `procedure` (optional, enum).
  `$defs` introduces the two-value denominator policy enum for
  generators that need to validate the enum explicitly.

### Downstream

- `punit` and `feotest` need extending to consume the new suites; see
  `DIR-MULTI-CRITERIA-FIXTURES-punit.md` and
  `DIR-MULTI-CRITERIA-FIXTURES-feotest.md` (forthcoming).

---

## [0.7.0] — Unreleased

**Breaking — `latency_threshold_bootstrap` fixture role change and
shape change.**

`inst/cases/latency_threshold_bootstrap.json` is upgraded from an
*informational* comparison report (R-internal) to a *conformance*
contract for the exact binomial order-statistic upper bound. Both
`punit` and `feotest` will now consume this suite to verify their
implementations agree exactly with `javai-R`'s on the same lognormal
baselines. The bootstrap-vs-binomial comparison content is preserved
alongside as informational fields.

### Changed

- **`inst/cases/latency_threshold_bootstrap.json` shape.** Each case
  now publishes the (ascending-sorted) baseline sample in
  `inputs.baseline_latencies`, alongside `p` and `confidence`. The
  `expected` section gains four conformance fields:
    - `rank` (was `binomial_rank`),
    - `threshold` (was `binomial_bound`),
    - `baseline_percentile` (the raw sample quantile `Q(p)`),
    - `n` (the baseline sample count).
  The fields `bootstrap_upper`, `point_estimate`, and `diff` are
  preserved as informational comparison content and are no longer
  conformance targets. The suite-level `description` documents the
  new role; `method` is rewritten to lead with the binomial
  construction.

- **`scripts/bootstrap_compare.R`.** The generator logic moved into
  `generate_latency_threshold_bootstrap_cases()` in `R/latency.R`.
  The script is now a thin wrapper that produces the markdown
  comparison table for §12.4.4 of the Statistical Companion; JSON
  emission is driven by `scripts/generate_all.R`.

- **`R/latency.R`.** Added the bootstrap-comparison generator plus a
  reusable `bootstrap_upper()` helper. The bootstrap RNG seed is
  fixed (default `seed = 1`) so the informational fields stay stable
  across regenerations.

### Conformance properties

The new conformance fields are integer-valued or are specific
elements of the integer-valued `baseline_latencies` array, so the
suite carries `tolerance: 0` (exact equality), matching the sister
suite `latency_threshold.json`. Per-field precision contract:

| Field                 | Conformance check    |
|-----------------------|----------------------|
| `rank`                | exact integer match  |
| `threshold`           | exact match (equals `baseline_latencies[rank - 1]`) |
| `baseline_percentile` | exact match (`t_{([p·n])}`) |
| `n`                   | exact integer match  |
| `bootstrap_upper`     | informational only   |
| `point_estimate`      | informational only   |
| `diff`                | informational only   |

### Downstream impact

The four existing cases (`lognormal_n200_p95`, `lognormal_n200_p99`,
`lognormal_n935_p95`, `lognormal_n935_p99`) keep their names and
keep the same underlying lognormal draws (the `set.seed(42)` calls
are unchanged), so consumers picking up the upgraded fixture see
the same numerical `binomial_bound` / `binomial_rank` values they
would have read out of the prior shape — only the field names and
the addition of `baseline_latencies` differ.

Downstream maintainers should:

- Pull the upgraded `latency_threshold_bootstrap.json` into their
  test resources (or rely on the conformance-data download
  mechanism).
- Extend their conformance test (`LatencyConformanceTest` in
  `punit`; equivalent in `feotest`) to consume the new shape.

See `REQ-R-bootstrap-fixture-upgrade.md` in each downstream
project's `plan/` folder for per-framework guidance.

### Documentation (shipped alongside the fixture upgrade)

- `docs/STATISTICAL-COMPANION.md` — §1.3 restructured to add a new
  §1.3.1 *Why the Working Approximation is Defensible*, articulating
  the conditions under which the Bernoulli i.i.d. assumption is
  reasonable for LLM testing: a pinned-snapshot model identifier
  (versus a floating alias), fixed system prompt and sampling
  configuration, no conversation state carried between calls, a stable
  input-sampling process, and a single experimental run of bounded
  wall-clock duration. The new sub-section quotes Anthropic's
  documented commitment that every Claude model ID is a pinned snapshot
  and cites Chen, Zaharia & Zou (2023) as the empirical counterweight
  showing that floating aliases do drift across snapshots over months.
  Existing §1.3 material moves unchanged into §1.3.2 (formal
  assumptions and operational threats) and §1.3.3 (developer
  responsibility for trial independence — previously an unnumbered
  sub-section, now numbered to match the §8.3.x convention used
  elsewhere in the document). Bibliography gains entries 17 (Anthropic,
  2026) and 18 (Chen, Zaharia & Zou, 2023).

## [0.6.0] — 2026-05-08

**Breaking — threshold-derivation fixture content and signature change.**

The `threshold_sample_size_first` and `threshold_first_implied_confidence`
generators were not matching the statistical companion: they ignored
their `test_samples` parameter and computed `wilson_lower(k_baseline,
n_baseline, conf)` regardless. The companion's §3.4 / §4.3.2 / §6.3
construction is the one-sided Wilson lower bound at the *test* sample
size, with a two-step compression for the perfect-baseline case. This
release replaces the generators with the companion-correct construction
and regenerates the affected fixture.

Downstream conformance suites (punit, feotest) MUST be updated before
consuming this release. A requirements document describing the migration
exists at `plan/REQ-R-threshold-derivation-test-sample-size.md` in each
consumer repository.

### Changed

- `inst/cases/threshold_derivation.json` — **expected values change for
  every case, and the threshold-first input shape adds a required
  `test_samples` field**. `sample_size_first` thresholds are now derived
  by Wilson lower bound at the test sample size: general case (§3.4)
  uses the baseline point estimate as the formula's centre; perfect-
  baseline case (§4.3.2) compresses the baseline through its own Wilson
  lower bound first, then applies the same Wilson construction at the
  test sample size. New cases sweep `test_samples` to make the new
  sensitivity verifiable from the fixture alone (`ssf_950_of_1000_test50`,
  `ssf_950_of_1000_test200`, `ssf_perfect_baseline_n1000_test100`).
  Threshold-first cases acquire a `test_samples` input.
- `R/threshold.R` — `threshold_sample_size_first(...)` and
  `threshold_first_implied_confidence(...)` rewritten to follow the
  companion. `threshold_first_implied_confidence` gains `test_samples`
  in its signature; the binary search runs against the corrected
  forward construction.
- `R/wilson.R` — adds `wilson_lower_from_rate(p_hat, n, confidence)`
  for the continuous-rate Wilson lower bound that the threshold
  construction needs (the discrete `wilson_lower(k, n, conf)` is now a
  thin wrapper).

### Why

The previous generator effectively published `wilson_lower(baseline)`
under the name "threshold". A test passes (per §5.1) when the
*observed* test rate clears the threshold, and the threshold's role is
to bound the test-side false-positive rate at the configured α. That
calls for a Wilson construction parametrised by `n_test`, not
`n_baseline` — exactly what §3.4 / §3.5 already specified and what the
generators had drifted from. Smaller test samples lower the threshold
(§3.5), which the new fixture demonstrates.

## [0.5.0] — 2026-04-16

**Breaking — latency fixture schema and method change.**

Downstream conformance suites (punit, feotest) MUST be updated before
consuming this release. A requirements document describing the migration
exists at `plan/REQ-R-latency-threshold-binomial.md` in each consumer
repository.

### Changed

- `inst/cases/latency_threshold.json` — **inputs reshaped and method
  replaced**. The `s / sqrt(n_s)` standard-error approximation used to
  derive an upper bound on a baseline percentile has been superseded by
  an exact non-parametric construction: the binomial order-statistic
  upper confidence bound. Input fields changed from
  `{baseline_percentile, baseline_sd, baseline_n, confidence}` to
  `{baseline_latencies, p, confidence}`; expected output fields changed
  from `{raw_upper, threshold}` to `{rank, threshold, baseline_percentile, n}`.
  Tolerance is now zero (the expected threshold is always an exact order
  statistic of the integer-ms baseline).
- `inst/cases/latency_percentile.json` — summary cases drop the sample
  standard deviation (`sd`) field. `mean` and `max` remain. The latency
  distribution is not well-characterised by its second moment, and the
  new threshold construction does not use `s`.

### Added

- `inst/cases/latency_threshold_bootstrap.json` — informational
  reference data comparing the binomial order-statistic bound against a
  10,000-replicate percentile bootstrap on representative lognormal
  baselines. Not part of the conformance contract; provided so
  consumers can verify the §12.4.4 table in `STATISTICAL-COMPANION.md`
  without an R installation.
- `scripts/bootstrap_compare.R` — the script that generates the
  bootstrap comparison fixture.

### Notes

- A local `v0.4.0` tag existed on the commit that bumped `DESCRIPTION`
  to 0.4.0 but was never pushed to `origin`, so no 0.4.0 release was
  ever published. The 0.4.0 version number is skipped to avoid
  confusion with that un-released state. Downstream consumers
  upgrading should read this as 0.3.0 → 0.5.0 directly.

## [0.3.0] — 2026-03-28

Reference data upgraded to full-precision numerical output.

## [0.2.0] — 2026-03-28

JSON Schema for conformance case files added under `schema/`.

## [0.1.0] — 2026-03-28

Initial public release.
