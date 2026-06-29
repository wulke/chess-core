#!/bin/zsh
set -euo pipefail

# @spec PZL-001
# @spec PZL-008
# @spec PZL-011
# @spec PZL-012
# @spec PZL-013
# @spec PZL-014
# @spec PZL-015
# @spec PZL-016
# @spec PZL-017

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-file-backed-puzzles.XXXXXX.sqlite)"
trap 'rm -f "$DB_PATH"' EXIT

sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'puzzle-dataset',
  'dataset.csv',
  '/tmp/dataset.csv',
  'sha256:dataset-001',
  'pending'
);

INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  1,
  'dataset-row-001',
  'import',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);
SQL

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  1,
  'dataset-row-bad',
  'import',
  '8/8/8/8/8/8/8/K5k1 w - - 0 1',
  'b',
  'a1a2 g1g2'
);
SQL
then
  echo "expected malformed puzzle row insert to fail" >&2
  exit 1
fi

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  1,
  'dataset-row-002',
  'import',
  '8/8/8/8/8/8/8/K5k1 b - - 0 1',
  'b',
  'g1g2 a1a2'
);

UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 13:00:00'
WHERE id = 1;
SQL

dataset_row="$(sqlite3 -tabs "$DB_PATH" "SELECT source_type, import_status, imported_at, content_hash FROM source_documents WHERE id = 1;")"
[[ "$dataset_row" == $'puzzle-dataset\tcomplete\t2026-06-29 13:00:00\tsha256:dataset-001' ]]

puzzle_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM puzzles WHERE source_document_id = 1;")"
[[ "$puzzle_count" == "2" ]]

root_occurrence_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM position_occurrences WHERE source_kind = 'puzzle';")"
[[ "$root_occurrence_count" == "2" ]]

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'puzzle-dataset',
  'dataset-duplicate.csv',
  '/tmp/dataset-duplicate.csv',
  'sha256:dataset-001',
  'pending'
);
SQL
then
  echo "expected duplicate completed content_hash insert to fail" >&2
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
  'puzzle-dataset',
  'retry-dataset.csv',
  '/tmp/retry-dataset.csv',
  'sha256:retry-001',
  'failed'
);

UPDATE source_documents
SET import_status = 'pending'
WHERE id = 2;

INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  2,
  NULL,
  'import',
  '8/8/8/8/8/8/8/K4k2 w - - 0 1',
  'w',
  'a1a2 f1f2'
);

UPDATE source_documents
SET import_status = 'failed'
WHERE id = 2;

UPDATE source_documents
SET import_status = 'pending'
WHERE id = 2;
SQL

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  2,
  NULL,
  'import',
  '8/8/8/8/8/8/8/K4k2 w - - 0 1',
  'w',
  'a1a2 f1f2'
);
SQL

retry_puzzle_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM puzzles WHERE source_document_id = 2;")"
[[ "$retry_puzzle_count" == "1" ]]

retry_root_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM position_occurrences WHERE source_kind = 'puzzle' AND source_ref_id IN (SELECT id FROM puzzles WHERE source_document_id = 2);")"
[[ "$retry_root_count" == "1" ]]

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'puzzle-dataset',
  'empty-dataset.csv',
  '/tmp/empty-dataset.csv',
  'sha256:empty-001',
  'pending'
);

UPDATE source_documents
SET import_status = 'failed'
WHERE id = 3;

INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'puzzle-dataset',
  'crashed-dataset.csv',
  '/tmp/crashed-dataset.csv',
  'sha256:crash-001',
  'pending'
);

UPDATE source_documents
SET import_status = 'failed'
WHERE id = 4;
SQL

failed_statuses="$(sqlite3 -tabs "$DB_PATH" "SELECT id, import_status FROM source_documents WHERE id IN (3, 4) ORDER BY id;")"
[[ "$failed_statuses" == $'3\tfailed\n4\tfailed' ]]
