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

-- @spec ING-008
-- @spec CRP-012
-- @spec CRP-014
CREATE TABLE games (
  id INTEGER PRIMARY KEY,
  source_document_id INTEGER NOT NULL REFERENCES source_documents(id) ON DELETE RESTRICT,
  external_game_key TEXT NOT NULL CHECK (trim(external_game_key) <> ''),
  white_player TEXT NOT NULL CHECK (trim(white_player) <> ''),
  black_player TEXT NOT NULL CHECK (trim(black_player) <> ''),
  event TEXT NOT NULL CHECK (trim(event) <> ''),
  site TEXT NOT NULL CHECK (trim(site) <> ''),
  played_at TEXT,
  result TEXT NOT NULL CHECK (trim(result) <> ''),
  termination TEXT,
  eco_code TEXT,
  opening_name TEXT,
  pgn_text TEXT NOT NULL CHECK (trim(pgn_text) <> ''),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (played_at IS NULL OR trim(played_at) <> ''),
  CHECK (termination IS NULL OR trim(termination) <> ''),
  CHECK (eco_code IS NULL OR trim(eco_code) <> ''),
  CHECK (opening_name IS NULL OR trim(opening_name) <> '')
);

CREATE UNIQUE INDEX games_source_document_external_key_unique
ON games (source_document_id, external_game_key);

CREATE INDEX games_source_document_idx
ON games (source_document_id);

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

-- @spec ING-025
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

CREATE INDEX position_occurrences_game_idx
ON position_occurrences (game_id, ply_index);

-- @spec CRP-001
-- @spec CRP-003
-- @spec CRP-004
-- @spec CRP-007
-- @spec CRP-009
-- @spec CRP-010
-- @spec CRP-011
-- SQLite cannot share one trigger body across INSERT and UPDATE events, so any
-- validation change here must be mirrored in position_occurrences_validate_update_context.
CREATE TRIGGER position_occurrences_validate_insert_context
BEFORE INSERT ON position_occurrences
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NEW.source_kind = 'game' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'game position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'game' AND NEW.game_id IS NULL
    THEN RAISE(ABORT, 'game position occurrence requires game_id')
    WHEN NEW.source_kind = 'game' AND NEW.source_ref_id != NEW.game_id
    THEN RAISE(ABORT, 'game position occurrence source_ref_id must match game_id')
    WHEN NEW.source_kind = 'game'
      AND NOT EXISTS (
        SELECT 1
        FROM games
        WHERE id = NEW.game_id
      )
    THEN RAISE(ABORT, 'game position occurrence references unknown game')
    WHEN NEW.source_kind = 'book' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'book position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'book' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'book position occurrence must not set game_id')
    WHEN NEW.source_kind = 'book'
      AND NOT EXISTS (
        SELECT 1
        FROM book_chunks
        WHERE id = NEW.source_ref_id
      )
    THEN RAISE(ABORT, 'book position occurrence references unknown book chunk')
    WHEN NEW.source_kind = 'puzzle' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'puzzle position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'puzzle' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'puzzle position occurrence must not set game_id')
    WHEN NEW.source_kind = 'puzzle'
      AND NOT EXISTS (
        SELECT 1
        FROM puzzles
        WHERE id = NEW.source_ref_id
      )
    THEN RAISE(ABORT, 'puzzle position occurrence references unknown puzzle')
    WHEN NEW.source_kind = 'manual' AND NEW.source_ref_id IS NOT NULL
    THEN RAISE(ABORT, 'manual position occurrence must not set source_ref_id')
    WHEN NEW.source_kind = 'manual' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'manual position occurrence must not set game_id')
  END;
END;

