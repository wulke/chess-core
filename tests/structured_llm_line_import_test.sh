#!/bin/zsh
set -euo pipefail

# @spec CRP-023
# @spec CRP-024
# @spec CRP-025a
# @spec CRP-026
# @spec CRP-026a
# @spec CRP-027
# @spec CRP-028
# @spec CRP-029
# @spec CRP-029a
# @spec CRP-030
# @spec CRP-038
# @spec CRP-039
# @spec CRP-040
# @spec CRP-041
# @spec CRP-051
# @spec ING-022
# @spec ING-022a
# @spec ING-022b
# @spec ING-022c
# @spec ING-022d

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-structured-llm-line-import.XXXXXX.sqlite)"
trap 'rm -f "$DB_PATH"' EXIT

sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

sqlite3 -cmd 'PRAGMA foreign_keys = ON' "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'pgn',
  'structured-llm-lines.pgn',
  '/tmp/structured-llm-lines.pgn',
  'sha256:structured-llm-lines-pgn-001',
  'complete',
  '2026-06-30 09:00:00'
), (
  'pdf',
  'structured-llm-lines.pdf',
  '/tmp/structured-llm-lines.pdf',
  'sha256:structured-llm-lines-pdf-001',
  'complete',
  '2026-06-30 09:05:00'
);

INSERT INTO games (
  source_document_id,
  external_game_key,
  white_player,
  black_player,
  event,
  site,
  result,
  pgn_text
) VALUES (
  1,
  'structured-llm-game-001',
  'White',
  'Black',
  'Structured LLM Review',
  'Local',
  '1-0',
  '[Event "Structured LLM Review"] 1. e4 e5 1-0'
);

INSERT INTO book_chunks (
  source_document_id,
  chapter_label,
  section_label,
  page_start,
  page_end,
  chunk_index,
  text
) VALUES (
  2,
  'Chapter 3',
  'Candidate Lines',
  42,
  43,
  0,
  'Imported source prose that must remain unchanged by structured LLM imports.'
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
  'structured-llm-puzzle-001',
  'manual',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);

INSERT INTO position_occurrences (
  id,
  fen,
  side_to_move,
  position_hash,
  source_kind,
  source_ref_id,
  game_id,
  move_number,
  ply_index,
  is_mainline
) VALUES (
  10,
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'w',
  'structured-llm-game-root-hash',
  'game',
  1,
  1,
  1,
  0,
  1
), (
  11,
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'structured-llm-puzzle-root-hash',
  'puzzle',
  1,
  NULL,
  NULL,
  NULL,
  0
), (
  12,
  '8/8/8/8/8/8/8/K5k1 b - - 0 1',
  'b',
  'structured-llm-book-root-hash',
  'book',
  1,
  NULL,
  NULL,
  NULL,
  0
), (
  13,
  '8/8/8/8/8/8/8/2K4k w - - 0 1',
  'w',
  'structured-llm-manual-root-hash',
  'manual',
  NULL,
  NULL,
  NULL,
  NULL,
  0
);
SQL

sqlite3 -cmd 'PRAGMA foreign_keys = ON' "$DB_PATH" <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  10,
  'llm',
  'postgame',
  'Structured LLM game review',
  '2026-06-30 09:10:00'
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
  10,
  0,
  1,
  0,
  'e4',
  'e2e4',
  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
  'structured-llm-node-hash-001',
  'Shared prefix root move.'
), (
  1,
  1,
  10,
  1,
  2,
  0,
  '...e5',
  'e7e5',
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
  'structured-llm-node-hash-002',
  'Mainline continuation.'
), (
  1,
  1,
  10,
  2,
  2,
  1,
  '...c5',
  'c7c5',
  'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
  'structured-llm-node-hash-003',
  'Branch at the first divergent reply.'
);

INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body,
  payload_json
) VALUES (
  'analysis_session',
  1,
  'llm',
  'commentary',
  'Black has two reasonable replies after the shared e4 prefix.',
  '{"source":"structured-llm-import","format":"candidate-lines"}'
), (
  'analysis_node',
  2,
  'llm',
  'evaluation',
  'The ...e5 branch is more classical and balanced.',
  '{"cp":18}'
);

COMMIT;
SQL

session_annotation_row="$(sqlite3 -tabs "$DB_PATH" "SELECT target_type, target_id, author_type, annotation_kind, body FROM annotations WHERE id = 1;")"
[[ "$session_annotation_row" == $'analysis_session\t1\tllm\tcommentary\tBlack has two reasonable replies after the shared e4 prefix.' ]] \
  || { echo "analysis_session annotation assertion failed: got [$session_annotation_row]" >&2; exit 1; }

