#!/bin/bash
set -e

# ─── doctorPanel.ts ───
cat > mi-vscode/src/panels/doctorPanel.ts <<'DOCTOR_EOF'
import * as vscode from "vscode";
import { mioRun } from "../mi-cli.js";

export class DoctorPanel {
  public static current: DoctorPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  static createOrShow() {
    if (DoctorPanel.current) { DoctorPanel.current.panel.reveal(); DoctorPanel.current.load(); return; }
    const panel = vscode.window.createWebviewPanel(
      "mio.doctor", "Diagnostico", vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: false }
    );
    DoctorPanel.current = new DoctorPanel(panel);
  }

  private constructor(panel: vscode.WebviewPanel) {
    this.panel = panel;
    this.panel.webview.html = this.getHtml();
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(async (msg) => {
      if (msg.type === "ready" || msg.type === "refresh") await this.load();
    }, null, this.disposables);
  }

  private async load() {
    try {
      const out = await mioRun(["doctor", "--json"]);
      const lines = out.split("\n");
      let json = "";
      for (const l of lines) { if (l.trim().startsWith("{")) { json = l.trim(); break; } }
      if (!json) throw new Error("Sin JSON del CLI");
      this.panel.webview.postMessage({ type: "report", report: JSON.parse(json) });
    } catch (e: any) {
      this.panel.webview.postMessage({ type: "error", message: e.message });
    }
  }

  private getHtml(): string {
    return `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: var(--vscode-font-family); padding: 24px; color: var(--vscode-foreground); background: var(--vscode-editor-background); max-width: 780px; margin: 0 auto; font-size: 13px; }
      h1 { font-size: 16px; margin: 0 0 4px; }
      p.sub { font-size: 12px; opacity: 0.6; margin: 0 0 20px; }
      h2 { font-size: 13px; margin: 20px 0 8px; }
      .card { padding: 14px 18px; border-radius: 6px; background: var(--vscode-editorWidget-background); margin-bottom: 12px; border-left: 3px solid var(--vscode-focusBorder); }
      .card.ok { border-left-color: #2ea043; }
      .card.warn { border-left-color: #d29922; }
      .row { display: flex; justify-content: space-between; padding: 4px 0; }
      .badge { padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; }
      .badge.ok { background: #2ea043; color: white; }
      .badge.err { background: #f85149; color: white; }
      .badge.warn { background: #d29922; color: #1a1a1a; }
      button { padding: 6px 16px; background: var(--vscode-button-background); color: var(--vscode-button-foreground); border: none; border-radius: 3px; cursor: pointer; font-size: 12px; }
      #content { margin-top: 16px; }
      .empty { opacity: 0.5; font-style: italic; }
    </style></head><body>
      <h1>Diagnostico</h1>
      <p class="sub">Estado de bloques, anclajes y estructura.</p>
      <button id="refresh">Volver a analizar</button>
      <div id="content"><div class="empty">Analizando...</div></div>
      <script>
        var vscode = acquireVsCodeApi();
        document.getElementById("refresh").onclick = function(){ document.getElementById("content").innerHTML = '<div class="empty">Analizando...</div>'; vscode.postMessage({type:"refresh"}); };
        function esc(s){ return String(s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;"}[c];}); }
        function render(r) {
          var c = document.getElementById("content");
          var html = "<h2>Estructura</h2><div class=\\"card " + ((r.structure.hasPackageJson && r.structure.hasMiDir && r.structure.hasPrompts) ? "ok" : "warn") + "\\">";
          html += "<div class=\\"row\\"><span>package.json</span><span class=\\"badge " + (r.structure.hasPackageJson?"ok":"err") + "\\">" + (r.structure.hasPackageJson?"OK":"FALTA") + "</span></div>";
          html += "<div class=\\"row\\"><span>.mi/</span><span class=\\"badge " + (r.structure.hasMiDir?"ok":"err") + "\\">" + (r.structure.hasMiDir?"OK":"FALTA") + "</span></div>";
          html += "<div class=\\"row\\"><span>.mi/prompts/</span><span class=\\"badge " + (r.structure.hasPrompts?"ok":"err") + "\\">" + (r.structure.hasPrompts?"OK":"FALTA") + "</span></div></div>";
          html += "<h2>Bloques (" + r.blocks.total + ")</h2><div class=\\"card " + ((r.blocks.duplicates.length || r.blocks.orphanAnchors.length)?"warn":"ok") + "\\">";
          html += "<div class=\\"row\\"><span>Total</span><span>" + r.blocks.total + "</span></div>";
          if (r.blocks.duplicates.length) html += "<div class=\\"row\\"><span>IDs duplicados</span><span class=\\"badge err\\">" + r.blocks.duplicates.length + "</span></div>";
          if (r.blocks.orphanAnchors.length) html += "<div class=\\"row\\"><span>Anclajes huerfanos</span><span class=\\"badge warn\\">" + r.blocks.orphanAnchors.length + "</span></div>";
          if (!r.blocks.duplicates.length && !r.blocks.orphanAnchors.length) html += "<div class=\\"row\\"><span>Todo en orden</span><span class=\\"badge ok\\">OK</span></div>";
          html += "</div>";
          c.innerHTML = html;
        }
        window.addEventListener("message", function(ev){ var d=ev.data; if(d.type==="report") render(d.report); else if(d.type==="error") document.getElementById("content").innerHTML = '<div class="empty" style="color:#f85149">' + esc(d.message) + '</div>'; });
        vscode.postMessage({type:"ready"});
      </script>
    </body></html>`;
  }

  private dispose() {
    DoctorPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) this.disposables.pop()?.dispose();
  }
}
DOCTOR_EOF

