"""Typo-tolerant matching for short free-text fields against a small fixed
vocabulary (stay-type labels, Nigerian state names) - the kind of forgiveness
Postgres trigram similarity already gives city/title search in
`api/v1/listings.py::_relevance_expression`, applied here to reference lists
too small to be worth a database round trip for.

Standard library only (`difflib`), matching this codebase's general preference
for the built-in tool over a new dependency when it's good enough for the job.
"""
from __future__ import annotations

from difflib import SequenceMatcher

DEFAULT_THRESHOLD = 0.72


def _ratio(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def fuzzy_matches(needle: str, candidates: list[str], threshold: float = DEFAULT_THRESHOLD) -> bool:
    """Whether `needle` is close enough to any of `candidates` to count as a hit.

    Each candidate is checked whole *and* word-by-word: a misspelling in one
    word of a multi-word candidate ("vacatoin" for "Vacation rental") gets
    diluted into a low ratio against the full phrase, since a similarity ratio
    is sensitive to length mismatch - splitting gives the typo a same-length
    word to actually match against.

    Two ways to match each candidate, combined because each covers what the
    other misses:

    * substring containment either direction, so a short/partial query ("lag",
      "hote") still hits without needing to be "close" by edit distance;
    * similarity ratio, which is what catches an actual misspelling
      ("hotell", "abujah") that containment alone would reject outright.
    """
    lowered = needle.lower().strip()
    if not lowered:
        return False
    for candidate in candidates:
        candidate_lower = candidate.lower()
        pieces = {candidate_lower, *candidate_lower.split()}
        for piece in pieces:
            if lowered in piece or piece in lowered:
                return True
            if _ratio(lowered, piece) >= threshold:
                return True
    return False
