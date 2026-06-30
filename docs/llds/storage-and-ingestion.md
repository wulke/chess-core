# LLD: Storage And Ingestion Boundaries

## Interface / Data Model

This LLD defines where data lives in v1 and what ingestion guarantees `chess-core`
must make.

### Transaction Model
- **Staged commit model**
  - `SourceDocument` registration may be committed first so the system can retain provenance for attempted imports and support idempotent retry decisions.
  - Domain records for a given ingestion path are then written in a single transaction per import unit:
    - one PGN game normalization unit
    - one book chunk extraction batch
    - one puzzle row or manual puzzle entry
  - If the domain-record transaction fails, the retained `SourceDocument` must not cause duplicate successful imports on retry.
  - PGN imports use per-game deduplication via `Game.external_game_key` so a retry may skip already committed games within the same `SourceDocument` and continue importing the remaining games.
  - On retry after failure, `chess-core` resumes under the existing `failed` `SourceDocument` matched by `content_hash` instead of creating a new `SourceDocument` row.
  - Book/document ingestion retries also resume under the existing `failed` `SourceDocument` matched by `content_hash`; chunk extraction is treated as one transactional batch, so failed batches are rolled back and the full batch is re-attempted on retry.
  - Puzzle dataset ingestion treats each dataset row as its own import unit; one malformed row must not roll back previously committed valid puzzle rows from the same file.
  - Puzzle dataset retries resume under the existing `failed` `SourceDocument`, reset `import_status` to `pending`, and skip already committed puzzle rows using `external_puzzle_id` when present or (`source_provider`, `fen`) otherwise.
  - v1 file-backed ingestion completion is reached when the canonical `sqlite` transaction for the import unit commits successfully and `SourceDocument.import_status` transitions to `complete`.
  - Manual linking treats one user submission as one canonical import unit; when one `BookChunk` is linked to several targets in the same workflow, all `BookAnchor` rows for that submission commit or roll back together.
  - Derived analytics or projection work, including any future `duckdb` projection, must run outside that file-backed completion boundary and must not block a successful v1 ingestion result.

### Storage Layers
- **Raw artifacts**
  - Purpose: Preserve user-provided source files and derivative extracts without
    normalizing away the original material.
  - Examples:
    - `.pgn` files
    - `.pdf` files
    - extracted text files
    - future exported note bundles
  - Ownership:
    - files remain the canonical raw inputs
    - `SourceDocument.path` references them

- **Canonical sqlite store**
  - Purpose: Hold the normalized relational corpus model owned by `chess-core`.
  - Must contain:
    - source metadata
    - games
    - puzzles
    - normalized move records
    - position occurrences
    - book chunks
    - anchors
    - analysis sessions/nodes
    - study lines
    - annotations

- **Derived analytics**
  - Purpose: explicitly out of the v1 critical path
  - v1 rule:
    - no ingestion is incomplete because a derived analytics layer is absent
    - `duckdb` is deferred until query pressure justifies projection work

### v1 Ingestion Contracts
- **PGN ingestion**
  - Input:
    - one or more `.pgn` files
  - Output:
    - `SourceDocument`
    - `Game`
    - `PositionOccurrence`
    - `MoveRecord`
  - Guarantees:
    - preserve original PGN text
    - normalize individual moves into queryable records
    - derive position occurrences for mainline game states
    - skip duplicate whole-file re-import by default when a `SourceDocument.content_hash` already exists in `complete` state, unless a future explicit overwrite mode is requested
    - support retry after partial-file failure by reusing the existing `failed` `SourceDocument`, resetting its `import_status` to `pending`, and deduplicating per game on `Game.external_game_key` within that same `SourceDocument`
  - Notes:
    - v1 intentionally creates `PositionOccurrence` rows for mainline positions only during PGN ingestion

- **Book/document ingestion**
  - Input:
    - `.pdf` files
    - extracted text/chunk metadata from a parser pipeline
  - Output:
    - `SourceDocument`
    - `BookChunk`
  - Guarantees:
    - preserve citation context such as chapter labels, section labels, and page ranges when available
    - ingestion does not require perfect diagram or line extraction
    - skip duplicate re-import by default when a `SourceDocument.content_hash` already exists in `complete` state, unless a future explicit overwrite mode is requested
    - support retry after failed chunk extraction by reusing the existing `failed` `SourceDocument`, resetting its `import_status` to `pending`, and re-running the chunk batch as a whole