# ─── findPanel.ts ───
cat > mi-vscode/src/panels/findPanel.ts <<'FIND_EOF'
import * as vscode from "vscode";
import { mioRun } from "../mi-cli.js";

export class FindPanel {
  public static current: FindPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  static createOrShow() {
    if (FindPanel.current) { FindPanel.current.panel.reveal(); return; }
    const panel = vscode.window.createWebviewPanel(
      "mio.find", "Buscar", vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: false }
    );
    FindPanel.current = new FindPanel(panel);
  }

  private constructor(panel: vscode.WebviewPanel) {
    this.panel = panel;
    this.panel.webview.html = this.getHtml();
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(async (msg) => {
      try {
        if (msg.type === "find") {
          const out = await mioRun(["find", msg.query, "--json"]);
          const lines = out.split("\n");
          let json = "";
          for (const l of lines) { if (l.trim().startsWith("{")) { json = l.trim(); break; } }
          if (!json) throw new Error("Sin JSON del CLI");
          this.panel.webview.postMessage({ type: "results", report: JSON.parse(json) });
        }
        if (msg.type === "openBlock") {
          const doc = await vscode.workspace.openTextDocument(msg.file);
          const ed = await vscode.window.showTextDocument(doc);
          const pos = new vscode.Position(msg.line - 1, 0);
          ed.revealRange(new vscode.Range(pos, pos), vscode.TextEditorRevealType.InCenter);
        }
      } catch (e: any) {
        this.panel.webview.postMessage({ type: "error", message: e.message });
      }
    }, null, this.disposables);
  }

  private getHtml(): string {
    return `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: var(--vscode-font-family); padding: 24px; color: var(--vscode-foreground); background: var(--vscode-editor-background); max-width: 800px; margin: 0 auto; font-size: 13px; }
      h1 { font-size: 15px; margin: 0 0 4px; }
      p.sub { font-size: 12px; opacity: 0.6; margin: 0 0 14px; }
      textarea { width: 100%; min-height: 80px; padding: 12px; background: var(--vscode-input-background); color: var(--vscode-input-foreground); border: 1px solid var(--vscode-input-border, #444); border-radius: 4px; font-family: var(--vscode-editor-font-family); font-size: 12px; resize: vertical; }
      textarea:focus { outline: 1px solid var(--vscode-focusBorder); }
      .actions { margin-top: 12px; display: flex; gap: 8px; }
      button { padding: 6px 16px; background: var(--vscode-button-background); color: var(--vscode-button-foreground); border: none; border-radius: 3px; cursor: pointer; font-size: 12px; font-weight: 500; }
      button.secondary { background: transparent; color: var(--vscode-foreground); border: 1px solid var(--vscode-panel-border, #444); }
      #count { font-size: 12px; opacity: 0.6; margin: 16px 0 8px; }
      .match { border: 1px solid var(--vscode-panel-border, #333); border-radius: 6px; margin-bottom: 10px; overflow: hidden; }
      .match-h { padding: 10px 14px; background: var(--vscode-editorWidget-background); display: flex; justify-content: space-between; align-items: center; }
      .match-id { font-family: var(--vscode-editor-font-family); font-weight: 700; color: var(--vscode-charts-blue); }
      .match-file { font-size: 11px; opacity: 0.6; font-family: var(--vscode-editor-font-family); margin-top: 2px; }
      .match-ctx { padding: 10px 14px; background: var(--vscode-editor-background); border-top: 1px solid var(--vscode-panel-border, #333); font-family: var(--vscode-editor-font-family); font-size: 11px; line-height: 1.6; white-space: pre; overflow-x: auto; }
      .empty { padding: 30px; text-align: center; opacity: 0.5; font-style: italic; }
    </style></head><body>
      <h1>Buscar en bloques</h1>
      <p class="sub">Pega un fragmento y busca en que bloque esta.</p>
      <textarea id="q" placeholder="import React from &quot;react&quot;"></textarea>
      <div class="actions">
        <button id="search">Buscar</button>
        <button id="clear" class="secondary">Limpiar</button>
      </div>
      <div id="count"></div>
      <div id="results"></div>
      <script>
        var vscode = acquireVsCodeApi();
        function esc(s){ return String(s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;"}[c];}); }
        function render(r) {
          var c = document.getElementById("results");
          var count = document.getElementById("count");
          if (!r.matches || r.matches.length === 0) { count.textContent=""; c.innerHTML='<div class="empty">Sin coincidencias en ' + r.totalBlocks + ' bloques.</div>'; return; }
          count.textContent = r.matches.length + " coincidencia(s) en " + r.totalBlocks + " bloques";
          c.innerHTML = "";
          r.matches.forEach(function(m, i) {
            var d = document.createElement("div");
            d.className = "match";
            var ctx = m.context.map(function(l){ return esc(l); }).join("\\n");
            d.innerHTML = '<div class="match-h"><div><div class="match-id">' + esc(m.blockId) + '</div><div class="match-file">' + esc(m.anchorFile || m.file) + ':' + m.lineInFile + '</div></div><button data-i="' + i + '" class="secondary">Abrir</button></div><div class="match-ctx">' + ctx + '</div>';
            c.appendChild(d);
          });
          c.querySelectorAll("button[data-i]").forEach(function(b){
            b.onclick = function() {
              var m = r.matches[parseInt(b.getAttribute("data-i"))];
              vscode.postMessage({type:"openBlock", file:m.file, line:m.lineInFile});
            };
          });
        }
        document.getElementById("search").onclick = function(){
          var q = document.getElementById("q").value;
          if (!q.trim()) return;
          document.getElementById("count").textContent = "Buscando...";
          vscode.postMessage({type:"find", query:q});
        };
        document.getElementById("clear").onclick = function(){
          document.getElementById("q").value="";
          document.getElementById("results").innerHTML="";
          document.getElementById("count").textContent="";
        };
        window.addEventListener("message", function(ev){
          var d=ev.data;
          if(d.type==="results") render(d.report);
          else if(d.type==="error") document.getElementById("results").innerHTML = '<div class="empty" style="color:#f85149">' + esc(d.message) + '</div>';
        });
      </script>
    </body></html>`;
  }

  private dispose() {
    FindPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) this.disposables.pop()?.dispose();
  }
}
FIND_EOF

echo "OK doctorPanel.ts + findPanel.ts"