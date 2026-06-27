# V1 PGN Ingestion

Backed by:
- [docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md)
- [docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md)
- Specs: `ING-008` through `ING-014`, `CRP-012` through `CRP-023`, `CRP-047` through `CRP-049`

```mermaid
sequenceDiagram
    autonumber
    participant User as User or tool
    participant Core as chess-core
    participant SD as SourceDocument store
    participant Game as Game records
    participant Move as MoveRecord records
    participant Pos as PositionOccurrence records

    User->>Core: Submit PGN file
    Core->>SD: Register SourceDocument(path, content_hash)
    alt Matching complete SourceDocument exists
        Core-->>User: Skip duplicate whole-file re-import by default
    else New import or retry under failed SourceDocument
        Core->>SD: Set import_status = pending
        loop For each PGN game in file
            Core->>Game: Upsert Game by external_game_key within SourceDocument
            alt Game already committed in prior partial attempt
                Game-->>Core: Skip duplicate game
            else New game to normalize
                Core->>Game: Preserve PGN text and game metadata
                Core->>Pos: Create mainline PositionOccurrence rows
                Core->>Move: Create MoveRecord rows linked to positions
            end
        end
        alt Full import unit succeeds
            Core->>SD: Set import_status = complete
            Core->>SD: Set imported_at timestamp
            Core-->>User: PGN ingestion complete
        else Import fails partway through file
            Core->>SD: Set import_status = failed
            Core-->>User: Retry may resume under same SourceDocument
        end
    end
```

## Reading Notes
- The retry path is file-scoped for provenance but game-scoped for deduplication.
- v1 PGN ingestion creates mainline `PositionOccurrence` rows only.
- `MoveRecord` links games to positions in both sequence and provenance terms.
