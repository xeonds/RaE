%{
open Ast

let mk_loc sp ep =
  { loc_start = { pos_fname = sp.Lexing.pos_fname; pos_lnum = sp.Lexing.pos_lnum;
                  pos_bol = sp.Lexing.pos_bol; pos_cnum = sp.Lexing.pos_cnum };
    loc_end   = { pos_fname = ep.Lexing.pos_fname; pos_lnum = ep.Lexing.pos_lnum;
                  pos_bol = ep.Lexing.pos_bol; pos_cnum = ep.Lexing.pos_cnum } }
%}

%token <string> IDENT
%token <int> INT
%token <float> FLOAT
%token <string> STRING_LIT

%token FILE STRUCT ENUM BITFIELD TEMPLATE VARIANT
%token AFTER ALIGN COUNT VALIDATE ENDIAN LEND BEND LET IN
%token I8 I16 I32 I64 U8 U16 U32 U64 F32 F64
%token STRING BYTES ARRAY
%token LBRACE RBRACE LPAREN RPAREN LBRACK RBRACK
%token LT GT EQEQ EQUAL COLON SEMICOLON COMMA DOT PIPE AT BANG
%token PLUS MINUS STAR SLASH
%token FATARROW EOF

%start <Ast.program> program

%%

(* ============== top level ============== *)

program:
  | files = list(file_def) actions = separated_list(SEMICOLON, expr) option(SEMICOLON) EOF
    { { files; actions; loc = mk_loc $startpos $endpos } }
  ;

(* ============== file / defs / fields ============== *)

file_def:
  | FILE name = IDENT LBRACE defs = list(def) fields = list(field_decl) RBRACE
    { { name; definitions = defs; fields; loc = mk_loc $startpos $endpos } }
  ;

def:
  | struct_def    { $1 }
  | enum_def      { $1 }
  | bitfield_def  { $1 }
  | template_def  { $1 }
  ;

(* ---------- struct ---------- *)

struct_def:
  | STRUCT name = IDENT params = option(type_params) cond = option(struct_condition)
    LBRACE members = list(struct_item) RBRACE
    { StructDef { name; params = Option.value params ~default:[];
                  members; condition = cond; loc = mk_loc $startpos $endpos } }
  ;

struct_condition:
  | LPAREN e = expr RPAREN { e }
  ;

type_params:
  | LT ps = separated_list(COMMA, IDENT) GT { ps }
  ;

struct_item:
  | f = field_decl  { Field f }
  | VARIANT LPAREN tag = IDENT RPAREN LBRACE cases = list(variant_case) RBRACE
    { Variant(tag, cases, mk_loc $startpos $endpos) }
  ;

variant_case:
  | pat = expr FATARROW LBRACE fs = list(field_decl) RBRACE
    { { pattern = pat; fields = fs; loc = mk_loc $startpos $endpos } }
  ;

(* ---------- enum ---------- *)

enum_def:
  | ENUM name = IDENT COLON typ = type_expr LBRACE ms = list(enum_member) RBRACE
    { EnumDef { name; base_type = typ; members = ms; loc = mk_loc $startpos $endpos } }
  ;

enum_member:
  | name = IDENT EQUAL v = expr SEMICOLON
    { { name; value = v; loc = mk_loc $startpos $endpos } }
  ;

(* ---------- bitfield ---------- *)

bitfield_def:
  | BITFIELD name = IDENT LBRACE fs = list(bitfield_item) RBRACE
    { BitFieldDef { name; fields = fs; loc = mk_loc $startpos $endpos } }
  ;

bitfield_item:
  | name = IDENT COLON sz = INT SEMICOLON
    { let loc = mk_loc $startpos $endpos in
      { name; field_type = I8; expects = None; attributes = []; offset = Fixed sz; loc } }
  ;

(* ---------- template ---------- *)

template_def:
  | TEMPLATE LT param = IDENT GT name = IDENT LBRACE ms = list(field_decl) RBRACE
    { TemplateDef { param; name; members = ms; loc = mk_loc $startpos $endpos } }
  ;

(* ============== field declaration ============== *)

field_decl:
  | name = IDENT COLON typ = type_expr
    AT off = offset_expr
    attrs = option(attributes)
    exp = option(expects)
    option(SEMICOLON)
    { { name; field_type = typ; expects = exp;
        attributes = Option.value attrs ~default:[]; offset = off;
        loc = mk_loc $startpos $endpos } }
  ;

expects:
  | EQEQ e = expr { e }
  ;

offset_expr:
  | i = INT { Fixed i }
  | AFTER LPAREN f = IDENT RPAREN { After f }
  | ALIGN LPAREN e = expr RPAREN { Align e }
  | LPAREN e = expr RPAREN { Dynamic e }
  ;

attributes:
  | LBRACK attrs = separated_list(COMMA, attribute) RBRACK { attrs }
  ;

attribute:
  | key = attr_key EQUAL e = expr
    { let loc = mk_loc $startpos $endpos in
      match key with
      | "count"    -> Count(e, loc)
      | "if"       -> Cond(e, loc)
      | "validate" -> Validate(e, loc)
      | _          -> failwith ("Unknown attribute: " ^ key) }
  | ENDIAN EQUAL k = endian_kind
    { Endian(k, mk_loc $startpos $endpos) }
  ;

endian_kind:
  | LEND { LE }
  | BEND { BE }
  ;

attr_key:
  | COUNT    { "count" }
  | VALIDATE { "validate" }
  | IDENT    { $1 }
  ;

