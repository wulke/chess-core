# chess-core

`chess-core` is a SQLite schema and trigger library that defines the shared data model for downstream chess applications. It ships schema and documentation only: there is no compiled code and no runtime binary.

## Integrate

```sh
git submodule add https://github.com/wulke/chess-core.git vendor/chess-core
sqlite3 mydb.sqlite < vendor/chess-core/schema/sqlite/schema.sql
```

Replace the repository URL if you vendor `chess-core` from a fork, and pin the submodule to the tag or commit your application depends on.

## Start Reading

Use [AGENTS.md](AGENTS.md) for repo navigation and workflow expectations.

Read these two consumer contracts before writing SQL against this schema:
- [`docs/llds/canonical-corpus-model.md`](docs/llds/canonical-corpus-model.md): authoritative entity model
- [`docs/llds/storage-and-ingestion.md`](docs/llds/storage-and-ingestion.md): authoritative transaction contracts and trigger behavior
