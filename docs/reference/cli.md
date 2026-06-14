# CLI usage

```bash
rae <script> <binary> [-o out.bin]
```

## Modes of invocation

### File mode

Pass a `.rae` script file and a binary file:

```bash
rae script.rae binary.bin
```

The script is read, imports are processed, and the binary is parsed against the schema.

### Inline mode

Pass the schema + expression as a single argument:

```bash
rae "file F { a: u8; } .a" binary.bin
```

Use this for one-liners. Quote carefully — your shell will see the whole string as one argument.

### Stdin mode

Omit the binary file argument and pipe bytes via stdin:

```bash
cat binary.bin | rae script.rae -o out.bin
```

When the binary argument is missing, RaE reads stdin. Combine with `-o` to write the result back to a file.

### Construct mode

To build a binary from scratch, pass `/dev/null` as the input:

```bash
rae "file F { struct P { x: u8; } } new P { x = 42 } | @write(\"out.bin\")" /dev/null
```

## Flags

| Flag   | Argument     | Effect                                                 |
|--------|--------------|--------------------------------------------------------|
| `-o`   | output path  | After evaluating the script, write the result to `path`|

`-o` is the only flag. Output format is raw bytes.

## Exit codes

| Code | Meaning                                          |
|------|--------------------------------------------------|
| 0    | Success                                          |
| 1    | Lexical, syntax, or engine error (message printed to stderr) |

## Errors

Errors are printed to stderr with a location when available:

```
Syntax error at line 3, col 5-12: Unexpected token
Engine error: Field 'magic' expected value doesn't match
```

The exit code is `1` for any error.

## Input files

RaE scripts may use `import 'path.rae'` to include other files. Imports are resolved relative to the importing file's directory and concatenated as plain text — there is no namespace mechanism.

```rae
import 'common.rae'
import 'header.rae'
```

Avoid name conflicts across imports.

## Shebang

A `rae` script can be made executable with a shebang:

```bash
#!/usr/bin/env rae
file F { a: u8; }
.a
```

The engine strips the first line if it starts with `#!` so the parser sees the schema and expression normally.