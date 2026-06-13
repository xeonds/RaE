open Ast

type input_scheme = File of string | Inline of string
type binary_source = File of string | Stdin
type config = { scheme: input_scheme; binary: binary_source; output: string option }
exception Engine_error of string

let construct_defs : Ast.def list ref = ref []
let set_construct_defs defs = construct_defs := defs

(* ---------- file I/O ---------- *)
let read_file filename =
  let ic = open_in filename in
  let content = really_input_string ic (in_channel_length ic) in close_in ic; content

let read_binary_file filename =
  let ic = open_in_bin filename in let len = in_channel_length ic in
  let bytes = Bytes.create len in really_input ic bytes 0 len; close_in ic; bytes

(* ---------- command line ---------- *)
let parse_script_file filename =
  let content = read_file filename in
  if String.length content >= 2 && String.sub content 0 2 = "#!" then
    let lines = String.split_on_char '\n' content in
    (match lines with first :: rest when String.length first >= 2 && String.sub first 0 2 = "#!" ->
      String.concat "\n" rest | _ -> content)
  else content

let process_imports content =
  let import_re = Str.regexp "import '[^']*'" in
  let rec find_all acc pos = try
    let _ = Str.search_forward import_re content pos in
    let matched = Str.matched_string content in
    let filename = String.sub matched 8 (String.length matched - 9) in
    find_all (filename :: acc) (Str.match_end())
  with Not_found -> List.rev acc in
  let imports = find_all [] 0 in
  List.fold_left (fun acc filename -> acc ^ "\n" ^ read_file filename) content imports

(* ---------- helpers ---------- *)
let value_to_bytes v = match v with
  | VBytes b -> b | VString s -> Bytes.of_string s
  | VInt n -> Bytes.of_string (string_of_int n)
  | VInt32 n -> Bytes.of_string (Int32.to_string n)
  | VInt64 n -> Bytes.of_string (Int64.to_string n)
  | VArray items ->
    let buf = Buffer.create 64 in
    List.iter (fun item -> match item with
      | VInt n -> Buffer.add_string buf (string_of_int n)
      | VInt32 n -> Buffer.add_string buf (Int32.to_string n)
      | VInt64 n -> Buffer.add_string buf (Int64.to_string n)
      | VString s -> Buffer.add_string buf s | _ -> ()) items;
    Bytes.of_string (Buffer.contents buf)
  | VObj fields ->
    let buf = Buffer.create 128 in
    List.iter (fun (k,v) -> Buffer.add_string buf k; Buffer.add_string buf "=";
      match v with VInt n -> Buffer.add_string buf (string_of_int n) | VString s -> Buffer.add_string buf s | _ -> ())
      (List.rev fields);
    Bytes.of_string (Buffer.contents buf)
  | VNull -> Bytes.of_string "null" | VFloat f -> Bytes.of_string (string_of_float f)

let serialize_value v _env = match v with VBytes b -> b | _ -> value_to_bytes v

let crc32 bytes =
  let t = Array.make 256 0l in
  for i = 0 to 255 do
    let c = ref (Int32.of_int i) in
    for _j = 0 to 7 do
      c := if Int32.logand !c 1l <> 0l then Int32.logxor (Int32.shift_right_logical !c 1) 0xEDB88320l
           else Int32.shift_right_logical !c 1
    done;
    t.(i) <- !c
  done;
  let crc = ref 0xFFFFFFFFl in
  for i = 0 to Bytes.length bytes - 1 do
    let idx = Int32.to_int (Int32.logxor !crc (Int32.of_int (Char.code (Bytes.get bytes i)))) land 0xFF in
    crc := Int32.logxor (Int32.shift_right_logical !crc 8) t.(idx)
  done;
  Int32.logxor !crc 0xFFFFFFFFl

let reverse_bytes b =
  let len = Bytes.length b in
  let r = Bytes.make len '\000' in
  for i = 0 to len - 1 do Bytes.set r i (Bytes.get b (len - 1 - i)) done;
  r

let write_uint value size =
  let buf = Bytes.make size '\000' in let v = ref value in
  for i = 0 to size - 1 do
    Bytes.set buf i (Char.chr (Int64.to_int (Int64.logand !v 0xFFL)));
    v := Int64.shift_right_logical !v 8
  done; buf

