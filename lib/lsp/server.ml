open Rae_lib
open Types
open Jsonrpc

type document = {
  uri : string;
  text : string;
  version : int;
}

type state = {
  documents : (string, document) Hashtbl.t;
  initialized : bool;
}

let create_state () = {
  documents = Hashtbl.create 16;
  initialized = false;
}

let parse_document text =
  try
    let lexbuf = Lexing.from_string text in
    let _ = Parser.program Lexer.token lexbuf in
    []
  with
  | Ast.Syntax_error (msg, loc) ->
    let range = range_of_loc loc in
    [{ range; severity = 1; message = msg }]
  | Parser.Error ->
    [{ range = { start_ = { line = 0; character = 0 }; end_ = { line = 0; character = 0 } };
       severity = 1; message = "Syntax error" }]
  | Lexer.SyntaxError msg ->
    [{ range = { start_ = { line = 0; character = 0 }; end_ = { line = 0; character = 0 } };
       severity = 1; message = Printf.sprintf "Lexical error: %s" msg }]
  | _ ->
    [{ range = { start_ = { line = 0; character = 0 }; end_ = { line = 0; character = 0 } };
       severity = 1; message = "Unknown error" }]

let diagnostics_to_json diags =
  `List (List.map (fun d ->
    `Assoc [
      ("range", `Assoc [
        ("start", `Assoc [("line", `Int d.range.start_.line); ("character", `Int d.range.start_.character)]);
        ("end", `Assoc [("line", `Int d.range.end_.line); ("character", `Int d.range.end_.character)])
      ]);
      ("severity", `Int d.severity);
      ("message", `String d.message);
    ]
  ) diags)

let publish_diagnostics uri diags =
  let params = `Assoc [
    ("uri", `String uri);
    ("diagnostics", diagnostics_to_json diags)
  ] in
  write_json (make_notification "textDocument/publishDiagnostics" params)

let handle_initialize id _params state =
  let capabilities = `Assoc [
    ("textDocumentSync", `Assoc [
      ("openClose", `Bool true);
      ("change", `Int 1)
    ]);
  ] in
  let result = `Assoc [("capabilities", capabilities)] in
  write_json (make_response id result);
  { state with initialized = true }

let handle_did_open params state =
  begin match params with
  | `Assoc fields ->
    (match List.assoc_opt "textDocument" fields with
     | Some (`Assoc td) ->
       let uri = match List.assoc_opt "uri" td with Some (`String u) -> u | _ -> "" in
       let text = match List.assoc_opt "text" td with Some (`String t) -> t | _ -> "" in
       let version = match List.assoc_opt "version" td with Some (`Int v) -> v | _ -> 0 in
       Hashtbl.replace state.documents uri { uri; text; version };
       let diags = parse_document text in
       publish_diagnostics uri diags
     | _ -> ())
  | _ -> ()
  end;
  state

let handle_did_change params state =
  begin match params with
  | `Assoc fields ->
    (match List.assoc_opt "textDocument" fields with
     | Some (`Assoc td) ->
       let uri = match List.assoc_opt "uri" td with Some (`String u) -> u | _ -> "" in
       let version = match List.assoc_opt "version" td with Some (`Int v) -> v | _ -> 0 in
       (match List.assoc_opt "contentChanges" fields with
        | Some (`List (change :: _)) ->
          (match change with
           | `Assoc cc ->
             let text = match List.assoc_opt "text" cc with Some (`String t) -> t | _ -> "" in
             Hashtbl.replace state.documents uri { uri; text; version };
             let diags = parse_document text in
             publish_diagnostics uri diags
           | _ -> ())
        | _ -> ())
     | _ -> ())
  | _ -> ()
  end;
  state

let handle_did_close params state =
  begin match params with
  | `Assoc fields ->
    (match List.assoc_opt "textDocument" fields with
     | Some (`Assoc td) ->
       let uri = match List.assoc_opt "uri" td with Some (`String u) -> u | _ -> "" in
       Hashtbl.remove state.documents uri
     | _ -> ())
  | _ -> ()
  end;
  state

let handle_shutdown id state =
  write_json (make_response id `Null);
  state

let rec loop state =
  let msg =
    try read_message stdin
    with End_of_file -> None
  in
  match msg with
  | Some (Request { id; method_ = "initialize"; params }) ->
    let state' = handle_initialize id params state in
    loop state'
  | Some (Request { id; method_ = "shutdown"; _ }) ->
    let state' = handle_shutdown id state in
    loop state'
  | Some (Request { id; method_ = m; _ }) ->
    write_json (make_error id (-32601) ("Method not found: " ^ m));
    loop state
  | Some (Notification { method_ = "initialized"; _ }) ->
    loop state
  | Some (Notification { method_ = "textDocument/didOpen"; params }) ->
    let state' = handle_did_open params state in
    loop state'
  | Some (Notification { method_ = "textDocument/didChange"; params }) ->
    let state' = handle_did_change params state in
    loop state'
  | Some (Notification { method_ = "textDocument/didClose"; params }) ->
    let state' = handle_did_close params state in
    loop state'
  | Some (Notification { method_ = "exit"; _ }) -> exit 0
  | Some _ -> loop state
  | None -> ()

let run () =
  let state = create_state () in
  loop state
