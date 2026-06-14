# Schema overview

The schema is the first part of any RaE script. It declares the layout of the binary file: types, offsets, sizes, and assertions.

## Top-level structure

```rae
file F {
  // type definitions (struct, enum, bitfield, template)
  struct Header { ... }
  enum Color : u8 { ... }

  // top-level fields
  header: Header @ 0;
  body: bytes(1024);
}
```

A script has exactly one `file` block. Inside it:

- **Type definitions** (`struct`, `enum`, `bitfield`, `template`) come first.
- **Top-level fields** describe the file itself. These are the fields the expression operates on.

You can refer to types and fields defined anywhere in the file block; order doesn't matter.

## Field declaration syntax

```rae
name: type @ offset [== expected] [attrs];
```

| Element   | Required | Notes                                                                |
|-----------|----------|----------------------------------------------------------------------|
| `name`    | yes      | Identifier used in expressions (`.name`).                            |
| `type`    | yes      | One of the [types](/reference/types).                                |
| `offset`  | no       | `@ N`, `@ after(field)`, `@ align(N)`, or omitted for auto-layout.   |
| `==`      | no       | Hard assertion — parse fails if the field's value doesn't match.     |
| `attrs`   | no       | Comma-separated list inside `[...]`. See [Attributes](/reference/attributes). |

A field's offset may be omitted: the engine places it after the previous field's end.

## Example

```rae
file ELF {
  struct Header {
    magic: u32 @ 0 [endian = be] == 0x7F454C46;
    class: u8 @ 4;
    data: u8 @ 5;
    version: u8 @ 6;
  }

  header: Header @ 0;
  body: bytes(8) @ after(header);
}
```

This declares:

- A `Header` struct with four fields. The first is asserted to equal `0x7F454C46` (`"\x7FELF"`).
- A top-level `header` field of type `Header` at offset 0.
- A `body` field of 8 bytes, placed immediately after `header`.

In an expression, `.header.magic` returns the magic number, `.body` returns the 8 raw bytes.

## What the engine maintains

You don't track offsets by hand. When you write the schema, the engine:

1. **Computes each field's offset** based on `@ N`, `@ after(...)`, `@ align(...)`, or auto-layout.
2. **Recalculates** dependent offsets when a field's size changes.
3. **Checks assertions** at parse time (`== expected`).
4. **Swaps bytes** for fields marked `[endian = be]` (default is little-endian).
5. **Routes variants** through `variant(tag_field)` based on the tag's runtime value.
6. **Fills checksums** on construction via `[checksum = expr]`.

See the reference pages for details:

- **[Types](/reference/types)** — primitive, string, bytes, array, struct, template.
- **[Offsets](/reference/offsets)** — `@ N`, `after`, `align`, dynamic expressions.
- **[Attributes](/reference/attributes)** — `count`, `if`, `validate`, `endian`, `checksum`.
- **[Structs & variants](/reference/structs)** — nested structures and tagged unions.