let size_of_type = function
  | I8|U8 -> 1 | I16|U16 -> 2 | I32|U32|F32 -> 4 | I64|U64|F64 -> 8
  | BytesType (Some (IntLit (n,_))) -> n | StringType _|BytesType _ -> 0
  | ArrayType _ -> 0 | StructType _ -> 0 | TemplateType _ -> 0

(* ---------- expression evaluation ---------- *)
type struct_info = { fields: field_decl list; variants: (identifier * variant_case list) list }

let rec lookup_struct name defs = match defs with
  | [] -> raise (Engine_error (Printf.sprintf "Struct '%s' not found" name))
  | (Ast.StructDef s) :: _ when s.name = name ->
    { fields = List.filter_map (function Ast.Field f -> Some f | _ -> None) s.members;
      variants = List.filter_map (function Ast.Variant (t,c,_) -> Some (t,c) | _ -> None) s.members }
  | _ :: rest -> lookup_struct name rest

let rec lookup_template name args_val defs = match defs with
  | [] -> raise (Engine_error (Printf.sprintf "Template '%s' not found" name))
  | (Ast.TemplateDef t) :: _ when t.name = name ->
    let subst = try List.combine t.params args_val with Invalid_argument _ -> raise (Engine_error "Template arg count mismatch") in
    let rec subst_type = function
      | Ast.StructType n -> (try List.assoc n subst with Not_found -> Ast.StructType n)
      | Ast.ArrayType elem -> Ast.ArrayType (subst_type elem)
      | other -> other in
    List.map (fun f -> { f with field_type = subst_type f.field_type }) t.members
  | _ :: rest -> lookup_template name args_val rest

let rec set_path path_expr env current rhs = match path_expr with
  | Ident ("_", _) -> rhs
  | Ident (name, _) ->
    (match current with VObj fields -> VObj ((name, rhs) :: List.remove_assoc name fields) | _ -> current)
  | FieldAccess (base, field, _) ->
    let base_val = eval_expr base env (ref current) in
    let new_base_val = match base_val with
      | VObj fields -> VObj ((field, rhs) :: List.remove_assoc field fields) | _ -> base_val in
    set_path base env current new_base_val
  | ArrayAccess (base, idx, _) ->
    let i = eval_expr idx env (ref current) in
    let base_val = eval_expr base env (ref current) in
    let new_base_val = match base_val, i with
      | VArray items, VInt n -> VArray (List.mapi (fun j v -> if j = n then rhs else v) items) | _ -> base_val in
    set_path base env current new_base_val
  | _ -> current

