#!/bin/zsh
set -euo pipefail

# @spec ING-008
# @spec ING-009
# @spec ING-010
# @spec CRP-001
# @spec CRP-002
# @spec CRP-003
# @spec CRP-004
# @spec CRP-009
# @spec CRP-010
# @spec CRP-011
# @spec CRP-012
# @spec CRP-014
# @spec CRP-015
# @spec CRP-016
# @spec CRP-017
# @spec CRP-018
# @spec CRP-019
# @spec CRP-020
# @spec CRP-021
# @spec CRP-022

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA_PATH="$ROOT_DIR/schema/sqlite/schema.sql"
DB_PATH="$(mktemp /tmp/chess-core-pgn-happy-path.XXXXXX.sqlite)"
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
  'pgn',
  'happy-path.pgn',
  '/tmp/happy-path.pgn',
  'sha256:pgn-happy-path-001',
  'pending'
);

INSERT INTO games (
  source_document_id,
  external_game_key,
  white_player,
  black_player,
  event,
  site,
  played_at,
  result,
  termination,
  eco_code,
  opening_name,
  pgn_text
) VALUES (
  1,
  'happy-path-game-001',
  'White Player',
  'Black Player',
  'Training Match',
  'Local Club',
  '2026.06.29',
  '1-0',
  NULL,
  'C20',
  'King Pawn Game',
  '[Event "Training Match"]
[Site "Local Club"]
[Date "2026.06.29"]
[Round "1"]
[White "White Player"]
[Black "Black Player"]
[Result "1-0"]
[ECO "C20"]
[Opening "King Pawn Game"]

1. e4 {Central control} e5 2. Nf3 Nc6 3. Bb5 a6 $1 1-0'
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
  is_mainline,
  occurred_at,
  user_note
) VALUES (
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'w',
  'startpos-hash',
  'game',
  1,
  1,
  1,
  0,
  1,
  '2026-06-29 19:00:00',
  NULL
), (
  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
  'b',
  'after-e4-hash',
  'game',
  1,
  1,
  1,
  1,
  1,
  '2026-06-29 19:00:01',
  NULL
), (
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
  'w',
  'after-e5-hash',
  'game',
  1,
  1,
  2,
  2,
  1,
  '2026-06-29 19:00:02',
  NULL
), (
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
  'b',
  'after-nf3-hash',
  'game',
  1,
  1,
  2,
  3,
  1,
  '2026-06-29 19:00:03',
  NULL
), (
  'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
  'w',
  'after-nc6-hash',
  'game',
  1,
  1,
  3,
  4,
  1,
  '2026-06-29 19:00:04',
  NULL
), (
  'r1bqkbnr/pppp1ppp/2n5/4pB2/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
  'b',
  'after-bb5-hash',
  'game',
  1,
  1,
  3,
  5,
  1,
  '2026-06-29 19:00:05',
  NULL
), (
  'r1bqkbnr/1ppp1ppp/p1n5/4pB2/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4',
  'w',
  'after-a6-hash',
  'game',
  1,
  1,
  4,
  6,
  1,
  '2026-06-29 19:00:06',
  NULL
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
  promotion_piece,
  nag,
  comment_text
) VALUES (
  1,
  1,
  2,
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
  NULL,
  NULL,
  'Central control'
), (
  1,
  2,
  3,
  2,
  1,
  'b',
  'e5',
  'e7e5',
  'P',
  'e7',
  'e5',
  0,
  0,
  0,
  NULL,
  NULL,
  NULL
), (
  1,
  3,
  4,
  3,
  2,
  'w',
  'Nf3',
  'g1f3',
  'N',
  'g1',
  'f3',
  0,
  0,
  0,
  NULL,
  NULL,
  NULL
), (
  1,
  4,
  5,
  4,
  2,
  'b',
  'Nc6',
  'b8c6',
  'N',
  'b8',
  'c6',
  0,
  0,
  0,
  NULL,
  NULL,
  NULL
), (
  1,
  5,
  6,
  5,
  3,
  'w',
  'Bb5',
  'f1b5',
  'B',
  'f1',
  'b5',
  0,
  0,
  0,
  NULL,
  NULL,
  NULL
), (
  1,
  6,
  7,
  6,
  3,
  'b',
  'a6',
  'a7a6',
  'P',
  'a7',
  'a6',
  0,
  0,
  0,
  NULL,
  '$1',
  NULL
);

UPDATE source_documents
SET import_status = 'complete',
    imported_at = '2026-06-29 19:00:10'
WHERE id = 1;
SQL

game_row="$(sqlite3 -tabs "$DB_PATH" "SELECT source_document_id, external_game_key, white_player, black_player, event, site, played_at, result, termination IS NULL, eco_code, opening_name, instr(pgn_text, '1. e4 {Central control} e5 2. Nf3 Nc6 3. Bb5 a6 \$1 1-0') > 0 FROM games;")"
[[ "$game_row" == $'1\thappy-path-game-001\tWhite Player\tBlack Player\tTraining Match\tLocal Club\t2026.06.29\t1-0\t1\tC20\tKing Pawn Game\t1' ]] \
  || { echo "game row assertion failed: got [$game_row]" >&2; exit 1; }

