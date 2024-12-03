type endianness = Little | Big [@@deriving show, eq]

type data_type =
  | UInt8
  | UInt16
  | UInt32
  | String of int
  | Blob of int
  [@@deriving show, eq]

type offset = int [@@deriving show, eq]

type condition =
  | Equals of expression
  | NoCondition
  [@@deriving show, eq]

and expression =
  | Int of int
  | Var of string
  | Equal of expression * expression
  | Plus of expression * expression
  | Times of expression * expression
  [@@deriving show, eq]

type field = {
  name: string;
  data_type: data_type;
  offset: offset;
  condition: condition;
} [@@deriving show, eq]

type block = {
  name: string;
  fields: field list;
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

type action =
  | If of expression * action list
  | Echo of string
  | ForIn of string * string * action list
  | Write of string
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