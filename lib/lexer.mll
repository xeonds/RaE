{
open Parser
exception LexError of string
}

let digit = ['0'-'9']
let alpha = ['a'-'z' 'A'-'Z']
let ident = (alpha|'_')(alpha|digit|'_')*
let whitespace = [' ' '\t']
let newline = '\n'
let hex = "0x" ['0'-'9' 'a'-'f' 'A'-'F']+
let string = '"' [^'"']* '"'

rule token = parse
  | whitespace { token lexbuf }
  | newline    {
    Lexing.new_line lexbuf;
    token lexbuf
   }
  | "file"     { FILE }
  | "block"    { BLOCK }
  | "metadata" { METADATA }
  | "let"      { LET }
  | "if"       { IF }
  | "else"     { ELSE }
  | "for"      { FOR }
  | "in"       { IN }
  | "echo"     { ECHO }
  | "u8"       { U8 }
  | "u16"      { U16 }
  | "u32"      { U32 }
  | "string"   { STRING }
  | "blob"     { BLOB }
  | "{"        { LBRACE }
  | "}"        { RBRACE }
  | "("        { LPAREN }
  | ")"        { RPAREN }
  | "["        { LBRACKET }
  | "]"        { RBRACKET }
  | ";"        { SEMICOLON }
  | ":"        { COLON }
  | "="        { EQUALS }
  | "=="       { DOUBLE_EQUALS }
  | "@"        { AT }
  | "+"        { PLUS }
  | "*"        { TIMES }
  | "."        { DOT }
  | hex as h   { HEXNUM (int_of_string h) }
  | digit+ as d { NUM (int_of_string d) }
  | ident as i  { IDENT i }
  | "/*"       { comment lexbuf; token lexbuf }
  | string as s { LITERAL s }
  | eof        { EOF }
  | _ as c     { raise (LexError ("Unexpected character: " ^ String.make 1 c)) }

and comment = parse
  | "*/"       { () }
  | "/*"       { comment lexbuf; comment lexbuf }
  | _          { comment lexbuf }

