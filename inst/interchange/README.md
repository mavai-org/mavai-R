# Interchange schemas and worked examples

Machine-readable schemas and worked examples for the mavai family's
**experiment interchange artefacts** — the framework-neutral YAML documents
the experiment workflows emit, consumed by shared tooling such as the
family's report renderer:

- `mavai-explore-1` — one document per explored experiment configuration
  ([schema](../../schema/mavai-explore-1.schema.json)).
- `mavai-optimize-1` — one document per optimize run: iteration history plus
  convergence ([schema](../../schema/mavai-optimize-1.schema.json)).

The **verdict XML interchange** schemas (`verdict-1.0.xsd` through
`verdict-1.3.xsd`, namespace `http://mavai.org/verdict/1.0`) are published
alongside them in [`schema/`](../../schema/) under the same terms: test
verdicts travel as XML, and the XSD set lets any emitter or consumer validate
a document of any published vintage. The namespace is an identifier, not a
retrieval URL. Frameworks that embed a copy of an XSD at runtime treat it as
a vendored snapshot of the published file, synced per release. From 1.3 the
record carries a first-class `<postcondition-standings>` element (descriptive
per-check tallies with the partial-credit facts stated verbatim); the
`verdict-1.3-typical.xml` example here is validated against the XSD by the
same build step that validates the YAML examples.

**This repository is the publication channel for these artefacts, not their
authority.** The formats are specified canonically in the mavai family's
requirements catalog; the JSON Schemas here are the machine-checkable
structural projection of those specifications, and the YAML files in this
directory are reference documents that conform to them. They ship with this
repository's tagged releases so that every framework's emitter-conformance
test, and every consumer, validates against one pinned, versioned artefact.

Unlike the statistical conformance cases in `inst/cases/`, nothing here is
computed in R and nothing here carries statistical authority: a document
format is not a statistical claim. The statistical values *inside* the
worked examples (observed rates, stated latency percentiles) follow the
family methodology — percentiles are stated value-or-absent under the
emitting framework's minimum-sample gate, which is why several examples
deliberately omit them — but their correctness is established by each
framework's statistics-module conformance suite, not re-verified at the
artefact level.

The schemas check structure only. Semantic obligations — the convergence
block's consistency with the iteration it names, the sortedness of the
latency vector, the gating of stated percentiles — are enforced by each
emitter's conformance tests, as specified in the canonical format
documentation.

Schema evolution is additive-only behind the `schemaVersion` string:
consumers ignore unknown fields, and a breaking change means a new version,
never a mutation of this one.
