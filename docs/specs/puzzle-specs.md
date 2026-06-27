# Specs: Puzzle Ingestion

| ID | Requirement | Status |
|---|---|---|
| PZL-001 | WHEN a puzzle is imported from a file-backed dataset THE SYSTEM SHALL allow a `SourceDocument` with `source_type = 'puzzle-dataset'` to own the imported puzzle rows. | [ ] → #9 |
| PZL-002 | WHEN a puzzle is created manually THE SYSTEM SHALL allow a `Puzzle` row with null `source_document_id`. | [ ] → #6 |
| PZL-003 | WHEN a puzzle is stored THE SYSTEM SHALL preserve the puzzle FEN and canonical solution line. | [ ] → #6 |
| PZL-004 | WHEN a puzzle is stored in v1 THE SYSTEM SHALL not require its solution line to be normalized into `MoveRecord` rows. | [ ] → #6 |
| PZL-005 | WHEN a puzzle is imported or created THE SYSTEM SHALL create a root `PositionOccurrence` for puzzle-study context. | [ ] → #6 |
| PZL-006 | WHEN a `PositionOccurrence` is rooted in puzzle-study context THE SYSTEM SHALL set `source_kind = 'puzzle'` and resolve `source_ref_id` to `Puzzle.id`. | [ ] → #6 |
| PZL-007 | WHEN a puzzle-review session is created THE SYSTEM SHALL recover puzzle provenance through the root `PositionOccurrence` rather than requiring a direct `puzzle_id` field on `AnalysisSession` in v1. | [ ] → #10 |
| PZL-008 | WHEN a file-backed puzzle import is retried and a matching `SourceDocument.content_hash` already exists in `complete` state THE SYSTEM SHALL skip duplicate whole-file re-import by default unless an explicit overwrite mode is requested. | [ ] → #9 |
| PZL-009 | WHEN a manual puzzle entry matches an existing non-null `external_puzzle_id` THE SYSTEM SHALL reject creation of a duplicate canonical puzzle row. | [ ] → #6 |
| PZL-010 | WHEN a manual puzzle entry has no `external_puzzle_id` THE SYSTEM SHALL use (`source_provider`, `fen`) as the fallback deduplication basis. | [ ] → #6 |
| PZL-011 | WHEN a bulk puzzle dataset contains malformed rows THE SYSTEM SHALL allow valid puzzles to be ingested and SHALL avoid duplicate puzzle creation on retry. | [ ] → #9 |
| PZL-012 | WHEN a bulk puzzle dataset contains malformed rows THE SYSTEM SHALL allow row-level success for valid puzzles rather than rolling back the full dataset batch. | [ ] → #9 |
