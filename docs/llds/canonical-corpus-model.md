# LLD: Canonical Corpus Model

## Interface / Data Model

This LLD defines the canonical entity boundaries for the `chess-core` study corpus.
`sqlite` is the source of truth for these records.

### Entity Groups

#### Source and provenance
- **SourceDocument**
  - Purpose: Represent an imported source artifact such as a PGN file, PDF, extracted text file, or future external study source.
  - Required v1 fields:
    - `id`
    - `source_type` (`pgn`, `pdf`, `text-extract`, `puzzle-dataset`)
    - `title`
    - `path`
    - `content_hash`
    - `import_status` (`pending`, `complete`, `failed`)
    - `created_at`
    - `imported_at` nullable
  - Notes:
    - `created_at` is the timestamp when the `SourceDocument` row is created in `sqlite`.
    - `path` stores the local file path to the raw artifact for file-backed sources.
    - `content_hash` stores the hash of the file-backed source artifact referenced by `path`.
    - `import_status` tracks whether downstream domain-record ingestion has not started yet, completed successfully, or failed after registration.
    - `imported_at` is only populated when `import_status` transitions to `complete` and records when ingestion of the referenced artifact completed successfully.

- **Game**
  - Purpose: Represent one chess game imported into the corpus.
  - Required v1 fields:
    - `id`
    - `source_document_id`
    - `external_game_key`
    - `white_player`
    - `black_player`
    - `event`
    - `site`
    - `played_at` nullable
    - `result`
    - `termination` nullable
    - `eco_code` nullable
    - `opening_name` nullable
    - `pgn_text`
    - `created_at`

- **BookChunk**
  - Purpose: Represent a cited text chunk extracted from a study source.
  - Required v1 fields:
    - `id`
    - `source_document_id`
    - `chapter_label` nullable
    - `section_label` nullable
    - `page_start` nullable
    - `page_end` nullable
    - `chunk_index`
    - `text`
    - `created_at`

- **Puzzle**
  - Purpose: Represent a puzzle source as a first-class study artifact rather than overloading `SourceDocument`.
  - Required v1 fields:
    - `id`
    - `source_document_id` nullable
    - `external_puzzle_id` nullable
    - `source_provider` (`lichess`, `manual`, `import`)
    - `fen`
    - `side_to_move`
    - `solution_line_uci`
    - `theme_tags_json` nullable
    - `difficulty` nullable
    - `created_at`
  - Notes:
    - `Puzzle` is a first-class entity because puzzles have stable chess-specific fields that do not fit generic source-document metadata cleanly.
    - a puzzle may come from bulk import or manual entry
    - `side_to_move` is denormalized from `fen` for query convenience and must agree with the FEN payload.
    - `external_puzzle_id` must be unique when non-null.
    - (`source_provider`, `fen`) is treated as the fallback uniqueness basis when no external puzzle identifier exists.
    - puzzle solution lines are stored on the puzzle record in v1 and are not normalized into `MoveRecord` rows unless later promoted into other corpus artifacts

#### Position and move records
- **PositionOccurrence**
  - Purpose: Represent a context-bound encounter with a chess position.
  - Required v1 fields:
    - `id`
    - `fen`
    - `side_to_move`
    - `position_hash`
    - `source_kind` (`game`, `book`, `puzzle`, `manual`)
    - `source_ref_id` nullable
    - `game_id` nullable
    - `move_number` nullable
    - `ply_index` nullable
    - `is_mainline`
    - `occurred_at` nullable
    - `user_note` nullable
    - `created_at`
  - Notes:
    - `fen` is the canonical chess-position payload.
    - `side_to_move` is denormalized from `fen` for query convenience and must agree with the FEN payload.
    - `position_hash` exists for stable equality/indexing without replacing the original FEN.
    - multiple `PositionOccurrence` rows may share the same `fen`
    - `source_ref_id` resolves by `source_kind` as follows:

      | `source_kind` | `source_ref_id` resolves to |
      |---|---|
      | `game` | `Game.id` |
      | `book` | `BookChunk.id` |
      | `puzzle` | `Puzzle.id` |
      | `manual` | no referent; `source_ref_id` is nullable |
    - `move_number` and `ply_index` are nullable for non-game contexts where no source move numbering exists.

