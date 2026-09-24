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
