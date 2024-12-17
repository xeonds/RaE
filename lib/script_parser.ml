open Types

exception Script_error of string

let is_shebang_line str =
  String.length str >= 2 && String.sub str 0 2 = "#!"

let trim_shebang content =
  let lines = String.split_on_char '\n' content in
  match lines with
  | first :: rest when is_shebang_line first ->
      String.concat "\n" rest
  | _ -> content

let parse_command_line args =
  match args with
  | [script; binary_file] ->
      (* test if the arg1 is a script file, or a script content *)
      if Filename.check_suffix script ".RaE" || Filename.check_suffix script ".rae" then
        { scheme = File script; binary_file }
      else
        { scheme = Inline script; binary_file }
  | _ ->
      raise (Script_error "Invalid arguments. Usage: rae <script.RaE | \"scheme\"> <binary_file>")

let parse_script_file filename =
  let content = Interpreter.read_file filename in
  if is_shebang_line content then
    trim_shebang content
  else
    content

