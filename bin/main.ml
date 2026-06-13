open Rae_lib

let parse_and_run config =
  try
    let source =
      match config.Engine.scheme with
      | Engine.File filename -> Engine.parse_script_file filename
      | Engine.Inline content -> content
    in
    let processed = Engine.process_imports source in
    let lexbuf = Lexing.from_string processed in
    let program = Parser.program Lexer.token lexbuf in
    let bytes = Engine.read_binary_file config.Engine.binary_file in

    match program.files with
    | [] ->
      Printf.eprintf "No file schema defined\n";
      exit 1
    | file_schema :: _ ->
      let env = Engine.parse_binary file_schema bytes in
      let root = Ast.VObj env in
      let call_env = ["__raw__", Ast.VBytes bytes; "__file__", Ast.VString file_schema.Ast.name] in
      let all_defs = (Ast.StructDef { name = file_schema.Ast.name; params = []; members = List.map (fun f -> Ast.Field f) file_schema.Ast.fields; condition = None; loc = file_schema.Ast.loc }) :: file_schema.Ast.definitions in
      Engine.set_construct_defs all_defs;
      let result = Engine.eval_actions program.actions call_env root in
      begin match result with
      | Ast.VInt n -> Printf.printf "%d\n" n
      | Ast.VInt32 n -> Printf.printf "%ld\n" n
      | Ast.VInt64 n -> Printf.printf "%Ld\n" n
      | Ast.VFloat f -> Printf.printf "%f\n" f
      | Ast.VString s -> Printf.printf "%s\n" s
      | Ast.VBytes _ -> Printf.printf "<bytes>\n"
      | Ast.VArray items -> Printf.printf "<array %d>\n" (List.length items)
      | Ast.VObj fields -> Printf.printf "<obj %d>\n" (List.length fields)
      | Ast.VNull -> ()
      end
  with
  | Lexer.SyntaxError msg ->
    Printf.eprintf "Lexical error: %s\n" msg;
    exit 1
  | Ast.Syntax_error (msg, loc) ->
    let line = loc.loc_start.pos_lnum in
    let col = loc.loc_start.pos_cnum - loc.loc_start.pos_bol in
    let end_col = loc.loc_end.pos_cnum - loc.loc_end.pos_bol in
    Printf.eprintf "Syntax error at line %d, col %d-%d: %s\n" line col end_col msg;
    exit 1
  | Parser.Error ->
    Printf.eprintf "Syntax error\n";
    exit 1
  | Engine.Engine_error msg ->
    Printf.eprintf "Engine error: %s\n" msg;
    exit 1
  | e ->
    Printf.eprintf "Error: %s\n" (Printexc.to_string e);
    exit 1

let print_usage () =
  Printf.printf "Usage:\n";
  Printf.printf "  rae <script.RaE> <binary_file>\n";
  Printf.printf "  rae \"<scheme content>\" <binary_file>\n"

let () =
  match Array.length Sys.argv with
  | 1 -> print_usage ()
  | n when n >= 3 ->
    let args = List.tl (Array.to_list Sys.argv) in
    let config = Engine.parse_command_line args in
    parse_and_run config
  | _ ->
    Printf.eprintf "Invalid arguments\n";
    print_usage ();
    exit 1
