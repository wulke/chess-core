# V1 Corpus Overview

Backed by:
- [docs/high-level-design.md](/Users/trevorwulke/workspace/chess-core/docs/high-level-design.md)
- [docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md)
- [docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md)
- Specs: `CRP-001` through `CRP-049`, `ING-001` through `ING-023`, `PZL-001` through `PZL-017`

This overview is lifecycle-first, but it keeps `PositionOccurrence` at the center
because v1 study meaning converges there regardless of source family.

```mermaid
flowchart LR
    classDef actor fill:#f5f0e6,stroke:#6b5b3e,color:#2d2618;
    classDef source fill:#eef4ff,stroke:#4f6ea9,color:#1e3152;
    classDef core fill:#f7f7f7,stroke:#444,color:#111;
    classDef central fill:#fff3cd,stroke:#9a6b00,color:#4d3600;

    User[Human user]:::actor
    Tool[Downstream tool]:::actor
    LLM[External LLM]:::actor

    PGN[PGN files]:::source
    PDF[PDF or text extracts]:::source
    Puzzles[Puzzle dataset or manual puzzle entry]:::source

    subgraph Core[chess-core canonical corpus]
        direction LR

        subgraph Provenance[Source and provenance]
            SD[SourceDocument]
            G[Game]
            BC[BookChunk]
            PZ[Puzzle]
        end

        PO[PositionOccurrence]:::central

        subgraph MoveGame[Game normalization]
            MR[MoveRecord]
        end

        subgraph Review[Review and durable study]
            AS[AnalysisSession]
            AN[AnalysisNode]
            SL[StudyLine]
        end

        subgraph Meaning[Linking and commentary]
            BA[BookAnchor]
            AT[Annotation]
        end
    end

    PGN --> SD
    PDF --> SD
    Puzzles -->|file-backed| SD
    Puzzles -->|manual path allowed| PZ

    SD --> G
    SD --> BC
    SD --> PZ
    G --> MR
    G --> PO
    MR --> PO
    BC --> BA
    PZ --> PO
    BA --> PO
    BA --> SL
    BA --> G
    BA --> PZ
    PO --> AS
    AS --> AN
    AS --> SL
    PO --> AT
    BC --> AT
    G --> AT
    PZ --> AT
    AN --> AT
    AS --> AT
    SL --> AT

    User -->|manual puzzle entry| PZ
    User -->|manual linking| BA
    User -->|notes or labels| AT
    Tool -->|imports or reads| Core
    LLM -->|freeform commentary| AT
    LLM -->|structured line exploration| AS
```

## Reading Notes
- `SourceDocument` exists for file-backed provenance, but manual puzzle entry may
  create `Puzzle` without it.
- `PositionOccurrence` is the center of study context, not merely a computed side
  table for moves.
- Post-ingestion enrichment writes into `BookAnchor`, `Annotation`,
  `AnalysisSession`, `AnalysisNode`, and optionally `StudyLine`.
