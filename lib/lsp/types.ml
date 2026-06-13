open Rae_lib

type position = { line : int; character : int }
type range = { start_ : position; end_ : position }

let range_of_loc (loc : Ast.loc) =
  { start_ = { line = loc.loc_start.pos_lnum - 1; character = loc.loc_start.pos_cnum - loc.loc_start.pos_bol };
    end_   = { line = loc.loc_end.pos_lnum - 1; character = loc.loc_end.pos_cnum - loc.loc_end.pos_bol } }

type diagnostic = {
  range : range;
  severity : int;
  message : string;
}
