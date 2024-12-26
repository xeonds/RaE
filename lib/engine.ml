open Ast

exception Engine_error of string

(* env is for saving states when parsing content *)
type env = (string * data_type) list

(* engine has 2 parts *)
(* one is engine for parse the bin data according to the ast.file *)
(* another is engine for evaluating all expressions *)

(* attach binary flow to given ast *)
let eval_file_ast ast data = 
  (* recursively parse the file's definations and fields *)
  (* a def is a struct shows that how some fields are composed *)
  let rec eval_defs defs env = 
    | [] -> xxx
    | item::rest -> 
        let res = match item with
          | StructDef s ->
          | EnumDef e ->
          | BitFieldDef b ->
          | TemplateDef t ->
        in
        [res::(eval_file_ast rest env)]
  in
  let rec eval_fields fields data env = 
    | [] -> xxx
    | item::rest -> (
        let res = match item with
          | recursive item -> eval_fields [item] env
          | non_recursive item -> 
              (* parse binary data according to field's def *)
              (* using tools in binlib *)
              let parsed = match field.type_expr with
                | BasicType t -> 
                    binlib.parse_basic t (pick data field.size) 
                | ArrayType -> 
                | StringType -> 
                | BytesType -> 
                | BitFieldType -> 
                | EnumType -> 
                | StructType -> 
                | TemplateType -> 
        in
        [res::(eval_fields rest (shift data field.size) env)]
    )
  in
  eval_fields ast.fields data (eval_defs ast.definations) 

(* engine of running script part *)
let rec eval_expr_ast exprs env = function
  | [], _ -> ()
  | expr::rest, _ env ->
    eval_expr_ast rest (env' = match expr with
      | Int n -> VInt n
      | Var x -> List.assoc x env
      | Equal (e1, e2) ->
          let v1 = eval_expr_ast env e1 in
          let v2 = eval_expr_ast env e2 in
          VBool (v1 = v2)
      | Plus (e1, e2) ->
          (match (eval_expr_ast env e1, eval_expr_ast env e2) with
          | (VInt n1, VInt n2) -> VInt (n1 + n2)
          | _ -> failwith "Type error in addition")
      | Times (e1, e2) ->
          (match (eval_expr_ast env e1, eval_expr_ast env e2) with
          | (VInt n1, VInt n2) -> VInt (n1 * n2)
          | _ -> failwith "Type error in multiplication")
      | Access (e, _field) ->
          (match eval_expr_ast env e with
          (* TODO: parse sub fields and redesign dsl structs *)
          | ParsedFile _parsed -> eval_expr_ast env e
              (* let field = List.find (fun f -> f.name = field) parsed.blocks in
              (match field.value with
              | Some bytes -> VString (Bytes.to_string bytes)
              | None -> failwith "Field not parsed") *)
          | _ -> failwith "Type error in field access")
      | Let (x, expr) ->
          let v = eval_expr_ast env expr in
          (x, v) :: env
      | If(expr, actions) -> 
          let v = eval_expr_ast env expr in
          (match v with
          | VBool true -> let _ = eval_actions env actions in env
          | VBool false -> env
          | _ -> failwith "Type error in if condition")
      | IfElse(expr, actions1, actions2) -> 
        let v = eval_expr_ast env expr in
          (match v with
          | VBool true -> let _ = eval_actions env actions1 in env
          | VBool false -> let _ = eval_actions env actions2 in env
          | _ -> failwith "Type error in if condition")
      | ForIn(x, range, actions) -> 
        let v = List.assoc range env in
          (match v with
          | VInt n -> 
              let rec loop env i =
                if i = n then env
                else
                  let env' = (x, VInt i) :: env in
                  let _ = eval_actions env' actions in
                  loop env (i + 1)
              in
              loop env 0
          | _ -> failwith "Type error in for loop")
      | Echo s -> 
          print_endline s;
          env
      | Write filename ->
          let oc = open_out filename in
          List.iter (fun (x, v) -> Printf.fprintf oc "%s = %s\n" x (string_of_value v)) env;
          close_out oc;
          env
      | NoOp -> env
    )

(* tools for file operation *)
(* read file as plaintext *)
let read_file filename =
  let ic = open_in filename in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

(* read file as binary flow *)
let read_binary_file filename =
  let ic = open_in_bin filename in
  let len = in_channel_length ic in
  let bytes = Bytes.create len in
  really_input ic bytes 0 len;
  close_in ic;
  bytes

(* command line operation utils *)
(* convert source code from file or stdin to plaintext *)
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

let parse_source = function
  | File filename -> read_file filename
  | Inline content -> content

let parse_script_file filename =
  let content = read_file filename in
  let is_shebang_line str =
    String.length str >= 2 && String.sub str 0 2 = "#!"
  in
  let trim_shebang content =
    let lines = String.split_on_char '\n' content in
    match lines with
    | first :: rest when is_shebang_line first ->
        String.concat "\n" rest
    | _ -> content
  in
  if is_shebang_line content then
    trim_shebang content
  else
    content

(* preprocess source code *)
let process_imports content =
  let import_scheme filename =
    try 
      read_file filename
    with _ -> 
      failwith (Printf.sprintf "Failed to import scheme from '%s'" filename)
  in
  let extract_imports content =
    let import_re = Str.regexp "import '[^']*'" in
    let rec find_all acc pos =
      try
        let _ = Str.search_forward import_re content pos in
        let matched = Str.matched_string content in
        let filename = String.sub matched 8 (String.length matched - 9) in
        find_all (filename :: acc) (Str.match_end())
      with Not_found -> 
        List.rev acc
    in
    find_all [] 0
  in
  let imports = extract_imports content in
  List.fold_left (fun acc filename ->
    let imported = import_scheme filename in
    acc ^ "\n" ^ imported
  ) content imports
