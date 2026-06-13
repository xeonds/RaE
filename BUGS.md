# RaE v1.0 — Release Notes

构建：`dune build` 通过，2 个 menhir shift/reduce conflict（预期内）。

## Features

- **Declarative schema**: struct, enum, bitfield, template, variant definitions
- **Binary I/O**: LE/BE endian, I8-U64, F32/F64, string/bytes, nested structs, dynamic arrays
- **Pipeline expressions**: field access, arithmetic, bitwise, comparison, logic operators
- **Mutation**: `.field = value` assignment with `set_path`, ref-based in-place updates
- **Construct**: `new Schema { ... }` from-scratch binary construction with checksum autofill
- **Block**: `@block { let x = e; @each(...) {...} }` statement sequences
- **Built-ins**: `@echo`, `@write`, `@checksum`, `@crc32`, `@align`, `@bswap16/32`, `@select`
- **CLI**: file/inline/stdin modes, `-o` output flag

## Quality

17 code quality items resolved (11 fixed, 6 deferred with rationale).
24 bugs resolved across 4 rounds of testing against real ELF binaries.

## Known Limitations

| Limitation | Workaround |
|------------|------------|
| u64 > 2^63-1 displays as negative | OCaml Int64 limitation, documented |
| No `|` bitwise-or (token used by pipe) | Use `lor` keyword or `+` for non-carry cases |
| `after(X)` = field end position, not field value | Use explicit `@ N` offset |
| `import` is flat text concatenation | No namespace, rename conflicts manually |