- **MoveRecord**
  - Purpose: Represent one normalized move as a first-class queryable record.
  - Required v1 fields:
    - `id`
    - `game_id`
    - `from_position_occurrence_id`
    - `to_position_occurrence_id`
    - `ply_index`
    - `move_number`
    - `side`
    - `san`
    - `uci`
    - `piece`
    - `from_square`
    - `to_square`
    - `is_capture`
    - `is_check`
    - `is_checkmate`
    - `promotion_piece` nullable
    - `nag` nullable
    - `comment_text` nullable
    - `created_at`
  - Notes:
    - `uci` is the canonical move encoding.
    - `from_square`, `to_square`, and `promotion_piece` are denormalized from `uci` for query convenience.
    - `comment_text` preserves PGN-native inline move commentary as imported provenance on the move row itself.
    - v1 annotation workflows must not rewrite, clear, or auto-copy `comment_text` into `Annotation`; attaching commentary to a `move_record` is a separate enrichment action.

#### Analysis and reusable study artifacts
- **AnalysisSession**
  - Purpose: Represent one bounded thinking or review episode rooted at a `PositionOccurrence`.
  - Required v1 fields:
    - `id`
    - `root_position_occurrence_id`
    - `author_type` (`user`, `llm`, `engine`, `import`)
    - `session_kind` (`postgame`, `book-review`, `opening-study`, `puzzle-review`, `manual`)
    - `title`
    - `started_at`
    - `ended_at` nullable
    - `created_at`
  - Notes:
    - `puzzle-review` sessions recover puzzle provenance through the root `PositionOccurrence` chain where the root `PositionOccurrence.source_kind = 'puzzle'` and `PositionOccurrence.source_ref_id = Puzzle.id`.
    - a direct `puzzle_id` field is not required in v1 because the root occurrence is the canonical context link for all session kinds.

- **AnalysisNode**
  - Purpose: Represent one step in a variation tree inside an `AnalysisSession`.
  - Required v1 fields:
    - `id`
    - `analysis_session_id`
    - `parent_node_id` nullable
    - `root_position_occurrence_id`
    - `node_index`
    - `ply_depth`
    - `branch_order`
    - `move_san`
    - `move_uci`
    - `fen_after`
    - `position_hash_after`
    - `user_note` nullable
    - `created_at`
  - Notes:
    - `parent_node_id = null` means the node is a first-ply branch from the root position.
    - child ordering is explicit via `branch_order`.
    - `node_index` is a stable per-session insertion-order index for uniquely identifying nodes independent of tree depth.
    - `root_position_occurrence_id` is denormalized from the owning session for fast join-free lookup from a node back to the root study position.

- **StudyLine**
  - Purpose: Represent a reusable line, plan, refutation, or pattern worth preserving outside a single analysis session.
  - Required v1 fields:
    - `id`
    - `title`
    - `line_purpose` (`opening-reference`, `middlegame-plan`, `tactical-motif`, `endgame-technique`, `defensive-resource`, `refutation`, `calculation-pattern`, `mistake-pattern`, `memorize`, `review-later`)
    - `root_fen`
    - `canonical_line_uci`
    - `origin_analysis_session_id` nullable
    - `summary` nullable
    - `status` (`active`, `archived`)
    - `created_at`
    - `updated_at`
  - Notes:
    - `origin_analysis_session_id` records promotion from a specific analysis session when applicable.
    - provenance from books, games, or imported sources may still be attached through `BookAnchor` and `Annotation`.

#### Linking and annotations
- **BookAnchor**
  - Purpose: Link `BookChunk` text to chess corpus objects.
  - Required v1 fields:
    - `id`
    - `book_chunk_id`
    - `target_type` (`position_occurrence`, `study_line`, `game`, `puzzle`, `analysis_session`, `analysis_node`)
    - `target_id`
    - `anchor_kind` (`example`, `discussion`, `diagram`, `exercise`, `reference`)
    - `created_at`
  - Notes:
    - `BookAnchor` is append-only enrichment metadata and must not update the linked `BookChunk.text` or citation fields.
    - `target_id` resolves by `target_type` as follows:

      | `target_type` | `target_id` resolves to |
      |---|---|
      | `position_occurrence` | `PositionOccurrence.id` |
      | `study_line` | `StudyLine.id` |
      | `game` | `Game.id` |
      | `puzzle` | `Puzzle.id` |
      | `analysis_session` | `AnalysisSession.id` |
      | `analysis_node` | `AnalysisNode.id` |
    - `move_record` is intentionally excluded from `target_type` in v1 because book prose is expected to anchor to positions, lines, games, puzzles, or analysis context rather than a single normalized move row.
    - the `target_type` enum is the approved v1 boundary even when some target entity tables land in later issues; adding a new supported workflow later must reuse this boundary rather than widening it ad hoc
    - Issue `#8` only requires link creation against target entity tables that already exist in the canonical schema at implementation time; future issues may activate additional approved target types once their owning tables are present

