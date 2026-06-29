#!/bin/zsh
set -euo pipefail

# @spec ING-015
# @spec ING-016
# @spec ING-017
# @spec ING-018
# @spec ING-019

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-book-chunks.XXXXXX.sqlite)"
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
  'book.pdf',
  '/tmp/book.pdf',
  'sha256:book-001',
  'pending'
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
  1,
  'Chapter 1',
  NULL,
  NULL,
  NULL,
  0,
  'First chunk without full citation metadata.'
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
  1,
  'Chapter 2',
  'Pawn Structures',
  14,
  15,
  1,
  'Second chunk with full citation metadata.'
);

UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 14:00:00'
WHERE id = 1;
SQL

book_chunks_row="$(sqlite3 -tabs "$DB_PATH" "SELECT chunk_index, chapter_label, section_label IS NULL, page_start IS NULL, page_end IS NULL, text FROM book_chunks WHERE source_document_id = 1 ORDER BY chunk_index;")"
[[ "$book_chunks_row" == $'0\tChapter 1\t1\t1\t1\tFirst chunk without full citation metadata.\n1\tChapter 2\t0\t0\t0\tSecond chunk with full citation metadata.' ]] \
  || { echo "book chunk rows assertion failed: got [$book_chunks_row]" >&2; exit 1; }

citation_row="$(sqlite3 -tabs "$DB_PATH" "SELECT chapter_label, section_label, page_start, page_end FROM book_chunks WHERE source_document_id = 1 AND chunk_index = 1;")"
[[ "$citation_row" == $'Chapter 2\tPawn Structures\t14\t15' ]] \
  || { echo "citation assertion failed: got [$citation_row]" >&2; exit 1; }

complete_document_row="$(sqlite3 -tabs "$DB_PATH" "SELECT import_status, imported_at FROM source_documents WHERE id = 1;")"
[[ "$complete_document_row" == $'complete\t2026-06-29 14:00:00' ]] \
  || { echo "complete source document assertion failed: got [$complete_document_row]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
INSERT INTO source_documents (
  source_type,
  title,
  path,
  content_hash,
  import_status
) VALUES (
  'pdf',
  'book-duplicate.pdf',
  '/tmp/book-duplicate.pdf',
  'sha256:book-001',
  'pending'
);
SQL
then
  echo "expected duplicate completed book import to fail" >&2
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
  'text-extract',
  'retry-book.txt',
  '/tmp/retry-book.txt',
  'sha256:retry-book-001',
  'failed'
);

UPDATE source_documents
SET import_status = 'pending'
WHERE id = 2;
SQL

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
BEGIN;

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
  'Retry Chapter',
  'Bad Batch',
  20,
  21,
  0,
  'Chunk that should roll back with the failed batch.'
), (
  2,
  NULL,
  NULL,
  22,
  21,
  1,
  'Invalid reversed page range.'
);

COMMIT;
SQL
then
  echo "expected invalid chunk batch to fail" >&2
  exit 1
fi

sqlite3 "$DB_PATH" <<'SQL'
UPDATE source_documents
SET import_status = 'failed'
WHERE id = 2;
SQL

failed_retry_row="$(sqlite3 -tabs "$DB_PATH" "SELECT import_status, imported_at IS NULL FROM source_documents WHERE id = 2;")"
[[ "$failed_retry_row" == $'failed\t1' ]] \
  || { echo "failed retry document assertion failed: got [$failed_retry_row]" >&2; exit 1; }

rolled_back_chunk_count="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM book_chunks WHERE source_document_id = 2;")"
[[ "$rolled_back_chunk_count" == "0" ]] \
  || { echo "rolled back chunk count assertion failed: got [$rolled_back_chunk_count]" >&2; exit 1; }

sqlite3 "$DB_PATH" <<'SQL'
UPDATE source_documents
SET import_status = 'pending'
WHERE id = 2;

BEGIN;

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
  'Retry Chapter',
  NULL,
  20,
  20,
  0,
  'Retried chunk batch row one.'
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
  NULL,
  'Recovered Section',
  NULL,
  NULL,
  1,
  'Retried chunk batch row two.'
);

COMMIT;

UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 14:30:00'
WHERE id = 2;
SQL

retry_document_row="$(sqlite3 -tabs "$DB_PATH" "SELECT id, import_status, imported_at FROM source_documents WHERE id = 2;")"
[[ "$retry_document_row" == $'2\tcomplete\t2026-06-29 14:30:00' ]] \
  || { echo "retry source document assertion failed: got [$retry_document_row]" >&2; exit 1; }

retry_chunk_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT chunk_index, chapter_label IS NULL, section_label IS NULL, page_start IS NULL, page_end IS NULL, text FROM book_chunks WHERE source_document_id = 2 ORDER BY chunk_index;")"
[[ "$retry_chunk_rows" == $'0\t0\t1\t0\t0\tRetried chunk batch row one.\n1\t1\t0\t1\t1\tRetried chunk batch row two.' ]] \
  || { echo "retry chunk rows assertion failed: got [$retry_chunk_rows]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'Retry Chapter',
  'Duplicate Index',
  23,
  23,
  1,
  'Duplicate chunk index should fail.'
);
SQL
then
  echo "expected duplicate chunk index within one source document to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  '',
  'Blank Chapter',
  24,
  24,
  2,
  'Blank chapter labels should fail.'
);
SQL
then
  echo "expected blank chapter label insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'Retry Chapter',
  '',
  24,
  24,
  2,
  'Blank section labels should fail.'
);
SQL
then
  echo "expected blank section label insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'Retry Chapter',
  'Blank Text',
  24,
  24,
  2,
  '   '
);
SQL
then
  echo "expected blank chunk text insert to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'Retry Chapter',
  'Zero Page',
  0,
  1,
  2,
  'Zero page start should fail.'
);
SQL
then
  echo "expected zero page_start insert to fail" >&2
  exit 1
fi
