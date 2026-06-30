## Linked-Intent Development

This repository uses LID. Follow [`LID.md`](LID.md) as the source of truth for the workflow, approval gates, traceability, and bug-fix protocol.

### Downstream Consumer Entry Points

If you are building a new app or agent against this schema, read these before writing any SQL. These LLDs are the authoritative downstream consumer contract for `chess-core`, not just internal design records.

- Entity model: `docs/llds/canonical-corpus-model.md`
- Transaction contracts and trigger behavior: `docs/llds/storage-and-ingestion.md`

### Navigation

| What you need | Where to look |
|---|---|
| High-level design | `docs/high-level-design.md` |
| Low-level designs | `docs/llds/` |
| EARS specs | `docs/specs/` |
