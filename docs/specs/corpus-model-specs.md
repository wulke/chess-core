# Specs: Corpus Model

| ID | Requirement | Status |
|---|---|---|
| CRP-001 | WHEN `chess-core` stores a chess position in the canonical corpus THE SYSTEM SHALL represent it as a `PositionOccurrence` distinguished by context-specific provenance rather than by FEN alone. | [x] → #4 |
| CRP-002 | WHEN two study contexts contain the same FEN THE SYSTEM SHALL allow multiple `PositionOccurrence` records to coexist with distinct provenance and annotations. | [x] → #4 |
| CRP-003 | WHEN a `PositionOccurrence` is stored THE SYSTEM SHALL persist `side_to_move` as a denormalized value that agrees with the FEN payload. | [x] → #4 |
| CRP-004 | WHEN a `PositionOccurrence` has `source_kind = 'game'` THE SYSTEM SHALL resolve `source_ref_id` to `Game.id`. | [x] → #4 |
| CRP-005 | WHEN a `PositionOccurrence` has `source_kind = 'book'` THE SYSTEM SHALL resolve `source_ref_id` to `BookChunk.id`. | [ ] → #8 |
| CRP-006 | WHEN a `PositionOccurrence` has `source_kind = 'puzzle'` THE SYSTEM SHALL resolve `source_ref_id` to `Puzzle.id`. | [x] → #6 |
| CRP-007 | WHEN a `PositionOccurrence` has `source_kind = 'manual'` THE SYSTEM SHALL allow `source_ref_id` to be null. | [x] → #4 |
| CRP-008 | WHEN `PositionOccurrence` records come from non-game contexts THE SYSTEM SHALL allow `move_number` and `ply_index` to be null. | [x] → #6 |
| CRP-009 | WHEN a `PositionOccurrence` is stored THE SYSTEM SHALL persist `position_hash` as a stable equality-and-indexing aid without replacing FEN as the canonical position payload. | [x] → #4 |
| CRP-010 | WHEN a `PositionOccurrence` is stored THE SYSTEM SHALL persist `is_mainline` to distinguish mainline positions from non-mainline contexts. | [x] → #4 |
| CRP-011 | WHEN a `PositionOccurrence` belongs to a game context THE SYSTEM SHALL allow a direct nullable `game_id` reference to the owning `Game` for join-friendly access independent of polymorphic source resolution. | [x] → #4 |
| CRP-012 | WHEN `chess-core` stores a game imported into the corpus THE SYSTEM SHALL represent it as a `Game` with player metadata, event metadata, result metadata, and preserved PGN text. | [x] → #4 |
| CRP-013 | WHEN a `Game` is stored THE SYSTEM SHALL persist `external_game_key` as the stable per-game deduplication key used during PGN retry. | [ ] → #7 |
| CRP-014 | WHEN optional PGN metadata such as `played_at`, `termination`, `eco_code`, or `opening_name` is unavailable THE SYSTEM SHALL allow those `Game` fields to remain null. | [x] → #4 |
| CRP-015 | WHEN `chess-core` stores a normalized game move THE SYSTEM SHALL represent it as a first-class `MoveRecord`. | [x] → #4 |
| CRP-016 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL persist a direct `game_id` reference to its owning `Game`. | [x] → #4 |
| CRP-017 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL preserve `move_number`, `ply_index`, and `side` as required game-sequencing fields. | [x] → #4 |
| CRP-018 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL link it to both the originating and resulting `PositionOccurrence` rows through `from_position_occurrence_id` and `to_position_occurrence_id`. | [x] → #4 |
| CRP-019 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL preserve SAN notation, piece identity, and move outcome flags including capture, check, and checkmate state. | [x] → #4 |
| CRP-020 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL preserve optional PGN-derived move metadata including NAG and move comment text when present. | [x] → #4 |
| CRP-021 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL treat `uci` as the canonical move encoding. | [x] → #4 |
| CRP-022 | WHEN a `MoveRecord` is stored THE SYSTEM SHALL preserve `from_square`, `to_square`, and `promotion_piece` as denormalized query-friendly fields derived from `uci`. | [x] → #4 |
| CRP-023 | WHEN a review episode is captured THE SYSTEM SHALL represent it as an `AnalysisSession` rooted at a `PositionOccurrence`. | [ ] → #10 |
| CRP-024 | WHEN an `AnalysisSession` is stored THE SYSTEM SHALL preserve `author_type` and `session_kind` from the approved enum set (`user`, `llm`, `engine`, `import`) and (`postgame`, `book-review`, `opening-study`, `puzzle-review`, `manual`) respectively. | [ ] → #10 |
| CRP-025 | WHEN an `AnalysisSession` is stored THE SYSTEM SHALL preserve `title`, `started_at`, and nullable `ended_at` as session lifecycle fields. | [ ] → #10 |
| CRP-026 | WHEN an `AnalysisSession` contains candidate-line exploration THE SYSTEM SHALL store explored moves as `AnalysisNode` records connected by parent-child relationships. | [ ] → #10 |
| CRP-027 | WHEN sibling `AnalysisNode` records exist under the same parent THE SYSTEM SHALL preserve explicit child ordering through `branch_order`. | [ ] → #10 |
| CRP-028 | WHEN an `AnalysisNode` is stored THE SYSTEM SHALL preserve `node_index` as a stable per-session insertion-order identifier. | [ ] → #10 |
| CRP-029 | WHEN an `AnalysisNode` is stored THE SYSTEM SHALL preserve `ply_depth` as the node depth from the root position within the variation tree. | [ ] → #10 |
| CRP-030 | WHEN an `AnalysisNode` is stored THE SYSTEM SHALL preserve `root_position_occurrence_id` as a denormalized reference for fast lookup back to the root study position. | [ ] → #10 |
| CRP-031 | WHEN a variation or plan has durable study value THE SYSTEM SHALL allow it to be promoted into a reusable `StudyLine`. | [ ] → #12 |
| CRP-032 | WHEN a `StudyLine` is stored THE SYSTEM SHALL preserve `title`, `root_fen`, `canonical_line_uci`, `line_purpose`, `status`, nullable `summary`, and `updated_at` as core study-line fields, where `line_purpose` is one of (`opening-reference`, `middlegame-plan`, `tactical-motif`, `endgame-technique`, `defensive-resource`, `refutation`, `calculation-pattern`, `mistake-pattern`, `memorize`, `review-later`) and `status` is one of (`active`, `archived`). | [ ] → #12 |
| CRP-033 | WHEN a `StudyLine` is promoted from a specific analysis session THE SYSTEM SHALL allow `origin_analysis_session_id` to reference that source session. | [ ] → #12 |
| CRP-034 | WHEN a book excerpt is imported THE SYSTEM SHALL represent it as a `BookChunk` with non-null `text`, stable `chunk_index`, and nullable citation fields for metadata that is unavailable from the source. | [x] → #5 |
| CRP-035 | WHEN a book excerpt is linked to chess meaning THE SYSTEM SHALL represent the link as a `BookAnchor` without mutating the source `BookChunk`. | [ ] → #8 |
| CRP-036 | WHEN a `BookAnchor` is stored THE SYSTEM SHALL preserve `anchor_kind` from the approved enum set (`example`, `discussion`, `diagram`, `exercise`, `reference`) for anchor semantics. | [ ] → #8 |
| CRP-037 | WHEN a `BookAnchor` target is chosen in v1 THE SYSTEM SHALL preserve `target_type` from the approved enum set (`position_occurrence`, `study_line`, `game`, `puzzle`, `analysis_session`, `analysis_node`) and SHALL exclude `move_record` from supported target types. | [ ] → #8 |
| CRP-038 | WHEN a note, evaluation, label, or commentary is attached to a supported corpus object THE SYSTEM SHALL store it as an `Annotation` with target polymorphism across (`position_occurrence`, `study_line`, `game`, `puzzle`, `book_chunk`, `analysis_session`, `analysis_node`, `move_record`). | [x] → #11 |
| CRP-039 | WHEN an `Annotation` is stored THE SYSTEM SHALL preserve `author_type` from the approved enum set (`user`, `llm`, `engine`, `import`) to identify who authored the annotation. | [x] → #11 |
| CRP-040 | WHEN an `Annotation` is stored THE SYSTEM SHALL preserve `annotation_kind` from the approved enum set (`note`, `commentary`, `evaluation`, `label`, `summary`, `warning`) for annotation semantics. | [x] → #11 |
| CRP-041 | WHEN structured annotation data exists alongside human-readable annotation text THE SYSTEM SHALL allow it to be stored in `payload_json`. | [x] → #11 |
| CRP-042 | WHEN a puzzle is stored THE SYSTEM SHALL represent it as a first-class `Puzzle` entity rather than overloading `SourceDocument`. | [x] → #6 |
| CRP-043 | WHEN a `Puzzle` is stored THE SYSTEM SHALL preserve `side_to_move` as a denormalized value that agrees with the puzzle FEN payload. | [x] → #6 |
| CRP-044 | WHEN a `Puzzle` is stored THE SYSTEM SHALL preserve `source_provider` from the approved enum set (`lichess`, `manual`, `import`). | [x] → #6 |
| CRP-045 | WHEN a `Puzzle.external_puzzle_id` is non-null THE SYSTEM SHALL enforce uniqueness for that identifier. | [x] → #6 |
| CRP-046 | WHEN a `Puzzle.external_puzzle_id` is null THE SYSTEM SHALL treat (`source_provider`, `fen`) as the fallback uniqueness basis. | [x] → #6 |
| CRP-047 | WHEN a `SourceDocument` is stored THE SYSTEM SHALL track `import_status` as `pending`, `complete`, or `failed`. | [x] → #3 |
| CRP-048 | WHEN a `SourceDocument.import_status` is not `complete` THE SYSTEM SHALL allow `imported_at` to remain null. | [x] → #3 |
| CRP-049 | WHEN a `SourceDocument.import_status` transitions to `complete` THE SYSTEM SHALL populate `imported_at` with the successful completion timestamp. | [x] → #3 |
| CRP-050 | WHEN a `BookAnchor` is stored THE SYSTEM SHALL preserve `target_id` as the identifier of the record selected by `target_type`. | [ ] → #8 |
| CRP-051 | WHEN a correction, supersession, or revision to an existing `Annotation` is required THE SYSTEM SHALL persist it as a new `Annotation` row and SHALL NOT mutate the existing row in place. | [x] → #11 |
