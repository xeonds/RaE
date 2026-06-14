# Quick start

A 60-second tour of RaE's three modes: extract, mutate, construct.

## 1. Extract — read fields from a binary

Read the magic bytes of an ELF executable:

```bash
rae "file ELF {
  struct H {
    magic: u32 @ 0 [endian = be];
    class: u8 @ 4;
  }
  h: H @ 0;
}
.h.magic" /bin/ls
# → 2135247942   (= 0x7F454C46, "\x7FELF")
```

The schema declares the layout; the expression `.h.magic` selects the field to print.

## 2. Mutate — change a field, write a new binary

```bash
cat > /tmp/patch.rae <<'EOF'
file F {
  a: u8;
  b: u8;
}

.a = 99;
.b = 100;
@write("out.bin")
EOF

printf '\x00\x00' > /tmp/in.bin
rae /tmp/patch.rae /tmp/in.bin -o /tmp/out.bin
xxd /tmp/out.bin
# → 00000000: 6364                                  cd
```

The script reads `in.bin`, rewrites bytes 0 and 1 to `99` and `100` (ASCII `cd`), and writes `out.bin`. The `-o` flag specifies the output path.

## 3. Construct — build a binary from scratch

```bash
rae "file F {
  struct P {
    x: u8;
    y: u8;
  }
}
new P { x = 42, y = 43 } | @write(\"out.bin\")" /dev/null
xxd /tmp/out.bin
# → 00000000: 2a2b                                  *+
```

`new P { ... }` builds the binary in memory; `@write("out.bin")` serializes it. The input file `/dev/null` is required because the CLI expects it — the binary isn't read.

## Reading the result

By default RaE prints the final expression's value as text. For `VInt`, that's a decimal integer; for `VBytes`, it's `bytes(N)`; for `VArray`, it's `[N]` (length only). Use `@echo(expr)` to print intermediate values.

```bash
rae "file F { a: u8; b: u8; }
  @echo(.a);
  @echo(.b);
  .a + .b" /tmp/in.bin
# → 0
# → 0
# → 0
```

## What's next?

- **[Modes of operation](/guide/modes)** — when each mode fits.
- **[Schema reference](/reference/schema)** — every field attribute and type.
- **[ELF header example](/examples/elf-header)** — a real-world schema.