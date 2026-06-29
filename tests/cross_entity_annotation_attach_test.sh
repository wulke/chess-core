#!/bin/zsh
set -euo pipefail

# @spec CRP-038
# @spec CRP-039
# @spec CRP-040
# @spec CRP-041
# @spec CRP-051
# @spec ING-021
# @spec ING-027

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-annotation-attach.XXXXXX.sqlite)"
trap 'rm -f "$DB_PATH"' EXIT

sqlite3 "$DB_PATH" < "$SCHEMA_PATH"

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'pgn',
  'annotations.pgn',
  '/tmp/annotations.pgn',
  'sha256:annotations-pgn-001',
  'complete',
  '2026-06-29 20:00:00'
);

INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status,
  imported_at
) VALUES (
  'pdf',
  'annotations.pdf',
  '/tmp/annotations.pdf',
  'sha256:annotations-pdf-001',
  'complete',
  '2026-06-29 20:05:00'
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
  'annotation-game-001',
  'White',
  'Black',
  'Annotation Match',
  'Local',
  '1-0',
  '[Event "Annotation Match"] 1. e4 e5 1-0'
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
  'Chapter 1',
  'Foundations',
  10,
  10,
  0,
  'Imported prose that must remain unchanged when annotations are attached.'
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
  'annotation-puzzle-001',
  'manual',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);

INSERT INTO position_occurrences (
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
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'w',
  'annotation-startpos-hash',
  'game',
  1,
  1,
  1,
  0,
  1
), (
  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
  'b',
  'annotation-after-e4-hash',
  'game',
  1,
  1,
  1,
  1,
  1
), (
  '8/8/8/8/8/8/8/K5k1 b - - 0 1',
  'b',
  'annotation-book-position-hash',
  'book',
  1,
  NULL,
  NULL,
  NULL,
  0
);

INSERT INTO move_records (
  game_id,
  from_position_occurrence_id,
  to_position_occurrence_id,
  ply_index,
  move_number,
  side,
  san,
  uci,
  piece,
  from_square,
  to_square,
  is_capture,
  is_check,
  is_checkmate,
  comment_text
) VALUES (
  1,
  2,
  3,
  1,
  1,
  'w',
  'e4',
  'e2e4',
  'P',
  'e2',
  'e4',
  0,
  0,
  0,
  'Imported PGN comment'
);
SQL

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body,
  payload_json
) VALUES (
  'position_occurrence',
  1,
  'user',
  'note',
  'Remember the central tension.',
  '{"priority":"high"}'
), (
  'game',
  1,
  'engine',
  'evaluation',
  'Engine prefers White by a small margin.',
  '{"cp":34,"depth":18}'
), (
  'book_chunk',
  1,
  'llm',
  'summary',
  'This passage frames the basic strategic idea.',
  '{"model":"gpt-5.4","prompt_id":"attach-001"}'
), (
  'puzzle',
  1,
  'import',
  'label',
  'king opposition',
  NULL
), (
  'move_record',
  1,
  'llm',
  'commentary',
  'This move claims space without changing the imported PGN note.',
  '{"style":"freeform"}'
);
SQL

annotation_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT target_type, target_id, author_type, annotation_kind, body, COALESCE(payload_json, 'NULL') FROM annotations ORDER BY id;")"
[[ "$annotation_rows" == $'position_occurrence\t1\tuser\tnote\tRemember the central tension.\t{"priority":"high"}\ngame\t1\tengine\tevaluation\tEngine prefers White by a small margin.\t{"cp":34,"depth":18}\nbook_chunk\t1\tllm\tsummary\tThis passage frames the basic strategic idea.\t{"model":"gpt-5.4","prompt_id":"attach-001"}\npuzzle\t1\timport\tlabel\tking opposition\tNULL\nmove_record\t1\tllm\tcommentary\tThis move claims space without changing the imported PGN note.\t{"style":"freeform"}' ]] \
  || { echo "annotation rows assertion failed: got [$annotation_rows]" >&2; exit 1; }

move_comment="$(sqlite3 "$DB_PATH" "SELECT comment_text FROM move_records WHERE id = 1;")"
[[ "$move_comment" == 'Imported PGN comment' ]] \
  || { echo "move comment mutation assertion failed: got [$move_comment]" >&2; exit 1; }

book_chunk_text="$(sqlite3 "$DB_PATH" "SELECT text FROM book_chunks WHERE id = 1;")"
[[ "$book_chunk_text" == 'Imported prose that must remain unchanged when annotations are attached.' ]] \
  || { echo "book chunk mutation assertion failed: got [$book_chunk_text]" >&2; exit 1; }

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body
) VALUES (
  'position_occurrence',
  1,
  'user',
  'note',
  'Follow-up note that supersedes nothing and coexists append-only.'
);
SQL

annotation_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM annotations WHERE target_type = 'position_occurrence' AND target_id = 1;")"
[[ "$annotation_count" == "2" ]] \
  || { echo "append-only count assertion failed: got [$annotation_count]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
UPDATE annotations
SET body = 'mutated'
WHERE id = 1;
SQL
then
  echo "expected annotation update to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
DELETE FROM annotations
WHERE id = 1;
SQL
then
  echo "expected annotation delete to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body
) VALUES (
  'position_occurrence',
  1,
  'coach',
  'note',
  'Unsupported author'
);
SQL
then
  echo "expected unsupported author_type insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body
) VALUES (
  'position_occurrence',
  1,
  'user',
  'theme',
  'Unsupported kind'
);
SQL
then
  echo "expected unsupported annotation_kind insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body
) VALUES (
  'study_line',
  1,
  'user',
  'note',
  'Should be rejected until study lines are implemented.'
);
SQL
then
  echo "expected unimplemented target_type insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO annotations (
  target_type,
  target_id,
  author_type,
  annotation_kind,
  body
) VALUES (
  'game',
  999,
  'user',
  'note',
  'No such game.'
);
SQL
then
  echo "expected missing target_id insert to fail" >&2
  exit 1
fi
