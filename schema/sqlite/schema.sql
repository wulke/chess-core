PRAGMA foreign_keys = ON;

-- Canonical sqlite schema for the currently implemented chess-core corpus surface.

-- @spec ING-001
-- @spec ING-002
-- @spec ING-004
-- @spec ING-005
-- @spec ING-006
-- @spec ING-007
-- @spec ING-023
-- @spec CRP-047
-- @spec CRP-048
-- @spec CRP-049
-- @spec PZL-015
-- @spec PZL-016
-- @spec PZL-017
CREATE TABLE source_documents (
  id INTEGER PRIMARY KEY,
  source_type TEXT NOT NULL CHECK (source_type IN ('pgn', 'pdf', 'text-extract', 'puzzle-dataset')),
  title TEXT NOT NULL CHECK (trim(title) <> ''),
  path TEXT NOT NULL CHECK (trim(path) <> ''),
  content_hash TEXT NOT NULL CHECK (trim(content_hash) <> ''),
  import_status TEXT NOT NULL CHECK (import_status IN ('pending', 'complete', 'failed')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  imported_at TEXT,
  CHECK (
    (import_status = 'complete' AND imported_at IS NOT NULL)
    OR (import_status IN ('pending', 'failed') AND imported_at IS NULL)
  )
);

CREATE INDEX source_documents_content_hash_idx
ON source_documents (content_hash);

-- @spec PZL-008
CREATE UNIQUE INDEX source_documents_active_content_hash_unique
ON source_documents (content_hash)
WHERE import_status != 'failed';

-- @spec ING-015
-- @spec ING-016
-- @spec ING-017
-- @spec ING-018
-- @spec ING-019
-- @spec CRP-034
CREATE TABLE book_chunks (
  id INTEGER PRIMARY KEY,
  source_document_id INTEGER NOT NULL REFERENCES source_documents(id) ON DELETE RESTRICT,
  chapter_label TEXT,
  section_label TEXT,
  page_start INTEGER,
  page_end INTEGER,
  chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
  text TEXT NOT NULL CHECK (trim(text) <> ''),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (chapter_label IS NULL OR trim(chapter_label) <> ''),
  CHECK (section_label IS NULL OR trim(section_label) <> ''),
  CHECK (page_start IS NULL OR page_start > 0),
  CHECK (page_end IS NULL OR page_end > 0),
  CHECK (
    page_start IS NULL
    OR page_end IS NULL
    OR page_end >= page_start
  )
);

-- @spec CRP-034
CREATE UNIQUE INDEX book_chunks_source_document_chunk_index_unique
ON book_chunks (source_document_id, chunk_index);

CREATE INDEX book_chunks_source_document_idx
ON book_chunks (source_document_id);

-- @spec ING-020
-- @spec ING-024
-- @spec ING-025
-- @spec ING-026
-- @spec CRP-035
-- @spec CRP-036
-- @spec CRP-037
-- @spec CRP-050
CREATE TABLE book_anchors (
  id INTEGER PRIMARY KEY,
  book_chunk_id INTEGER NOT NULL REFERENCES book_chunks(id) ON DELETE RESTRICT,
  target_type TEXT NOT NULL CHECK (
    target_type IN (
      'position_occurrence',
      'study_line',
      'game',
      'puzzle',
      'analysis_session',
      'analysis_node'
    )
  ),
  target_id INTEGER NOT NULL CHECK (target_id > 0),
  anchor_kind TEXT NOT NULL CHECK (
    anchor_kind IN ('example', 'discussion', 'diagram', 'exercise', 'reference')
  ),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX book_anchors_book_chunk_idx
ON book_anchors (book_chunk_id);

CREATE INDEX book_anchors_target_lookup_idx
ON book_anchors (target_type, target_id);

-- @spec ING-026
CREATE TRIGGER book_anchors_validate_insert_target
BEFORE INSERT ON book_anchors
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM book_chunks
      WHERE id = NEW.book_chunk_id
    )
    THEN RAISE(ROLLBACK, 'book anchor source chunk does not exist')
    WHEN NEW.target_type = 'position_occurrence'
      AND NOT EXISTS (
        SELECT 1
        FROM position_occurrences
        WHERE id = NEW.target_id
      )
    THEN RAISE(ROLLBACK, 'book anchor target does not exist')
    WHEN NEW.target_type = 'puzzle'
      AND NOT EXISTS (
        SELECT 1
        FROM puzzles
        WHERE id = NEW.target_id
      )
    THEN RAISE(ROLLBACK, 'book anchor target does not exist')
    WHEN NEW.target_type IN ('study_line', 'game', 'analysis_session', 'analysis_node')
    THEN RAISE(ROLLBACK, 'book anchor target type is not yet linkable in v1 schema')
  END;
END;

-- @spec PZL-001
-- @spec PZL-002
-- @spec PZL-003
-- @spec PZL-004
-- @spec PZL-009
-- @spec PZL-010
-- @spec CRP-042
-- @spec CRP-043
-- @spec CRP-044
-- @spec CRP-045
-- @spec CRP-046
-- @spec ING-003
CREATE TABLE puzzles (
  id INTEGER PRIMARY KEY,
  source_document_id INTEGER REFERENCES source_documents(id) ON DELETE RESTRICT,
  external_puzzle_id TEXT,
  source_provider TEXT NOT NULL CHECK (source_provider IN ('lichess', 'manual', 'import')),
  fen TEXT NOT NULL CHECK (trim(fen) <> ''),
  side_to_move TEXT NOT NULL CHECK (
    side_to_move IN ('w', 'b')
    AND side_to_move = substr(
      fen,
      instr(fen, ' ') + 1,
      instr(substr(fen, instr(fen, ' ') + 1), ' ') - 1
    )
  ),
  solution_line_uci TEXT NOT NULL CHECK (trim(solution_line_uci) <> ''),
  theme_tags_json TEXT,
  difficulty REAL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- @spec CRP-045
CREATE UNIQUE INDEX puzzles_external_puzzle_id_unique
ON puzzles (external_puzzle_id)
WHERE external_puzzle_id IS NOT NULL;

-- @spec PZL-010
-- @spec CRP-046
CREATE UNIQUE INDEX puzzles_source_provider_fen_fallback_unique
ON puzzles (source_provider, fen)
WHERE external_puzzle_id IS NULL;

-- @spec PZL-011
-- @spec PZL-013
-- @spec PZL-014
CREATE TRIGGER puzzles_skip_duplicate_file_backed_import_retry
BEFORE INSERT ON puzzles
FOR EACH ROW
WHEN
  NEW.source_document_id IS NOT NULL
  AND NEW.source_provider = 'import'
  AND EXISTS (
    SELECT 1
    FROM source_documents
    WHERE id = NEW.source_document_id
      AND source_type = 'puzzle-dataset'
  )
  AND EXISTS (
    SELECT 1
    FROM puzzles
    WHERE (
      NEW.external_puzzle_id IS NOT NULL
      AND external_puzzle_id = NEW.external_puzzle_id
    ) OR (
      NEW.external_puzzle_id IS NULL
      AND external_puzzle_id IS NULL
      AND source_provider = NEW.source_provider
      AND fen = NEW.fen
    )
  )
BEGIN
  SELECT RAISE(IGNORE);
END;

-- @spec PZL-005
-- @spec PZL-006
-- @spec CRP-006
-- @spec CRP-008
CREATE TABLE position_occurrences (
  id INTEGER PRIMARY KEY,
  fen TEXT NOT NULL CHECK (trim(fen) <> ''),
  side_to_move TEXT NOT NULL CHECK (
    side_to_move IN ('w', 'b')
    AND side_to_move = substr(
      fen,
      instr(fen, ' ') + 1,
      instr(substr(fen, instr(fen, ' ') + 1), ' ') - 1
    )
  ),
  position_hash TEXT NOT NULL CHECK (trim(position_hash) <> ''),
  source_kind TEXT NOT NULL CHECK (source_kind IN ('game', 'book', 'puzzle', 'manual')),
  source_ref_id INTEGER,
  game_id INTEGER,
  move_number INTEGER,
  ply_index INTEGER,
  is_mainline INTEGER NOT NULL CHECK (is_mainline IN (0, 1)),
  occurred_at TEXT,
  user_note TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX position_occurrences_source_lookup_idx
ON position_occurrences (source_kind, source_ref_id);

-- @spec PZL-005
-- @spec PZL-006
-- @spec CRP-006
-- @spec CRP-008
CREATE TRIGGER puzzles_create_root_position_occurrence
AFTER INSERT ON puzzles
FOR EACH ROW
BEGIN
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
    NEW.fen,
    NEW.side_to_move,
    NEW.fen,
    'puzzle',
    NEW.id,
    NULL,
    NULL,
    NULL,
    1
  );
END;
