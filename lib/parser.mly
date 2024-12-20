%{
open Ast
open Types
%}

%token <string> IDENT
%token <int> NUM
%token <int> HEXNUM
%token <string> LITERAL
%token FILE BLOCK METADATA
%token LET IF ELSE FOR IN ECHO
%token LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET
%token SEMICOLON COLON EQUALS DOUBLE_EQUALS AT DOT
%token PLUS TIMES
%token U8 U16 U32 STRING BLOB
%token EOF

%start <program> program

%%

program:
  | f=file_def* a=action* EOF { { file_defs=f; actions=a } }
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
  | BLOCK n=IDENT LBRACE f=field* RBRACE r=repeat a=annotations 
    { create_block n f r a }
  ;

field:
  | n=IDENT COLON t=data_type o=offset c=condition SEMICOLON
    { create_field n t o (match c with Some e -> e | None -> NoCondition) [] (* TODO: support annotations *) }
  ;

offset:
  | AT e=expression { Some e }
  | { None }
  ;

data_type:
  | U8 { UInt8 }
  | U16 { UInt16 }
  | U32 { UInt32 }
  | STRING LPAREN e=expression RPAREN { String e }
  | BLOB LPAREN e=expression RPAREN { Blob e }
  | IDENT { Custom $1 }
  | t=data_type LBRACKET e=expression RBRACKET { Array (t, e) }
  ;

repeat:
  // TODO: support var define in repeat
  | FOR LPAREN IDENT COLON e=expression RPAREN { Some e }
  | { None }
  ;

annotations:
  | AT LBRACE a=annotation_list RBRACE { a }
  | { [] }
  ;

annotation_list:
  | a=annotation SEMICOLON al=annotation_list { a :: al }
  | { [] }
  ;

annotation:
  | k=IDENT COLON v=LITERAL { (k, v) }
  ;

condition:
  | DOUBLE_EQUALS e=expression { Some (Equals e) }
  | { None }
  ;
expression:
  | n=NUM { Int n }
  | n=HEXNUM { Int n }
  | i=IDENT { Var i }
  | e1=expression DOUBLE_EQUALS e2=expression { Equal (e1, e2) }
  | e1=expression PLUS e2=expression { Plus (e1, e2) }
  | e1=expression TIMES e2=expression { Times (e1, e2) }
  | e=expression DOT i=IDENT { Access (e, i) }
  ;

action:
  | IF LPAREN e=expression RPAREN LBRACE a=action* RBRACE ELSE LBRACE b=action* RBRACE
    { IfElse (e, a, b) }
  | IF LPAREN e=expression RPAREN LBRACE a=action* RBRACE
    { If (e, a) }
  | ECHO s=LITERAL SEMICOLON
    { Echo s }
  | FOR LPAREN i=IDENT IN c=IDENT RPAREN LBRACE a=action* RBRACE
    { ForIn (i, c, a) }
  | LET i=IDENT EQUALS e=expression SEMICOLON
    { Let (i, e) }
  | SEMICOLON { NoOp }
  ;
