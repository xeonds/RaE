type json = Yojson.Basic.t

type message =
  | Request of { id : int; method_ : string; params : json }
  | Notification of { method_ : string; params : json }
  | Response of { id : int; result : json }
  | Error of { id : int; code : int; message : string }

let parse_message j =
  match j with
  | `Assoc fields ->
    let get k = List.assoc_opt k fields in
    let jsonrpc = match get "jsonrpc" with Some (`String v) -> Some v | _ -> None in
    let id = match get "id" with Some (`Int i) -> Some i | _ -> None in
    let method_ = match get "method" with Some (`String m) -> Some m | _ -> None in
    let params = match get "params" with Some p -> Some p | None -> Some (`Assoc []) in
    let result = get "result" in
    let err = get "error" in
    (match jsonrpc with
     | Some "2.0" ->
       (match method_, params with
        | Some m, Some p when Option.is_none id -> Notification { method_ = m; params = p }
        | Some m, Some p ->
          Request { id = Option.get id; method_ = m; params = p }
        | _ ->
          (match id, result with
           | Some i, Some r -> Response { id = i; result = r }
           | Some i, _ ->
             (match err with
              | Some (`Assoc e) ->
                let code = match List.assoc_opt "code" e with Some (`Int c) -> c | _ -> 0 in
                let msg = match List.assoc_opt "message" e with Some (`String s) -> s | _ -> "" in
                Error { id = i; code; message = msg }
              | _ -> Response { id = i; result = `Null })
           | _ -> Notification { method_ = "unknown"; params = `Assoc [] }))
     | _ -> Notification { method_ = "unknown"; params = `Assoc [] })
  | _ -> Notification { method_ = "unknown"; params = `Assoc [] }

let make_response id result =
  `Assoc [("jsonrpc", `String "2.0"); ("id", `Int id); ("result", result)]

let make_error id code message =
  `Assoc [("jsonrpc", `String "2.0"); ("id", `Int id);
          ("error", `Assoc [("code", `Int code); ("message", `String message)])]

let make_notification method_ params =
  `Assoc [("jsonrpc", `String "2.0"); ("method", `String method_);
          ("params", params)]

let read_header ic =
  let content_length = ref None in
  let rec loop () =
    let raw = input_line ic in
    let line = String.trim raw in
    if line = "" then
      if Option.is_some !content_length then ()
      else loop ()
    else begin
      (match String.split_on_char ':' line with
       | "Content-Length" :: rest ->
         let v = String.trim (String.concat ":" rest) in
         (try content_length := Some (int_of_string v)
          with Failure _ -> ());
         loop ()
       | _ -> loop ())
    end
  in
  (try loop () with End_of_file -> ());
  !content_length

let read_message ic =
  match read_header ic with
  | Some len ->
    let body = Bytes.create len in
    let n = (try input ic body 0 len with End_of_file -> 0) in
    if n < len then None
    else
      (try
         let json = Yojson.Basic.from_string (Bytes.to_string body) in
         Some (parse_message json)
       with Yojson.Json_error _ | Yojson.Basic.Util.Type_error _ -> None)
  | None -> None

let write_json j =
  let s = Yojson.Basic.to_string j in
  let header = Printf.sprintf "Content-Length: %d\r\n\r\n" (String.length s) in
  output_string stdout header;
  output_string stdout s;
  flush stdout
