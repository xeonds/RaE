%{
open Ast
open Types
%}

%token <string> IDENT
%token <int> NUM
%token <int> HEXNUM
%token FILE BLOCK METADATA
%token LET IF ELSE FOR IN ECHO
%token LBRACE RBRACE LPAREN RPAREN
%token SEMICOLON COLON EQUALS DOUBLE_EQUALS AT
%token PLUS TIMES
%token U8 U16 U32 STRING BLOB
%token EOF

%start <program> program

%%

program:
  | f=file_def a=action* EOF { { file_def=f; actions=a } }
  ;

file_def:
  | FILE n=IDENT LBRACE m=metadata b=block* RBRACE
    { create_file_def n m b }
  ;

metadata:
  | METADATA LBRACE e=endianness a=alignment? RBRACE
    { { endian=e; alignment=a } }
  ;

endianness:
  | IDENT COLON e=IDENT SEMICOLON
    { match e with
      | "little" -> Little
      | "big" -> Big
      | _ -> failwith "Invalid endianness"
    }
  ;

alignment:
  | IDENT COLON n=NUM SEMICOLON { n }
  ;

block:
  | BLOCK n=IDENT LBRACE f=field* RBRACE
    { create_block n f }
  ;

field:
  | n=IDENT COLON t=data_type AT o=offset c=condition? SEMICOLON
    { create_field n t o (match c with Some e -> e | None -> NoCondition) }
  ;

data_type:
  | U8 { UInt8 }
  | U16 { UInt16 }
  | U32 { UInt32 }
  | STRING LPAREN n=NUM RPAREN { String n }
  | BLOB LPAREN n=NUM RPAREN { Blob n }
  ;

offset:
  | n=NUM { n }
  | n=HEXNUM { n }
  ;

condition:
  | DOUBLE_EQUALS e=expression { Equals e }
  ;

expression:
  | n=NUM { Int n }
  | n=HEXNUM { Int n }
  | i=IDENT { Var i }
  | e1=expression DOUBLE_EQUALS e2=expression { Equal (e1, e2) }
  | e1=expression PLUS e2=expression { Plus (e1, e2) }
  | e1=expression TIMES e2=expression { Times (e1, e2) }
  ;

action:
  | IF LPAREN e=expression RPAREN LBRACE a=action* RBRACE
    { If (e, a) }
  | ECHO s=IDENT SEMICOLON
    { Echo s }
  | FOR i=IDENT IN c=IDENT LBRACE a=action* RBRACE
    { ForIn (i, c, a) }
  ;
