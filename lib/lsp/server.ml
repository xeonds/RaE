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
  let lexbuf = Lexing.from_string text in
  let pos_to_range (p_start : Lexing.position) (p_end : Lexing.position) =
    { start_ = { line = p_start.pos_lnum - 1; character = p_start.pos_cnum - p_start.pos_bol };
      end_   = { line = p_end.pos_lnum - 1; character = p_end.pos_cnum - p_end.pos_bol } }
  in
  try
    let _ = Parser.program Lexer.token lexbuf in
    []
  with
  | Ast.Syntax_error (msg, loc) ->
    [{ range = range_of_loc loc; severity = 1; message = msg }]
  | Parser.Error ->
    let p_start = lexbuf.lex_start_p in
    let p_end = lexbuf.lex_curr_p in
    let r = pos_to_range p_start p_end in
    [{ range = r; severity = 1; message = "Syntax error" }]
  | Lexer.SyntaxError msg ->
    let r = pos_to_range lexbuf.lex_start_p lexbuf.lex_curr_p in
    [{ range = r; severity = 1; message = Printf.sprintf "Lexical error: %s" msg }]
  | _ ->
    let r = pos_to_range lexbuf.lex_start_p lexbuf.lex_curr_p in
    [{ range = r; severity = 1; message = "Unknown error" }]

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
    ("completionProvider", `Assoc [
      ("triggerCharacters", `List [`String "."; `String "@"])
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

let completions = [
  (* keywords *)
  ("file", 14, "keyword"); ("struct", 14, "keyword"); ("enum", 14, "keyword");
  ("bitfield", 14, "keyword"); ("template", 14, "keyword"); ("variant", 14, "keyword");
  ("after", 14, "keyword"); ("align", 14, "keyword"); ("let", 14, "keyword");
  ("in", 14, "keyword"); ("new", 14, "keyword");
  (* types *)
  ("u8", 13, "type"); ("u16", 13, "type"); ("u32", 13, "type"); ("u64", 13, "type");
  ("i8", 13, "type"); ("i16", 13, "type"); ("i32", 13, "type"); ("i64", 13, "type");
  ("f32", 13, "type"); ("f64", 13, "type");
  ("string", 13, "type"); ("bytes", 13, "type"); ("array", 13, "type");
  (* attributes *)
  ("count", 14, "attribute"); ("if", 14, "attribute"); ("validate", 14, "attribute");
  ("checksum", 14, "attribute"); ("endian", 14, "attribute"); ("le", 14, "value"); ("be", 14, "value");
  (* builtins *)
  ("@block", 3, "function"); ("@each", 3, "function"); ("@echo", 3, "function");
  ("@write", 3, "function"); ("@checksum", 3, "function"); ("@crc32", 3, "function");
  ("@align", 3, "function"); ("@bswap16", 3, "function"); ("@bswap32", 3, "function");
  ("@select", 3, "function");
]

let handle_completion id params state =
  let uri = ref "" in let line = ref 0 in let char = ref 0 in
  begin match params with
  | `Assoc fields ->
    (match List.assoc_opt "textDocument" fields with
     | Some (`Assoc td) -> uri := (match List.assoc_opt "uri" td with Some (`String u) -> u | _ -> "")
     | _ -> ());
    (match List.assoc_opt "position" fields with
     | Some (`Assoc pos) ->
       line := (match List.assoc_opt "line" pos with Some (`Int l) -> l | _ -> 0);
       char := (match List.assoc_opt "character" pos with Some (`Int c) -> c | _ -> 0)
     | _ -> ());
  | _ -> ()
  end;
  let prefix = match Hashtbl.find_opt state.documents !uri with
    | Some doc ->
      let lines = String.split_on_char '\n' doc.text in
      if !line < List.length lines then
        let l = List.nth lines !line in
        let before = String.sub l 0 (min !char (String.length l)) in
        let rec take_word s i =
          if i > 0 && s.[i-1] <> ' ' && s.[i-1] <> '\t' && s.[i-1] <> '\n' && s.[i-1] <> ';'
          then take_word s (i-1) else String.sub s i (String.length s - i) in
        take_word before (String.length before)
      else ""
    | None -> "" in
  let items = List.filter_map (fun (label, kind, detail) ->
    if prefix = "" || String.length label >= String.length prefix &&
       String.sub label 0 (String.length prefix) = prefix then
      Some (`Assoc [
        ("label", `String label); ("kind", `Int kind); ("detail", `String detail);
        ("insertText", `String label)
      ])
    else None
  ) completions in
  let result = `Assoc [("isIncomplete", `Bool false); ("items", `List items)] in
  write_json (make_response id result);
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
  | Some (Request { id; method_ = "textDocument/completion"; params }) ->
    let state' = handle_completion id params state in
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