-- @spec CRP-001
-- @spec CRP-003
-- @spec CRP-004
-- @spec CRP-007
-- @spec CRP-009
-- @spec CRP-010
-- @spec CRP-011
-- Keep this logic aligned with position_occurrences_validate_insert_context.
CREATE TRIGGER position_occurrences_validate_update_context
BEFORE UPDATE ON position_occurrences
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NEW.source_kind = 'game' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'game position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'game' AND NEW.game_id IS NULL
    THEN RAISE(ABORT, 'game position occurrence requires game_id')
    WHEN NEW.source_kind = 'game' AND NEW.source_ref_id != NEW.game_id
    THEN RAISE(ABORT, 'game position occurrence source_ref_id must match game_id')
    WHEN NEW.source_kind = 'game'
      AND NOT EXISTS (
        SELECT 1
        FROM games
        WHERE id = NEW.game_id
      )
    THEN RAISE(ABORT, 'game position occurrence references unknown game')
    WHEN NEW.source_kind = 'book' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'book position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'book' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'book position occurrence must not set game_id')
    WHEN NEW.source_kind = 'book'
      AND NOT EXISTS (
        SELECT 1
        FROM book_chunks
        WHERE id = NEW.source_ref_id
      )
    THEN RAISE(ABORT, 'book position occurrence references unknown book chunk')
    WHEN NEW.source_kind = 'puzzle' AND NEW.source_ref_id IS NULL
    THEN RAISE(ABORT, 'puzzle position occurrence requires source_ref_id')
    WHEN NEW.source_kind = 'puzzle' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'puzzle position occurrence must not set game_id')
    WHEN NEW.source_kind = 'puzzle'
      AND NOT EXISTS (
        SELECT 1
        FROM puzzles
        WHERE id = NEW.source_ref_id
      )
    THEN RAISE(ABORT, 'puzzle position occurrence references unknown puzzle')
    WHEN NEW.source_kind = 'manual' AND NEW.source_ref_id IS NOT NULL
    THEN RAISE(ABORT, 'manual position occurrence must not set source_ref_id')
    WHEN NEW.source_kind = 'manual' AND NEW.game_id IS NOT NULL
    THEN RAISE(ABORT, 'manual position occurrence must not set game_id')
  END;
END;

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

-- @spec ING-009
-- @spec CRP-015
-- @spec CRP-016
-- @spec CRP-017
-- @spec CRP-018
-- @spec CRP-019
-- @spec CRP-020
-- @spec CRP-021
-- @spec CRP-022
CREATE TABLE move_records (
  id INTEGER PRIMARY KEY,
  game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE RESTRICT,
  from_position_occurrence_id INTEGER NOT NULL REFERENCES position_occurrences(id) ON DELETE RESTRICT,
  to_position_occurrence_id INTEGER NOT NULL REFERENCES position_occurrences(id) ON DELETE RESTRICT,
  ply_index INTEGER NOT NULL CHECK (ply_index > 0),
  move_number INTEGER NOT NULL CHECK (move_number > 0),
  side TEXT NOT NULL CHECK (side IN ('w', 'b')),
  san TEXT NOT NULL CHECK (trim(san) <> ''),
  uci TEXT NOT NULL CHECK (trim(uci) <> ''),
  piece TEXT NOT NULL CHECK (piece IN ('P', 'N', 'B', 'R', 'Q', 'K')),
  from_square TEXT NOT NULL CHECK (
    length(from_square) = 2
    AND substr(from_square, 1, 1) BETWEEN 'a' AND 'h'
    AND substr(from_square, 2, 1) BETWEEN '1' AND '8'
  ),
  to_square TEXT NOT NULL CHECK (
    length(to_square) = 2
    AND substr(to_square, 1, 1) BETWEEN 'a' AND 'h'
    AND substr(to_square, 2, 1) BETWEEN '1' AND '8'
  ),
  is_capture INTEGER NOT NULL CHECK (is_capture IN (0, 1)),
  is_check INTEGER NOT NULL CHECK (is_check IN (0, 1)),
  is_checkmate INTEGER NOT NULL CHECK (is_checkmate IN (0, 1)),
  promotion_piece TEXT CHECK (promotion_piece IS NULL OR promotion_piece IN ('N', 'B', 'R', 'Q')),
  nag TEXT,
  comment_text TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (length(uci) IN (4, 5)),
  CHECK (substr(uci, 1, 2) = from_square),
  CHECK (substr(uci, 3, 2) = to_square),
  CHECK (
    (length(uci) = 4 AND promotion_piece IS NULL)
    OR (length(uci) = 5 AND promotion_piece IS NOT NULL AND lower(substr(uci, 5, 1)) = lower(promotion_piece))
  ),
  CHECK (nag IS NULL OR trim(nag) <> ''),
  CHECK (comment_text IS NULL OR trim(comment_text) <> '')
);

CREATE UNIQUE INDEX move_records_game_ply_unique
ON move_records (game_id, ply_index);

CREATE INDEX move_records_game_move_number_idx
ON move_records (game_id, move_number, ply_index);

