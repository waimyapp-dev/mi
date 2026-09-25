const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const EXT = path.join(ROOT, "mi-vscode");

console.log("update-v2b.cjs: extension.ts + package.json...\n");

// ─── extension.ts ───
const extensionTs = `import * as vscode from "vscode";
import * as path from "node:path";
import * as fs from "node:fs";
import { BlocksProvider } from "./treeProvider.js";
import { mioRun, getWorkspaceRoot } from "./mi-cli.js";
import { NewBlockPanel } from "./panels/newBlockPanel.js";
import { DoctorPanel } from "./panels/doctorPanel.js";
import { FindPanel } from "./panels/findPanel.js";
import { SetupPanel } from "./panels/setupPanel.js";
import { play, stopPlay, deployToCloudflare } from "./panels/playPanel.js";
import { buildBlockCopy, buildBlockWithRelatedCopy } from "./copyHelper.js";

export function activate(context: vscode.ExtensionContext) {
  const provider = new BlocksProvider();
  vscode.window.registerTreeDataProvider("mio.blocksView", provider);

  const reg = (cmd: string, fn: (...args: any[]) => any) =>
    context.subscriptions.push(vscode.commands.registerCommand(cmd, fn));

  reg("mio.refresh", () => provider.refresh());
  reg("mio.newBlock", () => NewBlockPanel.createOrShow());
  reg("mio.doctor", () => DoctorPanel.createOrShow());
  reg("mio.find", () => FindPanel.createOrShow());
  reg("mio.setup", () => SetupPanel.createOrShow());
  reg("mio.play", async () => { try { await play(); } catch (e: any) { vscode.window.showErrorMessage("play: " + e.message); } });
  reg("mio.stopPlay", () => stopPlay());
  reg("mio.deploy", async () => { try { await deployToCloudflare(); } catch (e: any) { vscode.window.showErrorMessage("deploy: " + e.message); } });

  reg("mio.openBlock", async (node: any) => {
    const id = node?.id; if (!id) return;
    const blocks = await provider.getBlocks();
    const b = blocks.find((x: any) => x.id === id); if (!b) return;
    const doc = await vscode.workspace.openTextDocument(b.file);
    const ed = await vscode.window.showTextDocument(doc);
    const pos = new vscode.Position(b.startLine - 1, 0);
    ed.revealRange(new vscode.Range(pos, pos));
  });

  reg("mio.copyBlock", async (node: any) => {
    const id = node?.id; if (!id) return;
    try {
      const text = await buildBlockCopy(id);
      await vscode.env.clipboard.writeText(text);
      vscode.window.showInformationMessage("Bloque '" + id + "' copiado. Pegalo en la IA.");
    } catch (e: any) {
      vscode.window.showErrorMessage("copyBlock: " + e.message);
    }
  });

  reg("mio.copyBlockWithRelated", async (node: any) => {
    const id = node?.id; if (!id) return;
    try {
      const root = getWorkspaceRoot();
      const text = await buildBlockWithRelatedCopy(id, root);
      await vscode.env.clipboard.writeText(text);
      vscode.window.showInformationMessage("Bloque '" + id + "' + relacionados copiados. Pegalo en la IA.");
    } catch (e: any) {
      vscode.window.showErrorMessage("copyBlockWithRelated: " + e.message);
    }
  });

  reg("mio.copySystemPrompt", async () => {
    try {
      const root = getWorkspaceRoot();
      const f = path.join(root, ".mi", "prompts", "ai-system.md");
      if (!fs.existsSync(f)) throw new Error("No existe .mi/prompts/ai-system.md. Ejecuta mio init.");
      const content = fs.readFileSync(f, "utf8");
      await vscode.env.clipboard.writeText(content);
      vscode.window.showInformationMessage("Prompt de sistema copiado.");
    } catch (e: any) { vscode.window.showErrorMessage(e.message); }
  });

  reg("mio.copyExport", async () => {
    try {
      const root = getWorkspaceRoot();
      const out = await mioRun(["list", "--json"]);
      const blocks = JSON.parse(out);
      let md = "# Proyecto: " + path.basename(root) + "\\n\\n";
      md += "**Bloques:** " + blocks.length + "\\n\\n";
      for (const b of blocks) {
        const content = fs.readFileSync(b.file, "utf8").split("\\n").slice(b.startLine - 1, b.endLine).join("\\n");
        md += "## " + b.id + (b.desc ? " [" + b.desc + "]" : "") + "\\n\\n";
        md += "\`\`\`\\n" + content + "\\n\`\`\`\\n\\n";
      }
      await vscode.env.clipboard.writeText(md);
      vscode.window.showInformationMessage("Proyecto exportado (" + md.length + " bytes).");
    } catch (e: any) { vscode.window.showErrorMessage("export: " + e.message); }
  });

  provider.refresh();
}

export function deactivate() {}
`;

