#!/bin/zsh
set -euo pipefail

# @spec CRP-023
# @spec CRP-024
# @spec CRP-025
# @spec CRP-026
# @spec CRP-026a
# @spec CRP-026b
# @spec CRP-027
# @spec CRP-028
# @spec CRP-029
# @spec CRP-029a
# @spec CRP-030
# @spec PZL-007

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-analysis-session-tree.XXXXXX.sqlite)"
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
  'analysis-puzzle-001',
  'manual',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);
SQL

sqlite3 "$DB_PATH" <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at,
  ended_at
) VALUES (
  1,
  'user',
  'puzzle-review',
  'Candidate lines from the puzzle root',
  '2026-06-29 21:00:00',
  NULL
);

INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after,
  user_note
) VALUES (
  1,
  NULL,
  1,
  0,
  1,
  0,
  'Ka2',
  'a1a2',
  '8/8/8/8/8/8/K7/7k b - - 1 1',
  'analysis-node-hash-001',
  'Main candidate line from the puzzle root.'
), (
  1,
  NULL,
  1,
  1,
  1,
  1,
  'Kb1',
  'a1b1',
  '8/8/8/8/8/8/8/1K5k b - - 1 1',
  'analysis-node-hash-002',
  'Alternative first-ply branch.'
), (
  1,
  1,
  1,
  2,
  2,
  0,
  'Kh2',
  'h1h2',
  '8/8/8/8/8/8/K6k/8 w - - 2 2',
  'analysis-node-hash-003',
  'Follow-up reply under the main branch.'
);

COMMIT;
SQL

session_row="$(sqlite3 -tabs "$DB_PATH" "SELECT root_position_occurrence_id, author_type, session_kind, title, started_at, ended_at IS NULL FROM analysis_sessions WHERE id = 1;")"
[[ "$session_row" == $'1\tuser\tpuzzle-review\tCandidate lines from the puzzle root\t2026-06-29 21:00:00\t1' ]] \
  || { echo "analysis session row assertion failed: got [$session_row]" >&2; exit 1; }

node_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT analysis_session_id, COALESCE(parent_node_id, 'NULL'), root_position_occurrence_id, node_index, ply_depth, branch_order, move_san, move_uci, fen_after, position_hash_after FROM analysis_nodes ORDER BY node_index;")"
[[ "$node_rows" == $'1\tNULL\t1\t0\t1\t0\tKa2\ta1a2\t8/8/8/8/8/8/K7/7k b - - 1 1\tanalysis-node-hash-001\n1\tNULL\t1\t1\t1\t1\tKb1\ta1b1\t8/8/8/8/8/8/8/1K5k b - - 1 1\tanalysis-node-hash-002\n1\t1\t1\t2\t2\t0\tKh2\th1h2\t8/8/8/8/8/8/K6k/8 w - - 2 2\tanalysis-node-hash-003' ]] \
  || { echo "analysis node rows assertion failed: got [$node_rows]" >&2; exit 1; }

puzzle_provenance_row="$(sqlite3 -tabs "$DB_PATH" "SELECT s.root_position_occurrence_id, r.source_kind, r.source_ref_id FROM analysis_sessions AS s JOIN position_occurrences AS r ON r.id = s.root_position_occurrence_id WHERE s.id = 1;")"
[[ "$puzzle_provenance_row" == $'1\tpuzzle\t1' ]] \
  || { echo "puzzle provenance assertion failed: got [$puzzle_provenance_row]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  1,
  'llm',
  'puzzle-review',
  'Invalid cross-session parent attempt',
  '2026-06-29 21:05:00'
);

INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after
) VALUES (
  2,
  1,
  1,
  0,
  2,
  0,
  'Kh2',
  'h1h2',
  '8/8/8/8/8/8/8/K6k w - - 2 2',
  'analysis-node-invalid-cross-session'
);

COMMIT;
SQL
then
  echo "expected cross-session parent submission to fail" >&2
  exit 1
fi

session_count_after_cross_session_failure="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM analysis_sessions;")"
[[ "$session_count_after_cross_session_failure" == "1" ]] \
  || { echo "analysis session rollback assertion failed: got [$session_count_after_cross_session_failure]" >&2; exit 1; }

node_count_after_cross_session_failure="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM analysis_nodes;")"
[[ "$node_count_after_cross_session_failure" == "3" ]] \
  || { echo "analysis node rollback assertion failed: got [$node_count_after_cross_session_failure]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after
) VALUES (
  1,
  NULL,
  1,
  3,
  1,
  0,
  'Kc1',
  'b1c1',
  '8/8/8/8/8/8/8/2K4k b - - 1 1',
  'analysis-node-duplicate-root-branch'
);
SQL
then
  echo "expected duplicate root sibling branch_order to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after
) VALUES (
  1,
  NULL,
  1,
  1,
  1,
  2,
  'Kc2',
  'a2c2',
  '8/8/8/8/8/8/2K5/7k b - - 1 1',
  'analysis-node-duplicate-index'
);
SQL
then
  echo "expected duplicate node_index to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after
) VALUES (
  1,
  1,
  1,
  3,
  4,
  1,
  'Kg2',
  'h2g2',
  '8/8/8/8/8/8/K5k1/8 w - - 3 2',
  'analysis-node-invalid-depth'
);
SQL
then
  echo "expected invalid child ply_depth to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO analysis_nodes (
  analysis_session_id,
  parent_node_id,
  root_position_occurrence_id,
  node_index,
  ply_depth,
  branch_order,
  move_san,
  move_uci,
  fen_after,
  position_hash_after
) VALUES (
  1,
  NULL,
  999,
  3,
  1,
  2,
  'Kc1',
  'b1c1',
  '8/8/8/8/8/8/8/2K4k b - - 1 1',
  'analysis-node-invalid-root'
);
SQL
then
  echo "expected mismatched root_position_occurrence_id to fail" >&2
  exit 1
fi
