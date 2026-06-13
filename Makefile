.PHONY: all build clean vsix

all: build vsix

build:
	dune build

vsix:
	dune build bin/lsp_main.exe
	cp _build/default/bin/lsp_main.exe editors/vscode/rae-lsp
	cd editors/vscode && zip -r ../../_build/default/rae-lsp.vsix . -x "*.vsix"
	rm -f editors/vscode/rae-lsp

install:
	dune install

clean:
	dune clean
	rm -f _build/default/rae-lsp.vsix
