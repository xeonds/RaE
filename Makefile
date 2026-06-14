.PHONY: all build clean vsix docs docs-install docs-dev docs-build docs-clean

all: build vsix docs

build:
	dune build

vsix:
	dune build bin/lsp_main.exe
	cp _build/default/bin/lsp_main.exe editors/vscode/rae-lsp
	cd editors/vscode && zip -r ../../_build/default/rae-lsp.vsix . -x "*.vsix"
	rm -f editors/vscode/rae-lsp

install:
	dune install

docs: docs-install docs-build

docs-install:
	cd docs && pnpm install --frozen-lockfile || pnpm install

docs-dev:
	cd docs && pnpm run dev

docs-build:
	cd docs && pnpm run build

docs-clean:
	rm -rf docs/.vitepress/cache docs/.vitepress/dist docs/node_modules

clean:
	dune clean
	rm -f _build/default/rae-lsp.vsix
