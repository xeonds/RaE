# RaE — a binary file parser/transformer, akin to awk/jq for binaries

RaE reads binary files according to a declarative schema and lets you extract or transform data with a pipeline expression language.

## Install

```bash
git clone https://github.com/xeonds/RaE.git && cd RaE
dune build
```

Requires OCaml 4.14+, Dune 3.0.

## Usage

```bash
rae schema.rae binary_file             # run a schema+expressions from a file
rae "file F { ... } expression" file.bin   # inline schema and expression
```

The schema describes the binary layout. Expressions act on the parsed tree.

## Quick example

```
file ELF {
    struct Header {
        magic: u32 @ 0 [endian = be] == 0x7F454C46;
        version: u8 @ 4;
        num_sections: u16 @ 0x30;
    }
    header: Header @ 0;
}
.header.magic
```

```bash
$ rae elf.rae /bin/ls
2135247942
```

## Schema

A `file` block defines the binary layout. Inside, `struct` blocks define reusable components.

### Fields

```
name: type @ offset [== expected] [attrs];
```

- **type** — `u8`, `u16`, `u32`, `u64`, `i8`..`i64`, `f32`, `f64`, `array<T>`, or a struct name
- **offset** — `@ 0x10` | `@ after(field)` | `@ align(8)` | `@ (expr)`
- **== expected** — hard assertion on parse (value must match)
- **attrs** — `[endian = le|be]`, `[count = expr]`, `[if = expr]`, `[validate = expr]`

### Example schema

```
file ELF {
    struct Header {
        magic: u32 @ 0 [endian = be] == 0x7F454C46;
        version: u8 @ 4;
    }

    header: Header @ 0;

    struct Section {
        name_offset: u32 @ 0;
        size: u32 @ 4;
    }
    sections: array<Section> @ 0x40 [count = header.num_sections];
}
```

## Expressions

Expressions operate on the parsed data tree. The pipeline model is inspired by jq.

### Field access

```
.field          → value of top-level field
.field.sub      → nested struct member
.header.magic   → chain access
_               → the current pipeline value
```

### Pipe

```
_ | .header | .magic     → pass value through pipeline
.sections[] | @select(.type == .text)
```

### Arithmetic & comparison

```
a + b, a - b, a * b, a / b
a == b, a < b, a > b
```

### @block — multi-statement sequences

```
@block {
    let x = .header.magic;
    let y = .header.version;
    x + y
}
```

### @each — iterate arrays

```
@each(s in .sections) {
    s.size + 1
}
```

### Built-in functions

| Function | Description |
|----------|-------------|
| `@echo(expr)` | Print to stdout, return the value |
| `@checksum(expr)` | Byte-sum checksum (16-bit) |
| `@align(val, n)` | Align value to next multiple of n |
| `@write("path")` | Write raw binary to file |
| `@select(cond)` | Filter array elements |

## License

GNU General Public License V3. See [LICENSE](LICENSE).
