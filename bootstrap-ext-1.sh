#!/bin/bash
set -e

mkdir -p mi-vscode/src/panels mi-vscode/media

# ─── mi-vscode/package.json ───
cat > mi-vscode/package.json <<'EOF'
{
  "name": "mi-vscode",
  "displayName": "mio",
  "description": "Bloques de código con IA",
  "version": "1.0.0",
  "publisher": "waimyapp-dev",
  "engines": { "vscode": "^1.85.0" },
  "categories": ["Other"],
  "activationEvents": ["onStartupFinished"],
  "main": "./out/extension.js",
  "contributes": {
    "viewsContainers": {
      "activitybar": [
        { "id": "mio", "title": "mio", "icon": "media/icon.svg" }
      ]
    },
    "views": {
      "mio": [
        { "id": "mio.blocksView", "name": "Bloques", "icon": "media/icon.svg" }
      ]
    },
    "commands": [
      { "command": "mio.newBlock", "title": "Aplicar bloque", "icon": "$(new-file)" },
      { "command": "mio.find", "title": "Buscar", "icon": "$(search)" },
      { "command": "mio.doctor", "title": "Diagnóstico", "icon": "$(pulse)" },
      { "command": "mio.setup", "title": "Inicializar proyecto", "icon": "$(tools)" },
      { "command": "mio.play", "title": "Ejecutar", "icon": "$(play)" },
      { "command": "mio.stopPlay", "title": "Detener", "icon": "$(debug-stop)" },
      { "command": "mio.copyExport", "title": "Exportar proyecto", "icon": "$(export)" },
      { "command": "mio.copySystemPrompt", "title": "Prompt de sistema", "icon": "$(book)" },
      { "command": "mio.refresh", "title": "Refrescar", "icon": "$(refresh)" },
      { "command": "mio.openBlock", "title": "Abrir bloque", "icon": "$(go-to-file)" }
    ],
    "menus": {
      "view/title": [
        { "command": "mio.play", "when": "view == mio.blocksView", "group": "navigation@1" },
        { "command": "mio.newBlock", "when": "view == mio.blocksView", "group": "navigation@2" },
        { "command": "mio.find", "when": "view == mio.blocksView", "group": "navigation@3" },
        { "command": "mio.doctor", "when": "view == mio.blocksView", "group": "navigation@4" },
        { "command": "mio.setup", "when": "view == mio.blocksView", "group": "navigation@5" },
        { "command": "mio.copyExport", "when": "view == mio.blocksView", "group": "navigation@6" },
        { "command": "mio.copySystemPrompt", "when": "view == mio.blocksView", "group": "navigation@7" },
        { "command": "mio.refresh", "when": "view == mio.blocksView", "group": "navigation@8" }
      ],
      "view/item/context": [
        { "command": "mio.openBlock", "when": "view == mio.blocksView && viewItem == block", "group": "inline@1" }
      ]
    },
    "viewsWelcome": [
      {
        "view": "mio.blocksView",
        "contents": "### mio\n\nTrabaja con IA sobre bloques de código.\n\n- $(new-file) [Aplicar bloque](command:mio.newBlock)\n- $(tools) [Inicializar proyecto](command:mio.setup)\n- $(pulse) [Diagnóstico](command:mio.doctor)\n- $(book) [Prompt de sistema](command:mio.copySystemPrompt)"
      }
    ]
  },
  "scripts": {
    "compile": "tsc -p ./",
    "package": "vsce package"
  },
  "devDependencies": {
    "@types/vscode": "^1.85.0",
    "@types/node": "^22.0.0",
    "@vscode/vsce": "^3.2.0",
    "typescript": "^5.6.0"
  }
}
EOF

# ─── mi-vscode/tsconfig.json ───
cat > mi-vscode/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "ES2022",
    "outDir": "out",
    "rootDir": "src",
    "lib": ["ES2022"],
    "sourceMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "types": ["node", "vscode"]
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "out"]
}
EOF

# ─── mi-vscode/.vscodeignore ───
cat > mi-vscode/.vscodeignore <<'EOF'
.vscode/**
.vscode-test/**
src/**
node_modules/**
**/*.ts
**/*.map
**/tsconfig.json
**/.gitignore
**/.vscodeignore
**/package-lock.json
../**
../*
../**/*
EOF

# ─── mi-vscode/media/icon.svg ───
cat > mi-vscode/media/icon.svg <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="7" height="7" rx="1.5"/>
  <rect x="14" y="3" width="7" height="7" rx="1.5"/>
  <rect x="3" y="14" width="7" height="7" rx="1.5"/>
  <rect x="14" y="14" width="7" height="7" rx="1.5"/>
</svg>
EOF

# ─── mi-vscode/src/mi-cli.ts ───
cat > mi-vscode/src/mi-cli.ts <<'EOF'
import { spawn } from "node:child_process";
import * as vscode from "vscode";

export async function mioRun(args: string[], stdin?: string): Promise<string> {
  const cwd = getWorkspaceRoot();
  return new Promise((resolve, reject) => {
    const child = spawn("mio", args, { cwd, shell: true });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d: any) => (stdout += d.toString()));
    child.stderr.on("data", (d: any) => (stderr += d.toString()));
    child.on("close", (code: number) => {
      if (code === 0) resolve(stdout);
      else reject(new Error((stderr || "exit " + code).trim()));
    });
    child.on("error", reject);
    if (stdin) {
      child.stdin.write(stdin);
      child.stdin.end();
    }
  });
}

export function getWorkspaceRoot(): string {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) throw new Error("No hay workspace abierto");
  return folders[0].uri.fsPath;
}
EOF

echo "OK estructura base de la extension"

