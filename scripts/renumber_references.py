#!/usr/bin/env python3
"""Renumber a document's references by order of first citation in the body.

The first distinct source cited in the prose becomes [1], the next new
source [2], and so on; the reference list is relabelled and reordered to
match. Both the in-text citations and the reference-list entries are
rewritten in place.

This is a maintenance utility, not a statistical computation: it exists so
that inserting or moving a citation in the body does not require manual
renumbering. Re-run it whenever citations are added, removed, or reordered.

Assumptions (true of the mavai distributional-contracts document):
  * Citations are `[n]` tokens (digits only) in the prose *before* the
    `## References` heading. Markdown links like `[punit](url)` and maths
    intervals like `[0,1]` are not matched (the regex requires digits only
    and no comma).
  * The reference list follows the `## References` heading, one entry per
    line, each beginning `[n] ...`, and is the final section of the file.
  * Only `[n]` tokens that have a matching reference-list entry are treated
    as citations; a stray `[n]` in the body with no entry is left alone.

Usage:
    python3 scripts/renumber_references.py [path]
Default path: docs/DISTRIBUTIONAL-CONTRACTS.md (relative to repo root).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REF_HEADING = "## References"
CITE = re.compile(r"\[(\d+)\]")
REF_ENTRY = re.compile(r"^\[(\d+)\]\s")


def renumber(text: str) -> tuple[str, dict[int, int], list[int]]:
    """Return (new_text, old->new mapping, list of uncited old numbers)."""
    if REF_HEADING not in text:
        raise SystemExit(f"No '{REF_HEADING}' heading found.")
    body, refs = text.split(REF_HEADING, 1)

    # Parse reference entries (single line each), preserving file order.
    entries: dict[int, str] = {}
    order: list[int] = []
    for line in refs.split("\n"):
        m = REF_ENTRY.match(line)
        if m:
            n = int(m.group(1))
            if n in entries:
                raise SystemExit(f"Duplicate reference entry [{n}].")
            entries[n] = line
            order.append(n)
    if not entries:
        raise SystemExit("No reference entries found after the heading.")

    known = set(entries)

    # Assign new numbers by order of first appearance in the body.
    mapping: dict[int, int] = {}
    nxt = 1
    for m in CITE.finditer(body):
        old = int(m.group(1))
        if old in known and old not in mapping:
            mapping[old] = nxt
            nxt += 1

    # Any reference never cited in the body keeps a stable number after the
    # cited ones, in its existing list order, and is reported.
    uncited = [n for n in order if n not in mapping]
    for old in uncited:
        mapping[old] = nxt
        nxt += 1

    # Rewrite in-text citations.
    def sub(m: re.Match) -> str:
        old = int(m.group(1))
        return f"[{mapping[old]}]" if old in mapping else m.group(0)

    new_body = CITE.sub(sub, body)

    # Relabel each entry's leading token and reorder by the new number.
    relabelled = {
        mapping[old]: REF_ENTRY.sub(f"[{mapping[old]}] ", entry, count=1)
        for old, entry in entries.items()
    }
    new_refs = "\n\n" + "\n\n".join(relabelled[n] for n in sorted(relabelled)) + "\n"

    return new_body + REF_HEADING + new_refs, mapping, uncited


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else repo_root / "docs" / "DISTRIBUTIONAL-CONTRACTS.md"

    raw = path.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = raw.replace("\r\n", "\n")

    new_text, mapping, uncited = renumber(text)

    if uncited:
        print(
            "WARNING: reference(s) never cited in body (left at the end): "
            + ", ".join(f"[{n}]" for n in uncited),
            file=sys.stderr,
        )

    changed = [(o, n) for o, n in sorted(mapping.items()) if o != n]
    if not changed and new_text == text:
        print(f"{path.name}: already in first-citation order; no change.")
        return

    out = new_text.replace("\n", "\r\n") if crlf else new_text
    path.write_bytes(out.encode("utf-8"))

    print(f"{path.name}: renumbered by first citation order.")
    if changed:
        print("  changed: " + ", ".join(f"[{o}]->[{n}]" for o, n in changed))


if __name__ == "__main__":
    main()
