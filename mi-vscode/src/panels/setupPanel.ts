import * as vscode from "vscode";
import { mioRun } from "../mi-cli.js";

export class SetupPanel {
  public static current: SetupPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  static createOrShow() {
    if (SetupPanel.current) { SetupPanel.current.panel.reveal(); return; }
    const panel = vscode.window.createWebviewPanel(
      "mio.setup", "Inicializar proyecto", vscode.ViewColumn.One,
      { enableScripts: true, retainContextWhenHidden: true }
    );
    SetupPanel.current = new SetupPanel(panel);
  }

  private constructor(panel: vscode.WebviewPanel) {
    this.panel = panel;
    this.panel.webview.html = this.getHtml();
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(async (msg) => {
      try {
        if (msg.type === "close") { this.panel.dispose(); return; }
        if (msg.type === "setup") {
          this.panel.webview.postMessage({ type: "progress", message: "Inicializando .mi/..." });
          await mioRun(["init"]);
          this.panel.webview.postMessage({ type: "progress", message: "Creando proyecto " + msg.framework + "..." });
          await mioRun(["setup", msg.framework, "--lang", msg.lang, "--style", msg.style]);
          this.panel.webview.postMessage({ type: "ok", message: "Proyecto " + msg.framework + " creado." });
          vscode.commands.executeCommand("mio.refresh");
        }
      } catch (e: any) {
        this.panel.webview.postMessage({ type: "err", message: e.message });
      }
    }, null, this.disposables);
  }

