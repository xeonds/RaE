# Modes of operation

RaE has three modes that all share the same expression grammar. The difference is what the expression returns and whether a binary file is required.

## 1. Extract

Inspect an existing binary without modifying it.

```bash
rae "file ELF { struct H { magic: u32 @ 0 [endian = be]; } h: H @ 0; } .h.magic" /bin/ls
```

The expression resolves to a value (here `VInt`) which RaE prints to stdout.

**No `-o` flag.** The binary is read but never written.

## 2. Mutate

Change fields and write a new binary.

```bash
rae "file F { a: u8; b: u8; } .a = 99; @write(\"out.bin\")" in.bin -o out.bin
```

The expression returns a `VBytes` (the mutated tree serialized). RaE writes it to the path passed to `-o`.

**Two ways to trigger write:**

- Pass `-o out.bin` on the command line — the engine writes the final result.
- Call `@write("out.bin")` inside the script — useful when you want to write multiple files or write to a path computed at runtime.

If the final expression is not `VBytes` and `-o` is passed, the output is silently skipped.

## 3. Construct

Build a binary from scratch with `new Schema { ... }`.

```bash
rae "file F { struct P { x: u8; y: u8; } } new P { x = 42, y = 43 } | @write(\"out.bin\")" /dev/null
```

No input data is needed, but the CLI requires a binary argument. Pass `/dev/null` or any file (its contents are ignored).

`Construct` evaluates the field expressions, lays them out according to the schema, applies `[checksum = ...]` attributes, and returns a `VBytes` ready to write.

## Combining modes

Mixing is fine — mutate and extract can coexist:

```rae
file F {
  header: u32;
  body: bytes(8);
}

@echo(.header);                  // inspect
.header = 0xCAFEBABE;            // mutate
@write("out.bin")                // write
```

The last expression's value is the script's return value. Use semicolons (`;`) to chain statements and the pipe (`|`) to feed one expression into the next.