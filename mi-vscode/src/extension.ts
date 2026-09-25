import * as vscode from "vscode";
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
      let md = "# Proyecto: " + path.basename(root) + "\n\n";
      md += "**Bloques:** " + blocks.length + "\n\n";
      for (const b of blocks) {
        const content = fs.readFileSync(b.file, "utf8").split("\n").slice(b.startLine - 1, b.endLine).join("\n");
        md += "## " + b.id + (b.desc ? " [" + b.desc + "]" : "") + "\n\n";
        md += "```\n" + content + "\n```\n\n";
      }
      await vscode.env.clipboard.writeText(md);
      vscode.window.showInformationMessage("Proyecto exportado (" + md.length + " bytes).");
    } catch (e: any) { vscode.window.showErrorMessage("export: " + e.message); }
  });

  provider.refresh();
}

export function deactivate() {}
