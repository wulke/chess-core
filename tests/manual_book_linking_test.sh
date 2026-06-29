#!/bin/zsh
set -euo pipefail

# @spec ING-020
# @spec ING-024
# @spec ING-025
# @spec ING-026
# @spec CRP-035
# @spec CRP-036
# @spec CRP-037
# @spec CRP-050

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-manual-book-linking.XXXXXX.sqlite)"
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
  'pdf',
  'manual-linking-book.pdf',
  '/tmp/manual-linking-book.pdf',
  'sha256:manual-book-linking',
  'pending'
);

UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 18:00:00'
WHERE id = 1;

INSERT INTO book_chunks (
  source_document_id,
  chapter_label,
  section_label,
  page_start,
  page_end,
  chunk_index,
  text
) VALUES (
  1,
  'Chapter 3',
  'Critical Squares',
  42,
  43,
  0,
  'Imported source text that should remain unchanged after linking.'
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
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'book-position-hash-001',
  'book',
  1,
  NULL,
  NULL,
  NULL,
  0
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
  'book-link-target-001',
  'manual',
  '8/8/8/8/8/8/8/K6k w - - 0 1',
  'w',
  'a1a2 h1h2'
);
SQL

sqlite3 "$DB_PATH" <<'SQL'
BEGIN;

INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'position_occurrence',
  1,
  'example'
);

INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'puzzle',
  1,
  'reference'
);

COMMIT;
SQL

anchor_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT book_chunk_id, target_type, target_id, anchor_kind FROM book_anchors ORDER BY id;")"
[[ "$anchor_rows" == $'1\tposition_occurrence\t1\texample\n1\tpuzzle\t1\treference' ]] \
  || { echo "book anchor rows assertion failed: got [$anchor_rows]" >&2; exit 1; }

chunk_row="$(sqlite3 -tabs "$DB_PATH" "SELECT chapter_label, section_label, page_start, page_end, text FROM book_chunks WHERE id = 1;")"
[[ "$chunk_row" == $'Chapter 3\tCritical Squares\t42\t43\tImported source text that should remain unchanged after linking.' ]] \
  || { echo "book chunk mutation assertion failed: got [$chunk_row]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'move_record',
  1,
  'example'
);
SQL
then
  echo "expected unsupported target_type insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'position_occurrence',
  1,
  'summary'
);
SQL
then
  echo "expected unsupported anchor_kind insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  999,
  'position_occurrence',
  1,
  'discussion'
);
SQL
then
  echo "expected missing book_chunk insert to fail" >&2
  exit 1
fi

before_atomic_failure_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM book_anchors;")"
[[ "$before_atomic_failure_count" == "2" ]] \
  || { echo "unexpected pre-atomic-failure anchor count: got [$before_atomic_failure_count]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
BEGIN;

INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'position_occurrence',
  1,
  'diagram'
);

INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'puzzle',
  999,
  'exercise'
);

COMMIT;
SQL
then
  echo "expected atomic multi-link insert with invalid target to fail" >&2
  exit 1
fi

after_atomic_failure_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM book_anchors;")"
[[ "$after_atomic_failure_count" == "2" ]] \
  || { echo "atomic rollback anchor count assertion failed: got [$after_atomic_failure_count]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO book_anchors (
  book_chunk_id,
  target_type,
  target_id,
  anchor_kind
) VALUES (
  1,
  'study_line',
  1,
  'discussion'
);
SQL
then
  echo "expected unresolved approved target_type insert to fail before owning table exists" >&2
  exit 1
fi
