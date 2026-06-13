# RaE — Agent Instructions

## Build & Run
- **Build:** `dune build`
- **Run:** `dune exec rae -- <script> <binary_file>`
- **Clean:** `dune clean`

## Architecture
```
bin/main.ml        → executable entrypoint, arg parsing, ties lib modules together
lib/ast.ml         → all AST types (expr, data_type, def, program, etc.)
lib/lexer.mll      → ocamllex tokenizer
lib/parser.mly     → Menhir parser (generates parser.ml)
lib/engine.ml      → file import, binary eval, expression eval
lib/binlib.ml      → binary I/O: sizeof, pick, shift, parse_data
```

- Library name: `rae_lib` (public: `rae.lib`), executable: `rae`
- Uses `ppx_deriving.show` and `ppx_deriving.eq` on the lib (see `lib/dune`)
- Menhir generates code from `parser.mly`, ocamllex from `lexer.mll`

## Current Status
Project compiles and works. Core schema parsing, binary evaluation, and expression pipeline are functional.

## Design Principles
RaE is an awk/jq for binary files — declarative schema + pipeline operations, not "a general language with a binary lib".

### Unified model: schema defines a parsed tree, operations act on it
Three operation modes, one expression grammar:
```
1. Extract (jq-like)    .header.sections[] | select(.type==1) | {.name, .size}
2. Transform (awk-like)  .header.version = 2; @checksum(.header); write
3. Construct (reverse)   new ELF { header = { magic = 0x7F... }, ... }; write "out"
```

### Expression grammar: pipeline-first, block as escape hatch
- **Pipeline** covers 80%: `.field`, `.[]`, `select(cond)`, `{ key: expr }`, pipe `|`
- **Block** covers 20%: `@block { let x = ...; @each(...) {...} }` for imperative logic
- No `for`/`if`/`while` at top-level — traversal via `.[]` + `select()`, mutation via `=`
- Pipes and blocks compose: blocks can contain pipes, pipes can feed into blocks

### Schema: 4 core attributes per field, engine maintains invariants
```
name: type @ offset [== expected] [count = expr] [if = cond]
```
- `type`: u8..u64, i8..i64, f32/f64, string(n), bytes(n), struct_name
- `offset`: `0xN` | `after(field)` | `align(N)` | dynamic expr
- `== expected`: hard assertion on parse
- `count = expr` / `if = cond`: conditional existence and array sizing

Other checks (range, set, checksum) live in the **operation layer** via `@checksum`, `@validate`, etc.

### Engine responsibilities (automatic, not user-managed)
- **Offset recalculation**: changing a field's size shifts subsequent fields
- **Checksum update**: `@checksum(field)` marks it for auto-recompute on write
- **Endian handling**: per-field endian flag, engine swaps on read/write
- **Variant dispatch**: `variant(type_field)` routes to correct struct at parse time

### What makes this a DSL, not a general language + library
- Field offsets/alignment recalculate automatically — no manual `seek`/`sizeof` chains
- Schema IS the parser — no separate read/unpack/pack code
- Pipeline combinators are the control flow — no general-purpose loops for 80% cases
- The engine owns invariants; user only declares intent

## Conventions
- OCaml 4.14+, Dune 3.0, Menhir 2.1
- All source in `lib/`; the binary in `bin/` is thin
- `.ml` files are implementations, `.mli` are interfaces (none yet), `.mll` = ocamllex, `.mly` = menhir
- Keep `_build/` gitignored (Dune output)

## Development Workflow (lessons from building RaE)
- **Feature work touches 4 files**: `ast.ml` (type) → `lexer.mll` (token) → `parser.mly` (syntax) → `engine.ml` (semantics). Every feature walks this chain.
- **Build after every AST change**: dune caches aggressively; run `dune build` immediately to catch type mismatches before they cascade.
- **Full rewrite beats patching**: when 3+ edits fail in a row, write the entire file from scratch. OCaml's type checker catches all mistakes cleanly.
- **Avoid `_ -> VNull` / `_ -> Bytes.empty` fallthroughs**: every catch-all is a silent bug. Raise `Engine_error` with a descriptive message.
- **OCaml quirks to watch**:
  - `and` chains: types in mutual recursion share label namespace — avoid duplicate field names across `and`-linked records.
  - `let rec ... and ...`: only for mutually recursive FUNCTIONS. Types use `type ... and ...` (no `rec`).
  - `match e with pattern | _ -> raise ...` — the `|` before `_` must be on the same logical line as the previous case's expression, or parenthesized.
  - `Bytes.get`/`Bytes.set` for bytes indexing, NOT `.[]` which is for strings.
  - Parameter names that shadow type names can confuse type inference — use explicit `: Ast.type` annotations or rename params.
- **Menhir conflicts**: shift/reduce at IDENT-LPAREN, DOT-LBRACK, and MINUS are expected for expression parsers. Menhir's default shift resolves them correctly. Don't fight them.
- **Test after every logical chunk**: `printf '\x...' > /tmp/t.bin && dune exec rae -- "..." /tmp/t.bin`. One-liner assertions catch regressions instantly.
- **Commit granularity**: one commit per feature group (AST+Lexer+Parser, Engine, Main+Config, Docs). Don't mix unrelated changes.