-- @spec CRP-016
-- @spec CRP-017
-- @spec CRP-018
-- @spec CRP-021
-- @spec CRP-022
-- SQLite cannot share one trigger body across INSERT and UPDATE events, so any
-- validation change here must be mirrored in move_records_validate_update_links.
CREATE TRIGGER move_records_validate_insert_links
BEFORE INSERT ON move_records
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM games
      WHERE id = NEW.game_id
    )
    THEN RAISE(ABORT, 'move record references unknown game')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.from_position_occurrence_id
        AND game_id = NEW.game_id
        AND source_kind = 'game'
    )
    THEN RAISE(ABORT, 'move record from_position_occurrence_id must reference a game position in the same game')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.to_position_occurrence_id
        AND game_id = NEW.game_id
        AND source_kind = 'game'
    )
    THEN RAISE(ABORT, 'move record to_position_occurrence_id must reference a game position in the same game')
    WHEN NEW.from_position_occurrence_id = NEW.to_position_occurrence_id
    THEN RAISE(ABORT, 'move record must change position')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences AS from_pos
      JOIN position_occurrences AS to_pos
        ON to_pos.id = NEW.to_position_occurrence_id
      WHERE from_pos.id = NEW.from_position_occurrence_id
        AND from_pos.game_id = NEW.game_id
        AND to_pos.game_id = NEW.game_id
        AND from_pos.ply_index = NEW.ply_index - 1
        AND to_pos.ply_index = NEW.ply_index
    )
    THEN RAISE(ABORT, 'move record must link consecutive game positions for its ply_index')
    WHEN (
      (NEW.side = 'w' AND (NEW.ply_index % 2) != 1)
      OR (NEW.side = 'b' AND (NEW.ply_index % 2) != 0)
    )
    THEN RAISE(ABORT, 'move record side must match ply parity')
  END;
END;

-- @spec CRP-016
-- @spec CRP-017
-- @spec CRP-018
-- @spec CRP-021
-- @spec CRP-022
-- Keep this logic aligned with move_records_validate_insert_links.
CREATE TRIGGER move_records_validate_update_links
BEFORE UPDATE ON move_records
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM games
      WHERE id = NEW.game_id
    )
    THEN RAISE(ABORT, 'move record references unknown game')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.from_position_occurrence_id
        AND game_id = NEW.game_id
        AND source_kind = 'game'
    )
    THEN RAISE(ABORT, 'move record from_position_occurrence_id must reference a game position in the same game')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.to_position_occurrence_id
        AND game_id = NEW.game_id
        AND source_kind = 'game'
    )
    THEN RAISE(ABORT, 'move record to_position_occurrence_id must reference a game position in the same game')
    WHEN NEW.from_position_occurrence_id = NEW.to_position_occurrence_id
    THEN RAISE(ABORT, 'move record must change position')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences AS from_pos
      JOIN position_occurrences AS to_pos
        ON to_pos.id = NEW.to_position_occurrence_id
      WHERE from_pos.id = NEW.from_position_occurrence_id
        AND from_pos.game_id = NEW.game_id
        AND to_pos.game_id = NEW.game_id
        AND from_pos.ply_index = NEW.ply_index - 1
        AND to_pos.ply_index = NEW.ply_index
    )
    THEN RAISE(ABORT, 'move record must link consecutive game positions for its ply_index')
    WHEN (
      (NEW.side = 'w' AND (NEW.ply_index % 2) != 1)
      OR (NEW.side = 'b' AND (NEW.ply_index % 2) != 0)
    )
    THEN RAISE(ABORT, 'move record side must match ply parity')
  END;
END;

