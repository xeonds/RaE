open Types

module BinaryParser = struct
  let rec evaluate_expression (expr: expression) (offset: int) : int =
    match expr with
    | Int i -> i
    | Var _ -> offset
    | Equal (lhs, rhs) -> evaluate_expression lhs offset + evaluate_expression rhs offset
    | Plus (lhs, rhs) -> evaluate_expression lhs offset + evaluate_expression rhs offset
    | Times (lhs, rhs) -> evaluate_expression lhs offset * evaluate_expression rhs offset

  (* Utility to parse a specific field *)
  let parse_field (input: bytes) (field: field) (offset: int) : (parsed_field * int) parse_result =
    try
      (* Evaluate offset, handle dynamic offsets *)
      let resolved_offset = match field.offset with
        | Some expr -> 
          let evaluated_offset = evaluate_expression expr offset in
          evaluated_offset
        | None -> offset
      in
      (* Parse data based on type *)
      match field.data_type with
      | UInt8 ->
        let value = Bytes.get_uint8 input resolved_offset in
        Ok ({ name = field.name; value = Some (Bytes.of_string (String.make 1 (Char.chr value))) }, resolved_offset + 1)
      | UInt16 -> (* Add support for endianness *)
        Ok ({ name = field.name; value = None }, resolved_offset + 2) (* Placeholder *)
      | _ -> Error ("Unsupported type", ({ name = field.name; value = None }, resolved_offset))
    with e ->
      Error (Printexc.to_string e, ({ name = field.name; value = None }, offset))

  (* Utility to parse a block *)
  let parse_block (input: bytes) (block: block) (offset: int) : (parsed_block * int) parse_result =
    let rec parse_fields fields acc offset =
      match fields with
      | [] -> Ok (List.rev acc, offset)
      | field :: rest ->
        (match parse_field input field offset with
         | Ok (parsed_field, new_offset) -> parse_fields rest (parsed_field :: acc) new_offset
         | Error (err, (parsed_field, new_offset)) ->
           (* Attempt recovery and continue parsing remaining fields *)
           Printf.printf "Error parsing field %s: %s\n" parsed_field.name err;
           parse_fields rest (parsed_field :: acc) new_offset)
    in
    match parse_fields block.fields [] offset with
    | Ok (fields, new_offset) -> Ok ({ name = block.name; fields }, new_offset)
    | Error (err, (parsed_field, new_offset)) -> Error (err, ({ name = block.name; fields = parsed_field }, new_offset))

  (* Parse the entire file *)
  let parse_file (input: bytes) (file_def: file_def) : parsed_file parse_result =
    let rec parse_blocks blocks acc offset =
      match blocks with
      | [] -> Ok (List.rev acc)
      | block :: rest ->
        (match parse_block input block offset with
         | Ok (parsed_block, new_offset) -> parse_blocks rest (parsed_block :: acc) new_offset
         | Error (err, (parsed_block, _)) ->
           (* Attempt recovery and continue parsing remaining blocks *)
           Printf.printf "Error parsing block %s: %s\n" parsed_block.name err;
           parse_blocks rest (parsed_block :: acc) offset)
    in
    match parse_blocks file_def.blocks [] 0 with
    | Ok blocks -> Ok { name = file_def.name; blocks }
    | Error (err, blocks) -> Error (err, { name = file_def.name; blocks })

end