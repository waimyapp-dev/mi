#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════
# treeProvider.ts
# ═══════════════════════════════════════════════════════════
cat > mi-vscode/src/treeProvider.ts <<'EOF'
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
EOF

# ═══════════════════════════════════════════════════════════
# newBlockPanel.ts
# ═══════════════════════════════════════════════════════════
cat > mi-vscode/src/panels/newBlockPanel.ts <<'PANEL_EOF'
import * as vscode from "vscode";
import { mioRun } from "../mi-cli.js";

export class NewBlockPanel {
  public static current: NewBlockPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  static createOrShow() {
    if (NewBlockPanel.current) { NewBlockPanel.current.panel.reveal(); return; }
    const panel = vscode.window.createWebviewPanel(
      "mio.newBlock", "Aplicar bloque", vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: false }
    );
    NewBlockPanel.current = new NewBlockPanel(panel);
  }

  private constructor(panel: vscode.WebviewPanel) {
    this.panel = panel;
    this.panel.webview.html = this.getHtml();
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(async (msg) => {
      if (msg.type === "apply") {
        try {
          const out = await mioRun(["inject"], msg.code);
          this.panel.webview.postMessage({ type: "ok", message: out.trim() });
          vscode.commands.executeCommand("mio.refresh");
        } catch (e: any) {
          this.panel.webview.postMessage({ type: "err", message: e.message });
        }
      }
    }, null, this.disposables);
  }

  private getHtml(): string {
    return `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      * { box-sizing: border-box; }
      body { font-family: var(--vscode-font-family); padding: 0; margin: 0; color: var(--vscode-foreground); background: var(--vscode-editor-background); font-size: 13px; }
      .wrapper { max-width: 680px; margin: 0 auto; padding: 24px 20px 32px; }
      h1 { font-size: 15px; font-weight: 600; margin: 0 0 4px; }
      p.hint { font-size: 12px; color: var(--vscode-descriptionForeground); margin: 0 0 14px; }
      code { background: var(--vscode-textCodeBlock-background); padding: 1px 5px; border-radius: 3px; font-size: 11px; font-family: var(--vscode-editor-font-family); }
      textarea { width: 100%; min-height: 200px; max-height: 400px; padding: 12px 14px; background: var(--vscode-input-background); color: var(--vscode-input-foreground); border: 1px solid var(--vscode-input-border, transparent); border-radius: 4px; font-family: var(--vscode-editor-font-family); font-size: 12px; line-height: 1.6; resize: vertical; outline: none; }
      textarea:focus { border-color: var(--vscode-focusBorder); }
      .footer { display: flex; align-items: center; justify-content: space-between; margin-top: 14px; }
      button { padding: 6px 16px; cursor: pointer; background: var(--vscode-button-background); color: var(--vscode-button-foreground); border: none; border-radius: 3px; font-size: 12px; font-weight: 500; }
      button:hover:not(:disabled) { background: var(--vscode-button-hoverBackground); }
      button:disabled { opacity: 0.5; cursor: not-allowed; }
      button.secondary { background: transparent; color: var(--vscode-foreground); border: 1px solid var(--vscode-panel-border, #444); }
      #msg { margin-top: 14px; padding: 10px 14px; border-radius: 4px; font-size: 12px; display: none; white-space: pre-wrap; font-family: var(--vscode-editor-font-family); max-height: 180px; overflow-y: auto; }
      #msg.ok { background: rgba(46,160,67,0.15); border-left: 3px solid #2ea043; display: block; }
      #msg.err { background: rgba(248,81,73,0.15); border-left: 3px solid #f85149; display: block; }
    </style></head><body>
      <div class="wrapper">
        <h1>Aplicar bloque</h1>
        <p class="hint">Pega uno o varios bloques. Cada uno se procesa individualmente.<br><code>// @anchor:ruta</code> · <code>// @block:id [desc]</code> ... <code>// @end:id</code></p>
        <textarea id="code" spellcheck="false" placeholder="// @anchor:src/App.tsx&#10;// @block:app-001 [App]&#10;export function App() {&#10;  return &lt;h1&gt;Hola&lt;/h1&gt;;&#10;}&#10;// @end:app-001"></textarea>
        <div class="footer">
          <div><button id="apply">Aplicar</button> <button id="clear" class="secondary">Limpiar</button></div>
          <span style="font-size:11px;opacity:0.6">Ctrl+Enter para aplicar</span>
        </div>
        <div id="msg"></div>
      </div>
      <script>
        var vscode = acquireVsCodeApi();
        var txt = document.getElementById("code");
        var msg = document.getElementById("msg");
        function show(k, t) { if (!k) { msg.style.display="none"; return; } msg.className=k; msg.textContent=(k==="ok"?"\\u2713 ":"\\u2717 ")+t; msg.style.display="block"; }
        function apply() { var c=txt.value; if(!c.trim()){show("err","Pega al menos un bloque.");return;} document.getElementById("apply").disabled=true; vscode.postMessage({type:"apply",code:c}); }
        document.getElementById("apply").onclick = apply;
        document.getElementById("clear").onclick = function(){ txt.value=""; show("", ""); txt.focus(); };
        document.addEventListener("keydown", function(e){ if((e.ctrlKey||e.metaKey)&&e.key==="Enter"){ e.preventDefault(); apply(); } });
        window.addEventListener("message", function(ev){ var d=ev.data; document.getElementById("apply").disabled=false; if(d.type==="ok"){show("ok",d.message);txt.value="";} else if(d.type==="err"){show("err",d.message);} });
      </script>
    </body></html>`;
  }

  private dispose() {
    NewBlockPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) this.disposables.pop()?.dispose();
  }
}
PANEL_EOF

echo "OK treeProvider.ts + newBlockPanel.ts"