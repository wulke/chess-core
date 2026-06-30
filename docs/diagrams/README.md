# V1 Diagram Set

These diagrams are explanatory companion docs for the v1 `chess-core` design.
The normative source of truth remains [LID.md](/Users/trevorwulke/workspace/chess-core/LID.md),
[docs/high-level-design.md](/Users/trevorwulke/workspace/chess-core/docs/high-level-design.md),
[docs/llds/canonical-corpus-model.md](/Users/trevorwulke/workspace/chess-core/docs/llds/canonical-corpus-model.md),
[docs/llds/storage-and-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/llds/storage-and-ingestion.md),
and the EARS specs under [docs/specs](/Users/trevorwulke/workspace/chess-core/docs/specs).

## Scope
- v1 only
- flows explicitly backed by current HLD, LLD, and EARS docs
- lifecycle-first organization with `PositionOccurrence` as the semantic center

## Notation
- `Mermaid flowchart` for system structure and lifecycle overviews
- `Mermaid sequenceDiagram` for ordered workflow and access-pattern detail
- `Mermaid erDiagram` for concrete schema entity and foreign-key reference views

## Maintenance
When HLD, LLD, or EARS changes alter a depicted flow, actor, boundary, or entity
relationship, update the affected diagram docs in the same change. Diagrams are
companions, not normative sources.

## Diagram Index
1. [v1-corpus-overview.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-corpus-overview.md)
   - lifecycle-first overview of actors, canonical entity clusters, and read/write access patterns
   - backed by HLD component boundaries and corpus model relationships
2. [v1-ingestion-overview.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-ingestion-overview.md)
   - shared staged-commit lifecycle across file-backed and manual v1 ingestion paths
   - backed by storage/ingestion LLD and `ING-001` through `ING-023`
3. [v1-pgn-ingestion.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-pgn-ingestion.md)
   - PGN normalization, failure handling, retry, and per-game deduplication
   - backed by storage/ingestion LLD, corpus model LLD, and `ING-008` through `ING-014`
4. [v1-book-ingestion-and-linking.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-book-ingestion-and-linking.md)
   - document chunk ingestion plus post-ingestion manual linking
   - backed by storage/ingestion LLD, corpus model LLD, `ING-015` through `ING-020`, and `CRP-034` through `CRP-037`
5. [v1-puzzle-and-analysis-flows.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-puzzle-and-analysis-flows.md)
   - puzzle import/manual entry, root puzzle context, LLM annotation attach, and LLM analysis session flows
   - backed by storage/ingestion LLD, corpus model LLD, `ING-021` through `ING-023`, and `PZL-001` through `PZL-017`
6. [v1-schema-fk-erd.md](/Users/trevorwulke/workspace/chess-core/docs/diagrams/v1-schema-fk-erd.md)
   - concrete v1 schema entity-relationship view for the 10 implemented corpus tables and their declared foreign-key links
   - backed by corpus model LLD, corpus model specs, and the implemented `sqlite` schema
