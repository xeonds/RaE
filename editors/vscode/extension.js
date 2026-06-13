const { LanguageClient, TransportKind } = require('vscode-languageclient/node');
const vscode = require('vscode');

let client;

function activate(context) {
  const config = vscode.workspace.getConfiguration('rae');
  const serverPath = config.get('lsp.path', 'rae-lsp');

  const serverOptions = {
    command: serverPath,
    transport: TransportKind.stdio
  };

  const clientOptions = {
    documentSelector: [{ scheme: 'file', language: 'rae' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.rae')
    }
  };

  client = new LanguageClient(
    'rae-lsp',
    'RaE Language Server',
    serverOptions,
    clientOptions
  );

  client.start();
}

function deactivate() {
  if (client) {
    return client.stop();
  }
}

module.exports = { activate, deactivate };
