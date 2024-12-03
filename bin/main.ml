open Rae_lib
open Types

let process_binary_file filename _program =
  (* TODO: Implement binary file processing *)
  Printf.printf "Processing binary file '%s' with parsed program\n" filename

let parse_and_run script =
  try
    (* Process the scheme source *)
    let scheme_content = match script.scheme with
      | File filename -> Script_parser.parse_script_file filename
      | Inline content -> content
    in
    
    (* Process imports and parse the complete scheme *)
    let processed_scheme = Interpreter.process_imports scheme_content in
    let lexbuf = Lexing.from_string processed_scheme in
    let program = Parser.program Lexer.token lexbuf in
    
    (* Process the binary file with the parsed program *)
    process_binary_file script.binary_file program
    
  with
  | Lexer.LexError msg ->
      Printf.fprintf stderr "Lexical error: %s\n" msg;
      exit 1
  | Parser.Error ->
      Printf.fprintf stderr "Syntax error\n";
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
      parse_and_run script
  | _ ->
      Printf.fprintf stderr "Invalid number of arguments\n";
      (let () = () in
        Printf.printf "Usage:\n";
        Printf.printf "  rae <script.RaE> <binary_file>\n";
        Printf.printf "  rae \"<scheme or import statement>\" <binary_file>\n";
        Printf.printf "Or use as a shebang script:\n";
        Printf.printf "  ./script.rae <binary_file>\n");
      exit 1
