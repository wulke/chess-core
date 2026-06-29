#!/bin/zsh
set -euo pipefail

# @spec PZL-002
# @spec PZL-003
# @spec PZL-005
# @spec PZL-006
# @spec PZL-009
# @spec PZL-010
# @spec CRP-042
# @spec CRP-045
# @spec CRP-046
# @spec ING-003

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-manual-puzzle.XXXXXX.sqlite)"
trap 'rm -f "$DB_PATH"' EXIT

sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  NULL,
  NULL,
  'manual',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);
SQL

manual_puzzle_row="$(sqlite3 -tabs "$DB_PATH" "SELECT source_document_id IS NULL, source_provider, fen, side_to_move, solution_line_uci FROM puzzles;")"
[[ "$manual_puzzle_row" == $'1\tmanual\t8/8/8/8/8/8/8/K6k w - - 0 1\tw\ta1a2 h1h2' ]]

root_occurrence_row="$(sqlite3 -tabs "$DB_PATH" "SELECT source_kind, source_ref_id, fen, side_to_move, game_id IS NULL, move_number IS NULL, ply_index IS NULL, is_mainline FROM position_occurrences;")"
[[ "$root_occurrence_row" == $'puzzle\t1\t8/8/8/8/8/8/8/K6k w - - 0 1\tw\t1\t1\t1\t1' ]]

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
PRAGMA foreign_keys = ON;

INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  999,
  NULL,
  'import',
  '8/8/8/8/8/8/8/K2k4 w - - 0 1',
  'w',
  'a1a2 d1d2'
);
SQL
then
  echo "expected puzzle insert with unknown source_document_id to fail" >&2
  exit 1
fi

sqlite3 "$DB_PATH" <<'SQL'
PRAGMA foreign_keys = ON;

INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'puzzle-dataset',
  'batch.csv',
  '/tmp/batch.csv',
  'sha256:puzzle123',
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
  'file-backed-001',
  'import',
  '8/8/8/8/8/8/8/K1k5 b - - 0 1',
  'b',
  'c1c2 a1a2'
);
SQL

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
PRAGMA foreign_keys = ON;
DELETE FROM source_documents WHERE id = 1;
SQL
then
  echo "expected source document delete with attached puzzles to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  NULL,
  'dup-001',
  'manual',
  '8/8/8/8/8/8/8/K5k1 b - - 0 1',
  'b',
  'h1h2 a1a2'
);

INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  NULL,
  'dup-001',
  'manual',
  '8/8/8/8/8/8/8/K4k2 b - - 0 1',
  'b',
  'h1g1 a1a2'
);
SQL
then
  echo "expected duplicate external_puzzle_id insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  NULL,
  NULL,
  'manual',
  '8/8/8/8/8/8/8/K3k3 w - - 0 1',
  'w',
  'a1a2 e1e2'
);

INSERT INTO puzzles (
  source_document_id,
  external_puzzle_id,
  source_provider,
  fen,
  side_to_move,
  solution_line_uci
) VALUES (
  NULL,
  NULL,
  'manual',
  '8/8/8/8/8/8/8/K3k3 w - - 0 1',
  'w',
  'a1a2 e1d1'
);
SQL
then
  echo "expected duplicate source_provider + fen insert to fail" >&2
  exit 1
fi

position_occurrence_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM position_occurrences;")"
[[ "$position_occurrence_count" == "4" ]]