fs.writeFileSync(path.join(EXT, "src", "extension.ts"), extensionTs, "utf8");
console.log("OK extension.ts");

// ─── package.json ───
const pkgPath = path.join(EXT, "package.json");
const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
pkg.version = "1.1.0";

// Asegurar que existen todos los comandos
const allCmds = [
  { command: "mio.newBlock", title: "Aplicar bloque", icon: "$(new-file)" },
  { command: "mio.copyBlock", title: "Copiar bloque", icon: "$(clippy)" },
  { command: "mio.copyBlockWithRelated", title: "Copiar bloque + relacionados", icon: "$(references)" },
  { command: "mio.find", title: "Buscar", icon: "$(search)" },
  { command: "mio.doctor", title: "Diagnostico", icon: "$(pulse)" },
  { command: "mio.setup", title: "Inicializar proyecto", icon: "$(tools)" },
  { command: "mio.play", title: "Ejecutar", icon: "$(play)" },
  { command: "mio.stopPlay", title: "Detener", icon: "$(debug-stop)" },
  { command: "mio.deploy", title: "Deploy a Cloudflare", icon: "$(cloud-upload)" },
  { command: "mio.copyExport", title: "Exportar proyecto", icon: "$(export)" },
  { command: "mio.copySystemPrompt", title: "Prompt de sistema", icon: "$(book)" },
  { command: "mio.refresh", title: "Refrescar", icon: "$(refresh)" },
  { command: "mio.openBlock", title: "Abrir bloque", icon: "$(go-to-file)" },
];

pkg.contributes.commands = allCmds;

// ─── menus view/title: play, deploy, refresh, newBlock, find, doctor, more ───
pkg.contributes.menus = pkg.contributes.menus || {};
pkg.contributes.menus["view/title"] = [
  { command: "mio.play",     when: "view == mio.blocksView", group: "1_principal@1" },
  { command: "mio.deploy",   when: "view == mio.blocksView", group: "1_principal@2" },
  { command: "mio.refresh",  when: "view == mio.blocksView", group: "1_principal@3" },
  { command: "mio.newBlock", when: "view == mio.blocksView", group: "1_principal@4" },
  { command: "mio.find",     when: "view == mio.blocksView", group: "1_principal@5" },
  { command: "mio.doctor",   when: "view == mio.blocksView", group: "1_principal@6" },
  { submenu: "mio.moreMenu", when: "view == mio.blocksView", group: "2_mas@1" },
];

// ─── Contexto de bloque: 2 botones inline (copiar + copiar con relacionados) + menu ───
pkg.contributes.menus["view/item/context"] = [
  // Botones inline (aparecen al pasar el mouse sobre el bloque)
  { command: "mio.copyBlock",            when: "view == mio.blocksView && viewItem == block", group: "inline@1" },
  { command: "mio.copyBlockWithRelated", when: "view == mio.blocksView && viewItem == block", group: "inline@2" },
  { command: "mio.openBlock",            when: "view == mio.blocksView && viewItem == block", group: "inline@3" },

  // Menu contextual (clic derecho)
  { command: "mio.copyBlock",            when: "view == mio.blocksView && viewItem == block", group: "1_copiar@1" },
  { command: "mio.copyBlockWithRelated", when: "view == mio.blocksView && viewItem == block", group: "1_copiar@2" },
  { command: "mio.openBlock",            when: "view == mio.blocksView && viewItem == block", group: "2_abrir@1" },
];

// ─── Submenu "Mas acciones" ───
pkg.contributes.submenus = [{ id: "mio.moreMenu", label: "Mas acciones" }];
pkg.contributes.menus["mio.moreMenu"] = [
  { command: "mio.setup",            group: "1_proyecto@1" },
  { command: "mio.copyExport",       group: "2_contexto@1" },
  { command: "mio.copySystemPrompt", group: "2_contexto@2" },
  { command: "mio.stopPlay",         group: "3_utils@1" },
];

fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n", "utf8");
console.log("OK package.json -> 1.1.0");

console.log("\n==========================================");
console.log("  Actualizado. Ahora ejecuta:");
console.log("==========================================");
console.log("  cd C:\\Users\\ICATEN\\Documents\\mio");
console.log("  npm install");
console.log("");