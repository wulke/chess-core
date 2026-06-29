PRAGMA foreign_keys = ON;

-- Canonical sqlite schema for the currently implemented chess-core corpus surface.

-- @spec ING-001
-- @spec ING-002
-- @spec ING-004
-- @spec ING-005
-- @spec ING-006
-- @spec ING-007
-- @spec CRP-047
-- @spec CRP-048
-- @spec CRP-049
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
  source_document_id INTEGER REFERENCES source_documents(id),
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
