open Types

type value =
  | VInt of int
  | VString of string
  | VBool of bool
  | ParsedFile of parsed_file

type env = (string * value) list

let rec eval_expr env = function
  | Int n -> VInt n
  | Var x -> List.assoc x env
  | Equal (e1, e2) ->
      let v1 = eval_expr env e1 in
      let v2 = eval_expr env e2 in
      VBool (v1 = v2)
  | Plus (e1, e2) ->
      (match (eval_expr env e1, eval_expr env e2) with
      | (VInt n1, VInt n2) -> VInt (n1 + n2)
      | _ -> failwith "Type error in addition")
  | Times (e1, e2) ->
      (match (eval_expr env e1, eval_expr env e2) with
      | (VInt n1, VInt n2) -> VInt (n1 * n2)
      | _ -> failwith "Type error in multiplication")
  | Access (e, _field) ->
      (match eval_expr env e with
      (* TODO: parse sub fields and redesign dsl structs *)
      | ParsedFile _parsed -> eval_expr env e
          (* let field = List.find (fun f -> f.name = field) parsed.blocks in
          (match field.value with
          | Some bytes -> VString (Bytes.to_string bytes)
          | None -> failwith "Field not parsed") *)
      | _ -> failwith "Type error in field access")

let string_of_value = function
  | VInt n -> string_of_int n
  | VString s -> s
  | VBool b -> string_of_bool b
  | ParsedFile _ -> "<parsed file>"

let value_of_parsed_file parsed = ParsedFile parsed

let rec eval_actions env actions = match actions with
  | [] -> ()
  | action :: rest ->
      let env' = match action with
      | Let (x, expr) ->
          let v = eval_expr env expr in
          (x, v) :: env
      | If(expr, actions) -> 
          let v = eval_expr env expr in
          (match v with
          | VBool true -> let _ = eval_actions env actions in env
          | VBool false -> env
          | _ -> failwith "Type error in if condition")
      | IfElse(expr, actions1, actions2) -> 
        let v = eval_expr env expr in
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
      in
      eval_actions env' rest

let read_file filename =
  let ic = open_in filename in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

let read_binary_file filename =
  let ic = open_in_bin filename in
  let len = in_channel_length ic in
  let bytes = Bytes.create len in
  really_input ic bytes 0 len;
  close_in ic;
  bytes

let parse_source = function
  | File filename -> read_file filename
  | Inline content -> content

let import_scheme filename =
  try 
    read_file filename
  with _ -> 
    failwith (Printf.sprintf "Failed to import scheme from '%s'" filename)

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

let process_imports content =
  let imports = extract_imports content in
  List.fold_left (fun acc filename ->
    let imported = import_scheme filename in
    acc ^ "\n" ^ imported
  ) content imports