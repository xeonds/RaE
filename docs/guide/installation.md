# Installation

Detailed instructions for installing RaE and its dependencies on different platforms.

## OCaml toolchain

RaE targets OCaml 4.14+. The easiest way to get a working OCaml environment is via **opam**.

### Linux / macOS

```bash
# Install opam (skip if already installed)
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"

# Initialize opam
opam init --bare -y
eval $(opam env)

# Create an OCaml switch pinned to 4.14.0
opam switch create 4.14.0
eval $(opam env)
```

### Verify

```bash
ocaml --version    # The OCaml toplevel, version 4.14.x
opam --version
```

## System packages

Some OCaml packages link against system libraries. On Debian/Ubuntu:

```bash
sudo apt install -y libffi-dev libgmp-dev libssl-dev pkg-config m4
```

On macOS with Homebrew, the above are bundled.

## OCaml dependencies

After cloning RaE:

```bash
git clone https://github.com/xeonds/RaE.git
cd RaE
opam install . --deps-only
```

This installs:

| Package        | Purpose                          |
|----------------|----------------------------------|
| `dune`         | Build system                     |
| `menhir`       | Parser generator                 |
| `ppx_deriving` | Derives `show` / `eq` for the AST|

## Build & install

```bash
dune build           # compile the library + binaries
dune install         # install rae + lsp onto your PATH
```

After `dune install`, verify:

```bash
which rae            # should print ~/.opam/<switch>/bin/rae
rae --help           # prints usage to stderr
```

## Uninstall

```bash
opam uninstall rae
```

## Building from the repository

```bash
git clone https://github.com/xeonds/RaE.git
cd RaE
make build           # → _build/default/bin/main.exe
make vsix            # → _build/default/rae-lsp.vsix
make clean           # removes _build/ and built vsix
```

See the top-level `Makefile` for the full list of targets.