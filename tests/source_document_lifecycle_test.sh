#!/bin/zsh
set -euo pipefail

# @spec ING-001
# @spec ING-002
# @spec ING-004
# @spec ING-005
# @spec ING-006
# @spec ING-007
# @spec CRP-047
# @spec CRP-048
# @spec CRP-049

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-source-document.XXXXXX.sqlite)"
trap 'rm -f "$DB_PATH"' EXIT

sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

sqlite3 "$DB_PATH" <<'SQL'
BEGIN;

INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'pgn',
  'example.pgn',
  '/tmp/example.pgn',
  'sha256:abc123',
  'pending'
);

COMMIT;
SQL

registered_row="$(sqlite3 -tabs "$DB_PATH" "SELECT id, source_type, title, path, content_hash, import_status, imported_at IS NULL FROM source_documents;")"
[[ "$registered_row" == $'1\tpgn\texample.pgn\t/tmp/example.pgn\tsha256:abc123\tpending\t1' ]]

sqlite3 "$DB_PATH" <<'SQL'
BEGIN;

CREATE TABLE ingest_log (
  id INTEGER PRIMARY KEY,
  source_document_id INTEGER NOT NULL REFERENCES source_documents(id),
  payload TEXT NOT NULL
);

INSERT INTO ingest_log (source_document_id, payload)
VALUES (1, 'domain record created after source registration');

COMMIT;
SQL

ingest_log_row="$(sqlite3 -tabs "$DB_PATH" "SELECT source_document_id, payload FROM ingest_log;")"
[[ "$ingest_log_row" == $'1\tdomain record created after source registration' ]]

sqlite3 "$DB_PATH" <<'SQL'
UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 12:00:00'
WHERE id = 1;
SQL

complete_row="$(sqlite3 -tabs "$DB_PATH" "SELECT import_status, imported_at FROM source_documents WHERE id = 1;")"
[[ "$complete_row" == $'complete\t2026-06-29 12:00:00' ]]

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'pdf',
  'broken.pdf',
  '/tmp/broken.pdf',
  'sha256:def456',
  'pending'
);

UPDATE source_documents
SET import_status = 'failed'
WHERE id = 2;
SQL

failed_row="$(sqlite3 -tabs "$DB_PATH" "SELECT import_status, imported_at IS NULL FROM source_documents WHERE id = 2;")"
[[ "$failed_row" == $'failed\t1' ]]

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'text-extract',
  'invalid-pending.txt',
  '/tmp/invalid-pending.txt',
  'sha256:jkl012',
  'pending',
  '2026-06-29 12:15:00'
);
SQL
then
  echo "expected pending source document with imported_at to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'text-extract',
  'invalid-failed.txt',
  '/tmp/invalid-failed.txt',
  'sha256:mno345',
  'failed',
  '2026-06-29 12:30:00'
);
SQL
then
  echo "expected failed source document with imported_at to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'text-extract',
  'invalid.txt',
  '/tmp/invalid.txt',
  'sha256:ghi789',
  'complete',
  NULL
);
SQL
then
  echo "expected complete source document without imported_at to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'pgn',
  'duplicate-complete.pgn',
  '/tmp/duplicate-complete.pgn',
  'sha256:abc123',
  'pending'
);
SQL
then
  echo "expected duplicate active content_hash insert to fail" >&2
  exit 1
fi

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'pdf',
  'retryable-failure.pdf',
  '/tmp/retryable-failure.pdf',
  'sha256:def456',
  'failed'
);
SQL

failed_hash_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM source_documents WHERE content_hash = 'sha256:def456';")"
[[ "$failed_hash_count" == "2" ]]