and eval_expr expr env current = match expr with
  | IntLit (n, _) -> VInt n
  | FloatLit (f, _) -> VFloat f | StringLit (s, _) -> VString s
  | Ident (id, _) ->
    (match id with
     | "_" -> !current
     | _ -> (match !current with
        | VObj fields -> (try List.assoc id fields with Not_found -> try List.assoc id env with Not_found -> VNull)
        | _ -> (try List.assoc id env with Not_found -> VNull)))
  | BinaryOp (op, e1, e2, _) -> eval_binary_op op (eval_expr e1 env current) (eval_expr e2 env current)
  | FieldAccess (e, f, _) ->
    (match eval_expr e env current with
     | VObj fields -> (try List.assoc f fields with Not_found -> VNull)
     | VArray items -> VArray (List.map (fun item ->
         match item with VObj fields -> (try List.assoc f fields with Not_found -> VNull) | _ -> VNull) items)
     | _ -> VNull)
  | ArrayAccess (e, idx, _) ->
    (match eval_expr e env current, eval_expr idx env current with
     | VArray items, VInt n -> (try List.nth items n with Failure _ -> VNull) | _ -> VNull)
  | FuncCall (name, args, _) -> eval_builtin name args env current
  | Pipe (e1, e2, _) -> eval_expr e2 env (ref (eval_expr e1 env current))
  | BlockLit (lets, body, _) ->
    let env' = List.fold_left (fun env (id,e) -> (id, eval_expr e env current) :: env) env lets in
    (match List.rev body with
     | [] -> VNull | last :: rest ->
       List.iter (fun e -> ignore (eval_expr e env' current)) (List.rev rest);
       eval_expr last env' current)
  | Assign (e1, e2, _) -> let rhs = eval_expr e2 env current in current := set_path e1 env !current rhs; !current
  | Construct (name, field_vals, _) ->
    let vals = List.map (fun (k, e) -> (k, eval_expr e env current)) field_vals in
    construct_binary name vals !construct_defs
  | UnaryOp (op, e, _) ->
    let v = eval_expr e env current in
    (match op, v with
     | Neg, VInt n -> VInt (-n)
     | Neg, VInt32 n -> VInt32 (Int32.neg n)
     | Neg, VInt64 n -> VInt64 (Int64.neg n)
     | Neg, VFloat f -> VFloat (-. f)
     | Not, VInt n -> VInt (if n = 0 then 1 else 0)
     | BitNot, VInt n -> VInt (lnot n land 0xFF)
     | BitNot, VInt32 n -> VInt32 (Int32.lognot n)
     | BitNot, VInt64 n -> VInt64 (Int64.lognot n)
     | _ -> VNull)

and eval_binary_op op v1 v2 =
  let vi n = VInt n and vi32 n = VInt32 n and vi64 n = VInt64 n in
  match op, v1, v2 with
  | Add, VInt a, VInt b -> vi (a+b) | Sub, VInt a, VInt b -> vi (a-b)
  | Mul, VInt a, VInt b -> vi (a*b) | Div, VInt a, VInt b -> vi (a/b)
  | Add, VInt32 a, VInt32 b -> vi32 (Int32.add a b) | Sub, VInt32 a, VInt32 b -> vi32 (Int32.sub a b)
  | Mul, VInt32 a, VInt32 b -> vi32 (Int32.mul a b) | Div, VInt32 a, VInt32 b -> vi32 (Int32.div a b)
  | Add, VInt64 a, VInt64 b -> vi64 (Int64.add a b) | Sub, VInt64 a, VInt64 b -> vi64 (Int64.sub a b)
  | Mul, VInt64 a, VInt64 b -> vi64 (Int64.mul a b) | Div, VInt64 a, VInt64 b -> vi64 (Int64.div a b)
  | Add, VInt32 a, VInt b -> vi32 (Int32.add a (Int32.of_int b)) | Add, VInt a, VInt32 b -> vi32 (Int32.add (Int32.of_int a) b)
  | Sub, VInt32 a, VInt b -> vi32 (Int32.sub a (Int32.of_int b)) | Mul, VInt32 a, VInt b -> vi32 (Int32.mul a (Int32.of_int b))
  | Div, VInt32 a, VInt b -> vi32 (Int32.div a (Int32.of_int b))
  | Add, VInt64 a, VInt b -> vi64 (Int64.add a (Int64.of_int b)) | Add, VInt a, VInt64 b -> vi64 (Int64.add (Int64.of_int a) b)
  | Eq, VInt a, VInt b -> vi (if a=b then 1 else 0) | Lt, VInt a, VInt b -> vi (if a<b then 1 else 0) | Gt, VInt a, VInt b -> vi (if a>b then 1 else 0)
  | Eq, VInt32 a, VInt32 b -> vi (if a=b then 1 else 0) | Lt, VInt32 a, VInt32 b -> vi (if a<b then 1 else 0)
  | Eq, VInt64 a, VInt64 b -> vi (if a=b then 1 else 0)
  | Eq, VInt32 a, VInt b -> vi (if Int32.to_int a=b then 1 else 0) | Eq, VInt a, VInt32 b -> vi (if a=Int32.to_int b then 1 else 0)
  | Eq, VInt64 a, VInt b -> vi (if Int64.to_int a=b then 1 else 0) | Eq, VInt a, VInt64 b -> vi (if a=Int64.to_int b then 1 else 0)
  | Eq, VString a, VString b -> vi (if a=b then 1 else 0)
  | Neq, VInt a, VInt b -> vi (if a<>b then 1 else 0)
  | Neq, VInt32 a, VInt32 b -> vi (if a<>b then 1 else 0)
  | Neq, VInt64 a, VInt64 b -> vi (if a<>b then 1 else 0)
  | Le, VInt a, VInt b -> vi (if a<=b then 1 else 0)
  | Le, VInt32 a, VInt32 b -> vi (if a<=b then 1 else 0)
  | Ge, VInt a, VInt b -> vi (if a>=b then 1 else 0)
  | Ge, VInt32 a, VInt32 b -> vi (if a>=b then 1 else 0)
  | And, VInt a, VInt b -> vi (if a<>0 && b<>0 then 1 else 0)
  | Or, VInt a, VInt b -> vi (if a<>0 || b<>0 then 1 else 0)
  | BitAnd, VInt a, VInt b -> vi (a land b)
  | BitAnd, VInt32 a, VInt32 b -> vi32 (Int32.logand a b)
  | BitAnd, VInt64 a, VInt64 b -> vi64 (Int64.logand a b)
  | BitXor, VInt a, VInt b -> vi (a lxor b)
  | BitXor, VInt32 a, VInt32 b -> vi32 (Int32.logxor a b)
  | BitXor, VInt64 a, VInt64 b -> vi64 (Int64.logxor a b)
  | LShift, VInt a, VInt b -> vi (a lsl b)
  | LShift, VInt32 a, VInt b -> vi32 (Int32.shift_left a b)
  | LShift, VInt64 a, VInt b -> vi64 (Int64.shift_left a b)
  | RShift, VInt a, VInt b -> vi (a lsr b)
  | RShift, VInt32 a, VInt b -> vi32 (Int32.shift_right_logical a b)
  | RShift, VInt64 a, VInt b -> vi64 (Int64.shift_right_logical a b)
  | _ -> VNull

and eval_builtin name args env current = match name, args with
  | "expand", [e] -> (match eval_expr e env current with VArray items -> VArray items | _ -> VArray [VNull])
  | "select", [e] ->
    (match !current with VArray items ->
       VArray (List.filter (fun item -> match eval_expr e env (ref item) with VInt 0 -> false | _ -> true) items)
     | _ -> !current)
  | "echo", [e] ->
    let v = eval_expr e env current in
    (match v with
     | VInt n -> Printf.printf "%d\n" n | VInt32 n -> Printf.printf "%ld\n" n | VInt64 n -> Printf.printf "%Ld\n" n
     | VFloat f -> Printf.printf "%f\n" f | VString s -> Printf.printf "%s\n" s
     | VBytes b -> Printf.printf "%s\n" (Bytes.to_string b)
     | VArray items -> Printf.printf "["; List.iteri (fun i item ->
         if i > 0 then Printf.printf ", "; match item with VInt n -> Printf.printf "%d" n | VInt32 n -> Printf.printf "%ld" n | VString s -> Printf.printf "%s" s | _ -> Printf.printf "?") items; Printf.printf "]\n"
     | VObj fields -> Printf.printf "<obj %d>\n" (List.length fields) | VNull -> Printf.printf "null\n"); !current
  | "align", [e; n] ->
    (match eval_expr e env current, eval_expr n env current with VInt x, VInt y -> VInt ((x+y-1)/y*y) | _ -> VNull)
  | "bswap16", [e] ->
    (match eval_expr e env current with VInt n -> VInt (((n land 0xFF) lsl 8) lor ((n lsr 8) land 0xFF)) | _ -> VNull)
  | "bswap32", [e] ->
    (match eval_expr e env current with VInt32 n -> VInt32 (Int32.of_int
      (((Int32.to_int n) land 0xFF) lsl 24 lor
       (((Int32.to_int n) lsr 8) land 0xFF) lsl 16 lor
       (((Int32.to_int n) lsr 16) land 0xFF) lsl 8 lor
       ((Int32.to_int n) lsr 24))) | _ -> VNull)
   | "crc32", [e] ->
     let bytes = value_to_bytes (eval_expr e env current) in VInt32 (crc32 bytes)
  | "each", [Ident (varname, _); arr; blk] ->
    (match eval_expr arr env current with VArray items ->
       VArray (List.map (fun item -> eval_expr blk ((varname,item)::env) (ref item)) items) | _ -> VNull)
  | "checksum", [e] ->
    let bytes = value_to_bytes (eval_expr e env current) in
    let sum = ref 0 in for i = 0 to Bytes.length bytes - 1 do sum := !sum + Char.code (Bytes.get bytes i) done; VInt (!sum land 0xFFFF)
  | "checksum", [] ->
    let bytes = value_to_bytes !current in
    let sum = ref 0 in for i = 0 to Bytes.length bytes - 1 do sum := !sum + Char.code (Bytes.get bytes i) done; VInt (!sum land 0xFFFF)
  | "write", [e] ->
    let v = eval_expr e env current in
    let bytes = (match !current with
      | VObj fields ->
        let file_name = try match List.assoc "__file__" env with VString s -> s | _ -> "" with Not_found -> "" in
        if file_name <> "" then
          (match construct_binary file_name fields !construct_defs with VBytes b -> b | _ -> serialize_value !current env)
        else serialize_value !current env
      | _ -> serialize_value !current env) in
    (match v with VString filename -> let oc = open_out_bin filename in output oc bytes 0 (Bytes.length bytes); close_out oc; VInt 0 | _ -> VNull)
  | "object", _ -> VObj []
  | _ -> VNull

and write_value typ v = match typ with
  | I8 | U8 -> (match v with VInt n -> write_uint (Int64.of_int n) 1 | _ -> Bytes.make 1 '\000')
  | I16 | U16 -> (match v with VInt n -> write_uint (Int64.of_int n) 2 | _ -> Bytes.make 2 '\000')
  | I32 | U32 -> (match v with VInt32 n -> write_uint (Int64.of_int32 n) 4 | VInt n -> write_uint (Int64.of_int n) 4 | _ -> Bytes.make 4 '\000')
  | F32 -> (match v with VFloat f -> write_uint (Int64.bits_of_float f) 4 | _ -> Bytes.make 4 '\000')
  | I64 | U64 -> (match v with VInt64 n -> write_uint n 8 | VInt n -> write_uint (Int64.of_int n) 8 | _ -> Bytes.make 8 '\000')
  | F64 -> (match v with VFloat f -> write_uint (Int64.bits_of_float f) 8 | _ -> Bytes.make 8 '\000')
  | StringType _ | BytesType _ -> (match v with VString s -> Bytes.of_string s | VBytes b -> b | _ -> Bytes.empty)
  | _ -> raise (Engine_error (Printf.sprintf "Cannot serialize type %s" (match typ with I8 -> "i8" | U8 -> "u8" | _ -> "?")))

and construct_binary name field_vals struct_defs =
  let info = try lookup_struct name struct_defs
    with _ -> raise (Engine_error (Printf.sprintf "Struct '%s' not found for construction" name)) in
  let total = ref 0 in
  let cur_off = ref 0 in
  List.iter (fun f ->
    let sz = size_of_type f.field_type in
    let off = match f.offset with Fixed n -> n | After _ -> !cur_off | _ -> 0 in
    total := max !total (off + sz);
    cur_off := off + sz) info.fields;
  let buf = Bytes.make !total '\000' in
  cur_off := 0;
  let checksum_fields = ref [] in
  List.iter (fun f ->
    let offset = match f.offset with Fixed n -> n | After _ -> !cur_off | _ -> 0 in
    (match List.find_map (fun attr -> match attr with Ast.Checksum (_, _) -> Some offset | _ -> None) f.attributes with
     | Some cs_off -> checksum_fields := (cs_off, f) :: !checksum_fields
     | None -> ());
    let evald = (try List.assoc f.name field_vals
      with Not_found -> raise (Engine_error (Printf.sprintf "Field '%s' not provided for construction" f.name))) in
    let raw = match f.field_type with
      | Ast.StructType sn ->
        (match evald with
         | VObj sub -> (match construct_binary sn sub struct_defs with VBytes b -> b | _ -> Bytes.empty)
         | VBytes b -> b
         | _ -> raise (Engine_error (Printf.sprintf "Struct field '%s' requires VObj or VBytes" f.name)))
      | Ast.ArrayType elem ->
        (match evald with VArray items ->
           let buf2 = Buffer.create 256 in
           List.iter (fun item -> Buffer.add_bytes buf2 (write_value elem item)) items;
           Bytes.of_string (Buffer.contents buf2) | _ -> raise (Engine_error "Construction of array requires VArray value"))
      | _ -> write_value f.field_type evald in
    let field_bytes = let is_be = List.exists (fun attr -> match attr with Ast.Endian (BE, _) -> true | _ -> false) f.attributes in
      if is_be then reverse_bytes raw else raw in
    Bytes.blit field_bytes 0 buf offset (Bytes.length field_bytes);
    cur_off := offset + Bytes.length field_bytes) info.fields;
  List.iter (fun (cs_offset, _f) ->
    let cs_val = crc32 (Bytes.sub buf 0 !cur_off) in
    let cs_bytes = write_uint (Int64.of_int32 cs_val) 4 in
    Bytes.blit cs_bytes 0 buf cs_offset (min 4 (Bytes.length buf - cs_offset))) !checksum_fields;
  VBytes buf

and eval_actions actions env current_val =
  let cur = ref current_val in
  match List.rev actions with
  | [] -> VNull | last :: rest ->
    List.iter (fun a -> ignore (eval_expr a env cur)) (List.rev rest);
    eval_expr last env cur

let values_equal a b = match a, b with
  | VInt x, VInt y -> x=y | VInt32 x, VInt32 y -> x=y | VInt64 x, VInt64 y -> x=y
  | VFloat x, VFloat y -> x=y | VString x, VString y -> x=y
  | VInt32 x, VInt y -> Int32.to_int x=y | VInt x, VInt32 y -> x=Int32.to_int y
  | VInt64 x, VInt y -> Int64.to_int x=y | VInt x, VInt64 y -> x=Int64.to_int y
  | _ -> false

(* ---------- schema evaluation ---------- *)
let compute_offset off_expr prev_offset base_offset env field_ends = match off_expr with
  | Fixed n -> base_offset + n
  | After name ->
    (if name = "" then prev_offset
     else try List.assoc name field_ends with Not_found -> prev_offset)
  | Align e -> let n = match eval_expr e env (ref VNull) with VInt n -> n | _ -> 1 in ((prev_offset + n - 1) / n) * n
  | Dynamic e ->
    match eval_expr e env (ref VNull) with VInt n -> n | _ -> prev_offset

let field_endian attrs =
  List.fold_left (fun acc attr -> match attr with Ast.Endian (k,_) -> Some k | _ -> acc) None attrs

let read_uint data offset size endian =
  let acc = ref Int64.zero in
  for i = 0 to size - 1 do
    let pos = match endian with Some BE -> offset+size-1-i | _ -> offset+i in
    acc := Int64.logor !acc (Int64.shift_left (Int64.of_int (Char.code (Bytes.get data pos))) (8*i))
  done; !acc

let read_sint data offset size endian =
  let raw = read_uint data offset size endian in let bits = size*8 in
  let sign_bit = Int64.shift_left Int64.one (bits-1) in
  if Int64.logand raw sign_bit <> Int64.zero then Int64.logor raw (Int64.lognot (Int64.sub sign_bit Int64.one)) else raw

let parse_value typ data endian = match typ with
  | I8 -> let v = Char.code (Bytes.get data 0) in VInt (if v land 0x80 <> 0 then v-256 else v)
  | U8 -> VInt (Char.code (Bytes.get data 0))
  | I16 -> VInt (Int64.to_int (read_sint data 0 2 endian)) | U16 -> VInt (Int64.to_int (read_uint data 0 2 endian))
  | I32 -> VInt32 (Int64.to_int32 (read_sint data 0 4 endian)) | U32 -> VInt32 (Int64.to_int32 (read_uint data 0 4 endian))
  | F32 -> VFloat (Int32.float_of_bits (Int64.to_int32 (read_uint data 0 4 endian)))
  | I64 -> VInt64 (read_sint data 0 8 endian) | U64 -> VInt64 (read_uint data 0 8 endian)
  | F64 -> VFloat (Int64.float_of_bits (read_uint data 0 8 endian))
  | StringType _ -> VString (Bytes.to_string data) | BytesType _ -> VBytes data
  | _ -> raise (Engine_error "Cannot parse unsupported type")

let parse_field_bytes typ endian data offset =
  let size = match typ with StringType _|BytesType None -> Bytes.length data - offset | _ -> size_of_type typ in
  if offset + size > Bytes.length data then
    raise (Engine_error (Printf.sprintf "Field read out of bounds: offset=%d size=%d len=%d" offset size (Bytes.length data)));
  let buf = Bytes.sub data offset size in parse_value typ buf endian

let parse_binary schema bytes =
  let struct_registry = schema.definitions in
  let rec parse_fields fields data base_offset prev_offset env field_ends = match fields with
    | [] -> (env, prev_offset, field_ends)
    | f :: rest ->
      let offset = compute_offset f.offset prev_offset base_offset env field_ends in
      let val_ = parse_field f data offset env (field_endian f.attributes) in
      let size = size_of_field f data offset env in
      let new_env = (f.name, val_) :: env in
      let new_ends = (f.name, offset + size) :: field_ends in
      (match f.expects with
       | Some e -> let expected = eval_expr e new_env (ref VNull) in
         if not (values_equal val_ expected) then
           raise (Engine_error (Printf.sprintf "Field '%s' expected value doesn't match" f.name))
       | None -> ());
      parse_fields rest data base_offset (offset + size) new_env new_ends
  and parse_field f data offset env endian = match f.field_type with
    | Ast.TemplateType (name, args) ->
       let type_args = List.map (fun a -> Ast.StructType a) args in
       let members = lookup_template name type_args struct_registry in
       let struct_env, _, _ = parse_fields members data offset offset [] [] in VObj struct_env
    | Ast.StructType name ->
      let info = lookup_struct name struct_registry in
      let struct_env, _, struct_ends = parse_fields info.fields data offset offset [] [] in
      dispatch_variants info data offset struct_env struct_ends
    | Ast.ArrayType elem_type ->
      let count = ref 1 in
      List.iter (fun attr -> match attr with Ast.Count (expr,_) ->
        (match eval_expr expr env (ref VNull) with VInt n -> count := n | _ -> ()) | _ -> ()) f.attributes;
      let elems = ref [] in let off = ref offset in
      for _i = 1 to !count do
        let v = match elem_type with
          | Ast.StructType name ->
            let info = lookup_struct name struct_registry in
            let env, _, _ = parse_fields info.fields data !off !off [] [] in VObj env
          | _ -> parse_field_bytes elem_type endian data !off in
        elems := v :: !elems;
        off := !off + (match elem_type with
          | Ast.StructType name ->
            let info = lookup_struct name struct_registry in
            let _, fo, _ = parse_fields info.fields data !off !off [] [] in fo - !off
          | _ -> size_of_type elem_type)
      done; VArray (List.rev !elems)
    | _ -> parse_field_bytes f.field_type endian data offset
  and size_of_field f data offset env = match f.field_type with
    | Ast.TemplateType (name, args) ->
      let type_args = List.map (fun a -> Ast.StructType a) args in
      let members = lookup_template name type_args struct_registry in
      let _, fo, _ = parse_fields members data offset offset [] [] in fo - offset
    | Ast.StructType name ->
      let info = lookup_struct name struct_registry in
      let _, fo, _ = parse_fields info.fields data offset offset [] [] in fo - offset
    | Ast.ArrayType elem_type ->
      let count = ref 1 in
      List.iter (fun attr -> match attr with Ast.Count (expr,_) ->
        (match eval_expr expr env (ref VNull) with VInt n -> count := n | _ -> ()) | _ -> ()) f.attributes;
      let elem_size = match elem_type with
        | Ast.StructType name ->
          let info = lookup_struct name struct_registry in
          let _, fo, _ = parse_fields info.fields data offset offset [] [] in fo - offset | _ -> size_of_type elem_type in
      (!count) * elem_size
    | StringType _ | BytesType _ ->
      (match List.find_map (fun attr -> match attr with Ast.Count (IntLit (n,_),_) -> Some n | _ -> None) f.attributes with
       | Some n -> n | None -> Bytes.length data - offset)
    | _ -> size_of_type f.field_type
  and dispatch_variants info data base_offset env field_ends =
    let final_env = ref env in
    List.iter (fun (tag_name, cases) ->
      let tag_val = try List.assoc tag_name !final_env with Not_found -> VNull in
      List.iter (fun case ->
        let expected = eval_expr case.pattern [] (ref VNull) in
        if values_equal tag_val expected then
          let case_env, _, _ = parse_fields case.fields data base_offset base_offset !final_env field_ends in
          final_env := case_env) cases) info.variants;
    VObj !final_env
  in let env, _, _ = parse_fields schema.fields bytes 0 0 [] [] in env
