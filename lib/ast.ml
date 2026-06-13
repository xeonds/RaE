type location = {
  pos_fname : string;
  pos_lnum : int;
  pos_bol : int;
  pos_cnum : int;
}

type loc = {
  loc_start: location;
  loc_end: location;
}

type identifier = string

type binary_op = Add | Sub | Mul | Div | Mod | Eq | Neq | Lt | Le | Gt | Ge | And | Or
type unary_op = Neg | Not

type expr =
  | IntLit of int * loc
  | FloatLit of float * loc
  | StringLit of string * loc
  | Ident of identifier * loc
  | BinaryOp of binary_op * expr * expr * loc
  | UnaryOp of unary_op * expr * loc
  | FieldAccess of expr * identifier * loc
  | ArrayAccess of expr * expr * loc
  | FuncCall of identifier * expr list * loc
  | Pipe of expr * expr * loc
  | Assign of expr * expr * loc
  | BlockLit of (identifier * expr) list * expr list * loc
  | Construct of identifier * (identifier * expr) list * loc

type block_item =
  | BLet of identifier * expr
  | BExpr of expr

type data_type =
  | I8 | I16 | I32 | I64
  | U8 | U16 | U32 | U64
  | F32 | F64
  | StringType of string
  | BytesType of expr option
  | ArrayType of data_type
  | StructType of identifier
  | TemplateType of identifier * identifier list

type attribute =
  | Count of expr * loc
  | Cond of expr * loc
  | Validate of expr * loc
  | Endian of endian_kind * loc

and endian_kind = LE | BE

type offset_expr =
  | Fixed of int
  | After of identifier
  | Align of expr
  | Dynamic of expr

type value =
  | VInt of int | VInt32 of int32 | VInt64 of int64
  | VFloat of float
  | VString of string | VBytes of bytes
  | VArray of value list
  | VObj of (identifier * value) list
  | VNull

type field_decl = {
  name: identifier;
  field_type: data_type;
  expects: expr option;
  attributes: attribute list;
  offset: offset_expr;
  loc: loc;
}

type variant_case = {
  pattern: expr;
  fields: field_decl list;
  loc: loc;
}

type struct_member =
  | Field of field_decl
  | Variant of identifier * variant_case list * loc

type enum_member = {
  name: identifier;
  value: expr;
  loc: loc;
}

type def =
  | StructDef of {
      name: identifier;
      params: identifier list;
      members: struct_member list;
      condition: expr option;
      loc: loc;
    }
  | EnumDef of {
      name: identifier;
      base_type: data_type;
      members: enum_member list;
      loc: loc;
    }
  | BitFieldDef of {
      name: identifier;
      fields: field_decl list;
      loc: loc;
    }
  | TemplateDef of {
      param: identifier;
      name: identifier;
      members: field_decl list;
      loc: loc;
    }

type file_def = {
  name: identifier;
  definitions: def list;
  fields: field_decl list;
  loc: loc;
}

type program = {
  files: file_def list;
  actions: expr list;
  loc: loc;
}

exception Syntax_error of string * loc
