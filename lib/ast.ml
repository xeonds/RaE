open Types

let create_field name data_type offset condition annotations =
  { name; data_type; offset; condition; annotations }

let create_block name fields repeat annotations =
  { name; fields; repeat; annotations }

let create_metadata endian alignment =
  { endian; alignment }

let create_file_def name metadata blocks =
  { name; metadata; blocks }

let create_program file_defs actions =
  { file_defs; actions }
