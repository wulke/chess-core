# V1 Ingestion Overview

Backed by:
- [docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md)
- [docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md)
- Specs: `ING-001` through `ING-023`, `PZL-001` through `PZL-012`

This diagram shows the shared lifecycle shape across v1 source families. Detailed
per-source semantics are split into the focused workflow docs.

```mermaid
flowchart TD
    classDef start fill:#eef4ff,stroke:#4f6ea9,color:#1e3152;
    classDef action fill:#f7f7f7,stroke:#444,color:#111;
    classDef decision fill:#fff3cd,stroke:#9a6b00,color:#4d3600;
    classDef fail fill:#fdecea,stroke:#a94442,color:#6b1f1f;
    classDef success fill:#edf7ed,stroke:#4a7a4a,color:#1e4d1e;

    A[Receive source input]:::start --> B{File-backed source?}:::decision

    B -->|Yes| C[Create or reuse SourceDocument]:::action
    C --> D[Persist path and content hash]:::action
    D --> E[Set import_status to pending]:::action
    E --> F{Source family}:::decision

    B -->|No, manual puzzle entry| G[Create Puzzle without SourceDocument]:::action
    G --> H[Create root PositionOccurrence for puzzle context]:::action
    H --> I[Ingestion complete]:::success

    F -->|PGN| J[Normalize each game into Game, MoveRecord, PositionOccurrence]:::action
    F -->|Book or document| K[Extract one chunk batch into BookChunk rows]:::action
    F -->|Puzzle dataset| L[Persist valid Puzzle rows and root PositionOccurrence rows]:::action

    J --> M{Domain-record transaction succeeds?}:::decision
    K --> M
    L --> N{Valid rows committed?}:::decision

    M -->|Yes| O[Set import_status to complete and imported_at]:::success
    M -->|No| P[Set import_status to failed]:::fail
    N -->|Yes, with or without malformed rows| O
    N -->|No valid rows committed| P

    P --> Q{Retry requested?}:::decision
    Q -->|No| R[Retain failed SourceDocument for provenance]:::fail
    Q -->|Yes| S[Reuse failed SourceDocument and reset import_status to pending]:::action
    S --> F

    O --> T[Post-ingestion enrichment becomes available]:::success
```

## Reading Notes
- File-backed ingestion uses the staged-commit model: `SourceDocument` first, then
  domain records.
- PGN and book/document retries reuse the failed `SourceDocument`.
- Puzzle dataset ingestion may keep valid rows even when some rows are malformed.
