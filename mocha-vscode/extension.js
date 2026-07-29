'use strict';

const path = require('path');
const { workspace, window } = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

let client;

/**
 * @param {import('vscode').ExtensionContext} context
 */
function activate(context) {
    console.log('[mocha] activated');

    // Path to mocha_lsp.py — configurable via the "mocha.installPath" VS Code setting
    const config = workspace.getConfiguration('mocha');
    const serverScript = config.get('installPath');

    if (!serverScript) {
        window.showErrorMessage(
            'Mocha: "mocha.installPath" is not set. Please set it in VS Code settings ' +
            'to the path of mocha_lsp.py.'
        );
        return;
    }

    const serverOptions = {
        command: 'python',
        args: [serverScript],
        transport: TransportKind.stdio
    };

    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'mocha' }],
        synchronize: {
            fileEvents: workspace.createFileSystemWatcher('**/*.mch')
        }
    };

    client = new LanguageClient(
        'mocha-lsp',
        'Mocha Language Server',
        serverOptions,
        clientOptions
    );

    client.start();
    context.subscriptions.push(client);

    console.log('[mocha] LSP client started');
}

function deactivate() {
    if (client) {
        return client.stop();
    }
}

module.exports = { activate, deactivate };