open Ast

module Binlib = struct
  let rec sizeof = function
    | I8 _ -> 1
    | U8 _ -> 1
    | I16 _ -> 2
    | U16 _ -> 2
    | I32 _ -> 4
    | U32 _ -> 4
    | F32 _ -> 4
    | I64 _ -> 8
    | U64 _ -> 8
    | F64 _ -> 8
    | ArrayType (n, t) -> n * sizeof t
    | StringType s -> String.length s
    | BytesType b -> (match b with
      | None -> 0
      | Some s -> String.length (Bytes.to_string s))
    | BitFieldType (n, _) -> n
    | EnumType _ -> 0
    | StructType _ -> 0
    | TemplateType _ -> 0


  let pick data size = String.sub data 0 size

  let shift data size = String.sub data size (String.length data - size)

  let substring data offset size = String.sub data offset size

  let rec parse_data (data_type, byte_data) =
    match data_type with
    | I8 _ -> I8Data(int_of_string byte_data)
    | U8 _ -> U8Data (int_of_string byte_data)
    | I16 _ -> I16Data (int_of_string byte_data)
    | U16 _ -> U16Data (int_of_string byte_data)
    | I32 _ -> I32Data (Int32.of_string byte_data)
    | U32 _ -> U32Data (Int32.of_string byte_data)
    | F32 _ -> F32Data (float_of_string byte_data)
    | I64 _ -> I64Data (Int64.of_string byte_data)
    | U64 _ -> U64Data (Int64.of_string byte_data)
    | F64 _ -> F64Data (float_of_string byte_data)
    | ArrayType (n, t) -> 
        let size = n in
        let rec loop acc i =
          if i = size then acc
          else
            let item_size = sizeof t in
            let item = pick byte_data item_size in
            loop (acc @ [parse_data (t, item)]) (i + 1)
        in
        ArrayData (loop [] 0)
    | StringType _ ->
        let len = String.length byte_data in
        let str = Bytes.create len in
        Bytes.blit_string byte_data 0 str 0 len;
        StringData (Bytes.to_string str)
    | BytesType _ -> BytesData (Bytes.of_string byte_data)
    | BitFieldType _ -> BitFieldData (0, Bytes.of_string byte_data)
    | EnumType _ -> EnumData ""
    | StructType _ -> StructData ("", [])
    | TemplateType _ -> TemplateData ("", [])
end