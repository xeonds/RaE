{
open Parser
open Lexing

exception SyntaxError of string

let next_line lexbuf =
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { pos with pos_bol = lexbuf.lex_curr_pos;
               pos_lnum = pos.pos_lnum + 1
    }
}

let digit = ['0'-'9']
let hex = ['0'-'9' 'a'-'f' 'A'-'F']
let alpha = ['a'-'z' 'A'-'Z']
let id = (alpha|'_')(alpha|digit|'_')*
let whitespace = [' ' '\t']+
let newline = '\r' | '\n' | "\r\n"

rule token = parse
  | whitespace { token lexbuf }
  | newline    { next_line lexbuf; token lexbuf }
  | "//"       { single_line_comment lexbuf }
  | "/*"       { multi_line_comment lexbuf }

  (* Keywords *)
  | "file"|"FILE"   { FILE }
  | "struct"|"STRUCT" { STRUCT }
  | "enum"|"ENUM"     { ENUM }
  | "bitfield"|"BITFIELD" { BITFIELD }
  | "template"|"TEMPLATE" { TEMPLATE }
  | "variant"|"VARIANT" { VARIANT }
  | "after"|"AFTER"   { AFTER }
  | "align"|"ALIGN"   { ALIGN }
  | "count"|"COUNT"   { COUNT }
  | "validate"|"VALIDATE" { VALIDATE }
  | "endian"|"ENDIAN" { ENDIAN }
  | "le"|"LE" { LEND }
  | "be"|"BE" { BEND }
  | "let"|"LET" { LET }
  | "in"|"IN"   { IN }


  (* Basic Types *)
  | "I8"|"i8"   { I8 }
  | "I16"|"i16" { I16 }
  | "I32"|"i32" { I32 }
  | "I64"|"i64" { I64 }
  | "U8"|"u8"   { U8 }
  | "U16"|"u16" { U16 }
  | "U32"|"u32" { U32 }
  | "U64"|"u64" { U64 }
  | "F32"|"f32" { F32 }
  | "F64"|"f64" { F64 }
  | "string"|"STRING" { STRING }
  | "bytes"|"BYTES"   { BYTES }
  | "array"|"ARRAY"   { ARRAY }

  (* Symbols *)
  | "{"        { LBRACE }
  | "}"        { RBRACE }
  | "("        { LPAREN }
  | ")"        { RPAREN }
  | "["        { LBRACK }
  | "]"        { RBRACK }
  | "<"        { LT }
  | ">"        { GT }
  | "=="       { EQEQ }
  | "="        { EQUAL }
  | ":"        { COLON }
  | ";"        { SEMICOLON }
  | ","        { COMMA }
  | "."        { DOT }
  | "|"        { PIPE }
  | "@"        { AT }
  | "=>"       { FATARROW }
  | "!"        { BANG }
  | "+"        { PLUS }
  | "-"        { MINUS }
  | "*"        { STAR }
  | "/"        { SLASH }

  (* Literals *)
  | "0x" hex+ as h { INT(int_of_string h) }
  | digit+ as i    { INT(int_of_string i) }
  | digit+ "." digit+ as f { FLOAT(float_of_string f) }
  | '"' ([^'"']* as s) '"' { STRING_LIT(s) }

  | id as text  { IDENT(text) }
  | eof         { EOF }
  | _ as c      { raise (SyntaxError ("Unexpected char: " ^ Char.escaped c)) }

and single_line_comment = parse
  | newline { next_line lexbuf; token lexbuf }
  | eof     { EOF }
  | _       { single_line_comment lexbuf }

and multi_line_comment = parse
  | "*/"    { token lexbuf }
  | newline { next_line lexbuf; multi_line_comment lexbuf }
  | _       { multi_line_comment lexbuf }
