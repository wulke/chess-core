# V1 Book Ingestion And Linking

Backed by:
- [docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md)
- [docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md)
- Specs: `ING-015` through `ING-020`, `CRP-034` through `CRP-037`

## Book Or Document Ingestion

```mermaid
sequenceDiagram
    autonumber
    participant User as User or tool
    participant Core as chess-core
    participant SD as SourceDocument store
    participant Chunk as BookChunk records

    User->>Core: Submit PDF or extracted text source
    Core->>SD: Register SourceDocument(path, content_hash)
    alt Matching complete SourceDocument exists
        Core-->>User: Skip duplicate whole-file re-import by default
    else New import or retry under failed SourceDocument
        Core->>SD: Set import_status = pending
        Core->>Chunk: Persist one chunk extraction batch
        Note over Chunk: Keep chapter, section, and page metadata when available
        Note over Chunk: Still ingest rows when citation metadata is absent
        alt Batch succeeds
            Core->>SD: Set import_status = complete
            Core->>SD: Set imported_at timestamp
            Core-->>User: Book ingestion complete
        else Batch fails
            Core->>SD: Set import_status = failed
            Core-->>User: Retry reruns the full chunk batch under the same SourceDocument
        end
    end
```

## Manual Linking Swim Lane

```mermaid
flowchart LR
    classDef actor fill:#f5f0e6,stroke:#6b5b3e,color:#2d2618;
    classDef action fill:#f7f7f7,stroke:#444,color:#111;
    classDef optional fill:#eef4ff,stroke:#4f6ea9,color:#1e3152;

    User[Human user]:::actor --> Select[Select BookChunk and one or more targets]:::action
    Select --> Anchor[Persist BookAnchor rows]:::action
    Anchor --> Targets[Target types: PositionOccurrence, StudyLine, Game, Puzzle, AnalysisSession, AnalysisNode]:::optional
    Anchor --> OptLine[Optionally create or link StudyLine]:::optional
    Anchor --> OptNote[Optionally add Annotation]:::optional
```

## Reading Notes
- Import and linking are intentionally separate stages.
- `BookChunk` preserves source text; `BookAnchor` adds chess meaning without
  mutating the chunk itself.
- v1 excludes `move_record` as a direct `BookAnchor` target type.