-- @spec CRP-023
-- @spec CRP-024
-- @spec CRP-025
-- @spec PZL-007
CREATE TABLE analysis_sessions (
  id INTEGER PRIMARY KEY,
  root_position_occurrence_id INTEGER NOT NULL REFERENCES position_occurrences(id) ON DELETE RESTRICT,
  author_type TEXT NOT NULL CHECK (
    author_type IN ('user', 'llm', 'engine', 'import')
  ),
  session_kind TEXT NOT NULL CHECK (
    session_kind IN ('postgame', 'book-review', 'opening-study', 'puzzle-review', 'manual')
  ),
  title TEXT NOT NULL CHECK (trim(title) <> ''),
  started_at TEXT NOT NULL CHECK (trim(started_at) <> ''),
  ended_at TEXT CHECK (ended_at IS NULL OR trim(ended_at) <> ''),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX analysis_sessions_root_position_idx
ON analysis_sessions (root_position_occurrence_id, session_kind);

-- @spec CRP-026
-- @spec CRP-026a
-- @spec CRP-026b
-- @spec CRP-027
-- @spec CRP-028
-- @spec CRP-029
-- @spec CRP-029a
-- @spec CRP-030
CREATE TABLE analysis_nodes (
  id INTEGER PRIMARY KEY,
  analysis_session_id INTEGER NOT NULL REFERENCES analysis_sessions(id) ON DELETE RESTRICT,
  parent_node_id INTEGER REFERENCES analysis_nodes(id) ON DELETE RESTRICT,
  root_position_occurrence_id INTEGER NOT NULL REFERENCES position_occurrences(id) ON DELETE RESTRICT,
  node_index INTEGER NOT NULL CHECK (node_index >= 0),
  ply_depth INTEGER NOT NULL CHECK (ply_depth > 0),
  branch_order INTEGER NOT NULL CHECK (branch_order >= 0),
  move_san TEXT NOT NULL CHECK (trim(move_san) <> ''),
  move_uci TEXT NOT NULL CHECK (trim(move_uci) <> ''),
  fen_after TEXT NOT NULL CHECK (trim(fen_after) <> ''),
  position_hash_after TEXT NOT NULL CHECK (trim(position_hash_after) <> ''),
  user_note TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (length(move_uci) IN (4, 5)),
  CHECK (user_note IS NULL OR trim(user_note) <> '')
);

CREATE UNIQUE INDEX analysis_nodes_session_node_index_unique
ON analysis_nodes (analysis_session_id, node_index);

CREATE UNIQUE INDEX analysis_nodes_root_sibling_branch_order_unique
ON analysis_nodes (analysis_session_id, branch_order)
WHERE parent_node_id IS NULL;

CREATE UNIQUE INDEX analysis_nodes_child_sibling_branch_order_unique
ON analysis_nodes (analysis_session_id, parent_node_id, branch_order)
WHERE parent_node_id IS NOT NULL;

CREATE INDEX analysis_nodes_session_parent_idx
ON analysis_nodes (analysis_session_id, parent_node_id, node_index);

CREATE INDEX analysis_nodes_root_position_idx
ON analysis_nodes (root_position_occurrence_id, analysis_session_id);

-- @spec CRP-026b
-- @spec CRP-029
-- @spec CRP-029a
-- @spec CRP-030
-- SQLite cannot share one trigger body across INSERT and UPDATE events, so any
-- validation change here must be mirrored in analysis_nodes_validate_update_tree.
CREATE TRIGGER analysis_nodes_validate_insert_tree
BEFORE INSERT ON analysis_nodes
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM analysis_sessions
      WHERE id = NEW.analysis_session_id
    )
    THEN RAISE(ROLLBACK, 'analysis node references unknown session')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.root_position_occurrence_id
    )
    THEN RAISE(ROLLBACK, 'analysis node references unknown root position occurrence')
    WHEN NOT EXISTS (
      SELECT 1
      FROM analysis_sessions
      WHERE id = NEW.analysis_session_id
        AND root_position_occurrence_id = NEW.root_position_occurrence_id
    )
    THEN RAISE(ROLLBACK, 'analysis node root_position_occurrence_id must match the owning session root')
    WHEN NEW.parent_node_id IS NULL
      AND NEW.ply_depth != 1
    THEN RAISE(ROLLBACK, 'root analysis branches must use ply_depth = 1')
    WHEN NEW.parent_node_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND analysis_session_id = NEW.analysis_session_id
      )
    THEN RAISE(ROLLBACK, 'analysis node parent must belong to the same session')
    WHEN NEW.parent_node_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND analysis_session_id = NEW.analysis_session_id
          AND ply_depth = NEW.ply_depth - 1
      )
    THEN RAISE(ROLLBACK, 'analysis node child ply_depth must be exactly one greater than its parent')
    WHEN NEW.parent_node_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND root_position_occurrence_id != NEW.root_position_occurrence_id
      )
    THEN RAISE(ROLLBACK, 'analysis node root_position_occurrence_id must match its parent branch root')
  END;
END;

