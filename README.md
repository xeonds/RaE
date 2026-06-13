# RaE — awk/jq for binary files

Parse, inspect, mutate, and construct binary files with a declarative schema and pipeline expressions.

## Install

```bash
git clone https://github.com/xeonds/RaE.git && cd RaE
dune build
```

Requires OCaml 4.14+, Dune 3.0.

## Usage

```bash
rae schema.rae binary_file                  # file mode
rae "file F { ... } expression" file.bin    # inline mode
```

## Quick examples

**Extract** (jq-like):
```rae
file ELF {
    struct Header {
        magic: u32 @ 0 [endian = be] == 0x7F454C46;
        version: u8 @ 4;
    }
    header: Header @ 0;
}
.header.magic           # → 2135247942
```

**Mutate** (awk-like):
```rae
file F { a: u8 @ 0; b: u8 @ 1; }
.a = 99; .b = 100;
@write("out.bin")
```

**Construct** (reverse):
```rae
file F { struct P { x: u8 @ 0; y: u8 @ 1; } }
new P { x = 42, y = 43 } | @write("out.bin")   # → 2a 2b
```

**Nested construct:**
```rae
file F {
    struct H { a: u8 @ 0; b: u16 @ 1; }
    struct Outer { h: H @ 0; c: u8 @ 3; }
}
new Outer { h = new H { a = 1, b = 1000 }, c = 99 }
# → 01 e8 03 63
```

## Schema

### Fields

```
name: type @ offset [== expected] [attrs];
```

- **type** — `u8`..`u64`, `i8`..`i64`, `f32`, `f64`, `string(n)`, `bytes(n)`, `array<T>`, struct name, `template<T>`
- **offset** — `@ 0xN` | `@ after(field)` | `@ align(N)` | `@ (expr)`
- **== expected** — hard assertion, parse aborts if mismatch
- **attrs** — `[endian = le|be]`, `[count = expr]`, `[if = expr]`, `[validate = expr]`

### Structs, variants, templates

```
struct Header { magic: u32 @ 0; ... }

struct Packet {
    type: u8 @ 0;
    variant(type) {
        0x01 => { data: u32 @ 1; }
        0x02 => { count: u16 @ 1; }
    }
}

template<T> ArrayHeader {
    count: u32 @ 0;
    data: T @ 4;
}
```

## Expressions

### Pipeline

```
.field.sub      # field access
.arr[]          # array expand
.arr[0]         # array index
_ | .field      # pipe current value through
expr; expr      # multi-expression (; separated)
```

### @block — statements with local bindings

```
@block {
    let x = .header.magic;
    let y = .header.version;
    x + y
}
```

### @each — map over arrays

```
@each(s in .sections) { s.size + 1 }
```

### Assignment mutation

```
.header.version = 2
.sections[0].size = 1024
```

### Construct

```
new Header { magic = 0x7F454C46, version = 1 }
new Outer { h = new Inner { x = 1 }, c = 99 }
```

### Built-in functions

| Function | Description |
|----------|-------------|
| `@echo(expr)` | Print value to stdout |
| `@checksum(expr)` | 16-bit byte-sum checksum |
| `@align(val, n)` | Align to next multiple of n |
| `@write("path")` | Write current value as binary to file |
| `@select(cond)` | Filter array elements by condition |

## Related work

RaE sits in the "declarative schema + binary inspection" space. The closest peers:

### Kaitai Struct — the most direct analogue
YAML-declared schemas compiled into parsers for 9+ languages (C/Python/Ruby/JS/Go/Rust/Java/PHP/Perl), with a visual gallery browser. Mature, well-documented, ~3k stars.

- **vs RaE**: Kaitai solves "schema → parse" thoroughly but has no native write-back or transform pipelines. RaE targets jq-style composition *and* mutation/construction in one runtime.

### Construct (Python library)
Runtime `Struct / Int32ub / Array(this, ...) / If(this.x > 0, ...)` — essentially "what RaE wants to be as a DSL". Mature, popular, but slow at runtime and painful at deep nesting (manual context passing).

- **vs RaE**: Construct parses only. RaE's auto-maintained offsets/alignment/checksums aim to remove the manual bookkeeping Construct users hit. Pipeline syntax also composes more naturally than nested Python calls.

### 010 Editor / ImHex
GUI-first tools with C-like template languages. Powerful for interactive inspection (010's diff, ImHex's pattern rules), but templates are binary/non-portable and divorced from CLI workflows.

- **vs RaE**: textual, git-friendly DSL; usable in scripts and CI.

### jq / awk / protobuf-thrift
Not direct competitors — design influences:
- **jq**: path expressions, `[]`, `select(...)`, `|`
- **awk**: pattern-action, automatic field bookkeeping
- **Proto/Thrift**: IDL → parsers, declared types and constraints

### Differentiation — what RaE must deliver to matter

1. **Write-back with auto-maintained invariants** — checksum recompute, offset shifting after size changes, alignment fixup on mutate. Neither Kaitai nor Construct does this natively.
2. **jq-style pipelines over the parsed tree** — composable extraction/transform, not just structure definition.
3. **A killer vertical** — turnkey schemas for ELF / PE / container images / firmware, demonstrating the model end-to-end.

Without (1) and (2) shipping, RaE risks being "Construct in OCaml" — a fun toy, not a tool.

## License

GNU General Public License V3. See [LICENSE](LICENSE).
