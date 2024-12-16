type endianness = Little | Big [@@deriving show, eq]

type data_type =
  | UInt8
  | UInt16
  | UInt32
  | String of expression  (* Dynamic length strings *)
  | Blob of expression    (* Dynamic size blobs *)
  | Custom of string      (* A named custom parser *)
  [@@deriving show, eq]

and expression =
  | Int of int
  | Var of string
  | Equal of expression * expression
  | Plus of expression * expression
  | Times of expression * expression
  [@@deriving show, eq]

type condition =
  | Equals of expression
  | NoCondition
  [@@deriving show, eq]

type field = {
  name: string;
  data_type: data_type;
  offset: expression option;  (* Optional dynamic offset *)
  condition: condition;
  annotations: (string * string) list; (* Additional metadata *)
} [@@deriving show, eq]

type block = {
  name: string;
  fields: field list;
  repeat: expression option; (* Repeat block based on a condition *)
  annotations: (string * string) list; (* Additional metadata *)
} [@@deriving show, eq]

type metadata = {
  endian: endianness;
  alignment: int option;
} [@@deriving show, eq]

type file_def = {
  name: string;
  metadata: metadata;
  blocks: block list;
} [@@deriving show, eq]

(* Result type to capture errors and recovered state *)
type 'a parse_result = 
  | Ok of 'a
  | Error of string * 'a

(* Parsed field representation *)
type parsed_field = {
  name: string;
  value: bytes option; (* Parsed binary data or None if parsing failed *)
}

(* Parsed block representation *)
type parsed_block = {
  name: string;
  fields: parsed_field list;
}

(* Final parsed AST representation *)
type parsed_file = {
  name: string;
  blocks: parsed_block list;
}
type action =
  | If of expression * action list
  | IfElse of expression * action list * action list
  | Echo of string
  | ForIn of string * string * action list
  | Write of string
  | Let of string * expression  (* Define variables *)
  [@@deriving show, eq]

type program = {
  file_def: file_def;
  actions: action list;
} [@@deriving show, eq]

type source =
  | File of string
  | Inline of string
  [@@deriving show, eq]

type script = {
  scheme: source;
  actions: source option;
  binary_file: string;
} [@@deriving show, eq]