(* ============== type expressions ============== *)

type_expr:
  | basic_type { $1 }
  | ARRAY LT t = type_expr GT
    { ArrayType t }
  | STRING LPAREN enc = option(STRING_LIT) RPAREN
    { StringType(Option.value enc ~default:"utf8") }
  | STRING
    { StringType("utf8") }
  | BYTES LPAREN sz = option(expr) RPAREN
    { BytesType sz }
  | BYTES
    { BytesType None }
  | name = IDENT params = option(type_params)
    { match params with
      | None -> StructType name
      | Some p -> TemplateType(name, p) }
  ;

basic_type:
  | I8 { I8 } | I16 { I16 } | I32 { I32 } | I64 { I64 }
  | U8 { U8 } | U16 { U16 } | U32 { U32 } | U64 { U64 }
  | F32 { F32 } | F64 { F64 }
  ;

(* ============== expressions ============== *)

expr:
  | e = pipe_expr { e }
  ;

pipe_expr:
  | e = assign_expr PIPE r = pipe_expr
    { Pipe(e, r, mk_loc $startpos $endpos) }
  | e = assign_expr { e }
  ;

assign_expr:
  | e = cmp_expr EQUAL r = cmp_expr
    { Assign(e, r, mk_loc $startpos $endpos) }
  | e = cmp_expr { e }
  ;

cmp_expr:
  | e = add_expr op = cmp_op r = add_expr
    { BinaryOp(op, e, r, mk_loc $startpos $endpos) }
  | e = add_expr { e }
  ;

add_expr:
  | e = mul_expr op = add_op r = add_expr
    { BinaryOp(op, e, r, mk_loc $startpos $endpos) }
  | e = mul_expr { e }
  ;

mul_expr:
  | e = unary_expr op = mul_op r = mul_expr
    { BinaryOp(op, e, r, mk_loc $startpos $endpos) }
  | e = unary_expr { e }
  ;

unary_expr:
  | op = unary_op e = unary_expr
    { UnaryOp(op, e, mk_loc $startpos $endpos) }
  | e = postfix_expr { e }
  ;

postfix_expr:
  | e = postfix_expr DOT f = IDENT
    { FieldAccess(e, f, mk_loc $startpos $endpos) }
  | e = postfix_expr LBRACK RBRACK
    { FuncCall("expand", [e], mk_loc $startpos $endpos) }
  | e = postfix_expr LBRACK idx = expr RBRACK
    { ArrayAccess(e, idx, mk_loc $startpos $endpos) }
  | e = primary_expr { e }
  ;

primary_expr:
  | DOT IDENT
    { FieldAccess(Ident("_", mk_loc $startpos $endpos), $2, mk_loc $startpos $endpos) }
  | DOT LBRACK RBRACK
    { FuncCall("expand", [Ident("_", mk_loc $startpos $endpos)], mk_loc $startpos $endpos) }
  | DOT LBRACK idx = expr RBRACK
    { ArrayAccess(Ident("_", mk_loc $startpos $endpos), idx, mk_loc $startpos $endpos) }
  | DOT
    { Ident("_", mk_loc $startpos $endpos) }
  | i = INT
    { IntLit(i, mk_loc $startpos $endpos) }
  | f = FLOAT
    { FloatLit(f, mk_loc $startpos $endpos) }
  | s = STRING_LIT
    { StringLit(s, mk_loc $startpos $endpos) }
  | id = IDENT LPAREN args = separated_list(COMMA, expr) RPAREN
    { FuncCall(id, args, mk_loc $startpos $endpos) }
  | id = IDENT
    { Ident(id, mk_loc $startpos $endpos) }
  | LPAREN e = expr RPAREN { e }
  | AT name = at_func_name LPAREN id = IDENT IN arr = expr RPAREN
    LBRACE body = separated_list(SEMICOLON, expr) RBRACE
    { let blk = BlockLit([], body, mk_loc $startpos $endpos) in
      FuncCall(name, [Ident(id, mk_loc $startpos $endpos); arr; blk], mk_loc $startpos $endpos) }
  | AT _name = at_func_name LBRACE items = separated_list(SEMICOLON, block_item) RBRACE
    { let lets = List.filter_map (function BLet (id, e) -> Some (id, e) | _ -> None) items in
      let body = List.filter_map (function BExpr e -> Some e | _ -> None) items in
      BlockLit(lets, body, mk_loc $startpos $endpos) }
  | AT name = at_func_name LPAREN args = separated_list(COMMA, expr) RPAREN
    { FuncCall(name, args, mk_loc $startpos $endpos) }
  | AT name = at_func_name
    { FuncCall(name, [], mk_loc $startpos $endpos) }
  ;

block_item:
  | LET id = IDENT EQUAL e = expr { BLet (id, e) }
  | e = expr { BExpr e }
  ;

at_func_name:
  | IDENT    { $1 }
  | ALIGN    { "align" }
  | AFTER    { "after" }
  | COUNT    { "count" }
  | VALIDATE { "validate" }
  | ENDIAN   { "endian" }
  ;

(* ---------- operators ---------- *)

cmp_op:
  | EQEQ { Eq } | LT { Lt } | GT { Gt }
  ;

add_op:
  | PLUS { Add } | MINUS { Sub }
  ;

mul_op:
  | STAR { Mul } | SLASH { Div }
  ;

unary_op:
  | BANG { Not } | MINUS { Neg }
  ;