  private getHtml(): string {
    return `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
      body { font-family: var(--vscode-font-family); padding: 0; margin: 0; color: var(--vscode-foreground); background: var(--vscode-editor-background); font-size: 13px; }
      .wrapper { max-width: 780px; margin: 0 auto; padding: 24px 20px 32px; }
      h1 { font-size: 16px; font-weight: 600; margin: 0 0 4px; }
      p.sub { font-size: 12px; color: var(--vscode-descriptionForeground); margin: 0 0 20px; }
      fieldset { border: 1px solid var(--vscode-panel-border, #333); border-radius: 6px; padding: 14px 16px; margin: 0 0 14px; }
      legend { font-size: 12px; font-weight: 600; padding: 0 6px; }
      .opts { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 8px; margin-top: 6px; }
      label { display: flex; flex-direction: column; padding: 10px 12px; border: 1px solid var(--vscode-panel-border, #333); border-radius: 4px; cursor: pointer; }
      label:hover { background: var(--vscode-list-hoverBackground); }
      label input { display: none; }
      label.selected { border-color: var(--vscode-focusBorder); background: var(--vscode-list-activeSelectionBackground); color: var(--vscode-list-activeSelectionForeground); }
      label .title { font-weight: 600; font-size: 12px; margin-bottom: 2px; }
      label .desc { font-size: 11px; opacity: 0.7; }
      .actions { display: flex; gap: 10px; align-items: center; margin-top: 16px; }
      button { padding: 8px 20px; cursor: pointer; background: var(--vscode-button-background); color: var(--vscode-button-foreground); border: none; border-radius: 4px; font-size: 13px; font-weight: 600; }
      button:disabled { opacity: 0.5; cursor: not-allowed; }
      button.secondary { background: transparent; color: var(--vscode-foreground); border: 1px solid var(--vscode-panel-border, #444); }
      #status { margin-top: 14px; padding: 10px 14px; border-radius: 4px; font-size: 12px; display: none; white-space: pre-wrap; font-family: var(--vscode-editor-font-family); max-height: 200px; overflow-y: auto; }
      #status.info { background: var(--vscode-editorWidget-background); border-left: 3px solid var(--vscode-focusBorder); display: block; }
      #status.ok { background: rgba(46,160,67,0.15); border-left: 3px solid #2ea043; display: block; }
      #status.err { background: rgba(248,81,73,0.15); border-left: 3px solid #f85149; display: block; }
      .preview { margin-top: 12px; padding: 12px 14px; background: var(--vscode-textCodeBlock-background); border-radius: 4px; font-family: var(--vscode-editor-font-family); font-size: 11px; color: var(--vscode-descriptionForeground); }
      .preview code { color: var(--vscode-foreground); }
    </style></head><body>
      <div class="wrapper">
        <h1>Inicializar proyecto</h1>
        <p class="sub">Elige el stack. Se creara la estructura base, se instalaran dependencias y se configuraran los bloques.</p>
        <fieldset><legend>Framework</legend><div class="opts" id="fw">
          <label data-value="react"><input type="radio" name="fw" value="react" checked><span class="title">React</span><span class="desc">Con Vite</span></label>
          <label data-value="vue"><input type="radio" name="fw" value="vue"><span class="title">Vue 3</span><span class="desc">Con Vite</span></label>
          <label data-value="svelte"><input type="radio" name="fw" value="svelte"><span class="title">Svelte</span><span class="desc">Con Vite</span></label>
          <label data-value="next"><input type="radio" name="fw" value="next"><span class="title">Next.js</span><span class="desc">App Router</span></label>
          <label data-value="vanilla"><input type="radio" name="fw" value="vanilla"><span class="title">Vanilla</span><span class="desc">HTML + JS/TS</span></label>
        </div></fieldset>
        <fieldset><legend>Lenguaje</legend><div class="opts" id="lang">
          <label data-value="ts"><input type="radio" name="lang" value="ts" checked><span class="title">TypeScript</span><span class="desc">.ts / .tsx</span></label>
          <label data-value="js"><input type="radio" name="lang" value="js"><span class="title">JavaScript</span><span class="desc">.js / .jsx</span></label>
        </div></fieldset>
        <fieldset><legend>Estilos</legend><div class="opts" id="style">
          <label data-value="tailwind"><input type="radio" name="style" value="tailwind" checked><span class="title">Tailwind CSS</span><span class="desc">Clases utilitarias</span></label>
          <label data-value="css-modules"><input type="radio" name="style" value="css-modules"><span class="title">CSS Modules</span><span class="desc">*.module.css</span></label>
          <label data-value="plain"><input type="radio" name="style" value="plain"><span class="title">CSS plano</span><span class="desc">index.css</span></label>
        </div></fieldset>
        <div class="preview" id="preview"></div>
        <div class="actions">
          <button id="go">Crear proyecto</button>
          <button id="cancel" class="secondary">Cancelar</button>
        </div>
        <div id="status"></div>
      </div>
      <script>
        var vscode = acquireVsCodeApi();
        function selectLabel(l) { var n=l.querySelector("input").name; document.querySelectorAll("input[name=\\"" + n + "\\"]").forEach(function(i){ i.closest("label").classList.remove("selected"); }); l.classList.add("selected"); l.querySelector("input").checked=true; updatePreview(); }
        document.querySelectorAll("label").forEach(function(l) { if (l.querySelector("input").checked) l.classList.add("selected"); l.addEventListener("click", function(){ selectLabel(l); }); });
        function getVal(id) { var e=document.querySelector("#" + id + " input:checked"); return e ? e.value : null; }
        function updatePreview() { var f=getVal("fw"), l=getVal("lang"), s=getVal("style"); document.getElementById("preview").innerHTML = "Se ejecutara: <code>mio setup " + f + " --lang " + l + " --style " + s + "</code>"; }
        function setStatus(k, t) { var el=document.getElementById("status"); if(!k){el.style.display="none";return;} el.className=k; el.textContent=t; }
        document.getElementById("go").onclick = function() {
          document.getElementById("go").disabled=true; document.getElementById("cancel").disabled=true;
          setStatus("info", "Creando proyecto...");
          vscode.postMessage({ type:"setup", framework:getVal("fw"), lang:getVal("lang"), style:getVal("style") });
        };
        document.getElementById("cancel").onclick = function() { vscode.postMessage({type:"close"}); };
        window.addEventListener("message", function(ev){ var d=ev.data; if(d.type==="ok"){ setStatus("ok","\\u2713 " + d.message); document.getElementById("go").disabled=false; document.getElementById("cancel").disabled=false; } else if(d.type==="err"){ setStatus("err","\\u2717 " + d.message); document.getElementById("go").disabled=false; document.getElementById("cancel").disabled=false; } else if(d.type==="progress"){ setStatus("info", d.message); } });
        updatePreview();
      </script>
    </body></html>`;
  }

  private dispose() {
    SetupPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) this.disposables.pop()?.dispose();
  }
}
