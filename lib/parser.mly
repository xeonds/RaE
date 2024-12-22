%{
open Ast

let make_loc startpos endpos = 
  let loc_start = {
    pos_fname = startpos.Lexing.pos_fname;
    pos_lnum = startpos.Lexing.pos_lnum;
    pos_bol = startpos.Lexing.pos_bol;
    pos_cnum = startpos.Lexing.pos_cnum;
  } in
  let loc_end = {
    pos_fname = endpos.Lexing.pos_fname;
    pos_lnum = endpos.Lexing.pos_lnum;
    pos_bol = endpos.Lexing.pos_bol;
    pos_cnum = endpos.Lexing.pos_cnum;
  } in
  { loc_start; loc_end }

let make_id name loc = (name, loc)
%}

%token <string> IDENT
%token <int> INT
%token <float> FLOAT
%token <string> STRING_LIT

%token FILE STRUCT ENUM BITFIELD IF TEMPLATE VARIANT
%token I8 I16 I32 I64 U8 U16 U32 U64 F32 F64 HEX DEC OCT BIN
%token STRING BYTES ARRAY
%token LBRACE RBRACE LPAREN RPAREN LBRACK RBRACK
%token LT GT EQUAL COLON SEMICOLON COMMA DOT AT BANG MINUS
%token FATARROW EOF

%start <Ast.program> program

%%

program:
  | files = file_def* a=expr* EOF
    { { files; actions=a; loc = make_loc $startpos $endpos } }
;

file_def:
  | FILE name = identifier LBRACE defs = def* RBRACE
    { { name; definitions = defs; loc = make_loc $startpos $endpos } }
;

def:
  | struct_def  { $1 }
  | enum_def    { $1 }
  | bitfield_def { $1 }
  | template_def { $1 }
;

struct_def:
  | STRUCT name = identifier type_params = type_params? 
    condition = struct_condition? LBRACE 
    members = struct_item* RBRACE
    { StructDef {
        name;
        type_params = Option.value type_params ~default:[];
        members;
        condition;
        loc = make_loc $startpos $endpos
      }
    }
;

enum_def:
  | ENUM name = identifier COLON typ = type_expr LBRACE 
    members = enum_variant* RBRACE
    { EnumDef {
        name;
        base_type = typ;
        members;
        loc = make_loc $startpos $endpos
      }
    }
;

enum_variant:
  | name = identifier EQUAL value = expr SEMICOLON
    { { name; value; loc = make_loc $startpos $endpos } }
;

bitfield_def:
  | BITFIELD name = identifier LBRACE 
    fields = bitfield_item* RBRACE
    { BitFieldDef {
        name;
        fields;
        loc = make_loc $startpos $endpos
      }
    }
;

bitfield_item:
  | name = identifier COLON size = INT SEMICOLON
    { 
      let loc = make_loc $startpos $endpos in
      let attrs = [Size(IntLit(size, loc), loc)] in
      { name; attributes = attrs; loc = make_loc $startpos $endpos; offset = Fixed(IntLit(0, loc), loc); type_expr = BasicType(U8, loc) } 
    }
;

template_def:
  | TEMPLATE LT param = type_param GT name = identifier LBRACE 
    members = template_item* RBRACE
    { TemplateDef {
        param;
        name;
        members;
        loc = make_loc $startpos $endpos
      }
    }
;

template_item:
  | name = identifier COLON typ = type_expr 
    attrs = attributes? offset = offset_expr SEMICOLON
    { { name; 
        type_expr = typ;
        attributes = Option.value attrs ~default:[];
        offset;
        loc = make_loc $startpos $endpos 
      } 
    }
;

struct_condition:
  | IF EQUAL LPAREN e = expr RPAREN { e }
;

type_params:
  | LT params = separated_list(COMMA, type_param) GT { params }
;

type_param:
  | name = identifier { { name; loc = make_loc $startpos $endpos } }
;

struct_item:
  | field = field_decl { Field field }
  | VARIANT LPAREN name = identifier RPAREN LBRACE 
    cases = variant_case* RBRACE
    { Variant(name, cases, make_loc $startpos $endpos) }
;

variant_case:
  | pattern = expr FATARROW LBRACE fields = field_decl* RBRACE
    { { pattern; fields; loc = make_loc $startpos $endpos } }
;

field_decl:
  | name = identifier COLON typ = type_expr 
    attrs = attributes? offset = offset_expr SEMICOLON
    { { name; 
        type_expr = typ;
        attributes = Option.value attrs ~default:[];
        offset;
        loc = make_loc $startpos $endpos 
      } 
    }
;