node_annotation_row="$(sqlite3 -tabs "$DB_PATH" "SELECT target_type, target_id, author_type, annotation_kind, body FROM annotations WHERE id = 2;")"
[[ "$node_annotation_row" == $'analysis_node\t2\tllm\tevaluation\tThe ...e5 branch is more classical and balanced.' ]] \
  || { echo "analysis_node annotation assertion failed: got [$node_annotation_row]" >&2; exit 1; }

shared_prefix_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT node_index, COALESCE(parent_node_id, 'NULL'), ply_depth, branch_order, move_uci FROM analysis_nodes WHERE analysis_session_id = 1 ORDER BY node_index;")"
[[ "$shared_prefix_rows" == $'0\tNULL\t1\t0\te2e4\n1\t1\t2\t0\te7e5\n2\t1\t2\t1\tc7c5' ]] \
  || { echo "shared prefix rows assertion failed: got [$shared_prefix_rows]" >&2; exit 1; }

game_pgn_text="$(sqlite3 "$DB_PATH" "SELECT pgn_text FROM games WHERE id = 1;")"
[[ "$game_pgn_text" == '[Event "Structured LLM Review"] 1. e4 e5 1-0' ]] \
  || { echo "game mutation assertion failed: got [$game_pgn_text]" >&2; exit 1; }

book_chunk_text="$(sqlite3 "$DB_PATH" "SELECT text FROM book_chunks WHERE id = 1;")"
[[ "$book_chunk_text" == 'Imported source prose that must remain unchanged by structured LLM imports.' ]] \
  || { echo "book chunk mutation assertion failed: got [$book_chunk_text]" >&2; exit 1; }

sqlite3 -cmd 'PRAGMA foreign_keys = ON' "$DB_PATH" <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  11,
  'llm',
  'puzzle-review',
  'Structured LLM puzzle review',
  '2026-06-30 09:20:00'
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
  NULL,
  11,
  0,
  1,
  0,
  'Ka2',
  'a1a2',
  '8/8/8/8/8/8/K7/7k b - - 1 1',
  'structured-llm-puzzle-node-hash-001'
);

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  12,
  'llm',
  'book-review',
  'Structured LLM book review',
  '2026-06-30 09:30:00'
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
  3,
  NULL,
  12,
  0,
  1,
  0,
  'Kh2',
  'h1h2',
  '8/8/8/8/8/8/7k/K7 w - - 1 2',
  'structured-llm-book-node-hash-001'
);

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  13,
  'llm',
  'manual',
  'Structured LLM manual review',
  '2026-06-30 09:40:00'
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
  4,
  NULL,
  13,
  0,
  1,
  0,
  'Kc2',
  'c1c2',
  '8/8/8/8/8/8/2K5/7k b - - 1 1',
  'structured-llm-manual-node-hash-001'
);

COMMIT;
SQL

session_kind_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT id, root_position_occurrence_id, session_kind FROM analysis_sessions ORDER BY id;")"
[[ "$session_kind_rows" == $'1\t10\tpostgame\n2\t11\tpuzzle-review\n3\t12\tbook-review\n4\t13\tmanual' ]] \
  || { echo "session kind rows assertion failed: got [$session_kind_rows]" >&2; exit 1; }

if sqlite3 -cmd 'PRAGMA foreign_keys = ON' "$DB_PATH" 2>/dev/null <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  11,
  'llm',
  'postgame',
  'Mismatched puzzle session kind',
  '2026-06-30 09:50:00'
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
  5,
  NULL,
  11,
  0,
  1,
  0,
  'Ka2',
  'a1a2',
  '8/8/8/8/8/8/K7/7k b - - 1 1',
  'structured-llm-invalid-session-kind'
);

COMMIT;
SQL
then
  echo "expected mismatched session_kind submission to fail" >&2
  exit 1
fi

session_count_after_kind_failure="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM analysis_sessions;")"
[[ "$session_count_after_kind_failure" == "4" ]] \
  || { echo "session count after session_kind failure assertion failed: got [$session_count_after_kind_failure]" >&2; exit 1; }

if sqlite3 -cmd 'PRAGMA foreign_keys = ON' "$DB_PATH" 2>/dev/null <<'SQL'
BEGIN;

INSERT INTO analysis_sessions (
  root_position_occurrence_id,
  author_type,
  session_kind,
  title,
  started_at
) VALUES (
  10,
  'llm',
  'postgame',
  'Zero-node structured import',
  '2026-06-30 10:00:00'
);

COMMIT;
SQL
then
  echo "expected zero-node structured import to fail" >&2
  exit 1
fi

session_count_after_zero_node_failure="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM analysis_sessions;")"
[[ "$session_count_after_zero_node_failure" == "4" ]] \
  || { echo "session count after zero-node failure assertion failed: got [$session_count_after_zero_node_failure]" >&2; exit 1; }