- **Puzzle ingestion**
  - Input:
    - bulk puzzle datasets such as CSV/JSON
    - manual puzzle entry
  - Output:
    - `SourceDocument` when the puzzle came from a file-backed import
    - `Puzzle`
    - root `PositionOccurrence`
  - Guarantees:
    - preserve the puzzle FEN and canonical solution line
    - support both bulk-imported and manually authored puzzles
    - do not require puzzle solution moves to be normalized into `MoveRecord` rows in v1
    - skip duplicate file-backed re-import by default when a `SourceDocument.content_hash` already exists in `complete` state, unless a future explicit overwrite mode is requested
    - treat each file-backed dataset row as an independent canonical import unit so valid rows may commit even when sibling rows are malformed
    - reuse the existing `failed` `SourceDocument` on retry, reset `import_status` to `pending`, and skip already committed puzzle rows using `external_puzzle_id` when present or (`source_provider`, `fen`) otherwise
    - mark a file-backed dataset import `complete` when at least one valid row commits and no import-level failure aborts the workflow; malformed rows are surfaced as row-level failures without reopening committed puzzle rows
    - mark a file-backed dataset import `failed` when no valid rows commit or when an import-level failure prevents the dataset workflow from finishing
    - prevent duplicate manual puzzle entry in v1 by treating (`source_provider`, `fen`, `external_puzzle_id`) as the deduplication key, where `external_puzzle_id` may be null and `fen` + `source_provider` remains the fallback uniqueness basis

- **Manual linking**
  - Input:
    - user-selected corpus targets and source chunks
  - Output:
    - `BookAnchor`
    - optionally `StudyLine`
    - optionally `Annotation`
  - Guarantees:
    - linking is allowed after ingestion
    - linking appends `BookAnchor` rows without mutating the source `BookChunk`
    - a source chunk may link to many targets
    - one workflow submission may persist multiple `BookAnchor` rows for the same source chunk
    - one workflow submission is atomic for `BookAnchor` persistence; if any selected target fails validation or insert, no partial anchor set is committed for that submission
    - `BookAnchor.target_type` is constrained to the approved v1 enum set even if some target entity tables are implemented in later issues
    - Issue `#8` only requires target-resolution checks for canonical target tables that already exist in the repo at implementation time; later entity issues extend the workflow to their own approved target types without changing the `BookAnchor` contract

- **LLM annotation attach**
  - Input:
    - target corpus object
    - external LLM output
  - Output:
    - `Annotation`
  - Guarantees:
    - LLM output does not mutate imported source records directly
    - structured payloads may be preserved alongside human-readable text
    - freeform commentary persists as append-only `Annotation` rows rather than updates to prior annotations or imported move/source text
    - retry-safe deduplication is caller-managed in v1 when the same LLM response may be submitted more than once
    - model/session metadata may be stored in `payload_json`, but no first-class LLM provenance columns are required in v1

- **LLM analysis session**
  - Input:
    - root `PositionOccurrence`
    - external LLM output describing one or more explored lines
  - Output:
    - `AnalysisSession`
    - `AnalysisNode`
    - optionally `Annotation`
  - Guarantees:
    - LLM-authored line exploration is stored as a first-class analysis tree when it represents structured candidate-line output
    - the workflow derives `AnalysisSession.session_kind` from the chosen root `PositionOccurrence.source_kind` as `game -> postgame`, `puzzle -> puzzle-review`, `book -> book-review`, and `manual -> manual`
    - `opening-study` remains a valid general `AnalysisSession.session_kind` enum in v1, but it is not used by this LLM structured-import workflow
    - freeform commentary may still be attached only as `Annotation` when no line structure is present
    - when structured line output also includes accompanying prose, that prose is attached as append-only `Annotation` on the created `AnalysisSession` rather than on the root `PositionOccurrence`
    - LLM-generated sessions do not mutate imported source records directly
    - one review-capture submission is atomic for `AnalysisSession` plus `AnalysisNode` persistence; if any node fails validation, the workflow must not leave behind a partial tree
    - zero-node review captures are invalid in v1; the workflow must reject them before persisting any `AnalysisSession` or `AnalysisNode` rows
    - every persisted node reuses the chosen root `PositionOccurrence` through `root_position_occurrence_id` so later lookup back to the studied position does not require joining through the session row first
    - v1 review capture accepts caller-supplied `node_index` values so deterministic node identity can survive retry or replay of the same logical tree
    - v1 structured multi-line imports use shared-prefix tree semantics, so lines that share an opening sequence reuse the same ancestor `AnalysisNode` rows and branch only at the point of divergence