type_expr:
  | basic_type 
    { BasicType($1, make_loc $startpos $endpos) }
  | ARRAY LT t = type_expr GT
    { ArrayType(t, make_loc $startpos $endpos) }
  | STRING LPAREN enc = STRING_LIT? RPAREN
    { StringType(enc, make_loc $startpos $endpos) }
  | BYTES
    { BytesType(make_loc $startpos $endpos) }
  | name = identifier params = type_params?
    { match params with
      | None -> StructType(name, make_loc $startpos $endpos)
      | Some p -> TemplateType(name, p, make_loc $startpos $endpos)
    }
;

basic_type:
  | I8  { I8 }  | I16 { I16 } | I32 { I32 } | I64 { I64 }
  | U8  { U8 }  | U16 { U16 } | U32 { U32 } | U64 { U64 }
  | F32 { F32 } | F64 { F64 }
;

endian_type:
  | IDENT { match $1 with
            | "little" -> ELittle
            | "big" -> EBig
            | "dynamic" -> EDynamic
            | _ -> failwith "Unknown endian type"
          }
radix_type:
  | HEX { Hex }
  | DEC { Dec }
  | OCT { Oct }
  | BIN { Bin }

padding_type:
  | IDENT { match $1 with
            | "none" -> PNone
            | "zero" -> PZero
            | "custom" -> PCustom
            | _ -> failwith "Unknown padding type"
          }

attributes:
  | LBRACK attrs = separated_list(COMMA, attribute) RBRACK { attrs }
;

attribute:
  | IDENT EQUAL expr
    { match $1 with
      | "align" -> Align($3, make_loc $startpos $endpos)
      | "pack" -> Pack($3, make_loc $startpos $endpos)
      | "size" -> Size($3, make_loc $startpos $endpos)
      | "count" -> Count($3, make_loc $startpos $endpos)
      | "stride" -> Stride($3, make_loc $startpos $endpos)
      | "if" -> If($3, make_loc $startpos $endpos)
      | "validate" -> Validate($3, make_loc $startpos $endpos)
      | _ -> failwith "Unknown attribute"
    }
  | IDENT EQUAL endian_type
    { Endian($3, make_loc $startpos $endpos) }
  | IDENT EQUAL STRING_LIT
    { Encoding($3, make_loc $startpos $endpos) }
  | IDENT LPAREN radix_type RPAREN
    { Radix($3, make_loc $startpos $endpos) }
  | IDENT LPAREN padding_type RPAREN
    { Padding($3, make_loc $startpos $endpos) }
  | IDENT LPAREN expr* RPAREN
    { match $1 with
      | "range" -> if List.length $3 = 2 then
                     Range(List.nth $3 0, List.nth $3 1, make_loc $startpos $endpos)
                   else
                     failwith "Range attribute requires 2 arguments"
      | "set" -> Set($3, make_loc $startpos $endpos)
      | _ -> failwith "Unknown attribute"
    }
;

offset_expr:
  | AT INT
    { Fixed(IntLit($2, make_loc $startpos $endpos), 
            make_loc $startpos $endpos) }
  | AT IDENT LPAREN expr RPAREN
    { match $2 with
      | "align" -> Align($4, make_loc $startpos $endpos)
      | _ -> Dynamic($4, make_loc $startpos $endpos)
    }
  | AT IDENT LPAREN identifier RPAREN
    { Align(Identifier($4), make_loc $startpos $endpos) }
;

expr:
  | INT
    { IntLit($1, make_loc $startpos $endpos) }
  | FLOAT
    { FloatLit($1, make_loc $startpos $endpos) }
  | STRING_LIT
    { StringLit($1, make_loc $startpos $endpos) }
  | identifier
    { Identifier($1) }
  | expr binary_op expr
    { BinaryOp($2, $1, $3, make_loc $startpos $endpos) }
  | unary_op expr
    { UnaryOp($1, $2, make_loc $startpos $endpos) }
  | expr DOT identifier
    { FieldAccess($1, $3, make_loc $startpos $endpos) }
  | expr LBRACK expr RBRACK
    { ArrayAccess($1, $3, make_loc $startpos $endpos) }
  | identifier LPAREN args = separated_list(COMMA, expr) RPAREN
    { FunctionCall($1, args, make_loc $startpos $endpos) }
;

binary_op:
  | EQUAL EQUAL { Eq }
  | LT      { Lt }
  | GT      { Gt }
  | LT EQUAL { Le }
  | GT EQUAL { Ge }
  /* Add other operators as needed */
;

unary_op:
  | BANG { Not }
  | MINUS { Neg }
  /* Add other operators as needed */
;

identifier:
  | name = IDENT { make_id name (make_loc $startpos $endpos) }
;
