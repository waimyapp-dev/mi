#!/bin/bash
set -e

# ─── setupPanel.ts ───
cat > mi-vscode/src/panels/setupPanel.ts <<'SETUP_EOF'
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
SETUP_EOF

# ─── playPanel.ts ───
cat > mi-vscode/src/panels/playPanel.ts <<'PLAY_EOF'
import * as vscode from "vscode";
import * as fs from "node:fs";
import * as path from "node:path";
import { getWorkspaceRoot } from "../mi-cli.js";

let devTerminal: vscode.Terminal | undefined;

export async function play() {
  const root = getWorkspaceRoot();
  const pkgPath = path.join(root, "package.json");
  if (!fs.existsSync(pkgPath)) {
    vscode.window.showWarningMessage("No hay package.json. Inicializa el proyecto primero.");
    return;
  }
  let devCmd = "npm run dev";
  let port = 5173;
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
    if (!pkg.scripts || !pkg.scripts.dev) {
      if (pkg.scripts && pkg.scripts.start) devCmd = "npm start";
      else { vscode.window.showWarningMessage("No hay script dev ni start."); return; }
    }
    const deps = { ...(pkg.dependencies || {}), ...(pkg.devDependencies || {}) };
    if (deps["next"]) port = 3000;
  } catch (e: any) {
    vscode.window.showErrorMessage("package.json invalido: " + e.message);
    return;
  }
  if (devTerminal) devTerminal.dispose();
  devTerminal = vscode.window.createTerminal({ name: "mio: dev", cwd: root, isTransient: true });
  devTerminal.show();
  devTerminal.sendText(devCmd);
  const url = "http://localhost:" + port;
  vscode.window.showInformationMessage("Arrancando en " + url + "... (4s)");
  await new Promise((r) => setTimeout(r, 4000));
  try { await vscode.commands.executeCommand("simpleBrowser.show", url); }
  catch (e) { vscode.window.showWarningMessage("Servidor corriendo. Abre: " + url); }
}

export function stopPlay() {
  if (devTerminal) {
    devTerminal.dispose();
    devTerminal = undefined;
    vscode.window.showInformationMessage("Servidor detenido.");
  }
}

export async function deployToCloudflare(): Promise<void> {
  const root = getWorkspaceRoot();
  const pkgPath = path.join(root, "package.json");
  if (!fs.existsSync(pkgPath)) {
    vscode.window.showWarningMessage("No hay package.json.");
    return;
  }
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  const projectName = pkg.name || path.basename(root);

  const choice = await vscode.window.showQuickPick(
    [
      { label: "$(rocket) Direct Upload (Wrangler)", description: "Sin Git. Build + deploy directo", action: "wrangler" },
      { label: "$(github) Git Integration", description: "Conectar repo en Cloudflare dashboard", action: "git" }
    ],
    { placeHolder: "Como quieres hacer el deploy?" }
  );
  if (!choice) return;

  if (choice.action === "git") {
    const url = "https://dash.cloudflare.com/?to=/:account/workers-and-pages";
    const sel = await vscode.window.showInformationMessage(
      "Abre Cloudflare -> Workers & Pages -> Create -> Pages -> Connect to Git.",
      "Abrir Cloudflare"
    );
    if (sel === "Abrir Cloudflare") vscode.env.openExternal(vscode.Uri.parse(url));
    return;
  }

  const term = vscode.window.createTerminal({ name: "mio: deploy", cwd: root, isTransient: true });
  term.show();
  term.sendText("npm run build");
  await new Promise((r) => setTimeout(r, 8000));
  term.sendText("npx wrangler pages deploy dist --project-name=" + projectName);
  vscode.window.showInformationMessage("Deploy en curso. Si es la primera vez: npx wrangler login");
}
PLAY_EOF

# ─── extension.ts ───
cat > mi-vscode/src/extension.ts <<'EXT_EOF'
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
EXT_EOF

echo "OK setupPanel.ts + playPanel.ts + extension.ts"