open Rae_lib
open Types
open Binary_parser

(* parse the binary data with program *)
let process_binary_data bin program =
  (* TODO: support multi scheme headers parse *)
  let parsed = BinaryParser.parse_file bin (List.nth program.file_defs 0) in
  match parsed with
  | Ok parsed -> 
      let value = Interpreter.value_of_parsed_file parsed in
      Interpreter.eval_actions [((List.nth program.file_defs 0).name, value)] program.actions
  | Error (msg, _) ->
      Printf.fprintf stderr "Error parsing binary data: %s\n" msg;;

let parse_and_run script =
  let lexbuf = ref None in
  try
    (* Process the scheme source *)
    let scheme_content = match script.scheme with
      | File filename -> Script_parser.parse_script_file filename
      | Inline content -> content
    in
    
    (* Process imports and parse the complete scheme *)
    let processed_scheme = Interpreter.process_imports scheme_content in
    lexbuf := Some (Lexing.from_string processed_scheme);
    let program = Parser.program Lexer.token (Option.get !lexbuf) in

    (* Read the binary file *)
    let bytes = Interpreter.read_binary_file script.binary_file in
    
    (* Process the binary file with the parsed program *)
    process_binary_data bytes program
    
  with
  | Lexer.LexError msg ->
      Printf.fprintf stderr "Lexical error: %s\n" msg;
      exit 1
  | Parser.Error ->
      let pos = Lexing.lexeme_start_p (Option.get !lexbuf) in
      Printf.fprintf stderr "Syntax error at line %d, column %d\n" pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1);
      exit 1
  | Script_parser.Script_error msg ->
      Printf.fprintf stderr "Script error: %s\n" msg;
      exit 1
  | e ->
      Printf.fprintf stderr "Unexpected error: %s\n" (Printexc.to_string e);
      exit 1

let print_usage () =
  Printf.printf "Usage:\n";
  Printf.printf "  rae <script.RaE> <binary_file>\n";
  Printf.printf "  rae \"<scheme or import statement>\" <binary_file>\n";
  Printf.printf "Or use as a shebang script:\n";
  Printf.printf "  ./script.rae <binary_file>\n"

let () =
  match Array.length Sys.argv with
  | 1 ->
print_usage ()
  | n when n >= 3 ->
      let args = List.tl (Array.to_list Sys.argv) in
      let script = Script_parser.parse_command_line args in
      Printf.printf "Running script...\n";
      Printf.printf "Scheme: %s\n" (match script.scheme with File f -> f | Inline s -> s); 
      Printf.printf "Binary file: %s\n" script.binary_file;
      parse_and_run script
  | _ ->
      Printf.fprintf stderr "Invalid number of arguments\n";
      print_usage ();
      exit 1