-- @spec CRP-026b
-- @spec CRP-029
-- @spec CRP-029a
-- @spec CRP-030
-- Keep this logic aligned with analysis_nodes_validate_insert_tree.
CREATE TRIGGER analysis_nodes_validate_update_tree
BEFORE UPDATE ON analysis_nodes
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1
      FROM analysis_sessions
      WHERE id = NEW.analysis_session_id
    )
    THEN RAISE(ROLLBACK, 'analysis node references unknown session')
    WHEN NOT EXISTS (
      SELECT 1
      FROM position_occurrences
      WHERE id = NEW.root_position_occurrence_id
    )
    THEN RAISE(ROLLBACK, 'analysis node references unknown root position occurrence')
    WHEN NOT EXISTS (
      SELECT 1
      FROM analysis_sessions
      WHERE id = NEW.analysis_session_id
        AND root_position_occurrence_id = NEW.root_position_occurrence_id
    )
    THEN RAISE(ROLLBACK, 'analysis node root_position_occurrence_id must match the owning session root')
    WHEN NEW.parent_node_id IS NULL
      AND NEW.ply_depth != 1
    THEN RAISE(ROLLBACK, 'root analysis branches must use ply_depth = 1')
    WHEN NEW.parent_node_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND analysis_session_id = NEW.analysis_session_id
      )
    THEN RAISE(ROLLBACK, 'analysis node parent must belong to the same session')
    WHEN NEW.parent_node_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND analysis_session_id = NEW.analysis_session_id
          AND ply_depth = NEW.ply_depth - 1
      )
    THEN RAISE(ROLLBACK, 'analysis node child ply_depth must be exactly one greater than its parent')
    WHEN NEW.parent_node_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM analysis_nodes
        WHERE id = NEW.parent_node_id
          AND root_position_occurrence_id != NEW.root_position_occurrence_id
      )
    THEN RAISE(ROLLBACK, 'analysis node root_position_occurrence_id must match its parent branch root')
  END;
END;

-- @spec CRP-038
-- @spec CRP-039
-- @spec CRP-040
-- @spec CRP-041
-- @spec CRP-051
-- @spec ING-021
-- @spec ING-027
CREATE TABLE annotations (
  id INTEGER PRIMARY KEY,
  target_type TEXT NOT NULL CHECK (
    target_type IN (
      'position_occurrence',
      'study_line',
      'game',
      'puzzle',
      'book_chunk',
      'analysis_session',
      'analysis_node',
      'move_record'
    )
  ),
  target_id INTEGER NOT NULL CHECK (target_id > 0),
  author_type TEXT NOT NULL CHECK (
    author_type IN ('user', 'llm', 'engine', 'import')
  ),
  annotation_kind TEXT NOT NULL CHECK (
    annotation_kind IN ('note', 'commentary', 'evaluation', 'label', 'summary', 'warning')
  ),
  body TEXT NOT NULL CHECK (trim(body) <> ''),
  payload_json TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX annotations_target_lookup_idx
ON annotations (target_type, target_id);

CREATE INDEX annotations_author_kind_idx
ON annotations (author_type, annotation_kind);

-- @spec CRP-038
-- @spec ING-021
-- @spec ING-027
CREATE TRIGGER annotations_validate_insert_target
BEFORE INSERT ON annotations
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN NEW.target_type = 'position_occurrence'
      AND NOT EXISTS (
        SELECT 1
        FROM position_occurrences
        WHERE id = NEW.target_id
      )
    THEN RAISE(ABORT, 'annotation target does not exist')
    WHEN NEW.target_type = 'game'
      AND NOT EXISTS (
        SELECT 1
        FROM games
        WHERE id = NEW.target_id
      )
    THEN RAISE(ABORT, 'annotation target does not exist')
    WHEN NEW.target_type = 'puzzle'
      AND NOT EXISTS (
        SELECT 1
        FROM puzzles
        WHERE id = NEW.target_id
      )
    THEN RAISE(ABORT, 'annotation target does not exist')
    WHEN NEW.target_type = 'book_chunk'
      AND NOT EXISTS (
        SELECT 1
        FROM book_chunks
        WHERE id = NEW.target_id
      )
    THEN RAISE(ABORT, 'annotation target does not exist')
    WHEN NEW.target_type = 'move_record'
      AND NOT EXISTS (
        SELECT 1
        FROM move_records
        WHERE id = NEW.target_id
      )
    THEN RAISE(ABORT, 'annotation target does not exist')
    WHEN NEW.target_type IN ('study_line', 'analysis_session', 'analysis_node')
    THEN RAISE(ABORT, 'annotation target type is not yet annotatable in v1 schema')
  END;
END;

-- @spec CRP-051
CREATE TRIGGER annotations_prevent_update
BEFORE UPDATE ON annotations
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'annotations are append-only');
END;

-- @spec CRP-051
CREATE TRIGGER annotations_prevent_delete
BEFORE DELETE ON annotations
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'annotations are append-only');
END;
