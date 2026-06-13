open Ast

let sizeof = function
  | I8 | U8 -> 1
  | I16 | U16 -> 2
  | I32 | U32 | F32 -> 4
  | I64 | U64 | F64 -> 8
  | StringType _ -> 0
  | BytesType _ -> 0
  | ArrayType _ -> 0
  | StructType _ -> 0
  | TemplateType _ -> 0

let pick data size = String.sub data 0 size

let shift data size = String.sub data size (String.length data - size)

let substring data offset size = String.sub data offset size

let rec parse_data (data_type, byte_data) =
  match data_type with
  | I8 -> VInt (int_of_string byte_data)
  | U8 -> VInt (int_of_string byte_data)
  | I16 -> VInt (int_of_string byte_data)
  | U16 -> VInt (int_of_string byte_data)
  | I32 -> VInt32 (Int32.of_string byte_data)
  | U32 -> VInt32 (Int32.of_string byte_data)
  | F32 -> VFloat (float_of_string byte_data)
  | I64 -> VInt64 (Int64.of_string byte_data)
  | U64 -> VInt64 (Int64.of_string byte_data)
  | F64 -> VFloat (float_of_string byte_data)
  | ArrayType t ->
      let rec loop acc data remaining =
        if remaining <= 0 then acc
        else
          let item_size = sizeof t in
          let item_data = pick data item_size in
          let rest = shift data item_size in
          loop (acc @ [parse_data (t, item_data)]) rest (remaining - 1)
      in
      VArray (loop [] byte_data 0)
  | StringType _ ->
      let len = String.length byte_data in
      let str = Bytes.create len in
      Bytes.blit_string byte_data 0 str 0 len;
      VString (Bytes.to_string str)
  | BytesType _ -> VBytes (Bytes.of_string byte_data)
  | StructType _ -> VObj []
  | TemplateType _ -> VObj []

let write_data value =
  match value with
  | VInt n -> string_of_int n
  | VInt32 n -> Int32.to_string n
  | VInt64 n -> Int64.to_string n
  | VFloat f -> string_of_float f
  | VString s -> s
  | VBytes _ -> ""
  | VArray _ -> ""
  | VObj _ -> ""
  | VNull -> ""
