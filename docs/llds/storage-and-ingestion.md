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
    - a source chunk may link to many targets

- **LLM annotation attach**
  - Input:
    - target corpus object
    - external LLM output
  - Output:
    - `Annotation`
  - Guarantees:
    - LLM output does not mutate imported source records directly
    - structured payloads may be preserved alongside human-readable text

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
    - freeform commentary may still be attached only as `Annotation` when no line structure is present
    - LLM-generated sessions do not mutate imported source records directly

## Logic Flow

1. Register the raw artifact as a `SourceDocument` when the source is file-backed.
   - manual-entry puzzle creation skips `SourceDocument` when there is no file-backed source artifact
2. Route the source by type:
   - PGN -> game and move normalization path
   - PDF/text extract -> book chunk ingestion path
   - puzzle dataset or manual puzzle entry -> puzzle ingestion path
3. Persist canonical relational records into `sqlite`.
4. Allow later enrichment:
   - manual links
   - analysis sessions
   - study line creation
   - annotations
5. Defer any future analytical projections until the canonical store is stable and query needs justify them.

## Edge Case Probe
- PGN import fails midway through a file -> keep the `SourceDocument`, set `SourceDocument.import_status = 'failed'`, and avoid partial duplicate `Game` rows on retry.
- PDF text extraction is noisy -> ingest chunks anyway with citation metadata when available; do not block ingestion on cleanup perfection.
- A puzzle import arrives from a bulk dataset and some rows are malformed -> ingest valid puzzles, surface row-level failures at the workflow layer later, and avoid duplicate puzzle creation on retry.
- A manual puzzle is entered twice -> treat matching `external_puzzle_id` when present, otherwise matching `fen` + `source_provider`, as a duplicate and do not create a second canonical puzzle row.
- A downstream tool wants extra local tables -> allow tool-local caches, but they must not redefine canonical entities owned by `chess-core`.
- A user never installs `duckdb` -> all v1 ingestion and study flows still work.
- A future analytics projection disagrees with `sqlite` -> `sqlite` remains the source of truth and the projection must be rebuilt.
