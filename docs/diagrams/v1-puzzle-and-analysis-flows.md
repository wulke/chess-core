# V1 Puzzle And Analysis Flows

Backed by:
- [docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md)
- [docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md)
- Specs: `PZL-001` through `PZL-017`, `ING-021` through `ING-023`, `CRP-024` through `CRP-046`

## Puzzle Intake And Review Context

```mermaid
flowchart TD
    classDef actor fill:#f5f0e6,stroke:#6b5b3e,color:#2d2618;
    classDef action fill:#f7f7f7,stroke:#444,color:#111;
    classDef decision fill:#fff3cd,stroke:#9a6b00,color:#4d3600;
    classDef success fill:#edf7ed,stroke:#4a7a4a,color:#1e4d1e;
    classDef fail fill:#fdecea,stroke:#a94442,color:#6b1f1f;

    A[Puzzle source arrives] --> B{Manual entry or file-backed dataset?}:::decision
    B -->|Manual| C[Create Puzzle with null source_document_id]:::action
    B -->|File-backed| D[Register SourceDocument and set import_status = pending]:::action
    D --> E[Validate each dataset row and commit each valid row independently]:::action
    E --> F{Any valid rows committed?}:::decision
    F -->|No| G[Mark SourceDocument failed and retain provenance]:::fail
    F -->|Yes| H{Malformed rows present?}:::decision
    H -->|Yes| I[Keep committed Puzzle rows, skip malformed rows, and surface row-level failures later]:::fail
    H -->|No| J[Continue normally]:::success
    I --> L[Set import_status = complete]:::success
    J --> L
    C --> M
    L --> M[Puzzle review roots through PositionOccurrence provenance]:::success
```

## Post-Ingestion Enrichment Swim Lanes

```mermaid
flowchart LR
    classDef actor fill:#f5f0e6,stroke:#6b5b3e,color:#2d2618;
    classDef lane fill:#f7f7f7,stroke:#444,color:#111;
    classDef output fill:#eef4ff,stroke:#4f6ea9,color:#1e3152;

    Root[Root PositionOccurrence]:::output
    LLM[External LLM]:::actor
    User[Human or tool orchestrator]:::actor

    subgraph Lane1[Manual or tool-directed puzzle review]
        direction LR
        User --> Review[Select puzzle-root PositionOccurrence]:::lane
        Review --> Provenance[Recover puzzle provenance through the root PositionOccurrence]:::output
    end

    subgraph Lane2[LLM annotation attach]
        direction LR
        User --> Attach[Choose target corpus object]:::lane
        LLM --> Freeform[Produce freeform commentary]:::lane
        Attach --> SaveAnn[Persist Annotation only]:::output
        Freeform --> SaveAnn
    end

    subgraph Lane3[LLM analysis session]
        direction LR
        User --> Analyze[Choose root PositionOccurrence]:::lane
        LLM --> Structured[Produce structured candidate-line output]:::lane
        Analyze --> SaveSession[Persist AnalysisSession and AnalysisNode tree atomically]:::output
        Structured --> SaveSession
        SaveSession --> OrderSemantics[Assign session-local node_index, sibling branch_order, and depth from root]:::output
        OrderSemantics --> OptAnn[Optionally persist Annotation]:::output
    end

    Root --> Review
    Root --> Analyze
```

## Reading Notes
- Puzzle provenance for review flows through the root `PositionOccurrence`, not a
  direct `puzzle_id` on `AnalysisSession`.
- Analysis-tree persistence is atomic per capture submission; failed node
  validation must not leave behind a partial session tree.
- `AnalysisNode.node_index` is a caller-supplied stable session-local
  identifier, `branch_order` is sibling-local display order, and `ply_depth`
  counts plies from the root `PositionOccurrence`.
- File-backed puzzle datasets commit valid rows independently and reuse the same
  failed `SourceDocument` on retry, skipping already committed puzzles using
  `external_puzzle_id` when present or (`source_provider`, `fen`) otherwise.
- Freeform LLM output stays in `Annotation`.
- Structured line exploration becomes first-class `AnalysisSession` and
  `AnalysisNode` data.