## Logic Flow

1. Register the raw artifact as a `SourceDocument` when the source is file-backed.
   - manual-entry puzzle creation skips `SourceDocument` when there is no file-backed source artifact
2. Route the source by type:
   - PGN -> game and move normalization path
   - PDF/text extract -> book chunk ingestion path
   - puzzle dataset or manual puzzle entry -> puzzle ingestion path
3. Persist canonical relational records into `sqlite`.
   - puzzle datasets validate and commit each row independently so malformed rows fail at row scope while valid rows still create `Puzzle` plus root `PositionOccurrence` records
   - canonical `sqlite` persistence, including the `SourceDocument.import_status` transition to `complete`, is the v1 completion boundary for file-backed ingestion
4. Allow later enrichment:
   - manual links
     - validate the selected `BookChunk`
     - validate each selected target against the currently implemented target tables for this workflow
     - insert one `BookAnchor` row per validated target in the same user action
   - analysis sessions
     - validate the chosen root `PositionOccurrence`
     - validate that at least one candidate-line node is present
     - insert the `AnalysisSession`
     - insert the `AnalysisNode` tree in one transaction with caller-supplied per-session `node_index`, per-sibling `branch_order`, and depth-consistent `ply_depth`
     - enforce sibling `branch_order` uniqueness at the canonical-store layer, including the root-level sibling set where `parent_node_id` is null
   - study line creation
   - annotations
5. Defer any future analytical projections until the canonical store is stable and query needs justify them.
   - a missing projection layer does not reopen or invalidate a completed canonical ingestion

## Edge Case Probe
- PGN import fails midway through a file -> keep the `SourceDocument`, set `SourceDocument.import_status = 'failed'`, and avoid partial duplicate `Game` rows on retry.
- PDF text extraction is noisy -> ingest chunks anyway with citation metadata when available; do not block ingestion on cleanup perfection.
- A user links one chunk to several already-supported targets -> persist one `BookAnchor` row per target without editing the `BookChunk`.
- One target in a multi-link submission is invalid -> reject the submission and roll back the full `BookAnchor` set for that user action.
- A user attempts to link a chunk to a target type outside the approved v1 boundary -> reject the link instead of widening `BookAnchor.target_type`.
- A puzzle import arrives from a bulk dataset and some rows are malformed -> ingest valid puzzles, surface row-level failures at the workflow layer later, and avoid duplicate puzzle creation on retry.
- A puzzle dataset retry sees rows that already committed before the earlier failure -> reuse the same failed `SourceDocument` and skip the already committed puzzles using `external_puzzle_id` when present or (`source_provider`, `fen`) otherwise.
- A puzzle dataset contains no valid rows -> keep the `SourceDocument` for provenance and mark the import `failed`.
- A manual puzzle is entered twice -> treat matching `external_puzzle_id` when present, otherwise matching `fen` + `source_provider`, as a duplicate and do not create a second canonical puzzle row.
- A downstream tool wants extra local tables -> allow tool-local caches, but they must not redefine canonical entities owned by `chess-core`.
- One candidate line node references a parent from another session -> reject the workflow instead of allowing cross-session tree edges.
- A review capture arrives without any nodes -> reject the submission instead of creating an empty `AnalysisSession`.
- One candidate line tree write fails after the session row is inserted -> roll back the full analysis-session capture so the canonical store does not retain an orphaned or partial review tree.
- A user never installs `duckdb` -> all v1 ingestion and study flows still work.
- A future analytics projection disagrees with `sqlite` -> `sqlite` remains the source of truth and the projection must be rebuilt.
