import * as vscode from "vscode";
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
  constructor(public readonly block: BlockItem) {
    super(block.id, vscode.TreeItemCollapsibleState.None);
    this.id = block.id;
    this.description = block.desc;
    this.tooltip = block.file + ":" + block.startLine;
    this.contextValue = "block";
    this.iconPath = new vscode.ThemeIcon("symbol-method", new vscode.ThemeColor("charts.purple"));
    this.command = { command: "mio.openBlock", title: "Abrir", arguments: [this] };
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

  refresh() { this.cache = null; this._onDidChange.fire(); }

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
    return [];
  }
}