- **Annotation**
  - Purpose: Attach commentary, labels, or evaluations to corpus objects.
  - Required v1 fields:
    - `id`
    - `target_type` (`position_occurrence`, `study_line`, `game`, `puzzle`, `book_chunk`, `analysis_session`, `analysis_node`, `move_record`)
    - `target_id`
    - `author_type` (`user`, `llm`, `engine`, `import`)
    - `annotation_kind` (`note`, `commentary`, `evaluation`, `label`, `summary`, `warning`)
    - `body`
    - `payload_json` nullable
    - `created_at`
  - Notes:
    - `Annotation` is append-only enrichment metadata; correcting, superseding, or revising meaning creates a new row instead of mutating an existing one in place.
    - `target_id` resolves by `target_type` as follows:

      | `target_type` | `target_id` resolves to |
      |---|---|
      | `position_occurrence` | `PositionOccurrence.id` |
      | `study_line` | `StudyLine.id` |
      | `game` | `Game.id` |
      | `puzzle` | `Puzzle.id` |
      | `book_chunk` | `BookChunk.id` |
      | `analysis_session` | `AnalysisSession.id` |
      | `analysis_node` | `AnalysisNode.id` |
      | `move_record` | `MoveRecord.id` |
    - `move_record` is included for `Annotation` because a reviewer, engine, or LLM may need to attach meaning to one normalized move, even though book prose does not anchor to move rows in v1.
    - `payload_json` may store structured fields such as engine scores, parser output, or LLM metadata alongside the human-readable `body`.
    - v1 does not add first-class annotation provenance columns beyond `author_type`; when an LLM workflow needs model/session metadata it should store that data inside `payload_json`.
    - v1 does not enforce a schema-level deduplication key for `Annotation` because intentionally repeated notes may coexist on the same target; retry-safe deduplication is the responsibility of the calling workflow when idempotency matters.

### Relationship Summary
- one `SourceDocument` may produce many `Game` records
- one `SourceDocument` may produce many `BookChunk` records
- one `SourceDocument` may produce many `Puzzle` records when the puzzle source is file-backed
- one `Game` produces many `PositionOccurrence` and `MoveRecord` rows
- one `BookChunk` may produce one or more `PositionOccurrence` rows when imported study text is linked to explicit positions
- one `Puzzle` may produce one or more `PositionOccurrence` rows rooted in puzzle study context
- one `PositionOccurrence` may root many `AnalysisSession` rows
- one `AnalysisSession` owns many `AnalysisNode` rows in a tree
- one `StudyLine` may be linked from many `BookAnchor` and `Annotation` rows
- one `BookChunk` may anchor to many target records
- one target record may receive many `Annotation` rows

## Logic Flow

1. Import a `SourceDocument`.
2. Parse the source into domain records:
   - PGN sources create `Game`, `PositionOccurrence`, and `MoveRecord` rows.
   - PDF/text sources create `BookChunk` rows.
   - puzzle imports create `Puzzle` rows and root `PositionOccurrence` rows.
3. When a position is reviewed, create an `AnalysisSession` rooted at a `PositionOccurrence`.
4. Store explored branches as `AnalysisNode` rows linked by `parent_node_id`.
5. Promote durable variations or plans into `StudyLine` rows when they have long-term value.
6. Link study text to chess objects through append-only `BookAnchor` rows while leaving the source `BookChunk` unchanged.
7. Allow one workflow submission to create several `BookAnchor` rows for the same `BookChunk`.
8. Attach commentary or derived meaning through `Annotation`.

## Edge Case Probe
- Same FEN appears in many contexts -> store separate `PositionOccurrence` rows and use `position_hash` only for equality/indexing, not identity.
- Puzzle sources need solution lines but are not games -> store solution moves on `Puzzle.solution_line_uci` in v1 and use `AnalysisSession`/`AnalysisNode` for review activity.
- PGN comments exist on individual moves -> preserve them on `MoveRecord.comment_text` as imported provenance in v1, and any later annotation attach workflow must not rewrite, clear, or auto-create duplicate `Annotation` rows from that imported comment text.
- One book chunk refers to several positions -> create multiple `BookAnchor` rows from one `BookChunk`.
- One analysis session branches heavily -> preserve tree shape through `parent_node_id` and `branch_order`; do not flatten into one line string.
- A line becomes durable knowledge after analysis -> create a `StudyLine` instead of overloading `AnalysisNode`.
- An LLM or engine produces structured output -> store human-readable text in `body` and machine-friendly fields in `payload_json`.
- An annotation attach workflow is retried after a partial upstream failure -> accept append-only duplicates at the schema layer and require the caller to supply any idempotency policy above the canonical store.
