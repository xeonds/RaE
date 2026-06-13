open Ast

let sizeof = function
  | I8 | U8 -> 1 | I16 | U16 -> 2 | I32 | U32 | F32 -> 4 | I64 | U64 | F64 -> 8
  | StringType _ | BytesType _ | ArrayType _ | StructType _ | TemplateType _ -> 0
