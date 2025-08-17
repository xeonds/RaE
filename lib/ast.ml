type location = {
  pos_fname : string;  (* 文件名 *)
  pos_lnum : int;      (* 行号 *)
  pos_bol : int;       (* 行首位置 *)
  pos_cnum : int;      (* 字符位置 *)
}

(* 源码定位 *)
type loc = {
  loc_start: location;
  loc_end: location;
}

type identifier = string

(* 基础数据类型 *)
and data_type = 
  | I8 of int
  | I16 of int
  | I32 of int32
  | I64 of int64
  | U8  of int
  | U16  of int
  | U32  of int32
  | U64 of int64
  | F32  of float
  | F64 of float
  | ArrayType of int * data_type   (* 数组长度，元素类型 *)
  | StringType of string
  | BytesType of bytes option
  | BitFieldType of int * bytes
  | EnumType of identifier
  | StructType of identifier
  | TemplateType of identifier * identifier list

(* 对应的数据 *)
and data = 
  | I8Data of int
  | I16Data of int
  | I32Data of int32
  | I64Data of int64
  | U8Data of int
  | U16Data of int
  | U32Data of int32
  | U64Data of int64
  | F32Data of float
  | F64Data of float
  | StringData of string
  | BytesData of bytes
  | BitFieldData of int * bytes
  | EnumData of identifier
  | StructData of identifier * data list
  | TemplateData of identifier * data list
  | ArrayData of data list

(* attributes are exprs in [] that following the field *)
(* 就是field的属性 *)
(* 因为配合源码所以有loc源码定位字段 *)
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

(* 源码ast中的表达式类型 *)
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

(* 每一个field的ast *)
type field_decl = {
  name: identifier;
  field_type: data_type;
  attributes: attribute list;
  offset: offset_expr;
  loc: loc;
}

and offset_expr =
  | Fixed of int
  | After of identifier
  | Align of expr
  | Dynamic of expr

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