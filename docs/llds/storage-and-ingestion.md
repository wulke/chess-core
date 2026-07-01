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

## Trigger Contract Reference

This table summarizes the trigger-level write contracts that downstream
developers and agents must honor without reading SQLite DDL directly. Error
strings are listed exactly as raised by `schema/sqlite/schema.sql`. For
update-only or delete-only triggers, the "Insert preconditions" column states
what must already be true when the row is first created so later lifecycle
operations remain safe.

| Trigger name | Invariant enforced | Error raised | Insert preconditions |
|---|---|---|---|
| `book_anchors_validate_insert_target` | Every `BookAnchor` insert must point at an existing `BookChunk`, must target an existing supported entity, and must not use a target type that is still out of scope for v1 linking. | `book anchor source chunk does not exist`; `book anchor target does not exist`; `book anchor target type is not yet linkable in v1 schema` | `book_chunk_id` must reference an existing `BookChunk`; `target_type` must be one of the currently linkable v1 target types; `target_id` must exist in the table implied by `target_type`. |
| `puzzles_skip_duplicate_file_backed_import_retry` | A retry of a file-backed puzzle dataset import must silently skip puzzle rows that already committed under the dataset's deduplication rules instead of inserting duplicates. | `IGNORE` | The caller may safely insert only when the row is not a duplicate of an existing puzzle by `external_puzzle_id` when present or by (`source_provider`, `fen`) when `external_puzzle_id` is null; if `source_document_id` is set for this retry path, it must reference an existing `SourceDocument` with `source_type = 'puzzle-dataset'`, and `source_provider` must be `import`. |
| `puzzles_create_root_position_occurrence` | Every inserted `Puzzle` must immediately gain a root `PositionOccurrence` anchored to that puzzle. | None | A safe puzzle insert must provide values that also allow the derived root `PositionOccurrence` to satisfy the `puzzle` source-kind contract: the new `Puzzle` row must exist, `fen` must be valid, and the generated `source_ref_id = puzzle.id` path must remain valid. |
| `position_occurrences_validate_insert_context` | Every inserted `PositionOccurrence` must use a source context that matches its `source_kind`, required foreign keys, and allowed nullability rules. | `game position occurrence requires source_ref_id`; `game position occurrence requires game_id`; `game position occurrence source_ref_id must match game_id`; `game position occurrence references unknown game`; `book position occurrence requires source_ref_id`; `book position occurrence must not set game_id`; `book position occurrence references unknown book chunk`; `puzzle position occurrence requires source_ref_id`; `puzzle position occurrence must not set game_id`; `puzzle position occurrence references unknown puzzle`; `manual position occurrence must not set source_ref_id`; `manual position occurrence must not set game_id` | For `game`, set `source_ref_id = game_id` and ensure that `Game` exists; for `book`, set `source_ref_id` to an existing `BookChunk` and leave `game_id` null; for `puzzle`, set `source_ref_id` to an existing `Puzzle` and leave `game_id` null; for `manual`, leave both `source_ref_id` and `game_id` null. |
| `position_occurrences_validate_update_context` | A `PositionOccurrence` update must continue to satisfy the same source-context rules as insert. | `game position occurrence requires source_ref_id`; `game position occurrence requires game_id`; `game position occurrence source_ref_id must match game_id`; `game position occurrence references unknown game`; `book position occurrence requires source_ref_id`; `book position occurrence must not set game_id`; `book position occurrence references unknown book chunk`; `puzzle position occurrence requires source_ref_id`; `puzzle position occurrence must not set game_id`; `puzzle position occurrence references unknown puzzle`; `manual position occurrence must not set source_ref_id`; `manual position occurrence must not set game_id` | Safe creation of rows that may later be updated still requires the same source-kind setup as the insert trigger: valid referenced parent row for `game`, `book`, or `puzzle`, or both references null for `manual`. |
| `move_records_validate_insert_links` | Every inserted `MoveRecord` must belong to an existing game, connect two distinct game positions from that same game, link consecutive plies, and use a side value consistent with ply parity. | `move record references unknown game`; `move record from_position_occurrence_id must reference a game position in the same game`; `move record to_position_occurrence_id must reference a game position in the same game`; `move record must change position`; `move record must link consecutive game positions for its ply_index`; `move record side must match ply parity` | `game_id` must reference an existing `Game`; `from_position_occurrence_id` and `to_position_occurrence_id` must reference distinct `PositionOccurrence` rows with `source_kind = 'game'` in that same game; those positions must sit at `ply_index - 1` and `ply_index`; `side` must be `w` on odd plies and `b` on even plies. |
| `move_records_validate_update_links` | A `MoveRecord` update must continue to satisfy the same game-linking, consecutive-ply, distinct-position, and side-parity rules as insert. | `move record references unknown game`; `move record from_position_occurrence_id must reference a game position in the same game`; `move record to_position_occurrence_id must reference a game position in the same game`; `move record must change position`; `move record must link consecutive game positions for its ply_index`; `move record side must match ply parity` | Safe creation of rows that may later be updated still requires the same insert-time setup: an existing `Game`, two distinct same-game `PositionOccurrence` rows for adjacent plies, and correct `side` parity. |
| `analysis_sessions_validate_insert_kind` | Every inserted LLM-authored `AnalysisSession` must use a `session_kind` that matches the `source_kind` of its root `PositionOccurrence`. | `llm analysis session_kind must match the root position source_kind` | If `author_type = 'llm'`, `root_position_occurrence_id` must reference an existing `PositionOccurrence` whose `source_kind` maps to the inserted `session_kind` as `game -> postgame`, `puzzle -> puzzle-review`, `book -> book-review`, or `manual -> manual`; non-LLM sessions do not use this trigger check. |
| `analysis_sessions_validate_update_kind` | An `AnalysisSession` update must preserve the LLM `session_kind` to root-position mapping and must not change `nonempty_guard_session_id` to a value other than the session's own id. | `llm analysis session_kind must match the root position source_kind`; `analysis session nonempty guard must match the session id` | Safe creation of rows that may later be updated requires the same valid LLM root-position mapping as insert, and the session must rely on the schema-managed nonempty-guard lifecycle rather than caller-managed writes to `nonempty_guard_session_id`. |
| `analysis_sessions_set_nonempty_guard_after_insert` | Every inserted `AnalysisSession` must be normalized so `nonempty_guard_session_id` points back to that session's own id. | None | A safe session insert must allow the schema to perform the immediate self-referential guard fixup after insert; callers must not depend on keeping `nonempty_guard_session_id` at its default placeholder value. |
| `analysis_nodes_validate_insert_tree` | Every inserted `AnalysisNode` must belong to an existing session, reuse that session's root position, keep root branches at depth 1, and keep child nodes inside the same session with exactly one extra ply of depth. | `analysis node references unknown session`; `analysis node references unknown root position occurrence`; `analysis node root_position_occurrence_id must match the owning session root`; `root analysis branches must use ply_depth = 1`; `analysis node parent must belong to the same session`; `analysis node child ply_depth must be exactly one greater than its parent`; `analysis node root_position_occurrence_id must match its parent branch root` | `analysis_session_id` must reference an existing `AnalysisSession`; `root_position_occurrence_id` must reference an existing `PositionOccurrence` and equal the owning session's root; if `parent_node_id` is null then `ply_depth` must be `1`; otherwise `parent_node_id` must reference an existing node in the same session with `ply_depth = new.ply_depth - 1` and the same root position. |
| `analysis_nodes_validate_update_tree` | An `AnalysisNode` update must continue to satisfy the same session ownership, root-position consistency, root-depth, and parent-child depth rules as insert. | `analysis node references unknown session`; `analysis node references unknown root position occurrence`; `analysis node root_position_occurrence_id must match the owning session root`; `root analysis branches must use ply_depth = 1`; `analysis node parent must belong to the same session`; `analysis node child ply_depth must be exactly one greater than its parent`; `analysis node root_position_occurrence_id must match its parent branch root` | Safe creation of rows that may later be updated still requires the same insert-time tree shape: existing session, matching root position, root nodes at depth 1, and child nodes attached to a same-session parent exactly one ply shallower. |
| `analysis_nodes_mark_session_nonempty_after_insert` | The first inserted `AnalysisNode` for a session must mark that session as nonempty by creating its guard row if one does not already exist. | None | A safe node insert must use an `analysis_session_id` that references an existing `AnalysisSession`; callers must allow the schema to manage `analysis_session_nonempty_guards` automatically instead of writing guard rows directly. |
| `analysis_nodes_refresh_session_nonempty_after_update` | Updating an `AnalysisNode` must keep the destination session marked nonempty and must remove the old session's guard row only if that old session no longer has any nodes. | None | Safe creation of rows that may later move between sessions requires valid `AnalysisSession` ownership and assumes callers will let the schema maintain `analysis_session_nonempty_guards` as node membership changes. |
| `analysis_nodes_refresh_session_nonempty_after_delete` | Deleting an `AnalysisNode` must clear the owning session's guard row only when that session no longer contains any nodes. | None | Safe node creation assumes later deletions will happen through normal schema writes so `analysis_session_nonempty_guards` stays in sync automatically; callers must not treat guard rows as user-managed state. |
| `annotations_validate_insert_target` | Every inserted `Annotation` must target an existing annotatable v1 entity and must not use a target type that is still out of scope for v1 annotation. | `annotation target does not exist`; `annotation target type is not yet annotatable in v1 schema` | `target_type` must be one of the currently annotatable v1 target types; `target_id` must reference an existing row in the table implied by `target_type`; `study_line` must not be used until that target type becomes annotatable. |
| `annotations_prevent_update` | `Annotation` rows are append-only and may not be edited in place. | `annotations are append-only` | A safe insert assumes the caller will never rely on mutating the row later; corrections or new commentary must be written as a new `Annotation`. |
| `annotations_prevent_delete` | `Annotation` rows are append-only and may not be deleted after creation. | `annotations are append-only` | A safe insert assumes the caller will never rely on deleting the row later; superseding commentary must be modeled by adding another `Annotation`, not removing the original. |