position_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT ply_index, move_number, side_to_move, source_kind, source_ref_id, game_id, is_mainline FROM position_occurrences ORDER BY id;")"
[[ "$position_rows" == $'0\t1\tw\tgame\t1\t1\t1\n1\t1\tb\tgame\t1\t1\t1\n2\t2\tw\tgame\t1\t1\t1\n3\t2\tb\tgame\t1\t1\t1\n4\t3\tw\tgame\t1\t1\t1\n5\t3\tb\tgame\t1\t1\t1\n6\t4\tw\tgame\t1\t1\t1' ]] \
  || { echo "position rows assertion failed: got [$position_rows]" >&2; exit 1; }

move_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT ply_index, move_number, side, san, uci, piece, from_square, to_square, is_capture, is_check, is_checkmate, promotion_piece IS NULL, ifnull(nag, ''), ifnull(comment_text, '') FROM move_records ORDER BY id;")"
[[ "$move_rows" == $'1\t1\tw\te4\te2e4\tP\te2\te4\t0\t0\t0\t1\t\tCentral control\n2\t1\tb\te5\te7e5\tP\te7\te5\t0\t0\t0\t1\t\t\n3\t2\tw\tNf3\tg1f3\tN\tg1\tf3\t0\t0\t0\t1\t\t\n4\t2\tb\tNc6\tb8c6\tN\tb8\tc6\t0\t0\t0\t1\t\t\n5\t3\tw\tBb5\tf1b5\tB\tf1\tb5\t0\t0\t0\t1\t\t\n6\t3\tb\ta6\ta7a6\tP\ta7\ta6\t0\t0\t0\t1\t$1\t' ]] \
  || { echo "move rows assertion failed: got [$move_rows]" >&2; exit 1; }

link_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT from_position_occurrence_id, to_position_occurrence_id, game_id FROM move_records ORDER BY id;")"
[[ "$link_rows" == $'1\t2\t1\n2\t3\t1\n3\t4\t1\n4\t5\t1\n5\t6\t1\n6\t7\t1' ]] \
  || { echo "move link assertion failed: got [$link_rows]" >&2; exit 1; }

complete_row="$(sqlite3 -tabs "$DB_PATH" "SELECT import_status, imported_at FROM source_documents WHERE id = 1;")"
[[ "$complete_row" == $'complete\t2026-06-29 19:00:10' ]] \
  || { echo "source document completion assertion failed: got [$complete_row]" >&2; exit 1; }

sqlite3 "$DB_PATH" <<'SQL'
INSERT INTO position_occurrences (
  fen,
  side_to_move,
  position_hash,
  source_kind,
  source_ref_id,
  game_id,
  move_number,
  ply_index,
  is_mainline,
  user_note
) VALUES (
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'w',
  'manual-startpos-hash',
  'manual',
  NULL,
  NULL,
  NULL,
  NULL,
  0,
  'Same FEN, different study context.'
);
SQL

shared_fen_rows="$(sqlite3 -tabs "$DB_PATH" "SELECT source_kind, source_ref_id IS NULL, game_id IS NULL, is_mainline, ifnull(user_note, '') FROM position_occurrences WHERE fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' ORDER BY id;")"
[[ "$shared_fen_rows" == $'game\t0\t0\t1\t\nmanual\t1\t1\t0\tSame FEN, different study context.' ]] \
  || { echo "shared FEN provenance assertion failed: got [$shared_fen_rows]" >&2; exit 1; }

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'bad-game-ref',
  'game',
  NULL,
  1,
  1,
  7,
  1
);
SQL
then
  echo "expected game position occurrence without source_ref_id to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  'bad-game-ref-mismatch',
  'game',
  999,
  1,
  1,
  7,
  1
);
SQL
then
  echo "expected game position occurrence with mismatched source_ref_id and game_id to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  is_checkmate
) VALUES (
  1,
  1,
  7,
  7,
  4,
  'w',
  'Qa4+',
  'd1a4',
  'Q',
  'd1',
  'a4',
  0,
  1,
  0
);
SQL
then
  echo "expected cross-position move link to fail when source positions do not match the move game" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  is_checkmate
) VALUES (
  1,
  1,
  2,
  2,
  1,
  'w',
  'e4',
  'e2e4',
  'P',
  'e2',
  'e4',
  0,
  0,
  0
);
SQL
then
  echo "expected side parity mismatch to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  is_checkmate
) VALUES (
  1,
  1,
  3,
  2,
  1,
  'b',
  'e5',
  'e7e5',
  'P',
  'e7',
  'e5',
  0,
  0,
  0
);
SQL
then
  echo "expected non-consecutive move link to fail" >&2
  exit 1
fi

if sqlite3 "$DB_PATH" 2>/dev/null <<'SQL'
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
  is_checkmate
) VALUES (
  1,
  1,
  2,
  0,
  1,
  'w',
  'e4',
  'e2e4',
  'P',
  'e2',
  'e4',
  0,
  0,
  0
);
SQL
then
  echo "expected ply_index zero to fail" >&2
  exit 1
fi
