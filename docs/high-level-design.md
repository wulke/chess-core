# HLD: chess-core Foundation

## Goal
Establish `chess-core` as the source-of-truth repository for the local-first chess study corpus. This repository defines the shared data model, storage boundaries, and ingestion contracts that other chess tools in the ecosystem will depend on.

## Strategy
- **Options**:
  - Option A: Continue evolving each existing chess repository independently and reconcile models later.
  - Option B: Create a single mega-application that absorbs all current and future chess tooling.
  - Option C: Create a neutral foundation repository that owns the canonical corpus model and integration contracts while letting individual tools remain separate.
- **Decision**: Option C — create `chess-core` as a dedicated foundation repo. This keeps architectural intent independent from any one existing tool, reduces semantic drift across repositories, and preserves freedom to refactor or replace individual apps without losing the long-term study model.

### Annotation Attachment Strategy
- **Options**:
  - Option A: Store notes and commentary directly on each owning entity row such as `Game`, `PositionOccurrence`, `BookChunk`, or `MoveRecord`.
  - Option B: Create separate per-entity annotation tables such as `game_annotations`, `position_annotations`, and `book_chunk_annotations`.
  - Option C: Store cross-entity commentary in one polymorphic `Annotation` record set keyed by target type and target id, while preserving imported source rows as immutable provenance records.
- **Decision**: Option C — use a single polymorphic annotation model for cross-entity commentary and derived meaning. This keeps notes, labels, evaluations, summaries, and freeform LLM output under one contract across supported corpus objects, avoids copy-pasting similar annotation schemas per entity, and preserves the boundary that imported source records are enriched through append-only sidecar records rather than edited in place.

## Architecture

### Components
- **Canonical Corpus Model**: Defines the durable entities for chess study, centered on `PositionOccurrence` and related records such as `Game`, `AnalysisSession`, `AnalysisNode`, `StudyLine`, `BookChunk`, `BookAnchor`, `Annotation`, and `SourceDocument`.
- **Storage Conventions**: Defines how raw files and canonical relational records are separated across plain files and a `sqlite` schema owned by `chess-core`.
- **Ingestion Contracts**: Defines the import boundaries for PGN game data, PDF-derived study material, manual linking workflows, and LLM-generated annotations.
- **Ecosystem Contracts**: Holds the design and schema contracts that downstream repositories use when they integrate with or publish into the shared study corpus.

### Core Entities Glossary
- **PositionOccurrence**: A context-bound encounter with a chess position. The FEN identifies the board state, but the occurrence record captures where the position came from, why it matters in that context, and what notes, analysis, and study artifacts attach to it. The same FEN may appear in many distinct `PositionOccurrence`s across games, books, puzzles, and study sessions.
- **StudyLine**: A reusable chess knowledge artifact representing a line, variation, plan, refutation, or pattern worth preserving beyond one analysis pass. A `StudyLine` may cite one or more `BookChunk`s, games, or annotations as provenance, but it is not owned by any single source artifact.
- **BookChunk**: A cited chunk of imported source text from a book or study document. `BookChunk`s preserve textual provenance first and may later be linked to positions, games, or `StudyLine`s through enrichment workflows.
- **BookAnchor**: A link record that associates a `BookChunk` with one or more chess corpus objects such as a `PositionOccurrence`, `StudyLine`, `Game`, or analysis subtree. `BookAnchor` allows imported text to be connected to chess meaning progressively without changing the source chunk itself.
- **AnalysisSession**: One bounded thinking or review episode rooted at a `PositionOccurrence`. Each session contains a tree of `AnalysisNode`s representing explored candidate moves and branches from that starting point.
- **AnalysisNode**: One step in an explored variation tree within an `AnalysisSession`. Nodes are connected by parent-child relationships to represent branching analysis rather than a flat event log.
- **Annotation**: An attached interpretation, note, label, or evaluation on a corpus object, authored by a user, LLM, engine, or import workflow. `Annotation` remains broad and polymorphic so commentary and derived meaning can be attached consistently across positions, lines, games, chunks, and analysis artifacts.

### Flow
```
Raw chess artifacts (PGN, PDF, notes)
  → chess-core ingestion contracts
  → canonical corpus records in sqlite
  → downstream tools for search, review, annotation, and training
```

### Key Trade-offs
- **Position-centered model vs game-centered model**: The system is centered on `PositionOccurrence` because the long-term study workflow is primarily about revisiting and comparing positions across games, books, notes, and analysis sources. `Game` remains important, but as provenance and grouping rather than the primary unit of study.
- **Docs-and-schema first vs implementation first**: `chess-core` starts as a design and schema repo, not an application. This slows down early coding but prevents premature implementation from hard-coding the wrong boundaries across multiple repositories.
- **sqlite ownership vs per-tool schemas**: `chess-core` owns the canonical `sqlite` schema directly. Downstream tools may maintain local caches or convenience tables, but the shared corpus model must not be redefined independently by each repository.
- **sqlite first vs early multi-database complexity**: `sqlite` is the only required database in v1 and will store canonical relational records, including normalized move records needed for position and piece-move study queries. `duckdb` is explicitly deferred from v1 and may be added later as a derived analytical projection layer if real analytical workload pressure justifies it.
- **Loose ecosystem integration vs repo unification**: The ecosystem will integrate through shared contracts instead of forcing all tools into one codebase. This preserves independence for tools like game search, book ingestion, LLM annotation, live note capture, and engine experimentation, while still allowing them to contribute to the same study corpus.
- **Progressive enrichment vs perfect ingestion**: Imported book content and external artifacts will be usable before they are perfectly linked to positions or lines. This keeps ingestion practical and allows higher-quality anchors and derived study lines to be added incrementally over time.
- **Minimum ingestion promise vs perfect extraction**: v1 ingestion guarantees support for PGN files, PDF source documents with extracted text chunks and citations, canonical relational records for games/moves/positions/source documents/book chunks, and manual linking to positions or `StudyLine`s. Automatic diagram extraction, perfect OCR cleanup, and full semantic linking are deferred.
