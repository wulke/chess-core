# Specs: Ingestion Contracts

| ID | Requirement | Status |
|---|---|---|
| ING-001 | WHEN a file-backed raw artifact is registered for ingestion THE SYSTEM SHALL create a `SourceDocument` before domain-record ingestion begins. | [ ] → #3 |
| ING-002 | WHEN a file-backed raw artifact is registered as a `SourceDocument` THE SYSTEM SHALL store the local file path and file content hash. | [ ] → #3 |
| ING-003 | WHEN a manual puzzle is created without a backing file THE SYSTEM SHALL allow ingestion to proceed without creating a `SourceDocument`. | [x] → #6 |
| ING-004 | WHEN domain-record ingestion begins for a newly registered `SourceDocument` THE SYSTEM SHALL set `import_status` to `pending`. | [ ] → #3 |
| ING-005 | WHEN ingestion succeeds for a `SourceDocument` THE SYSTEM SHALL set `import_status` to `complete`. | [ ] → #3 |
| ING-006 | WHEN ingestion fails after `SourceDocument` registration THE SYSTEM SHALL set `import_status` to `failed`. | [ ] → #3 |
| ING-007 | WHEN `chess-core` ingests file-backed artifacts THE SYSTEM SHALL use a staged-commit model where `SourceDocument` registration is committed before domain-record import units are committed. | [ ] → #3 |
| ING-008 | WHEN PGN ingestion processes a file THE SYSTEM SHALL preserve the original PGN text on each imported `Game`. | [ ] → #4 |
| ING-009 | WHEN PGN ingestion processes a game THE SYSTEM SHALL normalize individual moves into `MoveRecord` rows. | [ ] → #4 |
| ING-010 | WHEN PGN ingestion processes a game THE SYSTEM SHALL derive `PositionOccurrence` rows for mainline game positions in v1. | [ ] → #4 |
| ING-011 | WHEN a file-backed PGN import is retried and a matching `SourceDocument.content_hash` already exists in `complete` state THE SYSTEM SHALL skip duplicate whole-file re-import by default unless an explicit overwrite mode is requested. | [ ] → #7 |
| ING-012 | WHEN a PGN import fails partway through a multi-game file THE SYSTEM SHALL retain the existing `SourceDocument` and support retry under that same record. | [ ] → #7 |
| ING-013 | WHEN a PGN import is retried under an existing failed `SourceDocument` THE SYSTEM SHALL reset `import_status` to `pending` before resuming domain-record ingestion. | [ ] → #7 |
| ING-014 | WHEN a PGN import is retried after partial success THE SYSTEM SHALL deduplicate per game using `Game.external_game_key` within the existing `SourceDocument`. | [ ] → #7 |
| ING-015 | WHEN book/document ingestion processes extracted text THE SYSTEM SHALL create `BookChunk` rows even if chapter labels, section labels, or page ranges are unavailable. | [ ] → #5 |
| ING-016 | WHEN book/document ingestion receives citation metadata THE SYSTEM SHALL preserve chapter labels, section labels, and page ranges on `BookChunk` rows. | [ ] → #5 |
| ING-017 | WHEN a file-backed book/document import is retried and a matching `SourceDocument.content_hash` already exists in `complete` state THE SYSTEM SHALL skip duplicate whole-file re-import by default unless an explicit overwrite mode is requested. | [ ] → #5 |
| ING-018 | WHEN book/document chunk extraction fails under a `SourceDocument` THE SYSTEM SHALL mark the `SourceDocument` as `failed`. | [ ] → #5 |
| ING-019 | WHEN a failed book/document import is retried THE SYSTEM SHALL reuse the existing failed `SourceDocument`, reset `import_status` to `pending`, and rerun the chunk batch as a whole. | [ ] → #5 |
| ING-020 | WHEN a user links imported source text to corpus objects after ingestion THE SYSTEM SHALL persist the link as `BookAnchor` and SHALL allow multiple targets per source chunk. | [ ] → #8 |
| ING-021 | WHEN an external LLM response is attached as freeform commentary THE SYSTEM SHALL persist it as an `Annotation` without mutating imported source records directly. | [ ] → #11 |
| ING-022 | WHEN an external LLM response contains structured candidate-line exploration THE SYSTEM SHALL allow ingestion as `AnalysisSession` plus `AnalysisNode` records. | [ ] → #13 |
| ING-023 | WHEN an analytics projection layer such as `duckdb` is absent THE SYSTEM SHALL still consider v1 ingestion complete if canonical `sqlite` writes succeeded. | [ ] → #14 |
