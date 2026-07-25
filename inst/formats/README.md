# Declarative format schemas and conformance corpus

Machine-checkable materialisation of the mavai family's **declarative
authoring formats** — the contract file and the service-definition file
every family framework reads:

- `mavai-contract/1` — the declarative contract file
  ([schema](schemas/mavai-contract-1.schema.json)).
- `mavai-services/1` — the service-definition file
  ([schema](schemas/mavai-services-1.schema.json)).

This directory is this repository's **second oracle duty**, parallel to and
deliberately separate from the statistical one: `docs/STATISTICAL-COMPANION.md`
paired with `inst/cases/` owns *methodology* truth; the format specifications
paired with these schemas and corpus own *format* truth. Nothing here is
computed in R and nothing here carries statistical authority — mavai-R is the
distribution channel and single-source-of-truth home, hosting these artefacts
because it is already the family's language-neutral, release-tagged channel
with conformance plumbing on the consuming end.

**These artefacts are family engineering infrastructure, not a public
standard.** The canonical prose specifications are maintained in the mavai
family's internal requirements catalog and are not published; the schemas
here are what the implementing frameworks (baseltest, punit, feotest)
conform to — not a specification third-party frameworks are invited to
follow. The schemas validate the parsed YAML document (YAML is the file
encoding; the schema addresses the resulting structure) and carry section
citations into the prose specifications in `$comment` fields; a schema rule
without prose backing is a defect in the schema.

The **conformance corpus** (`corpus/valid/`, `corpus/invalid/`) holds
instance files with expected outcomes — the part schemas alone cannot carry,
because many refusals are semantic (an undeclared view named by `in:`, a
duplicate exploration grid point, per-input expectations under several
criteria, ...). `manifest.yaml` records every corpus entry's expected
outcome (`loads` / `refused: <category>`) and its classification **binding
vs informational**: refusal *categories* bind every consuming framework;
refusal *message texts* are informational (each framework speaks its own
author vocabulary). Each framework carries a vendored, pinned copy of this
corpus and a format-conformance test that diffs the assertions it actually
made against the manifest's binding obligations, so selective assertion
fails the build.

Validation is a build step here too: `scripts/validate_formats.R` (run by
`tests/testthat/test-format-schemas.R` and release CI) refuses to ship a
schema that does not compile, a `valid/` file a schema rejects, or a
corpus file whose manifest classification disagrees with the schema.

Each tagged release bundles this directory as `formats-vX.Y.Z.zip`
alongside `cases-vX.Y.Z.zip`. The *format* version (`mavai-contract/1` →
`/2`) and the *artefact* release version move independently; the manifest
records which format version(s) the corpus covers.
