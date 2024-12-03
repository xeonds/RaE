open Types

let create_field name data_type offset condition =
  { name; data_type; offset; condition }

let create_block name fields =
  { name; fields }

let create_metadata endian alignment =
  { endian; alignment }

let create_file_def name metadata blocks =
  { name; metadata; blocks }

let create_program file_def actions =
  { file_def; actions }
