# RaE v1.0 — awk/jq for binary files

Parse, inspect, mutate, and construct binary files with a declarative schema and pipeline expressions.

## Install

```bash
# One-time: OCaml
opam switch create 4.14.0 && eval $(opam env)

# Clone & install deps
git clone https://github.com/xeonds/RaE.git && cd RaE
opam install . --deps-only

# Build & run
dune build                  # → _build/default/bin/main.exe
dune exec rae -- ...        # build + run in one command
dune install                # → ~/.opam/<switch>/bin/rae (on PATH)
```

`dune build` 产物在 `_build/default/bin/main.exe`。`dune exec rae --` 自动编译后执行，无需手动找路径。`dune install` 安装到 opam 的环境 PATH 里。

Or install globally:

```bash
dune install
# now `rae` is on your PATH
```

Requires: OCaml 4.14+, Dune 3.0, Menhir 2.1, ppx_deriving 5.1.

## VSCode Extension

```bash
make vsix                         # → _build/default/rae-lsp.vsix
# Then in VS Code: Ctrl+Shift+P → "Install from VSIX..."
```

Or for local development:

```bash
ln -s $(pwd)/editors/vscode ~/.vscode/extensions/rae-lsp
```

Provides `.rae` syntax highlighting and diagnostics via LSP.

## Quick start

```bash
# Extract
rae "file ELF { struct H { magic: u32 @ 0 [endian = be]; version: u8 @ 4; } h: H @ 0; } .h.magic" /bin/ls
# → 2135247942

# Mutate + write
rae "file F { a: u8; b: u8; } .a = 99; .b = 100; @write(\"out.bin\")" file.bin

# Construct from scratch (no input file)
rae "file F { struct P { x: u8; y: u8; } } new P { x = 42, y = 43 } | @write(\"out.bin\")" /dev/null
```

## CLI

```bash
rae script.rae binary_file [-o out.bin]     # file mode
rae "file F { ... } expr" binary_file        # inline mode
cat file.bin | rae script.rae [-o out.bin]   # stdin mode
```

## Schema

```
name: type @ offset [== expected] [attrs];
```

| Element | Syntax |
|---------|--------|
| **type** | `u8`..`u64`, `i8`..`i64`, `f32`, `f64`, `string(n)`, `bytes(n)`, `array<T>`, struct name, `template<T>` |
| **offset** | `@ 0xN`, `@ after(f)`, `@ align(N)`, `@ (expr)`, or omitted (auto) |
| **==** | hard assertion on parse |
| **attrs** | `[endian = le\|be]`, `[count = n]`, `[if = expr]`, `[checksum = expr]` |

### Structs, variants, templates

```
struct Header { magic: u32 @ 0 [endian = be]; version: u8; }

struct Packet {
    type: u8 @ 0;
    variant(type) {
        0x01 => { data: u32 @ 1; }
        0x02 => { count: u16 @ 1; }
    }
}

template<T, U> Pair { first: T; second: U; }
```

## Expressions

| Pattern | Description |
|---------|-------------|
| `.field`, `.a.b` | field access |
| `.arr[0]`, `.arr[]` | array index / expand |
| `a + b`, `a & b`, `a << 2` | arithmetic / bitwise |
| `a == b`, `a != b`, `a < b` | comparison |
| `a && b`, `a \|\| b`, `!a`, `-a` | logic / unary |
| `expr1; expr2` | multi-expression |
| `_ \| .field` | pipe |
| `.a = 99` | assignment (mutation) |
| `new Name { a = 1, b = 2 }` | construct from scratch |
| `@block { let x = e; ... }` | multi-statement block |
| `@each(x in .arr) { x + 1 }` | map over array |

### Built-in functions

| Function | Description |
|----------|-------------|
| `@echo(expr)` | print value to stdout |
| `@write("path")` | write binary to file |
| `@checksum(expr)` | 16-bit byte-sum checksum |
| `@crc32(expr)` | IEEE 802.3 CRC32 |
| `@align(val, n)` | align to next multiple of n |
| `@bswap16(expr)` | swap 16-bit endian |
| `@bswap32(expr)` | swap 32-bit endian |
| `@select(cond)` | filter array elements |

## License

GNU General Public License V3. See [LICENSE](LICENSE).
