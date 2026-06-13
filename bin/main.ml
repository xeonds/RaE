open Rae_lib

let print_usage () =
  Printf.printf "Usage:\n";
  Printf.printf "  rae <script.RaE> <binary_file> [-o out]\n";
  Printf.printf "  rae \"<scheme>\" <binary_file> [-o out]\n";
  Printf.printf "  cat file.bin | rae <script.RaE> [-o out]\n"

let read_stdin () =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 4096 in
  let rec loop () =
    let n = input stdin chunk 0 4096 in
    if n > 0 then (Buffer.add_bytes buf (Bytes.sub chunk 0 n); loop ())
  in
  (try loop () with End_of_file -> ());
  Bytes.of_string (Buffer.contents buf)

let parse_and_run config =
  let source =
    match config.Engine.scheme with
    | Engine.File filename -> Engine.parse_script_file filename
    | Engine.Inline content -> content
  in
  let processed = Engine.process_imports source in
  let lexbuf = Lexing.from_string processed in
  try
    let program = Parser.program Lexer.token lexbuf in
    let bytes = match config.Engine.binary with
      | Engine.File f -> Engine.read_binary_file f
      | Engine.Stdin ->
        (try read_stdin () with End_of_file -> Bytes.empty)
    in
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
      (match config.Engine.output with
       | Some filename -> (match result with Ast.VBytes b -> let oc = open_out_bin filename in output oc b 0 (Bytes.length b); close_out oc | _ -> ())
       | None -> ());
      Printf.printf "%s\n" (Engine.format_value result)
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
    let p = lexbuf.lex_start_p in
    let line = p.pos_lnum in
    let col = p.pos_cnum - p.pos_bol in
    Printf.eprintf "Syntax error at line %d, col %d\n" line col;
    exit 1
  | Engine.Engine_error msg ->
    Printf.eprintf "Engine error: %s\n" msg;
    exit 1
  | e ->
    Printf.eprintf "Error: %s\n" (Printexc.to_string e);
    exit 1

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  let (scheme : Engine.input_scheme), rest = match (args : string list) with
    | s :: r when Filename.check_suffix s ".RaE" || Filename.check_suffix s ".rae" ->
      (Engine.File s : Engine.input_scheme), r
    | s :: r -> (Engine.Inline s : Engine.input_scheme), r
    | [] -> print_usage (); exit 1
  in
  let (binary : Engine.binary_source), output, _ = List.fold_left (fun (bin, out, state) arg ->
    match state with
    | 0 when arg = "-o" -> (bin, out, 1)
    | 1 -> (bin, Some arg, 0)
    | 0 -> (Engine.File arg, out, 0)
    | _ -> (bin, out, state)
  ) ((Engine.Stdin : Engine.binary_source), None, 0) rest in
  parse_and_run { Engine.scheme = scheme; binary; output }
