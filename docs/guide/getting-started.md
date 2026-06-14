# Getting started

This page walks through installing RaE, building it from source, and running your first script.

## Prerequisites

- **OCaml ≥ 4.14** with **opam**
- **Dune ≥ 3.0**
- **Menhir ≥ 2.1**
- **ppx_deriving ≥ 5.1**
- **Node.js ≥ 18** and **pnpm** (only required if you build the documentation locally)

## Install OCaml and dependencies

```bash
# One-time setup
opam switch create 4.14.0
eval $(opam env)

# Clone and enter the project
git clone https://github.com/xeonds/RaE.git
cd RaE

# Install OCaml dependencies
opam install . --deps-only
```

## Build RaE

```bash
dune build         # → _build/default/bin/main.exe
dune exec rae --   # run without specifying a full path
```

Or install it onto your `PATH`:

```bash
dune install       # → ~/.opam/<switch>/bin/rae
```

After `dune install`, the `rae` binary is available everywhere — no `dune exec` prefix needed.

## First script

Create a tiny binary file:

```bash
printf '\x01\x02\x03\x04\x05\x06\x07\x08' > /tmp/hello.bin
```

Now extract its first byte with an inline RaE script:

```bash
rae "file F { a: u8 @ 0; b: u8 @ 1; } .a" /tmp/hello.bin
# → 1
```

Or write the schema to a file and reference it:

```bash
cat > /tmp/script.rae <<'EOF'
file F {
  a: u8 @ 0;
  b: u8 @ 1;
}

.a
EOF

rae /tmp/script.rae /tmp/hello.bin
# → 1
```

## VSCode extension

For syntax highlighting and diagnostics in `.rae` files:

```bash
make vsix
# Then in VS Code: Ctrl+Shift+P → "Install from VSIX..."
# Or symlink for live development:
ln -s $(pwd)/editors/vscode ~/.vscode/extensions/rae-lsp
```

## Building the documentation

```bash
cd docs
pnpm install
pnpm run dev      # local preview at http://localhost:5173
pnpm run build    # → docs/.vitepress/dist
```

The top-level `make docs` target automates the install + build steps.

## Next steps

- Read **[Modes of operation](/guide/modes)** to see the three ways you can drive RaE.
- Skim the **[Schema reference](/reference/schema)** to learn the field declaration syntax.
- Try the **[ELF header example](/examples/elf-header)** for a real-world walkthrough.