open Types

type value =
  | VInt of int
  | VString of string
  | VBool of bool

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


let rec eval_action env = function
  | If (cond, actions) ->
      begin match eval_expr env cond with
      | VBool true -> List.iter (eval_action env) actions
      | VBool false -> ()
      | _ -> failwith "Condition must evaluate to boolean"
      end
  | Echo s -> print_endline s
  | ForIn (_var, _collection, _actions) ->
      (* TODO: Implement iteration *)
          ()
      | IfElse (cond, then_actions, else_actions) ->
          begin match eval_expr env cond with
          | VBool true -> List.iter (eval_action env) then_actions
          | VBool false -> List.iter (eval_action env) else_actions
          | _ -> failwith "Condition must evaluate to boolean"
          end
      | Let (var, expr) ->
          let value = eval_expr env expr in
          eval_action ((var, value) :: env)
  | Write _filename ->
      (* TODO: Implement file writing *)
      ()

let read_file filename =
  let ic = open_in filename in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content

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