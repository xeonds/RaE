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
  | "file"     { FILE }
  | "struct"   { STRUCT }
  | "enum"     { ENUM }
  | "bitfield" { BITFIELD }
  | "if"       { IF }
  | "template" { TEMPLATE }
  | "variant"  { VARIANT }
  
  (* Basic Types *)
  | "I8"       { I8 }
  | "I16"      { I16 }
  | "I32"      { I32 }
  | "I64"      { I64 }
  | "U8"       { U8 }
  | "U16"      { U16 }
  | "U32"      { U32 }
  | "U64"      { U64 }
  | "F32"      { F32 }
  | "F64"      { F64 }
  | "STRING"   { STRING }
  | "BYTES"    { BYTES }
  | "ARRAY"    { ARRAY }
  | "HEX"      { HEX }
  | "DEC"      { DEC }
  | "OCT"      { OCT }
  | "BIN"      { BIN }
  
  (* Symbols *)
  | "{"        { LBRACE }
  | "}"        { RBRACE }
  | "("        { LPAREN }
  | ")"        { RPAREN }
  | "["        { LBRACK }
  | "]"        { RBRACK }
  | "<"        { LT }
  | ">"        { GT }
  | "="        { EQUAL }
  | ":"        { COLON }
  | ";"        { SEMICOLON }
  | ","        { COMMA }
  | "."        { DOT }
  | "@"        { AT }
  | "=>"       { FATARROW }
  | "!"        { BANG }
  | "-"        { MINUS }
  
  (* Literals *)
  | digit+ as i     { INT(int_of_string i) }
  | "0x" hex+ as h  { INT(int_of_string h) }
  | digit+ "." digit+ as f { FLOAT(float_of_string f) }
  | '"' ([^'"']* as s) '"' { STRING_LIT(s) }
  
  (* Identifiers *)
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
