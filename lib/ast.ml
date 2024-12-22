
type location = {
  pos_fname : string;  (* 文件名 *)
  pos_lnum : int;      (* 行号 *)
  pos_bol : int;       (* 行首位置 *)
  pos_cnum : int;      (* 字符位置 *)
}

type loc = {
  loc_start: location;
  loc_end: location;
}

type identifier = string * loc

type type_param = {
  name: identifier;
  loc: loc;
}

type type_expr =
  | BasicType of basic_type * loc
  | ArrayType of type_expr * loc
  | StringType of string option * loc (* encoding option *)
  | BytesType of loc
  | BitFieldType of loc
  | EnumType of identifier * loc
  | StructType of identifier * loc
  | TemplateType of identifier * type_param list * loc

and basic_type =
  | I8 | I16 | I32 | I64
  | U8 | U16 | U32 | U64
  | F32 | F64

type attribute = 
  | Endian of endian_type * loc
  | Encoding of string * loc
  | Radix of radix_type * loc
  | Align of expr * loc
  | Padding of padding_type * loc
  | Pack of expr * loc
  | Size of expr * loc
  | Count of expr * loc
  | Stride of expr * loc
  | If of expr * loc
  | Validate of expr * loc
  | Range of expr * expr * loc
  | Set of expr list * loc

and endian_type = ELittle | EBig | EDynamic
and radix_type = Hex | Dec | Oct | Bin
and padding_type = PNone | PZero | PCustom

and expr =
  | IntLit of int * loc
  | FloatLit of float * loc
  | StringLit of string * loc
  | BytesLit of bytes * loc
  | Identifier of identifier
  | BinaryOp of binary_op * expr * expr * loc
  | UnaryOp of unary_op * expr * loc
  | FunctionCall of identifier * expr list * loc
  | FieldAccess of expr * identifier * loc
  | ArrayAccess of expr * expr * loc
  | InRange of expr * expr * expr * loc
  | InSet of expr * expr list * loc

and binary_op =
  | Add | Sub | Mul | Div | Mod
  | Eq | Neq | Lt | Le | Gt | Ge
  | And | Or
  | BitAnd | BitOr | BitXor
  | LShift | RShift

and unary_op =
  | Neg | Not | BitNot

type field_decl = {
  name: identifier;
  type_expr: type_expr;
  attributes: attribute list;
  offset: offset_expr;
  loc: loc;
}

and offset_expr =
  | Fixed of expr * loc
  | After of identifier * loc
  | Align of expr * loc
  | Dynamic of expr * loc

type variant_case = {
  pattern: expr;
  fields: field_decl list;
  loc: loc;
}

type struct_item =
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
      type_params: type_param list;
      members: struct_item list;
      condition: expr option;
      loc: loc;
    }
  | EnumDef of {
      name: identifier;
      base_type: type_expr;
      members: enum_member list;
      loc: loc;
    }
  | BitFieldDef of {
      name: identifier;
      fields: field_decl list;
      loc: loc;
    }
  | TemplateDef of {
      param: type_param;
      name: identifier;
      members: field_decl list;
      loc: loc;
    }

type file_def = {
  name: identifier;
  definitions: def list;
  loc: loc;
}

type program = {
  files: file_def list;
  actions: expr list;
  loc: loc;
}