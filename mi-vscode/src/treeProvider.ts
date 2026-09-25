import * as vscode from "vscode";
import * as fs from "node:fs";
import { mioRun } from "./mi-cli.js";

export interface BlockItem {
  id: string;
  desc: string;
  file: string;
  startLine: number;
  endLine: number;
}

class BlockNode extends vscode.TreeItem {
  public readonly id: string;
  public readonly block: BlockItem;
  constructor(block: BlockItem) {
    super(block.id, vscode.TreeItemCollapsibleState.Collapsed);
    this.id = block.id;
    this.block = block;
    this.description = block.desc;
    this.tooltip = block.file + ":" + block.startLine + "\n(Clic para expandir el codigo)";
    this.contextValue = "block";
    this.iconPath = new vscode.ThemeIcon("symbol-method", new vscode.ThemeColor("charts.purple"));
    this.command = { command: "mio.openBlock", title: "Abrir", arguments: [this] };
  }
}

class CodeLineNode extends vscode.TreeItem {
  constructor(line: string, lineNum: number) {
    super(line.length > 0 ? line : " ", vscode.TreeItemCollapsibleState.None);
    this.contextValue = "codeLine";
    this.tooltip = "Linea " + lineNum;
  }
}

class GroupNode extends vscode.TreeItem {
  constructor(public readonly prefix: string, public readonly blocks: BlockItem[]) {
    super(prefix, vscode.TreeItemCollapsibleState.Expanded);
    this.description = blocks.length + " bloques";
    this.contextValue = "group";
    this.iconPath = new vscode.ThemeIcon("folder", new vscode.ThemeColor("charts.blue"));
  }
}

export class BlocksProvider implements vscode.TreeDataProvider<vscode.TreeItem> {
  private _onDidChange = new vscode.EventEmitter<void>();
  readonly onDidChangeTreeData = this._onDidChange.event;
  private cache: BlockItem[] | null = null;
  private expandedCache = new Map<string, vscode.TreeItem[]>();

  refresh() { this.cache = null; this.expandedCache.clear(); this._onDidChange.fire(); }

  async getBlocks(): Promise<BlockItem[]> {
    if (this.cache) return this.cache;
    try {
      const out = await mioRun(["list", "--json"]);
      this.cache = JSON.parse(out);
    } catch { this.cache = []; }
    return this.cache!;
  }

  getTreeItem(el: vscode.TreeItem) { return el; }

  async getChildren(el?: vscode.TreeItem): Promise<vscode.TreeItem[]> {
    const blocks = await this.getBlocks();

    if (!el) {
      const groups = new Map<string, BlockItem[]>();
      for (const b of blocks) {
        const p = b.id.split("-")[0];
        if (!groups.has(p)) groups.set(p, []);
        groups.get(p)!.push(b);
      }
      return [...groups.entries()].sort().map(([p, bs]) => new GroupNode(p, bs));
    }

    if (el instanceof GroupNode) {
      return el.blocks.map((b) => new BlockNode(b));
    }

    if (el instanceof BlockNode) {
      const cacheKey = el.block.id;
      if (this.expandedCache.has(cacheKey)) return this.expandedCache.get(cacheKey)!;
      try {
        const content = fs.readFileSync(el.block.file, "utf8");
        const all = content.split("\n");
        const start = el.block.startLine - 1;
        const end = el.block.endLine;
        const blockLines = all.slice(start, end);
        const MAX = 80;
        const shown = blockLines.slice(0, MAX);
        const items: vscode.TreeItem[] = shown.map((l, i) => new CodeLineNode(l, start + i + 1));
        if (blockLines.length > MAX) {
          items.push(new CodeLineNode("... (" + (blockLines.length - MAX) + " lineas mas)", 0));
        }
        this.expandedCache.set(cacheKey, items);
        return items;
      } catch (e: any) {
        return [new CodeLineNode("(no se pudo leer: " + e.message + ")", 0)];
      }
    }

    return [];
  }
}
