# What is RaE?

RaE is a domain-specific language for working with binary files. Think of it as **awk** or **jq**, but applied to raw bytes instead of text or JSON.

A RaE script has two parts:

1. **Schema** — a declarative description of the binary layout (`struct`, `enum`, `template`, etc.)
2. **Expressions** — a pipeline that operates on the parsed tree (extract, mutate, construct)

The engine reads your schema, parses the binary into an in-memory tree, runs your expression, and optionally writes a new binary back to disk.

## Why a DSL?

A general-purpose language plus a binary library makes you wire offsets, call `seek`, compute sizes, and remember endianness for every read and write. RaE flips that around:

- The **schema is the parser**. You declare the shape, the engine figures out where each field lives.
- **Offsets recalculate automatically** when a field's size changes.
- **Pipelines replace loops** for the common case: `.arr[] | select(cond) | { ... }`.
- **Checksums auto-update** on construction via the `[checksum = ...]` attribute.

You write down what the format *is*, not the step-by-step procedure to read or write it.

## Three modes, one grammar

```rae
// 1. Extract (jq-like)
.header.sections[] | select(.type == 1) | { .name, .size }

// 2. Transform (awk-like)
.header.version = 2; @checksum(.header); @write("out.bin")

// 3. Construct (reverse)
new ELF { header = { magic = 0x7F454C46, version = 1 }, ... } | @write("out.bin")
```

The expression grammar is the same across all three — only the intent changes.

## What's in this guide

- **[Getting started](/guide/getting-started)** — install RaE and run your first script.
- **[Modes of operation](/guide/modes)** — when to use extract, mutate, or construct.
- **[Schema reference](/reference/schema)** — every attribute and type.
- **[Expressions](/reference/expressions)** — operators, pipes, built-ins.
- **[Examples](/examples/elf-header)** — copy-paste recipes for common formats.