# Specs: Ingestion Contracts

| ID | Requirement | Status |
|---|---|---|
| ING-001 | WHEN a file-backed raw artifact is registered for ingestion THE SYSTEM SHALL create a `SourceDocument` before domain-record ingestion begins. | [x] → #3 |
| ING-002 | WHEN a file-backed raw artifact is registered as a `SourceDocument` THE SYSTEM SHALL store the local file path and file content hash. | [x] → #3 |
| ING-003 | WHEN a manual puzzle is created without a backing file THE SYSTEM SHALL allow ingestion to proceed without creating a `SourceDocument`. | [x] → #6 |
| ING-004 | WHEN domain-record ingestion begins for a newly registered `SourceDocument` THE SYSTEM SHALL set `import_status` to `pending`. | [x] → #3 |
| ING-005 | WHEN ingestion succeeds for a `SourceDocument` THE SYSTEM SHALL set `import_status` to `complete`. | [x] → #3 |
| ING-006 | WHEN ingestion fails after `SourceDocument` registration THE SYSTEM SHALL set `import_status` to `failed`. | [x] → #3 |
| ING-007 | WHEN `chess-core` ingests file-backed artifacts THE SYSTEM SHALL use a staged-commit model where `SourceDocument` registration is committed before domain-record import units are committed. | [x] → #3 |
| ING-008 | WHEN PGN ingestion processes a file THE SYSTEM SHALL preserve the original PGN text on each imported `Game`. | [x] → #4 |
| ING-009 | WHEN PGN ingestion processes a game THE SYSTEM SHALL normalize individual moves into `MoveRecord` rows. | [x] → #4 |
| ING-010 | WHEN PGN ingestion processes a game THE SYSTEM SHALL derive `PositionOccurrence` rows for mainline game positions in v1. | [x] → #4 |
| ING-011 | WHEN a file-backed PGN import is retried and a matching `SourceDocument.content_hash` already exists in `complete` state THE SYSTEM SHALL skip duplicate whole-file re-import by default unless an explicit overwrite mode is requested. | [ ] → #7 |
| ING-012 | WHEN a PGN import fails partway through a multi-game file THE SYSTEM SHALL retain the existing `SourceDocument` and support retry under that same record. | [ ] → #7 |
| ING-013 | WHEN a PGN import is retried under an existing failed `SourceDocument` THE SYSTEM SHALL reset `import_status` to `pending` before resuming domain-record ingestion. | [ ] → #7 |
| ING-014 | WHEN a PGN import is retried after partial success THE SYSTEM SHALL deduplicate per game using `Game.external_game_key` within the existing `SourceDocument`. | [ ] → #7 |
| ING-015 | WHEN book/document ingestion processes extracted text THE SYSTEM SHALL create `BookChunk` rows even if chapter labels, section labels, or page ranges are unavailable. | [x] → #5 |
| ING-016 | WHEN book/document ingestion receives citation metadata THE SYSTEM SHALL preserve chapter labels, section labels, and page ranges on `BookChunk` rows. | [x] → #5 |
| ING-017 | WHEN a file-backed book/document import is retried and a matching `SourceDocument.content_hash` already exists in `complete` state THE SYSTEM SHALL skip duplicate whole-file re-import by default unless an explicit overwrite mode is requested. | [x] → #5 |
| ING-018 | WHEN book/document chunk extraction fails under a `SourceDocument` THE SYSTEM SHALL mark the `SourceDocument` as `failed`. | [x] → #5 |
| ING-019 | WHEN a failed book/document import is retried THE SYSTEM SHALL reuse the existing failed `SourceDocument`, reset `import_status` to `pending`, and rerun the chunk batch as a whole. | [x] → #5 |
| ING-020 | WHEN a user links imported source text to one or more supported corpus targets after ingestion THE SYSTEM SHALL persist one `BookAnchor` per selected target and SHALL allow multiple targets per source chunk. | [ ] → #8 |
| ING-021 | WHEN an external LLM response is attached as freeform commentary THE SYSTEM SHALL persist it as an append-only `Annotation` without mutating imported source records directly. | [x] → #11 |
| ING-022 | WHEN an external LLM response contains structured candidate-line exploration THE SYSTEM SHALL allow ingestion as `AnalysisSession` plus `AnalysisNode` records. | [ ] → #13 |
| ING-023 | WHEN a file-backed v1 ingestion workflow commits its canonical `sqlite` import-unit writes and transitions `SourceDocument.import_status` to `complete` THE SYSTEM SHALL consider ingestion successful even if an analytics projection layer such as `duckdb` is absent. | [x] → #14 |
| ING-024 | WHEN one manual-linking submission contains several selected targets THE SYSTEM SHALL commit all requested `BookAnchor` rows atomically or roll them all back together. | [ ] → #8 |
| ING-025 | WHEN a manual-linking submission references a `BookChunk` that does not exist THE SYSTEM SHALL reject the submission without persisting any `BookAnchor` rows. | [ ] → #8 |
| ING-026 | WHEN a manual-linking submission references a target entity that does not exist for the selected `target_type` THE SYSTEM SHALL reject the submission without persisting any `BookAnchor` rows. | [ ] → #8 |
| ING-027 | WHEN an annotation attach workflow targets a `move_record` THE SYSTEM SHALL add commentary as `Annotation` enrichment without rewriting, clearing, or auto-copying `MoveRecord.comment_text`. | [x] → #11 |
